#!/usr/bin/env bash
# Thí nghiệm C: crash khi đang có tải, đo RPO / RTO, kiểm tra bất biến và hỏng dữ liệu.
# Dùng: bash scripts/run_expC.sh <pg|mysql> <process|os> <giá_trị_tham_số_flush> <lần>
#   ví dụ: bash scripts/run_expC.sh pg process off 1
#          bash scripts/run_expC.sh mysql process 2 1
# Mức os (DBMS chạy trong máy ảo KVM/libvirt tên dbvm) cần đặt thêm:
#   REMOTE="ssh bench@<IP_máy_ảo>"  DB_HOST=<IP_máy_ảo>
#   COMPOSE=/home/bench/uet-dbms/docker/docker-compose.yml   (đường dẫn TRONG máy ảo)
#   VM_CRASH_CMD="virsh destroy dbvm"      # ngắt nguồn đột ngột
#   VM_START_CMD="virsh start dbvm"        # bật lại (container tự chạy lại nhờ restart: always)
# Tùy chỉnh: THREADS=8 MIN_LOAD=60 MAX_LOAD=120
source "$(dirname "$0")/common.sh"
DB=${1:?pg|mysql}; LEVEL=${2:?process|os}; CFG=${3:?giá trị tham số}; REP=${4:-1}
THREADS=${THREADS:-8}; MIN_LOAD=${MIN_LOAD:-60}; MAX_LOAD=${MAX_LOAD:-120}
if [ "$DB" = pg ]; then PARAM=synchronous_commit; else PARAM=innodb_flush_log_at_trx_commit; fi
SVC=$DB; CONTAINER=bench-$DB
tag="C_${DB}_${LEVEL}_${CFG}_r${REP}"; out="$RAW/$tag"
rm -f "$out".*

log "== $tag: chuẩn bị"
wait_ready "$DB" >/dev/null
set_param "$DB" "$PARAM" "$CFG"
db_file "$DB" "$ROOT/scripts/reset_state.sql" >/dev/null
if [ "$DB" = pg ]; then pg_sql "VACUUM pgbench_history;" >/dev/null; pg_sql "CHECKPOINT;" >/dev/null; fi
SCALE=$(db_scale "$DB")   # client phải sinh aid/tid/bid đúng phạm vi dữ liệu, nếu không bất biến sẽ sai
init_inv=$(invariant "$DB")
[ "$init_inv" = "0|0|0|0|0" ] || { log "Trạng thái ban đầu chưa về 0: $init_inv"; exit 1; }
{ echo "db|$DB"; echo "level|$LEVEL"; echo "param|$PARAM"; echo "value|$(show_param "$DB" "$PARAM")"; echo "rep|$REP"; } > "$out.meta"

log "Bơm tải $THREADS luồng"
"$PY" "$ROOT/workload/crash_client.py" --db "$DB" --host "$DB_HOST" --threads "$THREADS" --scale "$SCALE" --out "$out" \
  > "$out.client.log" 2>&1 &
CLIENT=$!
load=$(( MIN_LOAD + RANDOM % (MAX_LOAD - MIN_LOAD + 1) ))
sleep "$load"

if [ "$LEVEL" = process ]; then
  log "CRASH tiến trình sau ${load}s: docker kill -s KILL $CONTAINER"
  $REMOTE docker kill -s KILL "$CONTAINER" >/dev/null
else
  log "CRASH hệ điều hành sau ${load}s: $VM_CRASH_CMD"
  $VM_CRASH_CMD
fi
t_crash=$(now)   # thời điểm lệnh gây sự cố đã trả về

# Cho client 10 giây để tự dừng (mất kết nối), sau đó buộc dừng.
sleep 10; kill "$CLIENT" 2>/dev/null || true; wait "$CLIENT" 2>/dev/null || true

log "Khởi động lại"
t_start=$(now)
if [ "$LEVEL" = process ]; then
  dc start "$SVC" >/dev/null
else
  $VM_START_CMD
  until $REMOTE true 2>/dev/null; do sleep 1; done           # chờ máy ảo nhận ssh
  t_vm_up=$(now)
fi
t_ready=$(wait_ready "$DB" 900)
log "Sẵn sàng sau $(awk "BEGIN{printf \"%.2f\", $t_ready - $t_start}") s"

# Log của lần khởi động này
dc logs --no-log-prefix --since "$(date -u -d "@${t_start%.*}" +%Y-%m-%dT%H:%M:%SZ)" "$SVC" > "$out.dblog" 2>&1 || true
"$PY" "$ROOT/scripts/parse_recovery_log.py" "$DB" "$out.dblog" > "$out.recovery" || true

# Dữ liệu còn lại sau phục hồi
db_sql "$DB" "SELECT txn_id FROM pgbench_history WHERE txn_id IS NOT NULL;" > "$out.present"
check_invariant "$DB" > "$out.inv"

# Kiểm tra hỏng dữ liệu
if [ "$DB" = pg ]; then
  integ=$(pg_sql "CREATE EXTENSION IF NOT EXISTS amcheck;
                  SELECT bt_index_check('pgbench_accounts_pkey'), bt_index_check('pgbench_tellers_pkey'),
                         bt_index_check('pgbench_branches_pkey');
                  SELECT count(*) FROM pgbench_accounts; SELECT count(*) FROM pgbench_history;" 2>&1 \
          && echo OK || echo FAIL)
  dc logs --no-log-prefix --since "$(date -u -d "@${t_start%.*}" +%Y-%m-%dT%H:%M:%SZ)" "$SVC" 2>&1 \
    | grep -qi "checksum" && integ="$integ CHECKSUM_ERROR"
else
  integ=$(my_sql "CHECK TABLE pgbench_accounts, pgbench_tellers, pgbench_branches, pgbench_history;" 2>&1)
  echo "$integ" | awk -F'\t' '$3=="status" && $4!="OK"{bad=1} END{exit bad}' && integ=OK || integ="FAIL"
fi
echo "$integ" | tail -1 > "$out.integrity"

{
  echo "t_crash|$t_crash"; echo "t_start|$t_start"; echo "t_ready|$t_ready"
  [ -n "${t_vm_up:-}" ] && echo "t_vm_up|$t_vm_up"
  echo "load_s|$load"
  echo "redo_s|$(grep '^redo_s|' "$out.recovery" | cut -d'|' -f2)"
  echo "redo_bytes|$(grep '^redo_bytes|' "$out.recovery" | cut -d'|' -f2)"
  echo "rto_log_s|$(grep '^rto_log_s|' "$out.recovery" | cut -d'|' -f2)"
  echo "integrity|$(tail -1 "$out.integrity" | awk '{print $NF}')"
} > "$out.times"

"$PY" "$ROOT/scripts/reconcile.py" "$out"
