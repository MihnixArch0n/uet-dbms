#!/usr/bin/env python3
"""Bơm tải TPC-B và ghi nhật ký những giao dịch đã được DBMS xác nhận COMMIT.

Chạy trên máy thật (ngoài máy ảo), để nhật ký không mất khi DBMS bị crash.

Mỗi luồng i ghi hai file:
  <out>.sent.<i> : txn_id ngay TRƯỚC khi gửi COMMIT (giao dịch có thể đã commit hoặc chưa)
  <out>.ack.<i>  : "txn_id,epoch" ngay SAU khi COMMIT trả về thành công
Sau crash: INFLIGHT = sent - ack; LOST = ack - (txn_id có trong pgbench_history).

Dùng:
  uv run python workload/crash_client.py --db pg    --host 127.0.0.1 --threads 8 --out results/raw/C_test
  uv run python workload/crash_client.py --db mysql --host 127.0.0.1 --threads 8 --out results/raw/C_test
Dừng khi mọi luồng mất kết nối (DBMS crash), hoặc hết --duration giây.
"""
import argparse
import random
import sys
import threading
import time

SQL = [
    "UPDATE pgbench_accounts SET abalance = abalance + %s WHERE aid = %s",
    "SELECT abalance FROM pgbench_accounts WHERE aid = %s",
    "UPDATE pgbench_tellers SET tbalance = tbalance + %s WHERE tid = %s",
    "UPDATE pgbench_branches SET bbalance = bbalance + %s WHERE bid = %s",
    "INSERT INTO pgbench_history (tid, bid, aid, delta, mtime, txn_id) "
    "VALUES (%s, %s, %s, %s, CURRENT_TIMESTAMP, %s)",
]


def connect(args):
    if args.db == "pg":
        import psycopg
        con = psycopg.connect(host=args.host, port=5432, user="postgres", password="bench",
                              dbname="postgres", connect_timeout=5)
    else:
        import pymysql
        con = pymysql.connect(host=args.host, port=3306, user="root", password="bench",
                              database="bank", connect_timeout=5, autocommit=False)
    return con


acked_total = 0
lock = threading.Lock()
stop_at = None


def worker(no, args):
    global acked_total
    scale = args.scale
    try:
        con = connect(args)
    except Exception as e:  # noqa: BLE001
        print(f"[luồng {no}] không kết nối được: {e}", file=sys.stderr)
        return
    cur = con.cursor()
    n = 0
    with open(f"{args.out}.sent.{no}", "a", buffering=1) as sent, \
         open(f"{args.out}.ack.{no}", "a", buffering=1) as ack:
        while stop_at is None or time.time() < stop_at:
            n += 1
            txn = no * 10**9 + n
            aid = random.randint(1, 100000 * scale)
            bid = random.randint(1, scale)
            tid = random.randint(1, 10 * scale)
            delta = random.randint(-5000, 5000)
            try:
                cur.execute(SQL[0], (delta, aid))
                cur.execute(SQL[1], (aid,))
                cur.fetchall()
                cur.execute(SQL[2], (delta, tid))
                cur.execute(SQL[3], (delta, bid))
                cur.execute(SQL[4], (tid, bid, aid, delta, txn))
                sent.write(f"{txn}\n")          # đã gửi xong lệnh, sắp COMMIT
                con.commit()
                ack.write(f"{txn},{time.time():.6f}\n")   # DBMS đã xác nhận COMMIT
                with lock:
                    acked_total += 1
            except Exception as e:  # noqa: BLE001  mất kết nối = DBMS đã crash
                print(f"[luồng {no}] dừng: {type(e).__name__}: {str(e)[:80]}", file=sys.stderr)
                return
    try:
        con.close()
    except Exception:  # noqa: BLE001
        pass


def main():
    global stop_at
    p = argparse.ArgumentParser()
    p.add_argument("--db", choices=["pg", "mysql"], required=True)
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--threads", type=int, default=8)
    p.add_argument("--scale", type=int, default=50)
    p.add_argument("--duration", type=float, default=0, help="giây; 0 = chạy tới khi DBMS crash")
    p.add_argument("--out", required=True, help="tiền tố file nhật ký")
    args = p.parse_args()
    if args.duration > 0:
        stop_at = time.time() + args.duration

    threads = [threading.Thread(target=worker, args=(i + 1, args), daemon=True) for i in range(args.threads)]
    for t in threads:
        t.start()
    t0 = time.time()
    while any(t.is_alive() for t in threads):
        time.sleep(5)
        print(f"{time.time() - t0:6.0f}s  đã xác nhận: {acked_total}", flush=True)
    print(f"Kết thúc. Tổng giao dịch đã xác nhận: {acked_total}", flush=True)


if __name__ == "__main__":
    main()
