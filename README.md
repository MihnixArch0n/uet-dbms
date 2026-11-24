# Durability và Crash Recovery: PostgreSQL vs MySQL InnoDB

Bài tập lớn môn Hệ quản trị cơ sở dữ liệu (INT3202). So sánh cơ chế đảm bảo độ bền giao dịch
(WAL / redo log, Full-Page Writes / doublewrite) và phục hồi sau sự cố của PostgreSQL 16 và MySQL 8.4,
trên dữ liệu ngân hàng TPC-B (pgbench, scale 50: 5 triệu tài khoản).

## Cấu trúc

```
pyproject.toml  thư viện Python (uv); uv.lock ghi phiên bản chính xác, commit cùng repo
docker/       docker-compose.yml, cấu hình nền của hai DBMS
data/         sinh dữ liệu pgbench và chép sang MySQL (setup_data.sh, mysql_schema.sql)
workload/     tpcb.lua (sysbench, dùng chung hai hệ), crash_client.py (bơm tải có nhật ký xác nhận COMMIT)
scripts/      common.sh, run_expA.sh, run_expB.sh, run_expC.sh, invariant.sql, reset_state.sql,
              reconcile.py, parse_recovery_log.py, collect_env.sh
analysis/     parse_results.py (gom kết quả), plots.py (vẽ hình), figures/
results/      raw/ (kết quả thô mỗi lần chạy), env/ (cấu hình máy và DBMS), *_summary.csv
demo/         part1_demo.sql, video demo
report/       báo cáo
```

## Chạy lại toàn bộ

Yêu cầu: Linux (hoặc WSL2), Docker + Docker Compose v2, sysbench, sysstat (iostat), [uv](https://docs.astral.sh/uv/) (quản lý Python và thư viện theo `pyproject.toml`).

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh   # cài uv (một lần)
uv sync                                            # tạo .venv và cài thư viện theo pyproject.toml / uv.lock
docker compose -f docker/docker-compose.yml up -d pg mysql
bash data/setup_data.sh 50            # sinh dữ liệu, chép sang MySQL, kiểm tra bất biến ban đầu
bash scripts/collect_env.sh           # ghi cấu hình máy và DBMS

# Khi đo chỉ bật một DBMS
docker compose -f docker/docker-compose.yml stop mysql
bash scripts/run_expA.sh pg           # thí nghiệm A: chi phí flush log
bash scripts/run_expB.sh pg           # thí nghiệm B: chi phí Full-Page Writes
bash scripts/run_expC.sh pg process on 1   # thí nghiệm C: crash tiến trình (lặp cho từng cấu hình, từng lần)
docker compose -f docker/docker-compose.yml stop pg
docker compose -f docker/docker-compose.yml start mysql
bash scripts/run_expA.sh mysql
bash scripts/run_expB.sh mysql
bash scripts/run_expC.sh mysql process 1 1

uv run python analysis/parse_results.py && uv run python analysis/plots.py
```

Thí nghiệm C mức "crash hệ điều hành" chạy DBMS trong máy ảo; xem phần đầu `scripts/run_expC.sh` cho các biến môi trường.

## Định nghĩa đo

- **Bất biến:** tổng `abalance` = tổng `tbalance` = tổng `bbalance` = tổng `delta` trong `pgbench_history`
  (`scripts/invariant.sql`). Trạng thái ban đầu tất cả bằng 0.
- **RPO:** số giao dịch client đã nhận xác nhận COMMIT nhưng không còn sau phục hồi; quy ra thời gian là
  khoảng từ lần xác nhận sớm nhất bị mất tới lần xác nhận cuối trước crash.
- **RTO:** thời gian từ lúc khởi động lại tới khi DBMS nhận truy vấn; thời gian redo đọc từ log DBMS.

## Kết quả

Báo cáo: `report/` · Video demo: (điền link) · Bảng tổng hợp: `results/*_summary.csv`, `results/C_table.md`
