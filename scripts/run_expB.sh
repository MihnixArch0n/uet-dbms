#!/usr/bin/env bash
# Thí nghiệm B: chi phí bảo vệ trang (Full-Page Writes / doublewrite).
# Flush log luôn ở cấu hình chặt (synchronous_commit=on / innodb_flush_log_at_trx_commit=1).
# Dùng:
#   bash scripts/run_expB.sh pg              # chỉ PostgreSQL (B.PG.01, B.PG.02)
#   bash scripts/run_expB.sh mysql           # chỉ MySQL (B.MY.01, B.MY.02)
#   bash scripts/run_expB.sh all             # chạy cả 4 kịch bản (pg rồi mysql)
#   bash scripts/run_expB.sh all --quick     # test nhanh cả 4 kịch bản (REPS=1 TIME=10 WARMUP=5 SAMPLE=5)
# Tùy chỉnh: CLIENTS=8 REPS=3 TIME=300 WARMUP=60 SAMPLE=10 QUICK=1
# Thí nghiệm phụ B2 (chỉ pg): EXTRA_PARAM=checkpoint_timeout EXTRA_VALUES="30s 5min" CONFIGS=on bash scripts/run_expB.sh pg
source "$(dirname "$0")/common.sh"
# Dù script kết thúc thế nào (xong, lỗi, Ctrl+C) cũng trả doublewrite về ON trong bench.cnf,
# để thí nghiệm C không vô tình chạy với cấu hình không bền vững
restore_dblwr() { sed -i "s/^innodb_doublewrite = .*/innodb_doublewrite = ON/" "$ROOT/docker/mysql/bench.cnf"; }
trap restore_dblwr EXIT

TARGET=""
QUICK=${QUICK:-0}
for arg in "$@"; do
  case "$arg" in
    --quick|-q) QUICK=1 ;;
    pg|mysql|all) TARGET="$arg" ;;
    *) log "Tham số không hợp lệ: $arg (chỉ nhận pg, mysql, all, --quick)"; exit 1 ;;
  esac
done
: "${TARGET:?"Cần tham số: pg, mysql hoặc all (ví dụ: bash scripts/run_expB.sh all --quick)"}"

if [ "$QUICK" = 1 ]; then
  CLIENTS=${CLIENTS:-8}
  REPS=${REPS:-1}
  TIME=${TIME:-10}
  WARMUP=${WARMUP:-5}
  SAMPLE=${SAMPLE:-5}
  log "Chế độ test nhanh (--quick): REPS=$REPS TIME=${TIME}s WARMUP=${WARMUP}s SAMPLE=${SAMPLE}s CLIENTS=$CLIENTS"
else
  CLIENTS=${CLIENTS:-8}
  REPS=${REPS:-3}
  TIME=${TIME:-300}
  WARMUP=${WARMUP:-60}
  SAMPLE=${SAMPLE:-10}
fi
EXTRA_PARAM=${EXTRA_PARAM:-}
EXTRA_VALUES=${EXTRA_VALUES:-"default"}

# Lấy mẫu chỉ số mỗi SAMPLE giây trong lúc chạy -> file CSV dạng "giây_thứ|tên|giá_trị"
sampler() {
  local db=$1 out=$2 t0; t0=$(date +%s)
  while true; do
    local t=$(( $(date +%s) - t0 ))
    snapshot "$db" 2>/dev/null | sed "s/^/$t|/" >> "$out" || true
    sleep "$SAMPLE"
  done
}

# Đặt tham số thí nghiệm (riêng innodb_doublewrite của MySQL phải sửa qua bench.cnf rồi restart)
set_exp_param() {
  local db=$1 name=$2 value=$3
  if [ "$db" = mysql ] && [ "$name" = innodb_doublewrite ]; then
    sed -i "s/^innodb_doublewrite = .*/innodb_doublewrite = $value/" "$ROOT/docker/mysql/bench.cnf"
    restart_db "$db"
    log "$db: $name = $(show_param "$db" "$name")"
  else
    set_param "$db" "$name" "$value"
  fi
}

run_db_exp() {
  local db=$1 other_db param cfgs
  if [ "$db" = pg ]; then
    other_db=mysql
    param=full_page_writes
    cfgs=${CONFIGS:-"on off"}
  else
    other_db=pg
    param=innodb_doublewrite
    cfgs=${CONFIGS:-"ON OFF"}
  fi

  log "Cô lập container: dừng $other_db, bật $db..."
  dc stop "$other_db" >/dev/null 2>&1 || true
  dc start "$db" >/dev/null
  wait_ready "$db" >/dev/null
  [ "$db" = mysql ] && sed -i "s/^innodb_doublewrite = .*/innodb_doublewrite = ON/" "$ROOT/docker/mysql/bench.cnf"
  reset_params "$db"

  for extra in $EXTRA_VALUES; do
    if [ -n "$EXTRA_PARAM" ] && [ "$extra" != default ]; then set_exp_param "$db" "$EXTRA_PARAM" "$extra"; fi
    for cfg in $cfgs; do
      set_exp_param "$db" "$param" "$cfg"
      for r in $(seq 1 "$REPS"); do
        suffix=""; [ -n "$EXTRA_PARAM" ] && suffix="_${EXTRA_PARAM}-${extra}"
        tag="B_${db}_${cfg}${suffix}_c${CLIENTS}_r${r}"; out="$RAW/$tag"
        log "== $tag"
        # Reset dữ liệu về 0 trước mỗi lần chạy để các test độc lập nhau
        db_file "$db" "$ROOT/scripts/reset_state.sql" >/dev/null
        [ "$(invariant "$db")" = "0|0|0|0|0" ] || { log "Trạng thái ban đầu chưa về 0: $(invariant "$db")"; exit 1; }
        restart_db "$db"
        if [ "$db" = pg ]; then pg_sql "CHECKPOINT;" >/dev/null; pg_sql "SELECT pg_stat_reset_shared('wal');" >/dev/null; fi
        {
          echo "db|$db"; echo "param|$param"; echo "value|$(show_param "$db" "$param")"
          echo "extra_param|$EXTRA_PARAM"; echo "extra_value|$extra"
          echo "clients|$CLIENTS"; echo "rep|$r"; echo "time|$TIME"
        } > "$out.meta"
        # Warmup trước khi chụp "before": khoảng before→after chỉ chứa lượt đo chính thức
        sysbench_warmup "$db" "$CLIENTS" "$WARMUP" || log "warmup lỗi"
        snapshot "$db" > "$out.before"
        : > "$out.samples"
        sampler "$db" "$out.samples" & SP=$!
        IO_PID=""
        if command -v iostat >/dev/null; then iostat -dxm 10 > "$out.iostat" & IO_PID=$!; fi
        run_sysbench "$db" "$CLIENTS" "$TIME" 0 "$out.txt" || log "sysbench lỗi, xem $out.txt"
        kill "$SP" 2>/dev/null || true
        [ -n "$IO_PID" ] && kill "$IO_PID" 2>/dev/null || true
        snapshot "$db" > "$out.after"
        check_invariant "$db" > "$out.inv"
        if [ "$db" = pg ]; then
          L1=$(grep '^lsn|' "$out.before" | cut -d'|' -f2); L2=$(grep '^lsn|' "$out.after" | cut -d'|' -f2)
          WAL_DIR="$(pg_sql 'SHOW data_directory;')/pg_wal"
          dc exec -T pg pg_waldump --stats=record --start="$L1" --end="$L2" -p "$WAL_DIR" \
            > "$out.waldump" 2>&1 || log "pg_waldump lỗi (WAL đã bị xóa?), xem $out.waldump"
          dc logs --since "$((TIME + WARMUP + 30))s" pg 2>&1 | grep -E 'checkpoint (starting|complete)' > "$out.checkpoints" || true
        fi
        log "   $(grep -E 'transactions:' "$out.txt" | head -1 | xargs) | inv=$(cat "$out.inv")"
      done
    done
  done
  [ "$db" = mysql ] && sed -i "s/^innodb_doublewrite = .*/innodb_doublewrite = ON/" "$ROOT/docker/mysql/bench.cnf"
  reset_params "$db"
  log "Xong thí nghiệm B cho $db."
}

if [ "$TARGET" = all ]; then
  run_db_exp pg
  run_db_exp mysql
else
  run_db_exp "$TARGET"
fi
