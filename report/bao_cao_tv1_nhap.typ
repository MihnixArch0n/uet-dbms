// ============================================================
// MẪU BÁO CÁO – PHẦN CỦA TV1
// Đề tài: Durability & Crash Recovery (PostgreSQL vs MySQL InnoDB)
// Phiên bản hoàn thiện công việc 24/11 – cập nhật 26/11/2026
// Số liệu thí nghiệm A: kết quả chính thức (45 lần chạy, results/A_summary.csv).
// ============================================================

#set document(
  title: "Durability & Crash Recovery – PostgreSQL vs MySQL InnoDB",
  author: "Nhóm XX – TV1",
)
#set page(
  paper: "a4",
  margin: (top: 2.5cm, bottom: 2.5cm, left: 2.5cm, right: 2cm),
  numbering: "1",
)
#set text(font: "New Computer Modern", size: 11pt, lang: "vi")
#set par(justify: true, leading: 0.85em)
#set heading(numbering: "1.1")
#show heading.where(level: 1): it => {
  pagebreak(weak: true)
  v(1.2em)
  it
  v(0.6em)
}
#show heading.where(level: 2): it => {
  v(0.9em)
  it
  v(0.4em)
}
#show figure: set block(breakable: true)
#let shot(path, cap, w: 100%) = figure(image(path, width: w), caption: cap)

// ============================================================
// BÌA
// ============================================================
#align(center)[
  #v(1.5cm)
  #text(14pt)[ĐẠI HỌC QUỐC GIA HÀ NỘI]
  #v(0.3cm)
  #text(13pt)[TRƯỜNG ĐẠI HỌC CÔNG NGHỆ]
  #v(1.8cm)
  #text(16pt, weight: "bold")[BÁO CÁO BÀI TẬP LỚN]
  #v(0.4cm)
  #text(14pt)[Hệ quản trị cơ sở dữ liệu]
  #v(1.2cm)
  #text(15pt, weight: "bold")[
    Durability \& Crash Recovery:\
    So sánh PostgreSQL và MySQL InnoDB
  ]
  #v(2cm)
  #text(12pt)[
    *Nhóm XX*\
    \
    Thành viên 1 (TV1): \[Họ tên\] – \[MSSV\]\
    Thành viên 2 (TV2): \[Họ tên\] – \[MSSV\]\
    Thành viên 3 (TV3): \[Họ tên\] – \[MSSV\]
  ]
  #v(1.5cm)
  #text(11pt)[
    Giảng viên hướng dẫn: \[Tên giảng viên\]\
    \
    Hà Nội, 11/2026
  ]
]

#pagebreak()

// ============================================================
// MỤC LỤC + PHÂN CÔNG
// ============================================================
#outline(title: "Mục lục", indent: 1em, depth: 2)

#v(1.5cm)
#heading(numbering: none)[Phân công công việc]

#table(
  columns: (auto, 1fr, auto),
  align: (left, left, center),
  stroke: 0.5pt,
  inset: 8pt,
  [*Thành viên*], [*Nội dung chính*], [*Mục báo cáo*],
  [TV1], [Kiểm chứng PostgreSQL, thí nghiệm A (chi phí flush log), Phần I báo cáo, lý thuyết WAL/flush, ghép báo cáo], [1, 2.1, 2.2 (phần flush), 2.4, 2.7],
  [TV2], [Kiểm chứng MySQL, thí nghiệm B (bảo vệ trang), lý thuyết Full-Page Writes / doublewrite, slide], [2.2 (phần bảo vệ trang), 2.5],
  [TV3], [Chuẩn bị máy đo, sinh dữ liệu, máy ảo, thí nghiệm C (crash recovery), video demo], [2.3, 2.6],
)

#v(0.8cm)
Repository GitHub: #link("https://github.com/MihnixArch0n/uet-dbms")

#pagebreak()

// ============================================================
// PHẦN 1 – POSTGRESQL
// ============================================================
= Phần 1. PostgreSQL

== Tổng quan

PostgreSQL bắt nguồn từ dự án POSTGRES tại Đại học California, Berkeley (1986) do Michael Stonebraker dẫn dắt. Năm 1996 dự án được đổi tên thành PostgreSQL và trở thành phần mềm mã nguồn mở. Hiện nay PostgreSQL là một trong những hệ quản trị cơ sở dữ liệu quan hệ (RDBMS) mạnh mẽ nhất, hỗ trợ đầy đủ chuẩn SQL và nhiều tính năng hướng đối tượng.

Điểm khác biệt nổi bật so với MySQL là mô hình *object-relational*: PostgreSQL cho phép người dùng định nghĩa kiểu dữ liệu mới, toán tử, hàm và chỉ mục tùy biến. MySQL (đặc biệt với engine InnoDB) tập trung vào hiệu năng web và dễ triển khai, trong khi PostgreSQL hướng tới tính đúng đắn, khả năng mở rộng và tuân thủ chuẩn. Oracle và SQL Server là các hệ thương mại có nhiều tính năng enterprise tương tự, nhưng PostgreSQL cung cấp hầu hết các khả năng đó dưới giấy phép mở (PostgreSQL License – tương tự BSD).

== Kiến trúc

PostgreSQL sử dụng mô hình *process-per-connection*. Tiến trình chính (postmaster / postgres) lắng nghe kết nối; mỗi client mới được fork thành một backend process riêng. Cách tiếp cận này đơn giản, cô lập lỗi tốt, nhưng tiêu tốn nhiều bộ nhớ hơn mô hình thread của MySQL.

Các tiến trình nền quan trọng:

- *checkpointer*: định kỳ ghi các trang bẩn từ shared buffers xuống đĩa và tạo checkpoint.
- *background writer*: ghi dần các trang bẩn để giảm áp lực lên checkpointer.
- *WAL writer*: đẩy các bản ghi WAL từ bộ nhớ ra đĩa theo chu kỳ `wal_writer_delay`.
- *autovacuum launcher* và worker: dọn dẹp phiên bản cũ của hàng (MVCC).

Bộ nhớ chia thành hai vùng chính:

- *Shared memory*: shared buffers (cache trang dữ liệu), WAL buffers, lock table…
- *Backend-private memory*: `work_mem`, `maintenance_work_mem`, vùng sắp xếp và hash tạm.

Lưu trữ vật lý nằm dưới thư mục `$PGDATA`:

- `base/` – dữ liệu từng database (mỗi bảng/chỉ mục là một hoặc nhiều file heap).
- `pg_wal/` – các file WAL kích thước cố định 16 MB.
- `global/` – catalog toàn cục và file điều khiển `pg_control`.
- Trang dữ liệu mặc định 8 KB. Dữ liệu lớn được tách sang TOAST.

#figure(
  // placeholder cho sơ đồ kiến trúc
  box(width: 100%, height: 4.5cm, stroke: 0.6pt + gray, inset: 1em)[
    #align(center + horizon)[
      _\[Hình H1 – Sơ đồ kiến trúc PostgreSQL\
      (postmaster, backend, shared buffers, WAL writer, checkpointer)\]_
    ]
  ],
  caption: [Sơ đồ kiến trúc tiến trình và bộ nhớ PostgreSQL.],
)

== Tính năng chính

PostgreSQL hỗ trợ nhiều kiểu dữ liệu nâng cao: JSONB (lưu trữ nhị phân có chỉ mục), mảng, range type, hstore, geometric… Hệ thống chỉ mục phong phú: B-tree (mặc định), GIN (cho mảng và JSONB), GiST (dữ liệu hình học và full-text), BRIN (bảng rất lớn, dữ liệu có thứ tự).

Cơ chế MVCC (Multi-Version Concurrency Control) cho phép đọc không bị chặn bởi ghi. Các phiên bản cũ của hàng được dọn bởi VACUUM. Mức cô lập hỗ trợ đầy đủ từ Read Committed đến Serializable (bằng SSI). Người dùng có thể viết hàm bằng PL/pgSQL, Python, Perl…, tạo trigger, view, materialised view và mở rộng hệ thống bằng extension (PostGIS, pg_stat_statements, timescaledb…).

== Cài đặt, cấu hình và vận hành

Trong dự án này, PostgreSQL được chạy bằng Docker Compose. Image chính thức `postgres:16` được cấu hình qua file `docker/pg/postgresql.conf` với các tham số nền:

- `shared_buffers = 2GB`
- `max_wal_size = 4GB`
- `checkpoint_timeout = 5min`
- `full_page_writes = on`
- `fsync = on`
- `synchronous_commit = on` (cấu hình bền vững mặc định)

Các tham số này được chọn để hai hệ (PostgreSQL và MySQL) có bộ đệm và dung lượng log tương đương, giúp so sánh công bằng chi phí flush log. Chi tiết lệnh khởi tạo và cấu hình đầy đủ được đặt trên repository GitHub; báo cáo chỉ nêu các tham số then chốt liên quan đến durability.

Hai container `bench-pg` (postgres:16) và `bench-mysql` (mysql:8.4) cùng chạy trên máy đo, mỗi container ánh xạ cổng riêng (5432 và 3306).

#shot("img/P1_01_docker_ps.png", [Hai container PostgreSQL 16 và MySQL 8.4 đang chạy bằng Docker Compose (`dc ps`).], w: 85%)

Cấu hình nạp thực tế được kiểm tra trực tiếp trên cả hai hệ: `shared_buffers = 2GB` và `innodb_buffer_pool_size = 2 GB`, `full_page_writes = on` và `innodb_doublewrite = ON`, `log_bin = 0` (tắt binlog), `innodb_flush_log_at_trx_commit = 1`, dung lượng redo log 4 GB.

#shot("img/P1_02_cau_hinh_nap.png", [Đối chiếu cấu hình nạp của PostgreSQL và MySQL trước khi chạy thí nghiệm.])

== Demo chức năng cơ bản

Các thao tác demo được thực hiện trên máy đo với PostgreSQL 16, dữ liệu pgbench scale 50. Danh sách các bước và kết quả:

1. Kiểm tra phiên bản và tham số độ bền.
2. Quan sát tiến trình nền qua `pg_stat_activity`.
3. Tạo bảng, nạp dữ liệu bằng `COPY`, chạy truy vấn và `EXPLAIN ANALYZE`.
4. Theo dõi LSN trước/sau COMMIT và tên file WAL đang ghi.
5. Đọc thống kê WAL và checkpoint, thử phân quyền.
6. Quan sát thư mục dữ liệu, sao lưu/khôi phục bằng `pg_dump` / `pg_restore`.
7. Chạy `pgbench` ngắn, và xem dữ liệu bằng công cụ đồ họa DBeaver.

=== Phiên bản và tham số độ bền

Máy chủ là PostgreSQL 16.16 (bản Debian, 64-bit). Các tham số then chốt đúng như thiết kế: `wal_level = replica`, `synchronous_commit = on`, `full_page_writes = on`, `shared_buffers = 2GB` và `data_checksums = on`. Việc bật `data_checksums` giúp phát hiện trang hỏng khi đọc, bổ sung cho cơ chế Full-Page Writes.

#shot("img/P1_03_phien_ban_tham_so.png", [Phiên bản PostgreSQL và các tham số liên quan đến durability.])

=== Tiến trình nền

Bảng `pg_stat_activity` liệt kê các tiến trình nền đã mô tả ở mục kiến trúc: `checkpointer`, `background writer`, `walwriter`, `autovacuum launcher`, `logical replication launcher`, cùng một `client backend` là phiên psql đang chạy truy vấn. Các tiến trình nền có PID liền nhau (27 đến 32), cho thấy chúng cùng được postmaster khởi tạo khi máy chủ khởi động. Ba tiến trình `checkpointer`, `background writer` và `walwriter` liên quan trực tiếp đến durability và sẽ xuất hiện lại ở Phần 2.

#shot("img/P1_04_tien_trinh.png", [Các tiến trình nền của PostgreSQL: checkpointer, background writer, walwriter…])

=== Nạp dữ liệu, truy vấn và kế hoạch thực thi

Bảng `demo_customer` được tạo và nạp 100.000 dòng bằng `COPY ... FROM PROGRAM`. Truy vấn gom nhóm trả về 100.000 dòng thuộc một thành phố với số dư trung bình 4995, khớp với dữ liệu sinh ra.

#shot("img/P1_05_copy_truy_van.png", [Tạo bảng, nạp 100.000 dòng bằng `COPY` và truy vấn gom nhóm.])

`EXPLAIN ANALYZE` cho thấy sự khác biệt giữa hai cách truy cập. Tra cứu theo khóa chính `aid = 12345` dùng Index Scan trên `pgbench_accounts_pkey` và mất 1,236 ms. Truy vấn lọc theo `abalance > 1000` không có chỉ mục nên phải quét tuần tự toàn bảng bằng Parallel Seq Scan (2 worker) và mất 7956,85 ms, chậm hơn khoảng 6.400 lần.

#shot("img/P1_06_explain.png", [`EXPLAIN ANALYZE`: Index Scan theo khóa chính so với Parallel Seq Scan toàn bảng.])

=== LSN và file WAL

Trước khi COMMIT, vị trí ghi WAL là `F/2D950208`. Sau một giao dịch `UPDATE` rồi `COMMIT`, vị trí này tăng lên `F/2D950310`, tức tăng 0x108 = 264 byte. Đây là lượng WAL do giao dịch nhỏ này sinh ra (bản ghi cập nhật và bản ghi commit). Vị trí hiện tại nằm trong file `000000010000000F0000002D`, trong đó `00000001` là timeline, `0000000F` và `0000002D` xác định đoạn 16 MB. Minh họa này nối trực tiếp sang Phần 2: COMMIT chỉ an toàn khi WAL đến vị trí này đã được flush xuống đĩa.

#shot("img/P1_07_wal_lsn.png", [LSN trước và sau một giao dịch COMMIT, và tên file WAL đang ghi.])

=== Thống kê WAL và checkpoint

Hai view `pg_stat_wal` và `pg_stat_bgwriter` (tích lũy từ lần reset thống kê gần nhất) cho thấy hoạt động ghi của máy chủ. Về WAL: 2.666.921 bản ghi, 178.903.725 byte, 172 bản ghi ảnh trang đầy đủ (`wal_fpi`), `wal_buffers_full = 0` (WAL buffers chưa bị đầy). Số lần `wal_write` (116.912) và `wal_sync` (116.909) gần bằng nhau, nghĩa là hầu như mỗi lần ghi WAL đều đi kèm một lần đồng bộ xuống đĩa. Về checkpoint: 23 lần theo chu kỳ (`checkpoints_timed`) và 92 lần theo yêu cầu (`checkpoints_req`), nghĩa là phần lớn checkpoint được kích hoạt do lượng WAL đạt `max_wal_size` chứ không phải do hết `checkpoint_timeout`.

#shot("img/P1_08_thong_ke_wal.png", [Thống kê `pg_stat_wal` và `pg_stat_bgwriter` (hiển thị dạng dọc).])

=== Phân quyền

Tạo role `teller` có quyền đăng nhập và cấp `SELECT, UPDATE` trên `pgbench_accounts`. Lệnh `\dp` hiển thị `teller=rw/postgres`: `r` là đọc (SELECT), `w` là ghi (UPDATE), và `/postgres` cho biết người cấp quyền. Chủ sở hữu `postgres` có đầy đủ quyền (`arwdDxt`).

#shot("img/P1_09_phan_quyen.png", [Tạo role `teller` và cấp quyền trên bảng `pgbench_accounts`.])

=== Thư mục dữ liệu

Thư mục `$PGDATA` (`/var/lib/postgresql/data`) có các thành phần đã nêu ở mục kiến trúc: `base`, `global`, `pg_wal`, `pg_xact`, `pg_multixact`, `pg_commit_ts`, cùng các file cấu hình `postgresql.conf`, `pg_hba.conf` và `postmaster.pid`. Các file trong `pg_wal` có kích thước cố định 16 MB và tên theo định dạng timeline, log, segment. Thư mục `base` chứa các thư mục con theo mã database (1, 4, 5) và thư mục `pgsql_tmp` cho dữ liệu tạm.

#shot("img/P1_10_thu_muc_du_lieu.png", [Cấu trúc `$PGDATA`, các file WAL 16 MB trong `pg_wal` và thư mục `base`.])

=== Sao lưu và khôi phục

Hai bảng `pgbench_branches` và `pgbench_tellers` được sao lưu bằng `pg_dump -Fc`, sau đó khôi phục vào database mới `restore_demo` bằng `pg_restore`. Kết quả khôi phục có đủ hai bảng và bảng `pgbench_tellers` có 500 dòng, đúng với scale 50 (50 chi nhánh × 10 teller).

#shot("img/P1_11_sao_luu_khoi_phuc.png", [Kết quả khôi phục từ `pg_dump` vào database `restore_demo`.])

=== pgbench

Bộ kiểm tra tích hợp `pgbench` với 4 client, 2 luồng, chạy 30 giây xử lý 23.367 giao dịch, không có giao dịch lỗi, độ trễ trung bình 5,135 ms và đạt 778,88 TPS. Con số này cùng bậc độ lớn với kết quả cấu hình bền vững của thí nghiệm A (389 TPS với 1 client và 1149 TPS với 8 client), dù workload khác nhau (pgbench dùng kịch bản dựng sẵn, thí nghiệm A dùng kịch bản sysbench riêng).

#shot("img/P1_12_pgbench.png", [Kết quả `pgbench` 30 giây với 4 client.])

=== Công cụ đồ họa (DBeaver)

DBeaver kết nối vào PostgreSQL qua cổng 5432, hiển thị cây đối tượng và sơ đồ các bảng: `pgbench_branches`, `pgbench_tellers`, `pgbench_accounts`, `pgbench_history` và bảng demo `demo_customer`. Công cụ này cũng cho phép chạy truy vấn và xem kết quả trong cùng giao diện.

#shot("img/P1_13_so_do_bang.png", [Sơ đồ các bảng trong DBeaver.])

#shot("img/P1_14_explain_do_hoa.png", [Chạy truy vấn đếm trên `pgbench_accounts` trong DBeaver.])

#pagebreak()

// ============================================================
// PHẦN 2 – TÌM HIỂU VÀ THỰC NGHIỆM
// ============================================================
= Phần 2. Tìm hiểu và thực nghiệm về Durability \& Crash Recovery

== Đặt vấn đề

Trong mô hình ACID, thuộc tính *Durability* (độ bền) đòi hỏi: một khi hệ quản trị đã xác nhận COMMIT với client, dữ liệu của giao dịch đó không được mất dù hệ thống sập ngay sau đó.

Đường đi của dữ liệu từ lúc sửa đổi đến khi an toàn trên đĩa gồm nhiều tầng:

1. Bộ đệm của DBMS (shared buffers / InnoDB buffer pool).
2. Page cache của hệ điều hành (sau lệnh `write()`).
3. Cache của bộ điều khiển ổ đĩa.
4. Bề mặt từ tính / flash (sau `fsync()` hoặc tương đương).

Mỗi loại sự cố xóa một số tầng khác nhau:

- *Crash tiến trình DBMS* (kill -9, OOM…): mất toàn bộ bộ nhớ của tiến trình, nhưng page cache của hệ điều hành vẫn còn.
- *Crash hệ điều hành* (kernel panic, tắt nguồn ảo…): mất thêm page cache.
- *Mất điện thật*: có thể mất cả cache của ổ đĩa nếu ổ không tôn trọng lệnh flush.

Ghi thẳng trang dữ liệu khi COMMIT sẽ rất chậm vì truy cập ngẫu nhiên. Nguyên tắc *Write-Ahead Logging* (WAL) giải quyết bằng cách: mọi thay đổi được ghi tuần tự vào log trước; chỉ khi log đã xuống đĩa thì mới được phép báo COMMIT thành công. Trang dữ liệu có thể được ghi sau (lazy).

Tuy nhiên WAL không giải quyết hết mọi vấn đề. Trang dữ liệu của DBMS (8 KB ở PostgreSQL, 16 KB ở InnoDB) lớn hơn đơn vị ghi nguyên tử phổ biến của hệ điều hành và ổ đĩa (thường 4 KB). Nếu hệ thống sập giữa lúc ghi một trang, trang đó có thể bị *rách* (torn page) – nửa cũ nửa mới – và log thay đổi không đủ để sửa. Do đó cần cơ chế bảo vệ trang riêng (Full-Page Writes hoặc doublewrite buffer).

Hai vấn đề trên là độc lập:

- Mất giao dịch đã COMMIT → giải quyết bằng *flush log* khi COMMIT.
- Trang hỏng do ghi dở → giải quyết bằng *bảo vệ trang*.

Đây là lý do nhóm tách thành hai thí nghiệm A và B (đáp ứng nhận xét 3 của giảng viên).

#figure(
  box(width: 100%, height: 5cm, stroke: 0.6pt + gray, inset: 1em)[
    #align(center + horizon)[
      _\[Hình H1 – Đường đi dữ liệu và các tầng mất mát khi crash\]_
    ]
  ],
  caption: [Đường đi của dữ liệu từ DBMS đến đĩa và phạm vi ảnh hưởng của từng loại sự cố.],
)

Câu hỏi nghiên cứu chính của đề tài:

1. Chi phí hiệu năng (TPS, độ trễ) của việc chờ fsync log khi COMMIT là bao nhiêu? (Thí nghiệm A)
2. Chi phí của cơ chế bảo vệ trang là bao nhiêu? (Thí nghiệm B)
3. Khi crash thật sự xảy ra, giao dịch đã COMMIT có bị mất không, hệ thống có còn nhất quán không, và thời gian phục hồi (RTO) là bao lâu? (Thí nghiệm C)

== Cơ chế của hai hệ (phần flush log – TV1)

=== PostgreSQL – WAL và synchronous_commit

Mọi thay đổi dữ liệu trong PostgreSQL đều sinh ra một hoặc nhiều bản ghi WAL trong *WAL buffers* (vùng nhớ chia sẻ). Khi một giao dịch thực hiện COMMIT, backend ghi các bản ghi WAL còn lại ra đĩa và – tùy cấu hình – gọi `fsync` (hoặc `fdatasync`) đến vị trí LSN của bản ghi commit.

Tham số then chốt:

- `synchronous_commit = on` (mặc định): backend *chờ* WAL đã được flush xuống đĩa ổn định rồi mới trả lời client. Đây là cấu hình bền vững.
- `synchronous_commit = off`: backend trả lời client ngay sau khi bản ghi commit đã nằm trong WAL buffers. Tiến trình WAL writer sẽ flush sau theo chu kỳ `wal_writer_delay` (mặc định 200 ms). Tài liệu chính thức nêu cửa sổ mất dữ liệu tối đa khoảng ba lần chu kỳ này, nhưng dữ liệu vẫn nhất quán (không bị rách).

Lưu ý quan trọng: `synchronous_commit = off` *khác* với `fsync = off`. Tắt `fsync` có thể dẫn đến hỏng dữ liệu hoàn toàn và không được dùng trong thí nghiệm.

*Group commit*: khi nhiều backend cùng chờ fsync, PostgreSQL gom chúng lại và chỉ thực hiện một lần `fsync` cho cả nhóm. Cơ chế này giải thích vì sao TPS tăng đáng kể khi số client tăng, dù chi phí một lần fsync vẫn cao. Các tham số `commit_delay` và `commit_siblings` điều khiển hành vi group commit.

File WAL nằm trong `pg_wal/`, mỗi file 16 MB, được tái sử dụng theo cơ chế checkpoint.

=== MySQL InnoDB – Redo log và innodb_flush_log_at_trx_commit

InnoDB cũng dùng write-ahead logging. Mọi thay đổi được ghi vào *redo log* (vòng tròn, kích thước cố định). Tham số tương ứng:

- `innodb_flush_log_at_trx_commit = 1`: mỗi COMMIT đều flush log xuống đĩa. Cấu hình bền vững nhất.
- `= 2`: ghi log vào page cache của hệ điều hành mỗi COMMIT, nhưng chỉ flush xuống đĩa khoảng mỗi giây. An toàn với crash tiến trình, nhưng có thể mất khoảng 1 giây giao dịch cuối khi crash hệ điều hành.
- `= 0`: log được ghi và flush khoảng mỗi giây. Có thể mất dữ liệu ngay cả với crash tiến trình.

Khi bật binlog, InnoDB còn phải đồng bộ thêm một lần nữa (`sync_binlog`). Trong thí nghiệm này binlog bị tắt (`disable_log_bin`) để chỉ so sánh chi phí redo log với WAL.

=== Cấu hình bền vững dùng trong thí nghiệm

#table(
  columns: (auto, 1fr),
  align: left,
  stroke: 0.5pt,
  inset: 6pt,
  [*Hệ*], [*Cấu hình bền vững*],
  [PostgreSQL], [`fsync = on`, `synchronous_commit = on`, `full_page_writes = on`],
  [MySQL InnoDB], [`innodb_flush_log_at_trx_commit = 1`, `innodb_doublewrite = ON`],
)

Thí nghiệm A *chỉ* thay đổi tham số flush log, giữ nguyên cơ chế bảo vệ trang. Nhờ vậy có thể đo riêng chi phí của việc chờ fsync khi COMMIT.

== Phương pháp thực nghiệm (tóm tắt phần liên quan đến A)

*Máy đo*: một máy Linux duy nhất (Ubuntu/WSL2), SSD, ≥ 4 nhân, 12 GB RAM. Mọi số liệu chính thức chạy trên máy này.

*Dữ liệu*: schema pgbench scale 50 (≈ 5 triệu tài khoản), được sinh một lần và dùng chung cho cả hai hệ. Trạng thái ban đầu thỏa bất biến $A = T = B = H = 0$.

*Workload*: giao dịch TPC-B viết lại bằng sysbench Lua (`workload/tpcb.lua`), chạy được trên cả PostgreSQL và MySQL.

*Bất biến*: sau mỗi lần chạy, bốn tổng số dư và tổng delta lịch sử phải bằng nhau. Script kiểm chứng đã được dùng để xác nhận cả trường hợp dương (dữ liệu đúng) và âm (cố tình làm lệch).

*Thiết kế thí nghiệm A*:

- Biến độc lập: tham số flush (`synchronous_commit` on/off; `innodb_flush_log_at_trx_commit` 1/2/0) và số client (1, 8, 32).
- Mỗi ô chạy 3 lần lặp, thời gian đo 300 s (sau warmup).
- Đo: TPS, độ trễ (p50/p95/p99), số lần fsync log / giao dịch, số byte log / giao dịch.
- Full-Page Writes / doublewrite luôn bật.

(Chi tiết đầy đủ phương pháp do TV3 viết; phần trên chỉ nêu những điểm cần cho việc giải thích kết quả A.)

== Kết quả thí nghiệm A

Số liệu dưới đây là kết quả chính thức: 45 lần chạy (PostgreSQL 18 lần, MySQL 27 lần), mỗi ô chạy 3 lần lặp, thời gian đo 300 giây, với số client 1, 8 và 32. Cả 45 lần chạy đều vượt qua kiểm tra bất biến ($A = T = B = H$). Cột TPS ghi giá trị trung bình, trong ngoặc là hệ số biến thiên (CV) giữa 3 lần lặp.

=== Bảng kết quả

#table(
  columns: (auto, auto, auto, auto, auto, auto),
  align: center,
  stroke: 0.5pt,
  inset: 6pt,
  [*Cấu hình*], [*Clients*], [*TPS (CV)*], [*p50 (ms)*], [*p99 (ms)*], [*fsync/txn*],
  [PG `on`], [1], [389 (12,3%)], [2,35], [8,9], [1,000],
  [PG `on`], [8], [1.149 (4,4%)], [4,82], [47,2], [0,270],
  [PG `on`], [32], [3.441 (1,7%)], [4,94], [79,1], [0,090],
  [PG `off`], [1], [5.217 (13,5%)], [0,18], [0,3], [0,001],
  [PG `off`], [8], [20.930 (1,3%)], [0,35], [0,5], [0,001],
  [PG `off`], [32], [12.773 (0,5%)], [1,19], [52,9], [0,001],
  [MySQL `=1`], [1], [214 (13,0%)], [2,90], [35,6], [1,391],
  [MySQL `=1`], [8], [735 (9,6%)], [7,00], [76,0], [0,251],
  [MySQL `=1`], [32], [1.760 (23,5%)], [7,57], [178,4], [0,064],
  [MySQL `=2`], [1], [2.420 (7,0%)], [0,16], [0,4], [0,002],
  [MySQL `=2`], [8], [3.607 (16,7%)], [0,52], [22,4], [0,002],
  [MySQL `=2`], [32], [3.728 (4,4%)], [1,33], [197,1], [0,002],
  [MySQL `=0`], [1], [2.511 (3,4%)], [0,15], [0,3], [0,002],
  [MySQL `=0`], [8], [4.539 (5,0%)], [0,52], [7,6], [0,002],
  [MySQL `=0`], [32], [4.893 (3,7%)], [1,20], [182,2], [0,001],
)

Lưu ý về độ tin cậy: năm ô có CV trên 10% gồm MySQL `=1` ở 32 client (23,5%), MySQL `=2` ở 8 client, PostgreSQL `off` ở 1 client, MySQL `=1` ở 1 client và PostgreSQL `on` ở 1 client. Các nhận xét về những ô này chỉ mang tính định hướng; nhóm dự kiến chạy lại các ô này nếu còn thời gian.

=== Hình ảnh kết quả

#shot("img/H3_tps_vs_clients.png", [H3 – Thông lượng (TPS) theo cấu hình flush log và số client.])

#shot("img/H4_latency.png", [H4 – Độ trễ p50/p95/p99 theo cấu hình flush log.])

#shot("img/H5_fsync_per_txn.png", [H5 – Số lần fsync log trên mỗi giao dịch (group commit).], w: 80%)

=== Phân tích

*1. Với 1 client, TPS bị chặn bởi tốc độ fsync.* PostgreSQL `on` chỉ đạt 389 TPS với 1,000 fsync mỗi giao dịch, tức mỗi COMMIT chờ đúng một lần fsync. Con số này cùng bậc với tốc độ fsync của đĩa đo bằng `pg_test_fsync` trên máy đo (khoảng 424 thao tác/giây với `fdatasync`). MySQL `=1` đạt 214 TPS, gần với mức 210 thao tác/giây của `fsync` trong `pg_test_fsync`, và có 1,391 fsync mỗi giao dịch. Giá trị lớn hơn 1 có thể do mỗi COMMIT của InnoDB kéo theo thêm hoạt động đồng bộ ngoài redo log, nhưng nguyên nhân cụ thể cần được kiểm tra thêm nên báo cáo chưa kết luận.

*2. Group commit giảm chi phí fsync khi tăng số client.* Số fsync mỗi giao dịch của PostgreSQL `on` giảm từ 1,000 (1 client) xuống 0,270 (8 client) và 0,090 (32 client). MySQL `=1` giảm từ 1,391 xuống 0,251 và 0,064. Nhờ vậy TPS tăng theo số client dù mỗi lần fsync vẫn tốn thời gian: PostgreSQL `on` tăng từ 389 lên 1149 rồi 3441 TPS, MySQL `=1` tăng từ 214 lên 735 rồi 1760 TPS. Mức tăng không tuyến tính theo số client.

*3. Cái giá của durability.* Tỉ lệ TPS giữa cấu hình mềm và cấu hình bền vững như sau:

#table(
  columns: (auto, auto, auto, auto),
  align: center,
  stroke: 0.5pt,
  inset: 6pt,
  [*So sánh*], [*1 client*], [*8 client*], [*32 client*],
  [PG `off` / `on`], [13,4×], [18,2×], [3,7×],
  [MySQL `=0` / `=1`], [11,7×], [6,2×], [2,8×],
  [MySQL `=2` / `=1`], [11,3×], [4,9×], [2,1×],
)

Khoảng cách lớn nhất xuất hiện ở tải thấp đến trung bình (13,4 lần và 18,2 lần với PostgreSQL) và thu hẹp khi có nhiều client (còn 3,7 lần ở 32 client), vì lúc đó group commit đã chia nhỏ chi phí fsync cho nhiều giao dịch. Với cấu hình `off`, số fsync mỗi giao dịch gần bằng 0 (0,001) ở mọi mức client, vì WAL writer flush nền theo chu kỳ. Độ trễ cũng phản ánh điều này: ở 8 client, p99 của PostgreSQL `on` là 47,2 ms so với 0,5 ms khi `off`.

*4. MySQL `=2` nằm giữa `=1` và `=0`, và gần `=0` ở tải thấp.* Ở 1 client, `=2` đạt 2420 TPS, gần `=0` (2511 TPS) và cao hơn `=1` khoảng 11 lần. Ở 8 và 32 client, `=2` thấp hơn `=0` (3607 so với 4539 TPS và 3728 so với 4893 TPS) vì mỗi COMMIT vẫn phải gọi `write()` đẩy log sang page cache, trong khi `=0` chỉ ghi định kỳ. Cấu hình `=2` chỉ flush xuống đĩa khoảng mỗi giây (0,002 fsync mỗi giao dịch), nên an toàn khi tiến trình MySQL sập nhưng có thể mất khoảng 1 giây giao dịch cuối khi hệ điều hành sập.

*5. Ở 32 client, hiệu năng bị giới hạn bởi tranh chấp khóa chứ không chỉ bởi fsync.* PostgreSQL `off` đạt 20.930 TPS ở 8 client nhưng chỉ 12.773 TPS ở 32 client, đồng thời p99 tăng từ 0,5 ms lên 52,9 ms. Nhiều khả năng nguyên nhân là tranh chấp khóa dòng trên bảng `pgbench_branches` chỉ có 50 dòng (scale 50) khi có nhiều client cập nhật đồng thời. Với MySQL, p99 ở 32 client đều quanh 180 đến 197 ms ở cả ba cấu hình (182 ms với `=0`, 178 ms với `=1`, 197 ms với `=2`), kể cả khi gần như không còn fsync, gợi ý cùng một nguyên nhân tranh chấp.

*6. So sánh hai hệ ở cấu hình bền vững.* PostgreSQL `on` đạt 389, 1149 và 3441 TPS ở 1, 8 và 32 client, cao hơn MySQL `=1` (214, 735 và 1760 TPS). Tuy nhiên đây là kết quả với đúng cấu hình và máy đo này. Byte log mỗi giao dịch của PostgreSQL `on` cũng biến động mạnh giữa các ô (4830 byte ở 1 client so với 1130 byte ở 32 client). Điều này có thể liên quan đến bản ghi ảnh trang đầy đủ (FPI) và sẽ được đối chiếu với kết quả thí nghiệm B (bảo vệ trang) do TV2 phụ trách.

== Kết luận và đề xuất (TV1 tổng hợp từ thí nghiệm A)

Thí nghiệm A cho thấy chi phí của việc đảm bảo durability bằng flush log là rất đáng kể: trên cùng một workload TPC-B, việc chờ fsync làm TPS của PostgreSQL thấp hơn cấu hình mềm từ 3,7 đến 18,2 lần tùy số client, và của MySQL từ 2,8 đến 11,7 lần. Group commit giảm bớt gánh nặng khi có nhiều client (số fsync mỗi giao dịch giảm xuống dưới 0,1 ở 32 client) nhưng không xóa bỏ hoàn toàn.

Cấu hình khuyến nghị phụ thuộc vào yêu cầu ứng dụng:

- Hệ thống tài chính, giao dịch quan trọng → dùng cấu hình bền vững (`synchronous_commit = on` / `innodb_flush_log_at_trx_commit = 1`).
- Hệ thống chấp nhận mất vài trăm millisecond dữ liệu cuối (log, metrics, cache…) → có thể cân nhắc `off` / `2` để đổi lấy hiệu năng.

Giới hạn của nghiên cứu hiện tại:

- Chỉ chạy trên một máy đo, một loại đĩa.
- Không mô phỏng mất điện vật lý thật (chỉ crash tiến trình và crash máy ảo).
- Binlog của MySQL bị tắt để so sánh công bằng; môi trường thật có thể có thêm chi phí.

(Phần kết luận sẽ được hoàn thiện sau khi có đủ kết quả B và C, cùng góp ý của TV2 và TV3.)

#pagebreak()

// ============================================================
// TÀI LIỆU THAM KHẢO (mẫu)
// ============================================================
#heading(numbering: none)[Tài liệu tham khảo]

1. PostgreSQL Global Development Group. *PostgreSQL 16 Documentation – Reliability and the Write-Ahead Log*. https://www.postgresql.org/docs/16/wal.html
2. PostgreSQL Global Development Group. *PostgreSQL 16 Documentation – Write Ahead Log Configuration*. https://www.postgresql.org/docs/16/runtime-config-wal.html
3. Oracle Corporation. *MySQL 8.0 Reference Manual – InnoDB Startup Options and System Variables*. https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html
4. Silberschatz, A., Korth, H. F., Sudarshan, S. *Database System Concepts* (các chương về Recovery và Storage).
5. Repo mã nguồn nhóm: https://github.com/MihnixArch0n/uet-dbms

#v(1.5cm)
#align(center)[
  #text(9pt, fill: gray)[
    — Hết phần nháp của TV1 —\
    Các mục 2.3 (phương pháp đầy đủ), 2.5, 2.6 và bảng so sánh A5.4 sẽ do TV2/TV3 bổ sung.
  ]
]
