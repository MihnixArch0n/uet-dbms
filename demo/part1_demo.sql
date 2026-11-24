-- Demo Phần I (PostgreSQL). Chạy từng đoạn trong psql:
--   docker compose -f docker/docker-compose.yml exec pg psql -U postgres
-- Chụp màn hình kết quả mỗi đoạn để đưa vào báo cáo.

-- 1. Phiên bản và các tham số liên quan tới độ bền
SELECT version();
SHOW data_directory;
SHOW wal_level;
SHOW synchronous_commit;
SHOW full_page_writes;
SHOW shared_buffers;
SHOW data_checksums;

-- 2. Các tiến trình của PostgreSQL (backend và tiến trình nền)
SELECT pid, backend_type, state FROM pg_stat_activity ORDER BY backend_type;

-- 3. Tạo bảng, nạp dữ liệu bằng COPY, truy vấn
CREATE TABLE demo_customer (id int PRIMARY KEY, name text, city text, balance numeric(12,2));
COPY demo_customer FROM PROGRAM 'seq 1 100000 | awk ''{print $1",Khach "$1",Ha Noi,"($1%1000)*10}''' WITH (FORMAT csv);
SELECT city, count(*), avg(balance) FROM demo_customer GROUP BY city;

-- 4. Kế hoạch thực thi: index scan và seq scan
EXPLAIN ANALYZE SELECT * FROM pgbench_accounts WHERE aid = 12345;
EXPLAIN ANALYZE SELECT count(*) FROM pgbench_accounts WHERE abalance > 1000;

-- 5. Giao dịch và vị trí WAL
SELECT pg_current_wal_lsn();
BEGIN;
UPDATE demo_customer SET balance = balance + 100 WHERE id = 1;
COMMIT;
SELECT pg_current_wal_lsn();
SELECT pg_walfile_name(pg_current_wal_lsn());

-- 6. Thống kê WAL và checkpoint
SELECT * FROM pg_stat_wal;
SELECT * FROM pg_stat_bgwriter;

-- 7. Người dùng và phân quyền
CREATE ROLE teller LOGIN PASSWORD 'teller123';
GRANT SELECT, UPDATE ON pgbench_accounts TO teller;
\dp pgbench_accounts

-- 8. Dọn dẹp
DROP TABLE demo_customer;
DROP OWNED BY teller; DROP ROLE teller;
