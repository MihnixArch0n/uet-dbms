#!/usr/bin/env python3
"""Khôi phục log phục hồi của MySQL ở thí nghiệm C mức os từ file log JSON gốc của Docker.

Bối cảnh: khi đĩa máy ảo đầy (26/11), file log JSON của container bench-mysql bị ghi dở một dòng;
từ đó "docker logs" dừng đọc tại dòng hỏng nên các file C_mysql_os_*.dblog bị rỗng.
Dữ liệu log vẫn nằm trong file JSON, chỉ cần đọc bỏ qua dòng hỏng.

Dùng:
  1) Chép file log gốc từ máy ảo về (đã có REMOTE):
       $REMOTE 'sudo cat "$(docker inspect -f "{{.LogPath}}" bench-mysql)"' > results/raw/mysql_vm_docker.json.log
  2) uv run python scripts/fix_mysql_os_dblog.py results/raw/mysql_vm_docker.json.log
Script: cắt log theo khoảng [t_start, t_ready + 3 s] của từng lần chạy, ghi lại .dblog và .recovery,
cập nhật redo_s / redo_bytes / rto_log_s trong .times, rồi dựng lại results/C_summary.csv theo đúng thứ tự cũ.
"""
import csv
import glob
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "results", "raw")
SUMMARY = os.path.join(ROOT, "results", "C_summary.csv")


def kv(path):
    d = {}
    for line in open(path):
        line = line.rstrip("\n")
        if "|" in line:
            k, v = line.split("|", 1)
            d[k] = v
    return d


def docker_ts(s):
    # "2026-11-26T05:19:31.411817123Z" -> epoch (Docker ghi giờ UTC)
    s = s.rstrip("Z")
    if "." in s:
        a, b = s.split(".", 1)
        s = a + "." + b[:6]
        fmt = "%Y-%m-%dT%H:%M:%S.%f"
    else:
        fmt = "%Y-%m-%dT%H:%M:%S"
    from datetime import timezone
    return datetime.strptime(s, fmt).replace(tzinfo=timezone.utc).timestamp()


def read_json_log(path):
    out, bad = [], 0
    with open(path, "rb") as f:
        for raw in f:
            # dòng hỏng do hết đĩa có thể chứa byte NUL hoặc bị cắt cụt: bỏ qua
            raw = raw.replace(b"\x00", b"").strip()
            if not raw:
                continue
            try:
                j = json.loads(raw)
                out.append((docker_ts(j["time"]), j.get("log", "").rstrip("\n")))
            except Exception:  # noqa: BLE001
                bad += 1
    return out, bad


def main(log_path):
    lines, bad = read_json_log(log_path)
    print(f"Đọc {len(lines)} dòng log, bỏ qua {bad} dòng hỏng")
    py = sys.executable
    runs = sorted(p[:-6] for p in glob.glob(os.path.join(RAW, "C_mysql_os_*.times")) if not p.endswith("_r0.times"))
    for prefix in runs:
        t = kv(prefix + ".times")
        # Chỉ lấy tới ngay sau lúc sẵn sàng: lần chạy kế tiếp khởi động lại MySQL (đổi tham số) chỉ
        # vài chục giây sau, nếu lấy rộng hơn sẽ dính lần khởi động sạch đó (không có crash recovery).
        t0, t1 = float(t["t_start"]), float(t["t_ready"]) + 3
        seg = [l for ts, l in lines if t0 <= ts <= t1]
        with open(prefix + ".dblog", "w") as f:
            f.write("\n".join(seg) + ("\n" if seg else ""))
        rec = subprocess.run([py, os.path.join(ROOT, "scripts", "parse_recovery_log.py"), "mysql", prefix + ".dblog"],
                             capture_output=True, text=True).stdout
        open(prefix + ".recovery", "w").write(rec)
        r = {k: v for k, v in (l.split("|", 1) for l in rec.splitlines() if "|" in l)}
        new = []
        for line in open(prefix + ".times").read().splitlines():
            k = line.split("|", 1)[0]
            if k in ("redo_s", "redo_bytes", "rto_log_s"):
                line = f"{k}|{r.get(k, '')}"
            new.append(line)
        open(prefix + ".times", "w").write("\n".join(new) + "\n")
        starts = sum("starting as process" in l for l in seg)
        crash = sum("Starting crash recovery" in l for l in seg)
        print(f"{os.path.basename(prefix):24s} {len(seg):4d} dòng log  khởi động={starts} crash_recovery={crash}  "
              f"redo_s={r.get('redo_s', '')!s:8s} rto_log_s={r.get('rto_log_s', '')}")

    # Dựng lại C_summary.csv theo đúng thứ tự cũ (reconcile.py nối từng dòng)
    old = list(csv.DictReader(open(SUMMARY)))
    shutil.copy(SUMMARY, SUMMARY + ".bak")
    os.remove(SUMMARY)
    for row in old:
        prefix = os.path.join(RAW, f"C_{row['db']}_{row['level']}_{row['value']}_r{row['rep']}")
        subprocess.run([py, os.path.join(ROOT, "scripts", "reconcile.py"), prefix],
                       stdout=subprocess.DEVNULL, check=True)
    print(f"Đã dựng lại {SUMMARY} ({len(old)} dòng); bản cũ: C_summary.csv.bak")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
