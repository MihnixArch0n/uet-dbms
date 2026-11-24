#!/usr/bin/env python3
"""Đối soát sau crash: so nhật ký xác nhận của client với dữ liệu còn trong DBMS.

Đầu vào (do run_expC.sh tạo):
  <prefix>.sent.*   txn_id đã gửi COMMIT
  <prefix>.ack.*    "txn_id,epoch" đã được xác nhận COMMIT
  <prefix>.present  txn_id có trong pgbench_history sau phục hồi (một số mỗi dòng)
  <prefix>.inv      "OK|a|t|b|h|count" hoặc "FAIL|..."
  <prefix>.times    các dòng "tên|giá trị": t_crash, t_start, t_ready, ...
  <prefix>.meta     các dòng "tên|giá trị": db, level, param, value, rep

In kết quả ra màn hình và nối một dòng vào results/C_summary.csv.
Dùng: uv run python scripts/reconcile.py results/raw/C_pg_process_on_r1
"""
import csv
import glob
import os
import sys


def kv(path):
    d = {}
    if os.path.exists(path):
        for line in open(path):
            line = line.strip()
            if "|" in line:
                k, v = line.split("|", 1)
                d[k] = v
    return d


def main(prefix):
    sent, ack = set(), {}
    for f in glob.glob(prefix + ".sent.*"):
        for line in open(f):
            tok = line.strip().split(",")[0]
            if tok:
                sent.add(int(tok))
    for f in glob.glob(prefix + ".ack.*"):
        for line in open(f):
            parts = line.strip().split(",")
            if len(parts) == 2:
                ack[int(parts[0])] = float(parts[1])
    present = set()
    for line in open(prefix + ".present"):
        line = line.strip()
        if line and line.lower() != "null":
            present.add(int(line))

    inv_line = open(prefix + ".inv").read().strip()
    inv = inv_line.split("|")
    times = kv(prefix + ".times")
    meta = kv(prefix + ".meta")

    ack_set = set(ack)
    inflight = sent - ack_set
    lost = ack_set - present
    inflight_committed = inflight & present
    phantom = present - ack_set - inflight
    h_count = int(inv[5]) if len(inv) > 5 else -1

    t_crash = float(times.get("t_crash", "nan"))
    t_start = float(times.get("t_start", "nan"))
    t_ready = float(times.get("t_ready", "nan"))
    # RPO theo thời gian = độ dài khoảng thời gian chứa các giao dịch đã xác nhận nhưng bị mất:
    # từ lần xác nhận sớm nhất bị mất tới lần xác nhận cuối cùng trước crash.
    rpo_ms = 0.0
    if lost:
        rpo_ms = (max(ack.values()) - min(ack[t] for t in lost)) * 1000
    last_ack_gap_ms = (t_crash - max(ack.values())) * 1000 if ack else float("nan")

    row = {
        "db": meta.get("db", ""), "level": meta.get("level", ""), "param": meta.get("param", ""),
        "value": meta.get("value", ""), "rep": meta.get("rep", ""),
        "acked": len(ack_set), "inflight": len(inflight), "present": len(present),
        "lost": len(lost), "inflight_committed": len(inflight_committed), "phantom": len(phantom),
        "history_count_matches": h_count == len(present),
        "rpo_ms": round(rpo_ms, 1), "last_ack_before_crash_ms": round(last_ack_gap_ms, 1),
        "invariant": inv[0], "a_t_b_h": "|".join(inv[1:5]),
        "rto_s": round(t_ready - t_start, 2),
        "rto_log_s": times.get("rto_log_s", ""),
        "redo_s": times.get("redo_s", ""), "redo_bytes": times.get("redo_bytes", ""),
        "integrity": times.get("integrity", ""),
    }

    print(f"\n=== Đối soát {os.path.basename(prefix)} ===")
    print(f"Đã xác nhận (ACK)            : {row['acked']}")
    print(f"Đang dở lúc crash (INFLIGHT) : {row['inflight']}  (trong đó đã commit: {row['inflight_committed']})")
    print(f"Còn trong DB sau phục hồi    : {row['present']}  (COUNT(*) khớp: {row['history_count_matches']})")
    print(f"MẤT giao dịch đã xác nhận    : {row['lost']}   RPO ≈ {row['rpo_ms']} ms")
    print(f"Giao dịch lạ (phải = 0)      : {row['phantom']}")
    print(f"Bất biến                     : {row['invariant']}  ({row['a_t_b_h']})")
    print(f"RTO (đo từ máy thật)         : {row['rto_s']} s   RTO theo log DBMS: {row['rto_log_s']} s   redo: {row['redo_s']} s")
    if row["phantom"]:
        print("CẢNH BÁO: có giao dịch lạ -> kiểm tra lại công cụ / bước reset dữ liệu")
    if not row["history_count_matches"]:
        print("CẢNH BÁO: COUNT(*) của pgbench_history khác số txn_id -> bảng lịch sử còn dữ liệu cũ?")

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "results", "C_summary.csv")
    new = not os.path.exists(out)
    with open(out, "a", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(row))
        if new:
            w.writeheader()
        w.writerow(row)
    print(f"Đã nối vào {out}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
