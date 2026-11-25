#!/usr/bin/env bash
# Thí nghiệm A: chi phí flush log khi COMMIT.
# Chỉ đổi tham số flush; Full-Page Writes / doublewrite luôn BẬT.
# Dùng: bash scripts/run_expA.sh pg      hoặc   bash scripts/run_expA.sh mysql
# Tùy chỉnh: CLIENTS="1 8 32" REPS=3 TIME=300 WARMUP=60 bash scripts/run_expA.sh pg
source "$(dirname "$0")/common.sh"
DB=${1:?"Cần tham số: pg hoặc mysql"}
CLIENTS=${CLIENTS:-"1 8 32"}
REPS=${REPS:-3}
TIME=${TIME:-300}
WARMUP=${WARMUP:-60}

if [ "$DB" = pg ]; then
  PARAM=synchronous_commit; CONFIGS=${CONFIGS:-"on off"}
else
  PARAM=innodb_flush_log_at_trx_commit; CONFIGS=${CONFIGS:-"1 2 0"}
fi

wait_ready "$DB" >/dev/null   # chờ DBMS sẵn sàng (vừa start xong)
reset_params "$DB"
# Đưa dữ liệu về trạng thái ban đầu để bất biến sau mỗi lần chạy có ý nghĩa
db_file "$DB" "$ROOT/scripts/reset_state.sql" >/dev/null
[ "$(invariant "$DB")" = "0|0|0|0|0" ] || { log "Trạng thái ban đầu chưa về 0: $(invariant "$DB")"; exit 1; }
for cfg in $CONFIGS; do
  set_param "$DB" "$PARAM" "$cfg"
  for c in $CLIENTS; do
    for r in $(seq 1 "$REPS"); do
      tag="A_${DB}_${cfg}_c${c}_r${r}"; out="$RAW/$tag"
      log "== $tag"
      restart_db "$DB"                                   # mọi lần chạy cùng điểm xuất phát
      if [ "$DB" = pg ]; then pg_sql "CHECKPOINT;" >/dev/null; pg_sql "SELECT pg_stat_reset_shared('wal');" >/dev/null; fi
      {
        echo "db|$DB"; echo "param|$PARAM"; echo "value|$(show_param "$DB" "$PARAM")"
        echo "clients|$c"; echo "rep|$r"; echo "time|$TIME"
      } > "$out.meta"
      # Warmup trước khi chụp "before": khoảng before→after chỉ chứa lượt đo chính thức
      sysbench_warmup "$DB" "$c" "$WARMUP" || log "warmup lỗi"
      snapshot "$DB" > "$out.before"
      IO_PID=""
      if command -v iostat >/dev/null; then iostat -dxm 10 > "$out.iostat" & IO_PID=$!; fi
      run_sysbench "$DB" "$c" "$TIME" 0 "$out.txt" || log "sysbench lỗi, xem $out.txt"
      [ -n "$IO_PID" ] && kill "$IO_PID" 2>/dev/null || true
      snapshot "$DB" > "$out.after"
      check_invariant "$DB" > "$out.inv"
      log "   $(grep -E 'transactions:' "$out.txt" | head -1 | xargs) | bất biến: $(cut -d'|' -f1 "$out.inv")"
    done
  done
done
reset_params "$DB"
log "Xong thí nghiệm A cho $DB. Kết quả trong $RAW/A_${DB}_*"
