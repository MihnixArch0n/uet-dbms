#!/usr/bin/env python3
"""Gom kết quả thô của thí nghiệm A và B thành bảng CSV.

Đọc results/raw/{A,B}_*.txt (+ .meta .before .after .inv .waldump .samples)
Ghi:  results/A_runs.csv, results/B_runs.csv   (mỗi lần chạy một dòng)
      results/A_summary.csv, results/B_summary.csv  (trung bình, độ lệch chuẩn, hệ số biến thiên)
      results/B_waldump.csv  (thành phần WAL theo loại bản ghi, PostgreSQL)
      results/B_samples.csv  (chuỗi thời gian lượng log)
Dùng: uv run python analysis/parse_results.py
"""
import glob
import os
import re

import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "results", "raw")
RES = os.path.join(ROOT, "results")

# Tên chỉ số chung cho hai hệ
NAMES = {
    "pg": {"log_bytes": "wal_bytes", "log_fsyncs": "wal_sync", "page_protect": "wal_fpi",
           "commits": "xact_commit"},
    "mysql": {"log_bytes": "Innodb_os_log_written", "log_fsyncs": "Innodb_os_log_fsyncs",
              "page_protect": "Innodb_dblwr_pages_written", "commits": "Com_commit",
              "pages_written": "Innodb_pages_written", "data_written": "Innodb_data_written"},
}


def kv(path):
    d = {}
    if os.path.exists(path):
        for line in open(path):
            line = line.strip()
            if "|" in line:
                k, v = line.split("|", 1)
                d[k] = v
    return d


def num(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return None


def parse_sysbench(path):
    txt = open(path, errors="replace").read()
    r = {}
    m = re.search(r"transactions:\s+(\d+)\s+\(([\d.]+) per sec", txt)
    if m:
        r["txns"], r["tps"] = int(m.group(1)), float(m.group(2))
    m = re.search(r"total time:\s+([\d.]+)s", txt)
    if m:
        r["total_time_s"] = float(m.group(1))
    m = re.search(r"ignored errors:\s+(\d+)", txt)
    r["errors"] = int(m.group(1)) if m else 0
    m = re.search(r"avg:\s+([\d.]+)", txt)
    if m:
        r["lat_avg_ms"] = float(m.group(1))
    # Histogram: dòng "   1.234 |*****    12"
    hist = []
    for line in txt.splitlines():
        if "|" in line:
            left, right = line.split("|", 1)
            try:
                v = float(left.strip())
                c = int(right.split()[-1])
                hist.append((v, c))
            except (ValueError, IndexError):
                pass
    if hist:
        total = sum(c for _, c in hist)
        for p in (50, 95, 99):
            target, acc = total * p / 100, 0
            for v, c in hist:
                acc += c
                if acc >= target:
                    r[f"p{p}_ms"] = v
                    break
    else:
        m = re.search(r"99th percentile:\s+([\d.]+)", txt)
        if m:
            r["p99_ms"] = float(m.group(1))
    return r


def parse_run(txt_path):
    base = txt_path[:-4]
    meta = kv(base + ".meta")
    db = meta.get("db")
    row = {"run": os.path.basename(base), **meta}
    row.update(parse_sysbench(txt_path))
    before, after = kv(base + ".before"), kv(base + ".after")
    deltas = {}
    for common, raw in NAMES.get(db, {}).items():
        b, a = num(before.get(raw)), num(after.get(raw))
        if a is not None and b is not None:
            deltas[common] = a - b
    row.update({f"d_{k}": v for k, v in deltas.items()})
    commits = deltas.get("commits") or 0
    if commits > 0:
        for k in ("log_bytes", "log_fsyncs", "page_protect", "pages_written", "data_written"):
            if k in deltas:
                row[f"{k}_per_txn"] = deltas[k] / commits
    inv = open(base + ".inv").read().strip() if os.path.exists(base + ".inv") else ""
    row["invariant"] = inv.split("|")[0] if inv else ""
    return row


def parse_waldump(path):
    rows = []
    for line in open(path, errors="replace"):
        m = re.match(r"^(\S+/\S+)\s+(\d+)\s+\(\s*[\d.]+\)\s+(\d+)\s+\(\s*[\d.]+\)\s+(\d+)\s+\(\s*[\d.]+\)\s+(\d+)", line)
        if m:
            rows.append({"type": m.group(1), "n": int(m.group(2)), "record_bytes": int(m.group(3)),
                         "fpi_bytes": int(m.group(4)), "combined_bytes": int(m.group(5))})
    return rows


def summarize(df, keys):
    metrics = [c for c in df.columns if c in ("tps", "p50_ms", "p95_ms", "p99_ms") or c.endswith("_per_txn")]
    g = df.groupby(keys)[metrics]
    s = g.agg(["mean", "std", "count"])
    s.columns = [f"{a}_{b}" for a, b in s.columns]
    if "tps_mean" in s:
        s["tps_cv_pct"] = 100 * s["tps_std"] / s["tps_mean"]
    return s.reset_index()


def main():
    for exp, keys in (("A", ["db", "param", "value", "clients"]),
                      ("B", ["db", "param", "value", "extra_param", "extra_value", "clients"])):
        files = sorted(glob.glob(os.path.join(RAW, f"{exp}_*.txt")))
        if not files:
            print(f"Chưa có kết quả thí nghiệm {exp}")
            continue
        df = pd.DataFrame([parse_run(f) for f in files])
        df["clients"] = pd.to_numeric(df["clients"])
        df.to_csv(os.path.join(RES, f"{exp}_runs.csv"), index=False)
        keys = [k for k in keys if k in df.columns]
        s = summarize(df, keys)
        s.to_csv(os.path.join(RES, f"{exp}_summary.csv"), index=False)
        print(f"Thí nghiệm {exp}: {len(df)} lần chạy")
        print(s.to_string(index=False, max_colwidth=18))
        bad = df[df["invariant"] != "OK"]
        if len(bad):
            print("CẢNH BÁO: bất biến sai ở", list(bad["run"]))
        if "tps_cv_pct" in s and (s["tps_cv_pct"] > 10).any():
            print("CẢNH BÁO: hệ số biến thiên TPS > 10% ở một số ô, nên chạy lại")

    wd = []
    for f in sorted(glob.glob(os.path.join(RAW, "B_pg_*.waldump"))):
        run = os.path.basename(f)[:-8]
        meta = kv(os.path.join(RAW, run + ".meta"))
        for r in parse_waldump(f):
            wd.append({"run": run, "value": meta.get("value"), "extra_value": meta.get("extra_value"), **r})
    if wd:
        pd.DataFrame(wd).to_csv(os.path.join(RES, "B_waldump.csv"), index=False)

    smp = []
    for f in sorted(glob.glob(os.path.join(RAW, "B_*.samples"))):
        run = os.path.basename(f)[:-8]
        meta = kv(os.path.join(RAW, run + ".meta"))
        for line in open(f):
            parts = line.strip().split("|")
            if len(parts) == 3:
                smp.append({"run": run, "db": meta.get("db"), "value": meta.get("value"),
                            "extra_value": meta.get("extra_value"), "t": int(parts[0]),
                            "name": parts[1], "v": num(parts[2])})
    if smp:
        pd.DataFrame(smp).to_csv(os.path.join(RES, "B_samples.csv"), index=False)


if __name__ == "__main__":
    main()
