#!/usr/bin/env python3
"""Kiểm chứng tính đúng đắn trên MySQL (D1.1 & D1.2) - Kịch bản TV2.

D1.1 (Kiểm chứng dương): Chạy tải TPC-B (mặc định 60s, 8 threads),
     kiểm tra 4 tổng bằng nhau và số bản ghi lịch sử khớp số transactions sysbench.
D1.2 (Kiểm chứng âm): Cố tình làm lệch số dư tài khoản, chứng minh bất biến báo FAIL,
     sau đó reset dữ liệu và xác nhận bất biến về OK|0|0|0|0|0.

Sử dụng:
    uv run python scripts/verify_d1.py [--test {all,d1.1,d1.2}] [--time SECONDS] [--threads N]
"""

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path
import pymysql

ROOT = Path(__file__).resolve().parent.parent
WORKLOAD_PATH = ROOT / "workload" / "tpcb.lua"

GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
BOLD = "\033[1m"
RESET = "\033[0m"


def log_info(msg: str):
    print(f"{CYAN}[INFO]{RESET} {msg}")


def log_pass(msg: str):
    print(f"{GREEN}[PASS]{RESET} {BOLD}{msg}{RESET}")


def log_fail(msg: str):
    print(f"{RED}[FAIL]{RESET} {BOLD}{msg}{RESET}")


def log_warn(msg: str):
    print(f"{YELLOW}[WARN]{RESET} {msg}")


def get_connection(args) -> pymysql.Connection:
    try:
        return pymysql.connect(
            host=args.host,
            port=args.port,
            user=args.user,
            password=args.password,
            database=args.db,
            autocommit=True,
            charset="utf8mb4",
        )
    except pymysql.MySQLError as e:
        log_fail(f"Không thể kết nối tới MySQL ({args.host}:{args.port}, db={args.db}): {e}")
        log_info("Hãy đảm bảo container MySQL đang chạy: docker compose -f docker/docker-compose.yml start mysql")
        sys.exit(1)


def check_tables_exist(conn: pymysql.Connection) -> bool:
    required_tables = {"pgbench_accounts", "pgbench_branches", "pgbench_tellers", "pgbench_history"}
    with conn.cursor() as cur:
        cur.execute("SHOW TABLES;")
        tables = {row[0].lower() for row in cur.fetchall()}
    missing = required_tables - tables
    if missing:
        log_fail(f"Thiếu các bảng trong database MySQL: {', '.join(sorted(missing))}")
        log_info("Vui lòng khởi tạo dữ liệu bằng lệnh: bash data/setup_data.sh 50")
        return False
    return True


def get_scale(conn: pymysql.Connection) -> int:
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM pgbench_branches;")
        row = cur.fetchone()
        return int(row[0]) if row else 0


def reset_state(conn: pymysql.Connection):
    log_info("Đưa dữ liệu về trạng thái sạch (reset_state)...")
    with conn.cursor() as cur:
        cur.execute("TRUNCATE TABLE pgbench_history;")
        cur.execute("UPDATE pgbench_accounts SET abalance = 0 WHERE abalance <> 0;")
        cur.execute("UPDATE pgbench_tellers SET tbalance = 0 WHERE tbalance <> 0;")
        cur.execute("UPDATE pgbench_branches SET bbalance = 0 WHERE bbalance <> 0;")


def get_invariant(conn: pymysql.Connection):
    query = """
    SELECT (SELECT COALESCE(SUM(abalance), 0) FROM pgbench_accounts) AS a_sum,
           (SELECT COALESCE(SUM(tbalance), 0) FROM pgbench_tellers)  AS t_sum,
           (SELECT COALESCE(SUM(bbalance), 0) FROM pgbench_branches) AS b_sum,
           (SELECT COALESCE(SUM(delta), 0)    FROM pgbench_history)  AS h_sum,
           (SELECT COUNT(*)                   FROM pgbench_history)  AS h_count;
    """
    with conn.cursor() as cur:
        cur.execute(query)
        a, t, b, h, count = cur.fetchone()
    a, t, b, h, count = int(a), int(t), int(b), int(h), int(count)
    is_ok = (a == t == b == h)
    status = "OK" if is_ok else "FAIL"
    raw_line = f"{status}|{a}|{t}|{b}|{h}|{count}"
    return is_ok, a, t, b, h, count, raw_line


def corrupt_balance(conn: pymysql.Connection, aid: int = 1, delta: int = 1):
    log_info(f"Cố tình sửa số dư: UPDATE pgbench_accounts SET abalance = abalance + {delta} WHERE aid = {aid}...")
    with conn.cursor() as cur:
        cur.execute("UPDATE pgbench_accounts SET abalance = abalance + %s WHERE aid = %s;", (delta, aid))


def run_sysbench(args, scale: int) -> tuple[int, int, str]:
    cmd = [
        "sysbench",
        str(WORKLOAD_PATH),
        "--db-driver=mysql",
        f"--mysql-host={args.host}",
        f"--mysql-port={args.port}",
        f"--mysql-user={args.user}",
        f"--mysql-password={args.password}",
        f"--mysql-db={args.db}",
        f"--scale={scale}",
        f"--threads={args.threads}",
        f"--time={args.time}",
        "--report-interval=10",
        "--histogram=on",
        "--percentile=99",
        "run",
    ]
    log_info(f"Chạy Sysbench TPC-B (threads={args.threads}, time={args.time}s, scale={scale})...")
    res = subprocess.run(cmd, capture_output=True, text=True)
    out = res.stdout + res.stderr

    if res.returncode != 0:
        log_warn(f"Sysbench hoàn thành với mã trả về {res.returncode}")

    # Parse transactions and ignored errors
    m_txns = re.search(r"transactions:\s+(\d+)", out)
    m_errs = re.search(r"ignored errors:\s+(\d+)", out)

    txns = int(m_txns.group(1)) if m_txns else -1
    errs = int(m_errs.group(1)) if m_errs else -1

    return txns, errs, out


def test_d1_1(conn: pymysql.Connection, args) -> bool:
    print(f"\n{BOLD}{'='*60}{RESET}")
    print(f"{BOLD}KỊCH BẢN D1.1: KIỂM CHỨNG DƯƠNG (Positive Verification){RESET}")
    print(f"{BOLD}{'='*60}{RESET}")

    reset_state(conn)

    scale = get_scale(conn)
    if scale == 0:
        log_fail("Scale = 0 (bảng pgbench_branches rỗng). Không thể chạy sysbench.")
        return False
    log_info(f"Đã phát hiện dữ liệu: scale = {scale} (branches = {scale})")

    txns, errs, full_out = run_sysbench(args, scale)

    # Hiển thị các dòng quan trọng đúng theo kịch bản:
    print("\n--- KẾT QUẢ SYSBENCH ---")
    for line in full_out.splitlines():
        if "transactions:" in line or "ignored errors:" in line:
            print(f"  {line.strip()}")
    print("------------------------\n")

    is_ok, a, t, b, h, count, inv_line = get_invariant(conn)
    print(f"Dòng kiểm tra bất biến: {BOLD}{inv_line}{RESET}\n")

    # Kiểm tra tiêu chí đạt
    all_passed = True
    if errs == 0:
        log_pass("Tiêu chí 1: ignored errors: 0")
    else:
        log_fail(f"Tiêu chí 1: ignored errors = {errs} (kỳ vọng: 0)")
        all_passed = False

    if is_ok and a != 0:
        log_pass(f"Tiêu chí 2: 4 tổng bằng nhau và khác 0 (A = T = B = H = {a})")
    else:
        log_fail(f"Tiêu chí 2: 4 tổng không bằng nhau hoặc bằng 0 (A={a}, T={t}, B={b}, H={h})")
        all_passed = False

    if count == txns:
        log_pass(f"Tiêu chí 3: Số bản ghi history ({count}) khớp chính xác số transactions ({txns})")
    else:
        log_fail(f"Tiêu chí 3: Số bản ghi history ({count}) không khớp transactions ({txns})")
        all_passed = False

    if all_passed:
        log_pass(">>> KỊCH BẢN D1.1: ĐẠT TIÊU CHÍ (PASSED) <<<")
    else:
        log_fail(">>> KỊCH BẢN D1.1: KHÔNG ĐẠT (FAILED) <<<")
    return all_passed


def test_d1_2(conn: pymysql.Connection) -> bool:
    print(f"\n{BOLD}{'='*60}{RESET}")
    print(f"{BOLD}KỊCH BẢN D1.2: KIỂM CHỨNG ÂM (Negative Verification){RESET}")
    print(f"{BOLD}{'='*60}{RESET}")

    # Bước 1: Cố tình cộng 1 đơn vị vào abalance của aid=1
    corrupt_balance(conn, aid=1, delta=1)

    # Bước 2: Kiểm tra bất biến - BẮT BUỘC PHẢI BÁO FAIL
    is_ok, a, t, b, h, count, inv_fail_line = get_invariant(conn)
    print(f"Bước 2 - Kiểm tra sau khi sửa số dư: {BOLD}{inv_fail_line}{RESET}")

    step2_passed = (not is_ok) and inv_fail_line.startswith("FAIL|")
    if step2_passed:
        log_pass("Tiêu chí 1: Phát hiện sai lệch thành công, in ra dòng FAIL")
    else:
        log_fail(f"Tiêu chí 1: Kỳ vọng FAIL nhưng nhận được: {inv_fail_line}")

    # Bước 3: Đưa dữ liệu về sạch và kiểm tra lại - PHẢI VỀ TOÀN 0
    reset_state(conn)
    is_ok_clean, a0, t0, b0, h0, c0, inv_clean_line = get_invariant(conn)
    print(f"Bước 3 - Kiểm tra sau khi reset dữ liệu: {BOLD}{inv_clean_line}{RESET}")

    expected_clean = "OK|0|0|0|0|0"
    step3_passed = (inv_clean_line == expected_clean)
    if step3_passed:
        log_pass(f"Tiêu chí 2: Reset thành công, in ra dòng {expected_clean}")
    else:
        log_fail(f"Tiêu chí 2: Kỳ vọng {expected_clean} nhưng nhận được {inv_clean_line}")

    all_passed = step2_passed and step3_passed
    if all_passed:
        log_pass(">>> KỊCH BẢN D1.2: ĐẠT TIÊU CHÍ (PASSED) <<<")
    else:
        log_fail(">>> KỊCH BẢN D1.2: KHÔNG ĐẠT (FAILED) <<<")
    return all_passed


def main():
    parser = argparse.ArgumentParser(description="Kiểm chứng tính đúng đắn trên MySQL (D1.1 & D1.2) - TV2")
    parser.add_argument("--test", choices=["all", "d1.1", "d1.2"], default="all",
                        help="Chọn kịch bản kiểm chứng (mặc định: all)")
    parser.add_argument("--time", type=int, default=60,
                        help="Thời gian chạy sysbench cho D1.1 tính bằng giây (mặc định: 60)")
    parser.add_argument("--threads", type=int, default=8,
                        help="Số luồng client cho sysbench (mặc định: 8)")
    parser.add_argument("--host", default=os.environ.get("DB_HOST", "127.0.0.1"),
                        help="MySQL host (mặc định: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=3306,
                        help="MySQL port (mặc định: 3306)")
    parser.add_argument("--user", default="root",
                        help="MySQL user (mặc định: root)")
    parser.add_argument("--password", default="bench",
                        help="MySQL password (mặc định: bench)")
    parser.add_argument("--db", default="bank",
                        help="MySQL database name (mặc định: bank)")

    args = parser.parse_args()

    conn = get_connection(args)
    if not check_tables_exist(conn):
        sys.exit(1)

    results = {}
    if args.test in ("all", "d1.1"):
        results["D1.1"] = test_d1_1(conn, args)

    if args.test in ("all", "d1.2"):
        results["D1.2"] = test_d1_2(conn)

    print(f"\n{BOLD}{'='*60}{RESET}")
    print(f"{BOLD}TỔNG HỢP KẾT QUẢ KIỂM CHỨNG:{RESET}")
    for test_name, passed in results.items():
        status_str = f"{GREEN}PASS{RESET}" if passed else f"{RED}FAIL{RESET}"
        print(f"  * {test_name}: {status_str}")
    print(f"{BOLD}{'='*60}{RESET}\n")

    conn.close()
    if not all(results.values()):
        sys.exit(1)


if __name__ == "__main__":
    main()
