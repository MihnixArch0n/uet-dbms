#!/usr/bin/env bash
# Thí nghiệm B: chi phí bảo vệ trang (Full-Page Writes / doublewrite).
# Flush log luôn ở cấu hình chặt (synchronous_commit=on / innodb_flush_log_at_trx_commit=1).
# Dùng: bash scripts/run_expB.sh pg      hoặc   bash scripts/run_expB.sh mysql
# Tùy chỉnh: CLIENTS=8 REPS=3 TIME=300 WARMUP=60 SAMPLE=10
# Thí nghiệm phụ B2 (chỉ pg): EXTRA_PARAM=checkpoint_timeout EXTRA_VALUES="30s 5min" CONFIGS=on bash scripts/run_expB.sh pg
source "$(dirname "$0")/common.sh"
DB=${1:?"Cần tham số: pg hoặc mysql"}
CLIENTS=${CLIENTS:-8}
REPS=${REPS:-3}
TIME=${TIME:-300}
WARMUP=${WARMUP:-60}
SAMPLE=${SAMPLE:-10}
EXTRA_PARAM=${EXTRA_PARAM:-}
EXTRA_VALUES=${EXTRA_VALUES:-"default"}

if [ "$DB" = pg ]; then
  PARAM=full_page_writes; CONFIGS=${CONFIGS:-"on off"}
else
  PARAM=innodb_doublewrite; CONFIGS=${CONFIGS:-"ON OFF"}
fi

# Lấy mẫu chỉ số mỗi SAMPLE giây trong lúc chạy -> file CSV dạng "giây_thứ,tên,giá_trị"
sampler() {
  local out=$1 t0; t0=$(date +%s)
  while true; do
    local t=$(( $(date +%s) - t0 ))
    snapshot "$DB" 2>/dev/null | sed "s/^/$t|/" >> "$out" || true
    sleep "$SAMPLE"
  done
}

wait_ready "$DB" >/dev/null   # chờ DBMS sẵn sàng (vừa start xong)
reset_params "$DB"
# Đưa dữ liệu về trạng thái ban đầu để bất biến sau mỗi lần chạy có ý nghĩa
db_file "$DB" "$ROOT/scripts/reset_state.sql" >/dev/null
[ "$(invariant "$DB")" = "0|0|0|0|0" ] || { log "Trạng thái ban đầu chưa về 0: $(invariant "$DB")"; exit 1; }
for extra in $EXTRA_VALUES; do
  if [ -n "$EXTRA_PARAM" ] && [ "$extra" != default ]; then set_param "$DB" "$EXTRA_PARAM" "$extra"; fi
  for cfg in $CONFIGS; do
    set_param "$DB" "$PARAM" "$cfg"
    for r in $(seq 1 "$REPS"); do
      suffix=""; [ -n "$EXTRA_PARAM" ] && suffix="_${EXTRA_PARAM}-${extra}"
      tag="B_${DB}_${cfg}${suffix}_c${CLIENTS}_r${r}"; out="$RAW/$tag"
      log "== $tag"
      restart_db "$DB"
      if [ "$DB" = pg ]; then pg_sql "CHECKPOINT;" >/dev/null; pg_sql "SELECT pg_stat_reset_shared('wal');" >/dev/null; fi
      {
        echo "db|$DB"; echo "param|$PARAM"; echo "value|$(show_param "$DB" "$PARAM")"
        echo "extra_param|$EXTRA_PARAM"; echo "extra_value|$extra"
        echo "clients|$CLIENTS"; echo "rep|$r"; echo "time|$TIME"
      } > "$out.meta"
      # Warmup trước khi chụp "before": khoảng before→after chỉ chứa lượt đo chính thức
      sysbench_warmup "$DB" "$CLIENTS" "$WARMUP" || log "warmup lỗi"
      snapshot "$DB" > "$out.before"
      : > "$out.samples"
      sampler "$out.samples" & SP=$!
      IO_PID=""
      if command -v iostat >/dev/null; then iostat -dxm 10 > "$out.iostat" & IO_PID=$!; fi
      run_sysbench "$DB" "$CLIENTS" "$TIME" 0 "$out.txt" || log "sysbench lỗi, xem $out.txt"
      kill "$SP" 2>/dev/null || true
      [ -n "$IO_PID" ] && kill "$IO_PID" 2>/dev/null || true
      snapshot "$DB" > "$out.after"
      check_invariant "$DB" > "$out.inv"
      if [ "$DB" = pg ]; then
        L1=$(grep '^lsn|' "$out.before" | cut -d'|' -f2); L2=$(grep '^lsn|' "$out.after" | cut -d'|' -f2)
        dc exec -T pg pg_waldump --stats=record --start="$L1" --end="$L2" -p /var/lib/postgresql/data/pg_wal \
          > "$out.waldump" 2>&1 || log "pg_waldump lỗi (WAL đã bị xóa?), xem $out.waldump"
        dc logs --since "$((TIME + WARMUP + 30))s" pg 2>&1 | grep -E 'checkpoint (starting|complete)' > "$out.checkpoints" || true
      fi
      log "   $(grep -E 'transactions:' "$out.txt" | head -1 | xargs)"
    done
  done
done
reset_params "$DB"
log "Xong thí nghiệm B cho $DB."
