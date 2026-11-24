-- Bất biến: A = T = B = H (chạy được trên cả PostgreSQL và MySQL)
-- Kết quả: a_sum, t_sum, b_sum, h_sum, h_count
SELECT (SELECT COALESCE(SUM(abalance), 0) FROM pgbench_accounts) AS a_sum,
       (SELECT COALESCE(SUM(tbalance), 0) FROM pgbench_tellers)  AS t_sum,
       (SELECT COALESCE(SUM(bbalance), 0) FROM pgbench_branches) AS b_sum,
       (SELECT COALESCE(SUM(delta), 0)    FROM pgbench_history)  AS h_sum,
       (SELECT COUNT(*)                   FROM pgbench_history)  AS h_count;
