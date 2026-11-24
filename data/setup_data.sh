#!/usr/bin/env bash
# Sinh dữ liệu ngân hàng pgbench trong PostgreSQL rồi chép đúng dữ liệu đó sang MySQL.
# Dùng: bash data/setup_data.sh [scale]      (mặc định scale = 50)
# Yêu cầu: cả hai container đang chạy (docker compose up -d pg mysql).
source "$(dirname "$0")/../scripts/common.sh"
SCALE="${1:-50}"
OUT="$ROOT/results/env/data_check.txt"

log "1/5 Sinh dữ liệu pgbench scale=$SCALE trong PostgreSQL"
dc exec -T pg pgbench -U postgres -i -s "$SCALE" postgres
pg_sql "ALTER TABLE pgbench_history ADD COLUMN IF NOT EXISTS txn_id bigint;"
pg_sql "VACUUM ANALYZE;"

log "2/5 Xuất 3 bảng ra CSV (bảng lịch sử đang rỗng)"
for t in branches tellers accounts; do
  case $t in
    branches) cols="bid, bbalance" ;;
    tellers)  cols="tid, bid, tbalance" ;;
    accounts) cols="aid, bid, abalance" ;;
  esac
  pg_sql "\\copy (SELECT $cols FROM pgbench_$t ORDER BY 1) TO STDOUT WITH CSV" > "$ROOT/data/pgbench_$t.csv"
  log "   pgbench_$t.csv: $(wc -l < "$ROOT/data/pgbench_$t.csv") dòng"
done

log "3/5 Tạo lược đồ trong MySQL"
my_file "$ROOT/data/mysql_schema.sql"

log "4/5 Nạp CSV vào MySQL (accounts mất vài phút)"
# Chép CSV vào thư mục secure_file_priv bên trong container (không mount thư mục data/ vào
# container, vì entrypoint của MySQL sẽ chown thư mục đó và dừng nếu nó chỉ đọc)
for t in branches tellers accounts; do
  dc cp "$ROOT/data/pgbench_$t.csv" "mysql:/var/lib/mysql-files/pgbench_$t.csv"
done
my_sql "LOAD DATA INFILE '/var/lib/mysql-files/pgbench_branches.csv' INTO TABLE pgbench_branches
        FIELDS TERMINATED BY ',' (bid, bbalance);"
my_sql "LOAD DATA INFILE '/var/lib/mysql-files/pgbench_tellers.csv' INTO TABLE pgbench_tellers
        FIELDS TERMINATED BY ',' (tid, bid, tbalance);"
my_sql "LOAD DATA INFILE '/var/lib/mysql-files/pgbench_accounts.csv' INTO TABLE pgbench_accounts
        FIELDS TERMINATED BY ',' (aid, bid, abalance) SET filler = '';"
my_sql "ANALYZE TABLE pgbench_branches, pgbench_tellers, pgbench_accounts, pgbench_history;" >/dev/null
dc exec -T mysql sh -c 'rm -f /var/lib/mysql-files/pgbench_*.csv'

log "5/5 Đối chiếu hai hệ và kiểm tra bất biến ban đầu"
Q="SELECT (SELECT COUNT(*) FROM pgbench_branches), (SELECT COUNT(*) FROM pgbench_tellers),
          (SELECT COUNT(*) FROM pgbench_accounts), (SELECT SUM(aid) FROM pgbench_accounts),
          (SELECT SUM(bid) FROM pgbench_accounts), (SELECT SUM(bid) FROM pgbench_tellers);"
{
  echo "# Đối chiếu dữ liệu $(date -Iseconds), scale=$SCALE"
  echo "# branches|tellers|accounts|sum(aid)|sum(accounts.bid)|sum(tellers.bid)"
  echo "postgresql: $(pg_sql "$Q")"
  echo "mysql:      $(my_sql "$Q" | tr '\t' '|')"
  echo "# Bất biến ban đầu (a_sum|t_sum|b_sum|h_sum|h_count), phải toàn 0"
  echo "postgresql: $(invariant pg)"
  echo "mysql:      $(invariant mysql)"
  echo "# Kích thước"
  echo "postgresql: $(pg_sql "SELECT pg_size_pretty(pg_database_size('postgres'));")"
  echo "mysql:      $(my_sql "SELECT CONCAT(ROUND(SUM(data_length+index_length)/1024/1024), ' MB') FROM information_schema.tables WHERE table_schema='bank';")"
} | tee "$OUT"
log "Đã ghi $OUT. Hai dòng đối chiếu phải giống hệt nhau."
