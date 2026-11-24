-- Đưa dữ liệu về trạng thái ban đầu: mọi số dư = 0, bảng lịch sử rỗng.
-- Chạy được trên cả PostgreSQL và MySQL.
TRUNCATE TABLE pgbench_history;
UPDATE pgbench_accounts SET abalance = 0 WHERE abalance <> 0;
UPDATE pgbench_tellers  SET tbalance = 0 WHERE tbalance <> 0;
UPDATE pgbench_branches SET bbalance = 0 WHERE bbalance <> 0;
