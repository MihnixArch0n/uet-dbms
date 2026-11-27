#!/usr/bin/env python3
"""Vẽ các hình cho báo cáo từ các file CSV do parse_results.py và reconcile.py tạo.

Dùng: uv run python analysis/parse_results.py && uv run python analysis/plots.py
Hình lưu ở analysis/figures/ (PNG 200 dpi), bảng B3 ở results/C_table.csv và .md
"""
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import pandas as pd  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "results")
FIG = os.path.join(ROOT, "analysis", "figures")
os.makedirs(FIG, exist_ok=True)
DBNAME = {"pg": "PostgreSQL", "mysql": "MySQL InnoDB"}
PNAME = {"synchronous_commit": "synchronous_commit", "innodb_flush_log_at_trx_commit": "flush_log_at_trx_commit"}


def load(name):
    p = os.path.join(RES, name)
    return pd.read_csv(p) if os.path.exists(p) else None


def save(fig, name):
    fig.tight_layout()
    fig.savefig(os.path.join(FIG, name), dpi=200)
    plt.close(fig)
    print("đã vẽ", name)


def label(row):
    return f"{DBNAME[row['db']]}: {PNAME.get(row['param'], row['param'])}={row['value']}"


def read_checkpoints(path, t0):
    """Đọc log checkpoint của PostgreSQL; trả về [(loại, giây kể từ t0)].
    loại: "time" (định kỳ), "manual" (lệnh CHECKPOINT), bỏ qua checkpoint lúc tắt máy (shutdown)."""
    import datetime as dt
    import re
    out = []
    if not os.path.exists(path):
        return out
    for line in open(path, errors="replace"):
        m = re.search(r"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+) (GMT|UTC).*checkpoint starting: (.*)", line)
        if not m:
            continue
        when = dt.datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S.%f").replace(tzinfo=dt.timezone.utc).timestamp()
        why = m.group(3)
        if "shutdown" in why:
            continue
        kind = "time" if why.strip().startswith("time") else ("manual" if "immediate" in why or "force" in why else "other")
        out.append((kind, when - t0))
    return out


def fig_A(s):
    # H3: TPS theo số client
    fig, axes = plt.subplots(1, 2, figsize=(11, 4), sharey=False)
    for ax, db in zip(axes, ["pg", "mysql"]):
        d = s[s["db"] == db]
        for val, g in d.groupby("value"):
            g = g.sort_values("clients")
            ax.errorbar(g["clients"], g["tps_mean"], yerr=g["tps_std"].fillna(0), marker="o", capsize=3,
                        label=f"{PNAME.get(g['param'].iloc[0])} = {val}")
        ax.set_title(DBNAME[db]); ax.set_xlabel("Số client"); ax.set_ylabel("Giao dịch/giây (TPS)")
        ax.set_xscale("log", base=2); ax.set_xticks(sorted(d["clients"].unique()))
        ax.get_xaxis().set_major_formatter(matplotlib.ticker.ScalarFormatter())
        ax.grid(alpha=.3); ax.legend(fontsize=8)
    fig.suptitle("H3. Thông lượng theo cấu hình flush log và số client (trung bình ± độ lệch chuẩn)")
    save(fig, "H3_tps_vs_clients.png")

    # H4: độ trễ P50/P95/P99 ở 8 client (hoặc mức client gần 8 nhất)
    c = 8 if 8 in s["clients"].values else sorted(s["clients"].unique())[len(s["clients"].unique()) // 2]
    d = s[s["clients"] == c].copy()
    d["nhan"] = d.apply(label, axis=1)
    cols = [x for x in ("p50_ms_mean", "p95_ms_mean", "p99_ms_mean") if x in d]
    if cols:
        ax = d.set_index("nhan")[cols].rename(columns=lambda x: x.split("_")[0].upper()).plot.bar(figsize=(10, 4.5))
        ax.set_ylabel("Độ trễ giao dịch (ms)"); ax.set_xlabel("")
        ax.set_title(f"H4. Độ trễ theo cấu hình flush log, {c} client")
        ax.grid(axis="y", alpha=.3); plt.xticks(rotation=20, ha="right")
        save(ax.figure, "H4_latency.png")

    # H5: số fsync log trên mỗi giao dịch theo số client
    if "log_fsyncs_per_txn_mean" in s:
        fig, ax = plt.subplots(figsize=(8, 4.5))
        style = {"pg": ("o", "-"), "mysql": ("s", "--")}
        for (db, val), g in s.groupby(["db", "value"]):
            g = g.sort_values("clients")
            mk, ls = style.get(db, ("o", "-"))
            ax.plot(g["clients"], g["log_fsyncs_per_txn_mean"], marker=mk, linestyle=ls,
                    markersize=6 if db == "pg" else 8, fillstyle="full" if db == "pg" else "none",
                    label=f"{DBNAME[db]}: {PNAME.get(g['param'].iloc[0], g['param'].iloc[0])} = {val}")
        hi = s[s["log_fsyncs_per_txn_mean"] > 1.05]
        for _, r in hi.iterrows():
            ax.annotate("> 1: chưa giải thích được\n(xem phân tích mục 1, thí nghiệm A)",
                        (r["clients"], r["log_fsyncs_per_txn_mean"]), xytext=(18, -6),
                        textcoords="offset points", fontsize=7, arrowprops=dict(arrowstyle="-", lw=.6))
        ax.text(0.98, 0.42, "Các cấu hình không fsync khi COMMIT (PG off, MySQL 0 và 2)\n"
                "đều xấp xỉ 0 nên các đường nằm chồng lên nhau",
                transform=ax.transAxes, ha="right", va="bottom", fontsize=7, color="dimgray",
                bbox=dict(facecolor="white", edgecolor="none", alpha=.8))
        ax.set_xscale("log", base=2); ax.set_xticks(sorted(s["clients"].unique()))
        ax.get_xaxis().set_major_formatter(matplotlib.ticker.ScalarFormatter())
        ax.set_xlabel("Số client"); ax.set_ylabel("Số lần fsync log / giao dịch")
        ax.set_title("H5. Group commit: số fsync log trên mỗi giao dịch"); ax.grid(alpha=.3); ax.legend(fontsize=7)
        save(fig, "H5_fsync_per_txn.png")


def fig_B(s, samples, wd):
    # H6: lượng ghi trên mỗi giao dịch, bật và tắt bảo vệ trang, tách theo thành phần.
    # PG: WAL = bản ghi thường + ảnh trang đầy đủ (FPI, từ pg_waldump).
    # MySQL: redo log + trang ghi vào tablespace + trang ghi qua doublewrite
    #   (Innodb_data_written không tính doublewrite nên không dùng nó ở đây).
    # Chấm đen: byte ghi đĩa đo bằng iostat, để đối chiếu độc lập.
    d = s[s["extra_value"].fillna("default").astype(str) == "default"] if "extra_value" in s else s
    if len(d):
        parts = {
            "pg": [("wal_record_bytes_per_txn_mean", "WAL: bản ghi thường"),
                   ("wal_fpi_bytes_per_txn_mean", "WAL: ảnh trang đầy đủ (FPI)")],
            "mysql": [("log_bytes_per_txn_mean", "Redo log"),
                      ("page_bytes_per_txn_mean", "Trang dữ liệu (tablespace)"),
                      ("dblwr_bytes_per_txn_mean", "Trang ghi qua doublewrite")],
        }
        order = {"pg": ["on", "off"], "mysql": ["ON", "OFF"]}
        fig, axes = plt.subplots(1, 2, figsize=(12, 4.5))
        for ax, db in zip(axes, ["pg", "mysql"]):
            g = d[d["db"] == db].set_index("value")
            if not len(g):
                ax.set_visible(False)
                continue
            vals = [v for v in order[db] if v in g.index]
            cols = [(c, lab) for c, lab in parts[db] if c in g and g[c].notna().any()]
            if not cols and "log_bytes_per_txn_mean" in g:
                cols = [("log_bytes_per_txn_mean", "Log")]
            bottom = pd.Series(0.0, index=vals)
            for c, lab in cols:
                y = g.loc[vals, c].fillna(0) / 1024
                ax.bar(vals, y, bottom=bottom, label=lab, width=0.55)
                bottom = bottom + y
            for i, (v, tot) in enumerate(bottom.items()):
                ax.text(i - 0.3, tot, f"{tot:.1f} KB", ha="left", va="bottom", fontsize=8)
            if "disk_write_per_txn_mean" in g and g["disk_write_per_txn_mean"].notna().any():
                dw = g.loc[vals, "disk_write_per_txn_mean"] / 1024
                err = g.loc[vals, "disk_write_per_txn_std"] / 1024 if "disk_write_per_txn_std" in g else None
                ax.errorbar(vals, dw, yerr=err, fmt="o", color="black", capsize=3, label="Ghi đĩa thực tế (iostat, mọi loại ghi)")
            ax.set_title(f"{DBNAME[db]}: {'full_page_writes' if db == 'pg' else 'innodb_doublewrite'}")
            ax.set_ylabel("KB / giao dịch"); ax.grid(axis="y", alpha=.3); ax.legend(fontsize=8)
        fig.suptitle("H6. Chi phí bảo vệ trang: lượng ghi trên mỗi giao dịch (8 client, trung bình 3 lần)")
        save(fig, "H6_page_protection_cost.png")

    # H7: tốc độ sinh WAL theo thời gian (lần chạy r1 của mỗi cấu hình PostgreSQL),
    # đánh dấu checkpoint đọc từ file .checkpoints (log PostgreSQL, giờ GMT).
    if samples is not None:
        sm = samples[(samples["db"] == "pg") & (samples["name"] == "lsn_bytes") & samples["run"].str.endswith("_r1")]
        ts = samples[(samples["db"] == "pg") & (samples["name"] == "ts") & samples["run"].str.endswith("_r1")]
        if len(sm):
            fig, ax = plt.subplots(figsize=(10, 4.5))
            colors = {}
            for run, g in sm.groupby("run"):
                g = g.sort_values("t")
                rate = g["v"].diff() / g["t"].diff() / 1e6
                lab = run.replace("B_pg_", "").replace("_c8_r1", "")
                line, = ax.plot(g["t"], rate, label=f"full_page_writes = {lab}")
                colors[run] = line.get_color()
            tmax = sm["t"].max()
            marked_manual = marked_timed = False
            for run in sm["run"].unique():
                t0 = ts[ts["run"] == run].sort_values("t")["v"]
                if not len(t0):
                    continue
                t0 = float(t0.iloc[0])
                for kind, t in read_checkpoints(os.path.join(RES, "raw", run + ".checkpoints"), t0):
                    if kind == "time" and 0 <= t <= tmax:
                        ax.axvline(t, color=colors[run], linestyle="--", lw=1.2)
                        ax.annotate("checkpoint định kỳ\n(checkpoint_timeout = 5min)", (t, ax.get_ylim()[1] * 0.9),
                                    xytext=(-8, 0), textcoords="offset points", ha="right", fontsize=8,
                                    color="black") if not marked_timed else None
                        marked_timed = True
                    elif kind == "manual" and -120 <= t < 0 and not marked_manual:
                        ax.axvline(t, color="gray", linestyle=":", lw=1.2)
                        ax.axvspan(t, 0, color="gray", alpha=.12)
                        ax.text((t + 0) / 2, ax.get_ylim()[1] * 0.5, "CHECKPOINT thủ công\n+ warmup 60 s\n(không đo)",
                                ha="center", fontsize=7, color="dimgray")
                        marked_manual = True
            ax.set_xlim(left=-75 if marked_manual else 0)
            ax.set_xlabel("Thời gian từ lúc bắt đầu đo (giây)"); ax.set_ylabel("WAL sinh ra (MB/giây)")
            ax.set_title("H7. Tốc độ sinh WAL theo thời gian: đỉnh sau mỗi checkpoint khi full_page_writes = on")
            ax.grid(alpha=.3); ax.legend(loc="upper center", fontsize=8)
            save(fig, "H7_wal_rate.png")

    # H8: thành phần WAL (byte bản ghi thường và byte full-page image), tách FPI_FOR_HINT
    if wd is not None and len(wd):
        wd = wd.copy()
        wd["loai"] = wd["type"].where(wd["type"] == "XLOG/FPI_FOR_HINT", wd["type"].str.split("/").str[0])
        agg = wd.groupby(["value", "loai"])[["record_bytes", "fpi_bytes"]].sum().reset_index()
        runs = wd.groupby("value")["run"].nunique()
        agg["MB"] = (agg["record_bytes"] + agg["fpi_bytes"]) / agg["value"].map(runs) / 1e6
        top = agg.groupby("loai")["MB"].sum().nlargest(6).index
        agg["loai"] = agg["loai"].where(agg["loai"].isin(top), "khác")
        pv = agg.pivot_table(index="value", columns="loai", values="MB", aggfunc="sum").fillna(0)
        tot = agg.groupby("value")[["record_bytes", "fpi_bytes"]].sum()
        fpi = tot["fpi_bytes"] / (tot["record_bytes"] + tot["fpi_bytes"])
        ax = pv.plot.bar(stacked=True, figsize=(8, 4.5), rot=0)
        for i, v in enumerate(pv.index):
            ax.text(i, pv.loc[v].sum(), f"FPI {100 * fpi[v]:.0f}%", ha="center", va="bottom", fontsize=9)
        ax.set_ylim(0, pv.sum(axis=1).max() * 1.12)
        ax.set_xlabel("full_page_writes"); ax.set_ylabel("MB WAL mỗi lần chạy (trung bình)")
        ax.legend(title="Loại bản ghi WAL", fontsize=8, title_fontsize=8)
        ax.set_title("H8. Thành phần WAL theo pg_waldump (FPI = phần ảnh trang đầy đủ)"); ax.grid(axis="y", alpha=.3)
        save(ax.figure, "H8_wal_composition.png")


def table_C(c):
    g = c.groupby(["db", "level", "value"])
    t = pd.DataFrame({
        "số lần crash": g.size(),
        "tổng giao dịch mất": g["lost"].sum(),
        "mất nhiều nhất / lần": g["lost"].max(),
        "RPO lớn nhất (ms)": g["rpo_ms"].max(),
        "bất biến sai (lần)": g["invariant"].apply(lambda x: (x != "OK").sum()),
        "giao dịch lạ": g["phantom"].sum(),
        "RTO trung bình (s)": g["rto_s"].mean().round(2),
        # RTO chỉ tính DBMS (từ dòng khởi động đầu tiên trong log tới "ready"), không gồm thời gian
        # máy ảo khởi động ở mức os: dùng cột này khi so sánh hai mức sự cố
        "RTO theo log DBMS, trung vị (s)": pd.to_numeric(c["rto_log_s"], errors="coerce").groupby([c["db"], c["level"], c["value"]]).median().round(2),
        "redo trung bình (s)": pd.to_numeric(c["redo_s"], errors="coerce").groupby([c["db"], c["level"], c["value"]]).mean().round(3),
        # Báo cáo (bảng B3) dùng trung vị cho thời gian redo, nên có thêm cột này để đối chiếu
        "redo trung vị (s)": pd.to_numeric(c["redo_s"], errors="coerce").groupby([c["db"], c["level"], c["value"]]).median().round(2),
    }).reset_index()
    t.to_csv(os.path.join(RES, "C_table.csv"), index=False)
    with open(os.path.join(RES, "C_table.md"), "w") as f:
        f.write("| " + " | ".join(t.columns) + " |\n|" + "---|" * len(t.columns) + "\n")
        for _, r in t.iterrows():
            f.write("| " + " | ".join(str(x) for x in r.values) + " |\n")
    print(t.to_string(index=False))

    # H9: thời gian redo theo lượng log cần redo
    cc = c.copy()
    cc["redo_s"] = pd.to_numeric(cc["redo_s"], errors="coerce")
    cc["redo_bytes"] = pd.to_numeric(cc["redo_bytes"], errors="coerce")
    cc = cc.dropna(subset=["redo_s", "redo_bytes"])
    if len(cc):
        fig, ax = plt.subplots(figsize=(8, 4.5))
        lv = {"process": ("o", "kill tiến trình (máy đo)"), "os": ("^", "tắt ngang máy ảo (KVM)")}
        colors = {"pg": "tab:blue", "mysql": "tab:orange"}
        for (db, level), g in cc.groupby(["db", "level"]):
            mk, lab = lv.get(level, ("s", level))
            ax.scatter(g["redo_bytes"] / 1e6, g["redo_s"], marker=mk, color=colors.get(db),
                       facecolors="none" if level == "os" else colors.get(db), s=45,
                       label=f"{DBNAME[db]} – {lab}")
        ax.set_xlabel("Lượng log cần redo (MB)"); ax.set_ylabel("Thời gian redo (giây)")
        ax.set_title("H9. Thời gian redo theo lượng log cần phát lại (42 lần crash)")
        ax.grid(alpha=.3); ax.legend(fontsize=8)
        save(fig, "H9_redo_time.png")


def main():
    a = load("A_summary.csv")
    if a is not None:
        fig_A(a)
    b = load("B_summary.csv")
    if b is not None:
        fig_B(b, load("B_samples.csv"), load("B_waldump.csv"))
    c = load("C_summary.csv")
    if c is not None:
        table_C(c)


if __name__ == "__main__":
    main()
