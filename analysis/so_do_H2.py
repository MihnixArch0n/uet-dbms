"""Vẽ hình H2 – sơ đồ kiến trúc tiến trình và bộ nhớ của PostgreSQL.
Chạy: uv run python analysis/so_do_H2.py  -> report/img/H2_kien_truc_pg.png
"""
import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

OUT = sys.argv[1] if len(sys.argv) > 1 else "report/img/H2_kien_truc_pg.png"
W, H = 1270, 840
fig = plt.figure(figsize=(W / 100, H / 100), dpi=100)
ax = fig.add_axes([0, 0, 1, 1]); ax.set_xlim(0, W); ax.set_ylim(H, 0); ax.axis("off")
plt.rcParams["font.family"] = "DejaVu Sans"

def box(x0, y0, x1, y1, fc, ec, lw=2.2, r=8):
    ax.add_patch(FancyBboxPatch((x0, y0), x1 - x0, y1 - y0, boxstyle=f"round,pad=0,rounding_size={r}",
                                fc=fc, ec=ec, lw=lw))

def label(x, y, s, size=13, color="black", weight="normal", ha="center", va="center", bg=None):
    kw = dict(fontsize=size, color=color, fontweight=weight, ha=ha, va=va, linespacing=1.35)
    if bg:
        kw["bbox"] = dict(boxstyle="round,pad=0.15", fc=bg, ec="none")
    ax.text(x, y, s, **kw)

def arrow(x0, y0, x1, y1, color="#333333", lw=2.2):
    ax.annotate("", xy=(x1, y1), xytext=(x0, y0),
                arrowprops=dict(arrowstyle="-|>", color=color, lw=lw, mutation_scale=18, shrinkA=0, shrinkB=0))

# màu
GRAY, GRAY_E = "#f1f3f5", "#555b61"
OR, OR_E = "#fff1c2", "#e8890c"
BL, BL_E = "#e7eefc", "#3b5bdb"
PU, PU_E, PU_IN = "#f3f0ff", "#7048e8", "#e5dbff"
YE, YE_E, YE_IN = "#fff9db", "#e8890c", "#ffe88a"
GR, GR_E, GR_IN = "#e6fcf5", "#12a37a", "#c3fae8"
PU_T, OR_T, GR_T = "#6741d9", "#e8590c", "#087f5b"

label(W / 2, 40, "Kiến trúc tiến trình và bộ nhớ của PostgreSQL", size=17, weight="bold")

# Client -> postmaster -> backend
box(48, 150, 235, 238, GRAY, GRAY_E); label(141, 194, "Client\n(psql, ứng dụng)", size=14)
box(315, 150, 527, 238, OR, OR_E); label(421, 194, "postmaster\n(lắng nghe, fork)", size=14, weight="bold")
arrow(235, 194, 313, 194); label(274, 176, "kết nối", size=13, color="#333333")
bys = [(95, 160), (175, 240), (255, 320)]
for (y0, y1), name in zip(bys, ["backend 1", "backend 2", "backend N"]):
    box(631, y0, 879, y1, BL, BL_E); label(755, (y0 + y1) / 2, name, size=14)
    arrow(527, 194, 629, (y0 + y1) / 2)
label(560, 126, "fork", size=13, color="#333333")
label(905, 205, "mỗi kết nối\nmột tiến trình\n(process-per-\nconnection)", size=12, color="#555555", ha="left")

# Bộ nhớ chung
box(48, 395, 697, 590, PU, PU_E); label(68, 418, "Bộ nhớ chung (shared memory)", size=14, color=PU_T, weight="bold", ha="left")
box(72, 455, 369, 570, PU_IN, PU_E); label(220, 512, "shared buffers\n(cache trang 8 KB)", size=14)
box(388, 455, 673, 570, PU_IN, PU_E); label(530, 512, "WAL buffers\n(bản ghi WAL chưa ghi)", size=14)

# backend -> bộ nhớ chung: một mũi tên tới khung ngoài, nhãn đặt bên trái, không đè lên đường kẻ
arrow(700, 320, 610, 393, color=PU_E)
label(628, 350, "đọc/ghi trang,\nsinh bản ghi WAL", size=13, color=PU_T, ha="right")

# Tiến trình nền
box(741, 395, 1220, 590, YE, YE_E); label(761, 418, "Tiến trình nền", size=14, color=OR_T, weight="bold", ha="left")
for (x0, x1), (y0, y1), name in [((759, 977), (445, 508), "checkpointer"), ((990, 1208), (445, 508), "background writer"),
                                 ((759, 977), (518, 580), "WAL writer"), ((990, 1208), (518, 580), "autovacuum")]:
    box(x0, y0, x1, y1, YE_IN, YE_E); label((x0 + x1) / 2, (y0 + y1) / 2, name, size=13)

# Đĩa
box(48, 680, 1220, 825, GR, GR_E); label(68, 703, "Đĩa ($PGDATA)", size=14, color=GR_T, weight="bold", ha="left")
for (x0, x1), s in [((72, 417), "base/ – file dữ liệu\n(heap, chỉ mục, TOAST)"), ((437, 782), "pg_wal/ – file WAL 16 MB"),
                    ((802, 1195), "global/pg_control –\nvị trí checkpoint cuối")]:
    box(x0, 728, x1, 810, GR_IN, GR_E); label((x0 + x1) / 2, 769, s, size=12.5)

arrow(225, 570, 240, 726, color=GR_T); label(210, 640, "ghi trang\n(checkpoint, bgwriter)", size=12, color=GR_T, ha="right")
arrow(530, 570, 600, 726, color=GR_T); label(592, 640, "flush WAL\nkhi COMMIT", size=12, color=GR_T, ha="left")
arrow(860, 580, 690, 726, color=YE_E); label(850, 650, "ghi WAL định kỳ", size=12, color=OR_T, ha="left")

fig.savefig(OUT, dpi=150, facecolor="white")
print("Đã ghi", OUT)
