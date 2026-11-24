#!/usr/bin/env python3
"""Đọc log của DBMS ở lần khởi động sau crash, tính thời gian redo và thời gian tới khi sẵn sàng.

Dùng: uv run python scripts/parse_recovery_log.py pg|mysql <file_log>
In ra các dòng "tên|giá trị": startup_ts, ready_ts, rto_log_s, redo_s, redo_bytes.
Giá trị nào không tìm thấy thì để trống (khi đó đọc log bằng tay và ghi vào báo cáo).
"""
import re
import sys
from datetime import datetime


def ts_pg(line):
    m = re.match(r"(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d(?:\.\d+)?)", line)
    return datetime.strptime(m.group(1)[:23], "%Y-%m-%d %H:%M:%S.%f").timestamp() if m else None


def ts_my(line):
    m = re.match(r"(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d+)Z", line)
    return datetime.strptime(m.group(1)[:26], "%Y-%m-%dT%H:%M:%S.%f").timestamp() if m else None


def lsn(s):
    hi, lo = s.split("/")
    return (int(hi, 16) << 32) + int(lo, 16)


def parse_pg(lines):
    start = max((i for i, l in enumerate(lines) if "starting PostgreSQL" in l), default=0)
    lines = lines[start:]
    r = {"startup_ts": ts_pg(lines[0]) if lines else None}
    for l in lines:
        if "redo starts at" in l:
            r["redo_from"] = l.split("redo starts at")[1].split()[0]
        if "redo done at" in l:
            r["redo_to"] = l.split("redo done at")[1].split()[0]
            m = re.search(r"elapsed: ([\d.]+) s", l)
            if m:
                r["redo_s"] = float(m.group(1))
        if "ready to accept connections" in l and "ready_ts" not in r:
            r["ready_ts"] = ts_pg(l)
    if "redo_from" in r and "redo_to" in r:
        r["redo_bytes"] = lsn(r["redo_to"]) - lsn(r["redo_from"])
    if "redo_from" not in r:
        r["redo_s"] = 0.0          # không cần redo (tắt sạch)
    return r


def parse_my(lines):
    start = max((i for i, l in enumerate(lines) if "starting as process" in l), default=0)
    lines = lines[start:]
    r = {"startup_ts": ts_my(lines[0]) if lines else None}
    t_rec0 = t_rec1 = None
    for l in lines:
        if "Starting crash recovery" in l and t_rec0 is None:
            t_rec0 = ts_my(l)
        if "Apply batch completed" in l:
            t_rec1 = ts_my(l)
        m = re.search(r"Starting to parse redo log at lsn = (\d+)", l)
        if m:
            r["redo_from"] = int(m.group(1))
        m = re.search(r"scanned up to log sequence number (\d+)", l)
        if m:
            r["redo_to"] = int(m.group(1))
        if "ready for connections" in l and "port: 3306" in l and "ready_ts" not in r:
            r["ready_ts"] = ts_my(l)
    if "ready_ts" not in r:
        for l in lines:
            if "ready for connections" in l:
                r["ready_ts"] = ts_my(l)
                break
    if t_rec0 and t_rec1:
        r["redo_s"] = round(t_rec1 - t_rec0, 3)
    if "redo_from" in r and "redo_to" in r:
        r["redo_bytes"] = r["redo_to"] - r["redo_from"]
    return r


def main():
    db, path = sys.argv[1], sys.argv[2]
    lines = [l.rstrip("\n") for l in open(path, errors="replace")]
    r = parse_pg(lines) if db == "pg" else parse_my(lines)
    if r.get("startup_ts") and r.get("ready_ts"):
        r["rto_log_s"] = round(r["ready_ts"] - r["startup_ts"], 3)
    for k in ["startup_ts", "ready_ts", "rto_log_s", "redo_s", "redo_bytes"]:
        v = r.get(k)
        print(f"{k}|{'' if v is None else v}")


if __name__ == "__main__":
    main()
