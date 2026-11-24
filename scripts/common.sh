#!/usr/bin/env bash
# Hàm dùng chung cho mọi script thí nghiệm. Dùng: source scripts/common.sh
# Biến môi trường có thể đặt trước khi chạy:
#   REMOTE   : rỗng = DBMS chạy trên máy này; "ssh bench@192.168.56.10" = DBMS chạy trong máy ảo
#   DB_HOST  : địa chỉ để sysbench / Python kết nối (mặc định 127.0.0.1)
#   COMPOSE  : đường dẫn file compose (trên máy chạy DBMS)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REMOTE="${REMOTE:-}"
DB_HOST="${DB_HOST:-127.0.0.1}"
COMPOSE="${COMPOSE:-$ROOT/docker/docker-compose.yml}"
# dc ...: docker compose trên máy chạy DBMS. Với REMOTE (ssh), tham số được trích dẫn lại để giữ nguyên khoảng trắng.
dc() {
  if [ -z "$REMOTE" ]; then docker compose -f "$COMPOSE" "$@"
  else $REMOTE "$(printf '%q ' docker compose -f "$COMPOSE" "$@")"; fi
}
RAW="$ROOT/results/raw"
mkdir -p "$RAW"

# Python của môi trường uv (tạo bằng "uv sync"); không có thì dùng python3 của hệ thống
if [ -x "$ROOT/.venv/bin/python" ]; then PY="$ROOT/.venv/bin/python"; else PY=python3; fi

now() { date +%s.%N; }
log() { echo "[$(date +%H:%M:%S)] $*" >&2; }

# ---------- chạy SQL ----------
# pg_sql "SQL"            -> in kết quả dạng không căn lề (-A), không tiêu đề (-t)
pg_sql()  { dc exec -T pg psql -U postgres -d postgres -v ON_ERROR_STOP=1 -At -c "$1"; }
pg_sqlx() { dc exec -T pg psql -U postgres -d postgres -v ON_ERROR_STOP=1 -Atx -c "$1"; }  # dạng "cột|giá trị"
pg_file() { dc exec -T pg psql -U postgres -d postgres -v ON_ERROR_STOP=1 -At < "$1"; }
my_sql()  { dc exec -T -e MYSQL_PWD=bench mysql mysql -uroot -N -B bank -e "$1"; }
my_file() { dc exec -T -e MYSQL_PWD=bench mysql mysql -uroot -N -B bank < "$1"; }

db_sql()  { if [ "$1" = pg ]; then pg_sql "$2"; else my_sql "$2"; fi; }
db_file() { if [ "$1" = pg ]; then pg_file "$2"; else my_file "$2"; fi; }

# ---------- trạng thái DBMS ----------
# Chờ tới khi DBMS nhận truy vấn; in ra thời điểm sẵn sàng (epoch, giây)
wait_ready() {
  local db=$1 timeout=${2:-600} t0; t0=$(date +%s)
  while true; do
    if [ "$db" = pg ]; then
      dc exec -T pg psql -U postgres -d postgres -At -c "SELECT 1" >/dev/null 2>&1 && break
    else
      dc exec -T -e MYSQL_PWD=bench mysql mysql -uroot -N -B -e "SELECT 1" >/dev/null 2>&1 && break
    fi
    if (( $(date +%s) - t0 > timeout )); then log "TIMEOUT chờ $db"; return 1; fi
    sleep 0.2
  done
  now
}

restart_db() { local db=$1; dc restart "$db" >/dev/null; wait_ready "$db" >/dev/null; }

# Đặt một tham số rồi khởi động lại DBMS để áp dụng
#   set_param pg synchronous_commit off
#   set_param mysql innodb_flush_log_at_trx_commit 2
set_param() {
  local db=$1 name=$2 value=$3
  if [ "$db" = pg ]; then
    pg_sql "ALTER SYSTEM SET $name = '$value';" >/dev/null
  else
    my_sql "SET PERSIST_ONLY $name = $value;" >/dev/null
  fi
  restart_db "$db"
  log "$db: $name = $(show_param "$db" "$name")"
}

show_param() {
  local db=$1 name=$2
  if [ "$db" = pg ]; then pg_sql "SHOW $name;"; else my_sql "SELECT @@GLOBAL.$name;"; fi
}

# Đưa tất cả tham số thí nghiệm về cấu hình bền vững
reset_params() {
  local db=$1
  if [ "$db" = pg ]; then
    pg_sql "ALTER SYSTEM RESET ALL;" >/dev/null
  else
    my_sql "RESET PERSIST;" >/dev/null
  fi
  restart_db "$db"
}

# ---------- chỉ số ----------
# Ảnh chụp chỉ số log/ghi đĩa, mỗi dòng "tên|giá trị"
snapshot() {
  local db=$1
  if [ "$db" = pg ]; then
    pg_sqlx "SELECT extract(epoch FROM now()) AS ts, pg_current_wal_lsn() AS lsn,
                    pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')::bigint AS lsn_bytes,
                    wal_records, wal_fpi, wal_bytes, wal_write, wal_sync, wal_sync_time,
                    (SELECT xact_commit FROM pg_stat_database WHERE datname = 'postgres') AS xact_commit
             FROM pg_stat_wal;"
  else
    my_sql "SELECT 'ts', UNIX_TIMESTAMP(NOW(6));
            SELECT 'lsn_bytes', VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_redo_log_current_lsn';
            SHOW GLOBAL STATUS WHERE Variable_name IN
              ('Innodb_os_log_written','Innodb_os_log_fsyncs','Innodb_data_fsyncs','Innodb_data_written',
               'Innodb_dblwr_pages_written','Innodb_dblwr_writes','Innodb_pages_written','Com_commit');" | tr '\t' '|'
  fi
}

# ---------- workload ----------
# Scale của dữ liệu đang có = số chi nhánh (pgbench tạo 1 chi nhánh cho mỗi đơn vị scale)
db_scale() { db_sql "$1" "SELECT COUNT(*) FROM pgbench_branches;"; }

# run_sysbench <pg|mysql> <threads> <time_s> <warmup_s> <file_out>
run_sysbench() {
  local db=$1 threads=$2 time=$3 warmup=$4 out=$5 conn
  if [ "$db" = pg ]; then
    conn="--db-driver=pgsql --pgsql-host=$DB_HOST --pgsql-port=5432 --pgsql-user=postgres --pgsql-password=bench --pgsql-db=postgres"
  else
    conn="--db-driver=mysql --mysql-host=$DB_HOST --mysql-port=3306 --mysql-user=root --mysql-password=bench --mysql-db=bank"
  fi
  # Sysbench 1.0.20 không hỗ trợ --warmup-time, nên chạy warmup riêng.
  # shellcheck disable=SC2086
  if [ "$warmup" -gt 0 ]; then
    sysbench "$ROOT/workload/tpcb.lua" $conn --scale="$(db_scale "$db")" --threads="$threads" --time="$warmup" \
      --report-interval=0 run > /dev/null 2>&1 || return $?
  fi

  # Lượt đo chính thức
  # shellcheck disable=SC2086
  sysbench "$ROOT/workload/tpcb.lua" $conn --scale="$(db_scale "$db")" --threads="$threads" --time="$time" \
    --report-interval=10 --histogram=on --percentile=99 run > "$out" 2>&1
}

# Kiểm tra bất biến, in "a_sum|t_sum|b_sum|h_sum|h_count"
invariant() { db_file "$1" "$ROOT/scripts/invariant.sql" | tr '\t' '|'; }

check_invariant() {
  local line; line=$(invariant "$1")
  IFS='|' read -r a t b h c <<< "$line"
  if [ "$a" = "$t" ] && [ "$t" = "$b" ] && [ "$b" = "$h" ]; then echo "OK|$line"; else echo "FAIL|$line"; fi
}
