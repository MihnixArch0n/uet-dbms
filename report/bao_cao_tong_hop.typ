// ============================================================
// BÁO CÁO TỔNG HỢP – cả nhóm
// Đề tài: Durability & Crash Recovery (PostgreSQL vs MySQL InnoDB)
// Ghép phần TV1 (mục 1, 2.1, 2.2, 2.4, 2.7), TV3 (2.2.4, 2.3, 2.6) – cập nhật 26/11/2026.
// Mục 2.2.4 do TV2 viết (tv2_2_2_bao_ve_trang.typ). Mục 2.5 (thí nghiệm B) do TV1 viết lại chi tiết, đã đối chiếu và đồng bộ số liệu theo bản của TV2.
// Biên dịch: typst compile report/bao_cao_tong_hop.typ
// ============================================================

#set document(
  title: "Durability & Crash Recovery – PostgreSQL vs MySQL InnoDB",
  author: "Nhóm 2",
)
#set page(
  paper: "a4",
  margin: (top: 2cm, bottom: 2cm, left: 2.2cm, right: 2cm),
  numbering: "1",
)
#set text(font: "New Computer Modern", size: 11pt, lang: "vi")
#set par(justify: true, leading: 0.68em)
#set heading(numbering: "1.1.")
#show heading.where(level: 1): it => {
  pagebreak(weak: true)
  v(0.8em)
  it
  v(0.4em)
}
#show heading.where(level: 2): it => {
  v(0.6em)
  it
  v(0.3em)
}
#show figure: set block(breakable: true)
#let shot(path, cap, w: 100%) = figure(image(path, width: w), caption: cap)
#import "diagrams.typ": diagram-data-path, diagram-pg-arch

// ============================================================
// BÌA
// ============================================================
#align(center)[
  #v(1cm)
  #text(14pt)[ĐẠI HỌC QUỐC GIA HÀ NỘI]
  #v(0.3cm)
  #text(13pt)[TRƯỜNG ĐẠI HỌC CÔNG NGHỆ]
  #v(0.8cm)
  #image("img/uet.jpg", width: 3.5cm)
  #v(0.8cm)
  #text(16pt, weight: "bold")[BÁO CÁO BÀI TẬP LỚN]
  #v(0.4cm)
  #text(14pt)[Hệ quản trị cơ sở dữ liệu]
  #v(1.0cm)
  #text(15pt, weight: "bold")[
    Durability \& Crash Recovery:\
    So sánh PostgreSQL và MySQL InnoDB
  ]
  #v(1.4cm)
  #text(12pt)[
    *Nhóm 2*\
    \
    Thành viên 1 (TV1): Vũ Việt Anh – 24020033\
    Thành viên 2 (TV2): Phạm Tuấn Minh – 24020240\
    Thành viên 3 (TV3): Trần Minh Hiếu – 24020132\
  ]
  #v(1fr)
  #text(11pt)[
    Hà Nội, 11/2026
  ]
  #v(0.5cm)
]

#pagebreak()

// ============================================================
// MỤC LỤC + PHÂN CÔNG
// ============================================================
#[
  #set text(size: 9.5pt)
  #show outline.entry: set block(above: 0.2em, below: 0.2em)
  #outline(title: "Mục lục", indent: 1em, depth: 2)
]

#v(0.2cm)
#heading(level: 2, numbering: none)[Phân công công việc]

#table(
  columns: (auto, 1fr, auto),
  align: (left, left, center),
  stroke: 0.5pt,
  inset: 4.5pt,
  [*Thành viên*], [*Nội dung chính*], [*Mục báo cáo*],
  [TV1], [Kiểm chứng PostgreSQL, thí nghiệm A (chi phí flush log), mục 1 báo cáo, lý thuyết WAL/flush, ghép báo cáo], [1, 2.1, 2.2 (phần flush), 2.4, 2.7],
  [TV2], [Kiểm chứng MySQL, thí nghiệm B (bảo vệ trang), lý thuyết Full-Page Writes / doublewrite, slide], [2.2 (phần bảo vệ trang), 2.5],
  [TV3], [Chuẩn bị máy đo, sinh dữ liệu, máy ảo, thí nghiệm C (crash recovery), video demo], [2.2 (checkpoint và phục hồi), 2.3, 2.6],
)

#v(0.8cm)
Repository GitHub: #link("https://github.com/MihnixArch0n/uet-dbms")

#pagebreak()

// ============================================================
// PHẦN 1 – POSTGRESQL
// ============================================================
= PostgreSQL

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
  diagram-pg-arch(),
  kind: image,
  caption: [Sơ đồ kiến trúc tiến trình và bộ nhớ PostgreSQL: postmaster, backend, bộ nhớ chung, tiến trình nền và các thư mục dữ liệu.],
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

#figure(
  grid(
    columns: 2,
    align: center,
    gutter: 8pt,
    image("img/P1_01_docker_ps.png", width: 82%),
    image("img/P1_02_cau_hinh_nap.png", width: 82%),
  ),
  caption: [Hai container PostgreSQL 16 và MySQL 8.4 (trái) và đối chiếu cấu hình nạp trước thí nghiệm (phải).],
)

== Demo chức năng cơ bản

Các thao tác cơ bản được thực hiện trên PostgreSQL 16.16 (dữ liệu `pgbench` scale 50). Ngoài các thao tác SQL/vận hành chuẩn đã kiểm chứng trên repository (`COPY`, `EXPLAIN ANALYZE`, phân quyền role, `pg_dump`/`pg_restore`, `pgbench`, DBeaver), báo cáo trình bày các điểm liên quan trực tiếp đến cơ chế durability ở Phần 2.

=== Phiên bản, tham số độ bền và tiến trình nền

Máy chủ là PostgreSQL 16.16 với các tham số đúng thiết kế: `wal_level = replica`, `synchronous_commit = on`, `full_page_writes = on`, `shared_buffers = 2GB` và `data_checksums = on` (giúp phát hiện trang hỏng khi đọc). Bảng `pg_stat_activity` xác nhận các tiến trình nền liên quan trực tiếp đến durability (`checkpointer`, `background writer`, `walwriter`) cùng các tiến trình `autovacuum launcher` và `client backend`.

#figure(
  grid(
    columns: 2,
    align: center,
    gutter: 8pt,
    image("img/P1_03_phien_ban_tham_so.png", width: 82%),
    image("img/P1_04_tien_trinh.png", width: 82%),
  ),
  caption: [Phiên bản, tham số durability (trái) và các tiến trình nền qua `pg_stat_activity` (phải).],
)

=== LSN, file WAL và thống kê checkpoint

Trước khi COMMIT, vị trí ghi WAL là `F/2D950208`. Sau một giao dịch `UPDATE` rồi `COMMIT`, vị trí này tăng lên `F/2D950310` (+264 byte cho bản ghi cập nhật và commit), nằm trong file `000000010000000F0000002D` (16 MB). Hai view `pg_stat_wal` và `pg_stat_bgwriter` ghi nhận 2.666.921 bản ghi WAL (178,9 MB), 172 FPI (`wal_fpi`), `wal_buffers_full = 0`, số lần `wal_write` (116.912) và `wal_sync` (116.909) gần bằng nhau; cùng 23 `checkpoints_timed` và 92 `checkpoints_req` (do đạt `max_wal_size`).

#figure(
  grid(
    columns: 2,
    align: center,
    gutter: 8pt,
    image("img/P1_07_wal_lsn.png", width: 82%),
    image("img/P1_08_thong_ke_wal.png", width: 82%),
  ),
  caption: [LSN trước/sau COMMIT (trái) và thống kê `pg_stat_wal` / `pg_stat_bgwriter` (phải).],
)

#pagebreak()

// ============================================================
// PHẦN 2 – TÌM HIỂU VÀ THỰC NGHIỆM
// ============================================================
= Tìm hiểu và thực nghiệm về Durability \& Crash Recovery

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
  diagram-data-path(),
  kind: image,
  caption: [Đường đi của dữ liệu từ DBMS đến đĩa và phạm vi mất dữ liệu của từng loại sự cố.],
)

Câu hỏi nghiên cứu chính của đề tài:

1. Chi phí hiệu năng (TPS, độ trễ) của việc chờ fsync log khi COMMIT là bao nhiêu? (Thí nghiệm A)
2. Chi phí của cơ chế bảo vệ trang là bao nhiêu? (Thí nghiệm B)
3. Khi crash thật sự xảy ra, giao dịch đã COMMIT có bị mất không, hệ thống có còn nhất quán không, và thời gian phục hồi (RTO) là bao lâu? (Thí nghiệm C)

== Cơ chế của hai hệ

=== PostgreSQL – WAL và synchronous_commit

Mọi thay đổi dữ liệu trong PostgreSQL đều sinh ra một hoặc nhiều bản ghi WAL trong *WAL buffers* (vùng nhớ chia sẻ). Khi một giao dịch thực hiện COMMIT, backend ghi các bản ghi WAL còn lại ra đĩa và – tùy cấu hình – gọi `fsync` (hoặc `fdatasync`) đến vị trí LSN của bản ghi commit.

Tham số then chốt:

- `synchronous_commit = on` (mặc định): backend *chờ* WAL đã được flush xuống đĩa ổn định rồi mới trả lời client. Đây là cấu hình bền vững.
- `synchronous_commit = off`: backend trả lời client ngay sau khi bản ghi commit đã nằm trong WAL buffers. Tiến trình WAL writer sẽ flush sau theo chu kỳ `wal_writer_delay` (mặc định 200 ms). Tài liệu chính thức nêu cửa sổ mất dữ liệu tối đa khoảng ba lần chu kỳ này, nhưng dữ liệu vẫn nhất quán (không bị rách).

Lưu ý quan trọng: `synchronous_commit = off` *khác* với `fsync = off`. Tắt `fsync` có thể dẫn đến hỏng dữ liệu hoàn toàn và không được dùng trong thí nghiệm.

*Group commit*: khi nhiều backend cùng chờ fsync, PostgreSQL gom chúng lại và chỉ thực hiện một lần `fsync` cho cả nhóm. Cơ chế này giải thích vì sao TPS tăng đáng kể khi số client tăng, dù chi phí một lần fsync vẫn cao. PostgreSQL tự động thực hiện group commit khi nhiều backend cùng chờ `WALWriteLock`; ngoài ra có thể tinh chỉnh thêm bằng `commit_delay` và `commit_siblings` (mặc định `commit_delay = 0`).

File WAL nằm trong `pg_wal/`, mỗi file 16 MB, được tái sử dụng theo cơ chế checkpoint.

=== MySQL InnoDB – Redo log và innodb_flush_log_at_trx_commit

InnoDB cũng dùng write-ahead logging. Mọi thay đổi được ghi vào *redo log* (vòng tròn, kích thước cố định). Tham số tương ứng:

- `innodb_flush_log_at_trx_commit = 1`: mỗi COMMIT đều flush log xuống đĩa. Cấu hình bền vững nhất.
- `= 2`: ghi log vào page cache của hệ điều hành mỗi COMMIT, nhưng chỉ flush xuống đĩa khoảng mỗi giây. An toàn với crash tiến trình, nhưng có thể mất khoảng 1 giây giao dịch cuối khi crash hệ điều hành.
- `= 0`: log được ghi và flush khoảng mỗi giây. Có thể mất dữ liệu ngay cả với crash tiến trình.

Khi bật binlog, InnoDB còn phải đồng bộ thêm một lần nữa (`sync_binlog`). Trong thí nghiệm này binlog bị tắt (`skip-log-bin`) để chỉ so sánh chi phí redo log với WAL.

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

#include "tv2_2_2_bao_ve_trang.typ"

Thí nghiệm B (mục 2.5) đo chi phí này, và chỉ thay đổi cơ chế bảo vệ trang, giữ nguyên flush log chặt, để tách khỏi thí nghiệm A (nhận xét 3 của giảng viên).

#include "tv3_2_2_checkpoint_phuc_hoi.typ"

#include "tv3_2_3_phuong_phap.typ"

== Kết quả thí nghiệm A

Thí nghiệm A đo chi phí hiệu năng của việc chờ `fsync` log khi COMMIT: chỉ thay đổi tham số flush log (PostgreSQL `on`/`off`; InnoDB `1`/`2`/`0`), giữ nguyên bảo vệ trang và tắt binlog. Tổng cộng 45 lần chạy (300 giây đo sau 60 giây làm nóng, ở 1, 8, 32 client, 3 lần lặp mỗi ô), xử lý 61.489.705 giao dịch.

=== Quy trình đo và tính đúng của dữ liệu

Trước mỗi loạt (một DBMS), script đưa dữ liệu về trạng thái ban đầu (`0|0|0|0|0`). Mỗi lần chạy gồm: khởi động lại DBMS; `CHECKPOINT` và reset thống kê WAL (PostgreSQL); làm nóng 60 giây; chụp thống kê trước; chạy `sysbench` 300 giây kèm `iostat` mỗi 10 giây; chụp thống kê sau; kiểm tra bất biến. Cả 45 lần chạy đều giữ đúng bất biến $A = T = B = H$ và 0 giao dịch lỗi (`ignored errors = 0`), kể cả ở cấu hình `off` và `=0`.

=== Bảng kết quả

#[
  #set text(size: 9.5pt)
  #figure(
    table(
      columns: (auto, auto, auto, auto, auto, auto, auto, auto),
      align: center,
      stroke: 0.5pt,
      inset: 5pt,
      table.header([*Cấu hình*], [*Clients*], [*TPS*], [*CV*], [*p50 (ms)*], [*p95 (ms)*], [*p99 (ms)*], [*fsync mỗi giao dịch*]),
      [PG `on`], [1], [389], [12,3%], [2,35], [2,7], [8,9], [1,000],
      [PG `on`], [8], [1.149], [4,4%], [4,82], [18,5], [47,2], [0,270],
      [PG `on`], [32], [3.441], [1,7%], [4,94], [20,0], [79,1], [0,090],
      [PG `off`], [1], [5.217], [13,5%], [0,18], [0,3], [0,3], [0,001],
      [PG `off`], [8], [20.930], [1,3%], [0,35], [0,4], [0,5], [0,001],
      [PG `off`], [32], [12.773], [0,5%], [1,19], [1,9], [52,9], [0,001],
      [MySQL `=1`], [1], [214], [13,0%], [2,90], [10,5], [35,6], [1,391],
      [MySQL `=1`], [8], [735], [9,6%], [7,00], [27,1], [76,0], [0,251],
      [MySQL `=1`], [32], [1.760], [23,5%], [7,57], [49,7], [178,4], [0,064],
      [MySQL `=2`], [1], [2.420], [7,0%], [0,16], [0,3], [0,4], [0,002],
      [MySQL `=2`], [8], [3.607], [16,7%], [0,52], [0,6], [22,4], [0,002],
      [MySQL `=2`], [32], [3.728], [4,4%], [1,33], [33,4], [197,1], [0,002],
      [MySQL `=0`], [1], [2.511], [3,4%], [0,15], [0,2], [0,3], [0,002],
      [MySQL `=0`], [8], [4.539], [5,0%], [0,52], [0,6], [7,6], [0,002],
      [MySQL `=0`], [32], [4.893], [3,7%], [1,20], [2,1], [182,2], [0,001],
    ),
    caption: [Kết quả thí nghiệm A: giá trị trung bình của 3 lần chạy (`results/A_summary.csv`). CV là hệ số biến thiên của TPS giữa 3 lần.],
  )
]

Số fsync mỗi giao dịch cho thấy hai nhóm cấu hình khác hẳn nhau. Với cấu hình bền vững ở 1 client, PostgreSQL gần như đúng 1 fsync cho mỗi giao dịch; với `off`, `=0` và `=2`, số này gần 0 (từ 0,000 đến 0,002) vì log chỉ được flush định kỳ. Đây là cơ sở để phân tích hiệu quả group commit ở bảng sau.

#[
  #set text(size: 9.5pt)
  #figure(
    table(
      columns: (auto, auto, auto, auto, auto, auto),
      align: center,
      stroke: 0.5pt,
      inset: 5pt,
      table.header([*Cấu hình*], [*Clients*], [*fsync mỗi giây*], [*Giao dịch mỗi fsync*], [*Nhóm lấp đầy so với số client*], [*So với trần fsync của ổ đĩa*]),
      [PG `on`], [1], [389], [1,0], [100%], [92%],
      [PG `on`], [8], [310], [3,7], [46%], [73%],
      [PG `on`], [32], [308], [11,2], [35%], [73%],
      [MySQL `=1`], [1], [298], [0,7], [72%], [142%],
      [MySQL `=1`], [8], [185], [4,0], [50%], [88%],
      [MySQL `=1`], [32], [112], [15,7], [49%], [53%],
    ),
    caption: [Hiệu quả group commit ở cấu hình bền vững. "fsync mỗi giây" bằng TPS nhân số fsync mỗi giao dịch. Trần fsync lấy từ `pg_test_fsync` (mục 2.3): 424 thao tác/giây với `fdatasync` (dùng cho PostgreSQL) và 210 thao tác/giây với `fsync` (dùng cho MySQL).],
  )
]

=== Đối chiếu với kết quả dự kiến

Từ lý thuyết ở mục 2.2 có thể rút ra các dự đoán sau. Bảng dưới đối chiếu từng dự đoán với kết quả đo.

#[
  #set text(size: 9.5pt)
  #figure(
    table(
      columns: (1.3fr, 1.7fr, auto),
      align: (left, left, center),
      stroke: 0.5pt,
      inset: 5pt,
      table.header([*Dự kiến theo lý thuyết*], [*Kết quả đo*], [*Đánh giá*]),
      [Ở 1 client với cấu hình bền vững, TPS xấp xỉ tốc độ fsync của ổ đĩa], [PostgreSQL `on`: 389 TPS (hai lần ổn định đạt 417, bằng 98% trần 424). MySQL `=1`: 214 TPS so với trần 210], [Khớp],
      [Tăng số client thì số fsync mỗi giao dịch giảm (group commit)], [PostgreSQL `on`: 1,000 → 0,270 → 0,090. MySQL `=1`: 1,391 → 0,251 → 0,064], [Khớp],
      [Cấu hình mềm cao hơn cấu hình bền vững nhiều lần], [PostgreSQL `off` gấp 13,4 đến 18,2 lần ở 1 và 8 client; MySQL `=0` gấp 6,2 đến 11,7 lần], [Khớp],
      [Khoảng cách thu hẹp khi tăng số client], [Thu hẹp ở 32 client (PostgreSQL còn 3,7 lần, MySQL còn 2,8 lần), nhưng với PostgreSQL khoảng cách ở 8 client (18,2 lần) lớn hơn ở 1 client (13,4 lần)], [Khớp một phần],
      [InnoDB `=2` gần `=0` ở tải thấp, đều cao hơn `=1`], [1 client: `=2` đạt 2.420, `=0` đạt 2.511, `=1` đạt 214 TPS. Thứ tự `=0` ≥ `=2` ≥ `=1` đúng ở cả ba mức client], [Khớp],
      [TPS tăng theo số client ở mọi cấu hình], [PostgreSQL `off` giảm từ 20.930 (8 client) xuống 12.773 (32 client); các cấu hình khác tăng], [Không khớp, cần giải thích (phân tích mục 6)],
      [Cấu hình mềm gần như không có fsync mỗi giao dịch], [Từ 0,000 đến 0,002 fsync mỗi giao dịch], [Khớp],
      [Mỗi giao dịch của MySQL có khoảng 1 fsync khi `=1`], [1,391 fsync mỗi giao dịch ở 1 client, lớn hơn 1], [Giải thích được từ kiến trúc `log_writer`/`log_flusher` (mục 1)],
    ),
    caption: [Đối chiếu dự đoán lý thuyết với kết quả thí nghiệm A.],
  )
]

=== Phân tích

*1. Với 1 client, TPS bị chặn đúng bằng tốc độ fsync của ổ đĩa.* Với PostgreSQL `on`, mỗi giao dịch dùng đúng 1,000 lần fsync; hai trong ba lần chạy đạt ~417 TPS (98% trần 424 của `fdatasync`), độ trễ p50 là 2,35 ms (khớp 1/424 s ≈ 2,36 ms). Với MySQL `=1`, TPS ổn định quanh 198 (một lần 246), gần trần 210 của `fsync`, p50 là 2,90 ms (trung bình ~4,7 ms ≈ 1/210 s). Sở dĩ InnoDB ghi nhận trung bình `1,391` fsync/giao dịch (298 fsync/giây) là do `Innodb_os_log_fsyncs` chỉ đếm `fsync()` trên file redo log; khi `=1`, cặp luồng `log_writer` và `log_flusher` kích hoạt `fsync()` mỗi khi `write_lsn` tiến lên (bao gồm cả các mini-transaction trước `COMMIT` và tác vụ nền), còn tốc độ 298 fsync/s có thể do ghi lô nhỏ khác kịch bản 8 KB cố định của `pg_test_fsync`.

*2. Group commit làm tăng TPS nhưng không làm tăng số fsync mỗi giây.* Ở PostgreSQL `on`, số fsync mỗi giây là 389, 310 và 308 khi số client là 1, 8 và 32: gần như không đổi từ 8 lên 32 client, và đạt khoảng 73% trần của ổ đĩa. TPS vẫn tăng từ 1.149 lên 3.441 vì mỗi lần fsync phục vụ trung bình 3,7 giao dịch ở 8 client và 11,2 giao dịch ở 32 client. Nhóm không bao giờ đầy: chỉ bằng 46% số client ở 8 client và 35% ở 32 client, nhiều khả năng vì các giao dịch đến không đồng bộ và mỗi giao dịch còn nhiều thao tác khác ngoài COMMIT. Với MySQL `=1`, số giao dịch mỗi fsync tăng từ 4,0 (8 client) lên 15,7 (32 client), nhưng số fsync mỗi giây lại giảm từ 185 xuống 112, chỉ còn khoảng một nửa trần. Nghĩa là ở 32 client MySQL không còn bị chặn bởi fsync mà bởi yếu tố khác (mục 6).

#shot("img/H5_fsync_per_txn.png", [H5 – Số lần fsync log trên mỗi giao dịch theo số client: group commit làm số fsync mỗi giao dịch giảm mạnh.], w: 72%)

*3. Cái giá của durability: bao nhiêu lần, và thay đổi theo số client.* Bảng sau là tỉ lệ TPS giữa cấu hình mềm và cấu hình bền vững.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: center,
    stroke: 0.5pt,
    inset: 6pt,
    table.header([*So sánh*], [*1 client*], [*8 client*], [*32 client*]),
    [PG `off` / `on`], [13,4×], [18,2×], [3,7×],
    [MySQL `=0` / `=1`], [11,7×], [6,2×], [2,8×],
    [MySQL `=2` / `=1`], [11,3×], [4,9×], [2,1×],
  ),
  caption: [Tỉ lệ TPS giữa cấu hình mềm và cấu hình bền vững.],
)

Khoảng cách lớn nhất ở tải thấp đến trung bình rồi thu hẹp ở 32 client, vì group commit đã chia nhỏ chi phí fsync cho nhiều giao dịch. Riêng PostgreSQL có khoảng cách ở 8 client lớn hơn ở 1 client, vì `off` đạt đỉnh 20.930 TPS ở 8 client trong khi `on` mới đạt 1.149 TPS.

#shot("img/H3_tps_vs_clients.png", [H3 – Thông lượng (TPS) theo cấu hình flush log và số client (trung bình ± độ lệch chuẩn).], w: 85%)

*4. Độ trễ: cấu hình bền vững chậm hơn nhiều lần ở tải thấp.* Độ trễ p50 của PostgreSQL `on` là 2,35 / 4,82 / 4,94 ms ở 1 / 8 / 32 client, chậm hơn `off` (0,18 / 0,35 / 1,19 ms) từ 4,2 đến 13,8 lần. Với `on`, p50 ở 8 và 32 client (~4,8–4,9 ms) xấp xỉ gấp đôi một lần fsync, gợi ý giao dịch phải chờ đợt fsync đang chạy xong rồi mới đến nhóm mình. Đuôi độ trễ của MySQL `=1` dài hơn (p95 10,5–49,7 ms; p99 lên tới 178,4 ms ở 32 client).

#shot("img/H4_latency.png", [H4 – Độ trễ p50, p95, p99 theo cấu hình flush log.], w: 85%)

*5. MySQL `=2` nằm giữa `=1` và `=0`, và khoảng cách với `=0` rộng ra khi tăng tải.* Ở 1 client, `=2` đạt 2.420 TPS, gần `=0` (2.511) và cao hơn `=1` ~11 lần vì không chờ `fsync`. Ở 8 và 32 client, `=2` thấp hơn `=0` (3.607 so với 4.539, và 3.728 so với 4.893), do mỗi COMMIT của `=2` vẫn phải gọi `write()` đẩy log sang page cache, còn `=0` chỉ ghi định kỳ.

*6. Ở 32 client, hiệu năng bị giới hạn bởi tranh chấp khóa chứ không chỉ bởi fsync.* PostgreSQL `off` đạt 20.930 TPS ở 8 client nhưng chỉ 12.773 TPS ở 32 client, đồng thời p99 tăng từ 0,5 ms lên 52,9 ms, trong khi p95 chỉ 1,9 ms (nghĩa là chỉ 1% giao dịch cuối bị chậm hẳn). Nhiều khả năng nguyên nhân là tranh chấp khóa dòng trên bảng `pgbench_branches` chỉ có 50 dòng (scale 50): 32 client cùng cập nhật 50 dòng, nên các giao dịch cùng chi nhánh phải xếp hàng. Với MySQL, p99 ở 32 client đều quanh 180 đến 200 ms ở cả ba cấu hình (182 ms với `=0`, 178 ms với `=1`, 197 ms với `=2`), kể cả khi gần như không còn fsync, và TPS của `=0` chỉ tăng thêm 8% khi từ 8 lên 32 client (4.539 lên 4.893). Cả hai quan sát cùng gợi ý một điểm nghẽn không liên quan đến flush log. Giá trị p99 giống hệt nhau ở ba lần chạy của PostgreSQL `off` (52,9 ms) nhiều khả năng do sysbench báo percentile theo các nhóm (bucket) của histogram.

*7. So sánh hai hệ, và phần chênh không đến từ flush.* Ở cấu hình bền vững, PostgreSQL `on` đạt 389, 1.149 và 3.441 TPS, cao hơn MySQL `=1` (214, 735 và 1.760 TPS) lần lượt 1,8 lần, 1,6 lần và 2,0 lần. Ở 1 client, tỉ lệ 1,8 lần gần với tỉ lệ trần fsync của hai hệ (424 so với 210, khoảng 2,0 lần), phù hợp với giả thuyết PostgreSQL dùng `fdatasync` còn InnoDB dùng `fsync` mặc định. Tuy nhiên ở cấu hình mềm, PostgreSQL `off` vẫn hơn MySQL `=0` (5.217 so với 2.511 ở 1 client, 20.930 so với 4.539 ở 8 client), tức khoảng cách này không thể giải thích bằng flush log mà đến từ các khác biệt khác của hai engine. Vì vậy chỉ nên so sánh hai hệ theo tỉ lệ giữa cấu hình mềm và cấu hình bền vững của từng hệ, không so TPS tuyệt đối.

*8. Đánh đổi giữa hiệu năng (thí nghiệm A) và dữ liệu mất (thí nghiệm C).* Bảng sau đặt TPS thu được ở 8 client cạnh lượng dữ liệu bị mất khi sự cố ở thí nghiệm C (mục 2.6), để thấy cái giá thực sự của việc nới lỏng flush.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: center,
    stroke: 0.5pt,
    inset: 6pt,
    table.header([*Cấu hình mềm*], [*TPS so với bền vững (8 client)*], [*Mất khi kill tiến trình*], [*Mất khi hệ điều hành sập (RPO lớn nhất)*]),
    [PG `off`], [18,2×], [tối đa 69 giao dịch, 20 ms], [tối đa 897 giao dịch, 197 ms],
    [MySQL `=0`], [6,2×], [tối đa 108 giao dịch, 19 ms], [tối đa 3.517 giao dịch, 630 ms],
    [MySQL `=2`], [4,9×], [không mất (0 giao dịch)], [tối đa 2.674 giao dịch, 552 ms],
  ),
  caption: [Đánh đổi TPS và dữ liệu mất. Cấu hình bền vững không mất giao dịch nào ở cả hai mức sự cố (thí nghiệm C).],
)

Nếu ứng dụng chấp nhận mất vài trăm mili giây dữ liệu cuối khi máy sập, PostgreSQL `off` là lựa chọn rẻ nhất về hiệu năng. `=2` thú vị ở chỗ an toàn khi chỉ tiến trình MySQL sập, nhưng khi hệ điều hành sập vẫn mất tới khoảng nửa giây dữ liệu, trong khi TPS chỉ bằng 4,9 lần cấu hình bền vững ở 8 client.

=== Độ tin cậy số liệu

Năm ô có hệ số biến thiên trên 10% (bảng dưới): phần lớn ở 1 client do một lần chạy lệch (PG `on`: 417, 416, 334; MySQL `=1`: 246, 195, 201), còn MySQL `=1` ở 32 client (CV 23,5%) bị ảnh hưởng bởi tranh chấp khóa. Các giới hạn chung của thiết kế đo được tổng hợp ở mục 2.7.

#[
  #set text(size: 9.5pt)
  #figure(
    table(
      columns: (auto, auto, auto, auto),
      align: center,
      stroke: 0.5pt,
      inset: 5pt,
      table.header([*Cấu hình*], [*Clients*], [*TPS ba lần chạy*], [*CV*]),
      [MySQL `=1`], [32], [1.710, 1.373, 2.195], [23,5%],
      [MySQL `=2`], [8], [4.257, 3.497, 3.067], [16,7%],
      [PG `off`], [1], [4.937, 4.697, 6.015], [13,5%],
      [MySQL `=1`], [1], [246, 195, 201], [13,0%],
      [PG `on`], [1], [417, 416, 334], [12,3%],
    ),
    caption: [Các ô có hệ số biến thiên trên 10% ở thí nghiệm A.],
  )
]

== Kết quả thí nghiệm B

Thí nghiệm B trả lời câu hỏi: cơ chế chống rách trang tốn bao nhiêu, và chi phí đó nằm ở đâu trong mỗi hệ. Chỉ thay đổi tham số bảo vệ trang: PostgreSQL `full_page_writes` bật hoặc tắt, InnoDB `innodb_doublewrite` ON hoặc OFF. Flush log luôn ở mức bền vững (`synchronous_commit = on`, `innodb_flush_log_at_trx_commit = 1`), để tách riêng chi phí này khỏi thí nghiệm A. Thí nghiệm gồm 12 lần chạy: 2 cấu hình mỗi hệ, 3 lần lặp, 8 client, 60 giây làm nóng và 300 giây đo.

Kết quả tóm tắt: chi phí nằm ở hai vị trí khác nhau. PostgreSQL trả bằng WAL: bật `full_page_writes` làm WAL mỗi giao dịch tăng 5,7 lần, trong đó 82% là ảnh trang đầy đủ. InnoDB trả bằng ghi trang dữ liệu: doublewrite làm mỗi trang flush bị ghi hai lần, tăng ghi đĩa mỗi giao dịch khoảng 1,8 lần, còn redo log không đổi. Ở 8 client, độ biến thiên TPS đủ lớn để chưa phân biệt được tác động lên thông lượng.

Lưu ý: `full_page_writes = off` và `innodb_doublewrite = OFF` chỉ được dùng để đo chi phí. Trên hệ thống thật, tắt chúng có thể làm hỏng dữ liệu không phục hồi được khi hệ điều hành sập hoặc mất điện.

=== Quy trình đo và kiểm chứng bất biến

Mỗi lần chạy bắt đầu từ trạng thái dữ liệu ban đầu (`0|0|0|0|0`) trong container đã khởi động lại; với PostgreSQL chạy thêm `CHECKPOINT` thủ công để đồng bộ điểm xuất phát, rồi dùng `pg_waldump --stats=record` phân loại WAL giữa hai mốc LSN. Với InnoDB ghi số trang flush và doublewrite; cả hai hệ đều dùng `iostat` đo lượng ghi đĩa độc lập.

Cả 12 lần chạy đều có bất biến $A = T = B = H$ đúng và 0 lỗi. Trước khi đo, hàm `check_invariant` cũng được kiểm chứng hai chiều trên MySQL (tương tự PostgreSQL ở mục 2.3): sau 60 giây chạy tải 8 client (70.756 giao dịch, `ignored errors: 0`) trả về `OK|-107122|-107122|-107122|-107122|70756`; cố ý cộng lệch `+1` vào `abalance` của `aid = 1` báo ngay `FAIL|-107121|...` rồi trở về `OK|0|0|0|0|0` sau khi reset.

=== Bảng kết quả

#[
  #set text(size: 9pt)
  #show table: set par(justify: false)
  #figure(
    table(
      columns: (auto, auto, auto, auto, auto, auto, auto, auto),
      align: (left, center, center, center, center, center, center, center),
      stroke: 0.5pt,
      inset: 4.5pt,
      table.header([*Cấu hình*], [*TPS (CV)*], [*p50 (ms)*], [*p95 (ms)*], [*p99 (ms)*], [*Log mỗi giao dịch (B)*], [*Bảo vệ mỗi giao dịch (B)*], [*Ghi đĩa mỗi giao dịch (B)*]),
      [PG `fpw = on`], [1.294 (17,0%)], [4,82], [9,74], [33,8], [2.280,5], [1.871,4 (FPI)], [5.882,6],
      [PG `fpw = off`], [1.170 (4,0%)], [4,82], [10,44], [46,4], [401,7], [0], [3.998,4],
      [MySQL `dblwr = ON`], [703 (20,2%)], [6,91], [23,83], [72,3], [1.068,6], [10.945,0 (doublewrite)], [24.749,0],
      [MySQL `dblwr = OFF`], [884 (17,1%)], [6,91], [14,50], [63,1], [1.071,4], [0], [13.723,6],
    ),
    caption: [Kết quả thí nghiệm B ở 8 client, trung bình 3 lần chạy (`results/B_summary.csv`). CV là hệ số biến thiên của TPS giữa 3 lần. "Log" là WAL của PostgreSQL hoặc redo log của InnoDB. "Bảo vệ" là dung lượng FPI trong WAL (PostgreSQL) hoặc lượng ghi qua doublewrite (MySQL). "Ghi đĩa" là tổng lượng ghi đo bằng `iostat` (gồm log, doublewrite, trang dữ liệu và metadata hệ tệp) chia cho số giao dịch. p50 của hai cấu hình trùng nhau do sysbench báo percentile theo các nhóm của histogram.],
  )
]

=== Đối chiếu với kết quả dự kiến

#[
  #set text(size: 9.5pt)
  #figure(
    table(
      columns: (1.3fr, 1.7fr, auto),
      align: (left, left, center),
      stroke: 0.5pt,
      inset: 5pt,
      table.header([*Dự kiến trước khi đo (theo mục 2.2.4)*], [*Kết quả đo*], [*Đánh giá*]),
      [PostgreSQL: bật `full_page_writes` làm tăng mạnh lượng WAL, chủ yếu là ảnh trang], [WAL mỗi giao dịch tăng từ 402 lên 2.281 byte (5,7 lần); FPI chiếm 82%], [Khớp],
      [Với 5 triệu tài khoản cập nhật ngẫu nhiên, tỉ lệ FPI cao], [82% byte WAL là FPI; tổng WAL mỗi lần chạy khoảng 874 MB so với 141 MB], [Khớp],
      [FPI tập trung ngay sau checkpoint rồi giảm], [Hình H7 (lần chạy r1): 8 đến 14 MB/giây trong khoảng 30 giây đầu của giai đoạn đo, về khoảng 0,6 MB/giây. Lần r2 và r3 đỉnh thấp hơn (khoảng 5 MB/giây) và giảm dần chậm hơn. Cả ba lần đều tăng lại khoảng 10 MB/giây sau checkpoint định kỳ], [Khớp một phần],
      [InnoDB: doublewrite làm mỗi trang flush bị ghi hai lần], [Lượng ghi qua doublewrite (10.945 byte) bằng lượng ghi trang dữ liệu (10.948 byte)], [Khớp],
      [InnoDB: redo log không đổi], [1.069 và 1.071 byte mỗi giao dịch], [Khớp],
      [Chi phí của InnoDB nhỏ nếu dữ liệu nằm gọn trong bộ đệm], [Mỗi giao dịch flush khoảng 0,67 trang nên chi phí đáng kể], [Không khớp],
      [TPS giảm khi bật bảo vệ trang], [PostgreSQL: không phân biệt được (1.294 so với 1.170, chồng lấn). InnoDB: tắt doublewrite tăng TPS 25,8% (884 so với 703), tức bật làm giảm khoảng 20%, nhưng hai khoảng giá trị chồng lấn], [Chưa kết luận được],
    ),
    caption: [Đối chiếu dự đoán lý thuyết với kết quả thí nghiệm B.],
  )
]

=== Phân tích

*1. PostgreSQL: chi phí nằm trong WAL, và gần như toàn bộ là ảnh trang đầy đủ.* Khi bật `full_page_writes`, mỗi giao dịch sinh 2.281 byte WAL so với 402 byte khi tắt, gấp khoảng 5,7 lần. Phần bản ghi thường gần như không đổi (408 và 402 byte); phần tăng thêm là 1.871 byte FPI, chiếm 82% WAL. Tổng lượng ghi đĩa đo độc lập bằng `iostat` tăng từ 3.998,4 lên 5.882,6 byte mỗi giao dịch (tăng 47,1%); phần chênh 1.884 byte khớp với phần FPI 1.871 byte. Nghĩa là số đo trong DBMS và số đo từ hệ điều hành xác nhận lẫn nhau. Số liệu cũng khớp với thí nghiệm A: ở 8 client, PostgreSQL `on` có 2.406 byte log mỗi giao dịch (mục 2.4), gần với 2.281 byte ở đây. Điều này cũng giải thích sự biến động byte log mỗi giao dịch của PostgreSQL giữa các ô ở thí nghiệm A.

#shot("img/H6_page_protection_cost.png", [H6 – Lượng ghi trên mỗi giao dịch khi bật và tắt bảo vệ trang. Chi phí của PostgreSQL nằm trong WAL, chi phí của InnoDB nằm ở ghi trang dữ liệu.], w: 75%)

*2. Phân loại WAL cho biết FPI đến từ đâu.* Kết quả `pg_waldump` cho thấy tổng WAL mỗi lần chạy khoảng 874 MB khi bật và 141 MB khi tắt, với FPI chiếm 82% khi bật. Trong phần FPI, nguồn lớn nhất là `Heap/HOT_UPDATE` (~47%) và `Heap2/PRUNE` (~33%), kế đến là `XLOG/FPI_FOR_HINT` (~8%, dao động 4,87–87,15 MB khi bật so với 0,21–0,81 MB khi tắt do cụm bật `--data-checksums`). Vì dữ liệu có 5 triệu tài khoản cập nhật ngẫu nhiên, hầu như mỗi giao dịch chạm một trang chưa sửa sau checkpoint và phải kèm ảnh 8 KB.

#shot("img/H8_wal_composition.png", [H8 – Thành phần WAL theo `pg_waldump`: ảnh trang đầy đủ (FPI) chiếm 82% khi `full_page_writes = on`.], w: 72%)

*3. Chi phí tập trung ngay sau checkpoint.* Hình H7 vẽ lần chạy r1 của mỗi cấu hình. Khi bật `full_page_writes`, WAL sinh ra ở mức 8 đến 14 MB/giây trong khoảng 30 giây đầu của giai đoạn đo (60 đến 90 giây sau `CHECKPOINT` thủ công), rồi giảm xuống khoảng 0,6 MB/giây từ giây thứ 50, bằng mức khi tắt. Hai lần chạy còn lại (r2, r3) đỉnh thấp hơn (~5 MB/giây) và giảm chậm hơn. Cả ba lần đều tăng lại khoảng 10 MB/giây khi đến thời điểm checkpoint định kỳ (`checkpoint_timeout = 5min`). Chu kỳ lặp lại này cho thấy FPI chỉ được ghi ở lần sửa đầu tiên của trang sau mỗi checkpoint; do đó checkpoint càng dày thì WAL càng phình nhưng thời gian phục hồi (RTO) càng ngắn.

#shot("img/H7_wal_rate.png", [H7 – Tốc độ sinh WAL theo thời gian (lần chạy r1 của mỗi cấu hình): đỉnh sau mỗi checkpoint khi `full_page_writes = on`.], w: 75%)

*4. TPS của PostgreSQL không phân biệt được hai cấu hình.* TPS là 1.294 khi bật và 1.170 khi tắt, nhưng độ biến thiên lớn (CV 17,0% khi bật) và các lần chạy khi bật (1.547,5, 1.189,3 và 1.145,4) chồng lấn với khi tắt (1.197,9, 1.116,2, 1.196,8). Độ trễ p50 của hai cấu hình trùng nhau (4,82 ms). Cùng lúc WAL tăng 5,7 lần, số fsync mỗi giao dịch gần như không đổi (0,270 và 0,269). Điều này gợi ý ở 8 client nút thắt vẫn là chờ fsync lúc COMMIT, chứ không phải lượng byte WAL, vì WAL được ghi tuần tự. Kết luận này khớp với thí nghiệm A, nơi ở 8 client PostgreSQL `on` đã bị giới hạn bởi tốc độ fsync.

*5. InnoDB: chi phí nằm ở ghi trang dữ liệu, redo log không đổi.* Redo log gần như không thay đổi giữa hai cấu hình (1.069 và 1.071 byte mỗi giao dịch). Với doublewrite ON, mỗi giao dịch ghi thêm khoảng 10.945 byte qua doublewrite (0,668 trang mỗi giao dịch, mỗi trang 16 KB), gần bằng lượng trang dữ liệu ghi thật (10.948 byte). Nghĩa là mỗi trang flush bị ghi hai lần. Điều này không nhân đôi số thao tác I/O ngẫu nhiên, vì doublewrite được ghi thành từng lô tuần tự lớn chỉ với một lần `fsync()` (mục 2.2.4), nhưng vẫn làm tăng gấp đôi lượng byte ghi trang. Ghi đĩa thực tế tăng từ 13.724 lên 24.749 byte mỗi giao dịch, gấp khoảng 1,8 lần (hay giảm 44,5% khi tắt doublewrite), và ba lần chạy của hai cấu hình tách rời nhau (22.351 đến 26.026 so với 12.967 đến 14.248 byte). Chi phí doublewrite tỉ lệ với số trang flush; ở workload này mỗi giao dịch cập nhật một trang ngẫu nhiên nên có khoảng 0,67 trang flush mỗi giao dịch, và chi phí không hề nhỏ.

*6. TPS của InnoDB cho thấy xu hướng, chưa đủ kết luận.* Tắt doublewrite làm TPS tăng từ 703 lên 884 (tăng 25,8%) và p99 giảm từ 72,3 xuống 63,1 ms; nói cách khác, bật doublewrite thấp hơn khoảng 20%. Tuy nhiên độ biến thiên rất lớn (CV 17% và 20%) và khoảng giá trị hai cấu hình chồng nhau (917,2, 718,7, 1.016,0 so với 619,2, 622,1, 866,8), nên với 3 lần chạy chỉ có thể nói xu hướng phù hợp với việc ghi trang gấp đôi.

*7. Chi phí ở hai vị trí khác nhau.* Chống rách trang tốn thêm khoảng 1,9 KB mỗi giao dịch trong WAL ở PostgreSQL, và khoảng 10,9 KB mỗi giao dịch ở ghi trang dữ liệu ở InnoDB. Số byte ở InnoDB lớn hơn nhiều, nhiều khả năng vì InnoDB ghi lại cả trang 16 KB mỗi lần flush, còn PostgreSQL chỉ chụp trang một lần sau mỗi checkpoint. So sánh tổng ghi đĩa thực tế mỗi giao dịch ở cấu hình bền vững (hình H6), InnoDB (24,7 KB) cao hơn khoảng 4,2 lần PostgreSQL (5,9 KB), do trang 16 KB lớn gấp đôi trang 8 KB và mọi trang bẩn đều ghi qua doublewrite. Hai con số không thể so trực tiếp thành "hệ nào rẻ hơn", vì đo ở hai vị trí khác nhau (log và trang dữ liệu), và PostgreSQL còn phụ thuộc vào tần suất checkpoint. Điều quan trọng là đúng như lý thuyết ở mục 2.2.4: chi phí của PostgreSQL nằm trong log, còn chi phí của InnoDB nằm trong ghi trang. Điều này có hệ quả thực tế: PostgreSQL có thể giảm chi phí này bằng cách giảm tần suất checkpoint (đánh đổi bằng RTO dài hơn), còn InnoDB nên chú ý băng thông ghi trang dữ liệu.

=== Độ tin cậy số liệu

Ba trong bốn cấu hình có CV TPS 17%–20% (PG `fpw=on`: 1.547,5 / 1.189,3 / 1.145,4, CV 17,0%; PG `off`: 1.197,9 / 1.116,2 / 1.196,8, CV 4,0%; MySQL `ON`: 619,2 / 622,1 / 866,8, CV 20,2%; MySQL `OFF`: 917,2 / 718,7 / 1.016,0, CV 17,1%) do dao động hiệu năng của ổ SSD gắn ngoài qua USB 3 khi phải gánh đồng thời ghi trang và `fsync`, nên nhóm không kết luận về tác động lên TPS. Ngược lại, các chỉ số đếm byte (WAL, doublewrite, `iostat`) ổn định cao giữa các lần chạy. Thí nghiệm B chỉ đo chi phí ở 8 client trên workload cập nhật ngẫu nhiên 5 triệu tài khoản, không mô phỏng tạo rách trang thật (lợi ích bảo vệ trang giải thích ở mục 2.2.4).

#include "tv3_2_6_ket_qua_C.typ"

== Kết luận và đề xuất

Tổng hợp kết quả ba thí nghiệm:

- *Thí nghiệm A (chi phí flush log):* Chờ `fsync` làm TPS cấu hình bền vững thấp hơn cấu hình mềm 3,7–18,2 lần ở PostgreSQL và 2,8–11,7 lần ở MySQL. Group commit giúp giảm số `fsync` mỗi giao dịch xuống dưới 0,1 ở 32 client nhưng không triệt tiêu hoàn toàn chi phí.
- *Thí nghiệm B (chi phí bảo vệ trang):* Hai hệ trả chi phí ở hai vị trí khác nhau — PostgreSQL tăng WAL 5,7 lần (82% là FPI ngay sau checkpoint), còn InnoDB tăng ghi đĩa 1,8 lần do doublewrite ghi mỗi trang flush hai lần (redo log không đổi). Không được tắt hai cơ chế này trên hệ thống thật vì rủi ro rách trang khi crash OS hoặc mất điện. Với PostgreSQL có thể tăng `checkpoint_timeout` / `max_wal_size` để giảm FPI (đổi lấy RTO dài hơn); với InnoDB có thể đặt `innodb_doublewrite_dir` trên ổ nhanh riêng.
- *Thí nghiệm C (crash và phục hồi):* Cấu hình bền vững (`on`, `=1`) không mất giao dịch nào qua 12 lần crash ở cả hai mức sự cố. InnoDB `=2` là "bẫy": an toàn khi kill tiến trình nhưng mất tới 2.674 giao dịch (~552 ms) khi hệ điều hành sập. Mọi cấu hình đều giữ đúng bất biến $A = T = B = H$ (42/42 lần) và `amcheck` / `CHECK TABLE` không thấy hỏng trang. RPO luôn nằm dưới chu kỳ flush định kỳ (≤ 197 ms với PG `off`, ≤ 630 ms với InnoDB `=2`/`=0`); RTO theo log 7–19 giây chủ yếu do các bước khởi động sau redo.

Cấu hình khuyến nghị phụ thuộc vào yêu cầu ứng dụng:

#figure(
  table(
    columns: (1.3fr, auto, auto, 2fr),
    align: (left, left, left, left),
    stroke: 0.5pt,
    inset: 5pt,
    table.header([*Loại ứng dụng*], [*PostgreSQL*], [*MySQL InnoDB*], [*Căn cứ*]),
    [Tài chính, đơn hàng, mọi dữ liệu không được phép mất], [`synchronous_commit = on`], [`=1`], [Không mất giao dịch nào qua 12 lần crash; đổi lại TPS thấp hơn nhiều lần (thí nghiệm A)],
    [Log, số liệu theo dõi, dữ liệu tái tạo được; chấp nhận mất ~1 giây cuối khi máy sập], [`off`], [`=0`], [RPO tối đa ~0,2 s (PostgreSQL) và ~0,63 s (InnoDB); dữ liệu vẫn nhất quán; TPS cao hơn nhiều lần],
    [Chỉ lo tiến trình DBMS sập, hệ điều hành ổn định], [không có tương đương], [`=2`], [Không mất khi kill tiến trình (0/5 lần), nhưng mất tới 552 ms khi hệ điều hành sập; không dùng nếu không chắc về hệ điều hành],
  ),
  caption: [Bảng B4 – Đề xuất cấu hình theo loại ứng dụng.],
)

Giới hạn chung của nghiên cứu: (1) chỉ đo trên một máy và một ổ SSD SATA gắn ngoài qua USB 3 (`write back`); (2) không mô phỏng mất điện vật lý thật hay tạo rách trang ở tầng block device; (3) tắt binlog MySQL để so sánh công bằng với WAL; (4) số lần lặp còn ít (3 lần mỗi ô ở A/B, 3–5 lần crash ở C) nên một số ô có CV > 10% và RPO/RTO chỉ mang tính định hướng.

// ============================================================
// TÀI LIỆU THAM KHẢO
// ============================================================
#heading(level: 2, numbering: none)[Tài liệu tham khảo]
#[
  #set text(size: 9.5pt)
  #set par(leading: 0.55em)
  1. PostgreSQL Global Development Group. *PostgreSQL 16 Documentation – Reliability and the Write-Ahead Log; WAL Configuration; WAL Internals; Asynchronous Commit; amcheck*. https://www.postgresql.org/docs/16/wal.html
  2. Oracle Corporation. *MySQL 8.4 Reference Manual – InnoDB Startup Options; InnoDB Recovery; 17.6.4 Doublewrite Buffer*. https://dev.mysql.com/doc/refman/8.4/en/innodb-parameters.html
  3. Silberschatz, A., Korth, H. F., Sudarshan, S. *Database System Concepts* (Recovery & Storage Systems).
  4. libvirt. *virsh – Virtual Machine Management (`virsh destroy`)*. https://libvirt.org/manpages/virsh.html
]
