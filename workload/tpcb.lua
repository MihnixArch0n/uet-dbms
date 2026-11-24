#!/usr/bin/env sysbench
-- Giao dịch TPC-B giống giao dịch mặc định của pgbench.
-- Chạy được cho cả --db-driver=pgsql và --db-driver=mysql.
-- Mỗi event() = một giao dịch gửi/rút tiền.

sysbench.cmdline.options = {
  scale = {"Hệ số scale của dữ liệu pgbench", 50}
}

function thread_init()
  drv = sysbench.sql.driver()
  con = drv:connect()
end

function thread_done()
  con:disconnect()
end

function event()
  local scale = sysbench.opt.scale
  local aid   = sysbench.rand.uniform(1, 100000 * scale)
  local bid   = sysbench.rand.uniform(1, scale)
  local tid   = sysbench.rand.uniform(1, 10 * scale)
  local delta = sysbench.rand.uniform(0, 10000) - 5000

  con:query("BEGIN")
  con:query(string.format("UPDATE pgbench_accounts SET abalance = abalance + %d WHERE aid = %d", delta, aid))
  con:query(string.format("SELECT abalance FROM pgbench_accounts WHERE aid = %d", aid))
  con:query(string.format("UPDATE pgbench_tellers SET tbalance = tbalance + %d WHERE tid = %d", delta, tid))
  con:query(string.format("UPDATE pgbench_branches SET bbalance = bbalance + %d WHERE bid = %d", delta, bid))
  con:query(string.format(
    "INSERT INTO pgbench_history (tid, bid, aid, delta, mtime) VALUES (%d, %d, %d, %d, CURRENT_TIMESTAMP)",
    tid, bid, aid, delta))
  con:query("COMMIT")
end
