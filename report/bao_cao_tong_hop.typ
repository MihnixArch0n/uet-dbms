// ============================================================
// BÁO CÁO TỔNG HỢP – cả nhóm
// Đề tài: Durability & Crash Recovery (PostgreSQL vs MySQL InnoDB)
// Ghép phần TV1 (mục 1, 2.1, 2.2, 2.4, 2.7), TV3 (2.2.4, 2.3, 2.6) – cập nhật 26/11/2026.
// Mục 2.2.4 do TV2 viết (tv2_2_2_bao_ve_trang.typ). Mục 2.5 (thí nghiệm B) do TV1 viết lại chi tiết, đã đối chiếu và đồng bộ số liệu theo bản của TV2.
// Biên dịch: typst compile report/bao_cao_tong_hop.typ
// ============================================================

#set document(
  title: "Durability & Crash Recovery – PostgreSQL vs MySQL InnoDB",
  author: "Vũ Việt Anh, Phạm Tuấn Minh, Trần Minh Hiếu",
)
#set page(
  paper: "a4",
  // Lề theo file mẫu của trường: trên 2,5 cm, dưới 3 cm, trái 3 cm, phải 2 cm
  margin: (top: 2.5cm, bottom: 3cm, left: 3cm, right: 2cm),
  // Trang bìa, tóm tắt, lời cam đoan, mục lục không đánh số; số trang bắt đầu từ 1 ở phần Mở đầu.
  numbering: none,
)
// Nội dung: Times New Roman 13 pt (Liberation Serif là phông thay thế cùng kích thước chữ).
#set text(font: ("Times New Roman", "Liberation Serif"), size: 13pt, lang: "vi")
// Giãn dòng 1,3 lines như Word: khoảng cách hai dòng = 1,3 × 1,15 em ≈ 1,49 em,
// tức leading 0,83 em (Typst đo từ chân dòng trên tới đỉnh chữ hoa dòng dưới). Cách đoạn thêm 6 pt.
#set par(justify: true, leading: 0.83em, spacing: 0.83em + 6pt, first-line-indent: (amount: 1cm, all: true))
#show raw: set text(size: 0.85em)
// Đánh số theo quy định: "Chương 1.", rồi 1.1., 1.1.1.
#set heading(numbering: (..n) => {
  let a = n.pos()
  if a.len() == 1 { "Chương " + str(a.first()) + "." } else { a.map(str).join(".") + "." }
})
// Chỉ các mục lớn bắt đầu trang mới: Phân công, 1., 2., Tài liệu tham khảo (và Mục lục).
#show heading.where(level: 1): it => {
  pagebreak(weak: true)
  // Hình, bảng đánh số lại từ đầu ở mỗi chương
  if it.numbering != none {
    counter(figure.where(kind: image)).update(0)
    counter(figure.where(kind: table)).update(0)
  }
  v(0.6em)
  it
  v(0.6em)
}
#show heading.where(level: 2): it => {
  v(0.6em)
  it
  v(0.3em)
}
#show figure: set block(breakable: true)
// Hình và bảng đánh số theo chương (Hình 1.1, Bảng 2.3); chú thích bảng đặt trên đầu bảng, chú thích hình đặt dưới hình.
#set figure(numbering: n => numbering("1.1", counter(heading).get().first(), n))
#set figure.caption(separator: [. ])
#show figure.where(kind: table): set figure.caption(position: top)
#show figure.where(kind: table): set block(breakable: false)
#show figure.caption: set par(first-line-indent: 0cm)
#show table.cell: set par(first-line-indent: 0cm)
#show outline: set par(first-line-indent: 0cm)
// Bảng: chữ 11 pt, giãn dòng hẹp hơn nội dung, không căn đều trong ô. Chú thích hình/bảng 12 pt.
#show table: set text(size: 11pt)
#show table: set par(justify: false, leading: 0.55em)
#show figure.caption: set text(size: 12pt)
// Hình nằm đúng vị trí trong văn bản. Riêng vài hình lớn ở giữa mục được đặt pl: top:
// nếu không đủ chỗ, hình lên đầu trang sau và phần chữ phía sau lấp chỗ trống ở trang hiện tại.
#let shot(path, cap, w: 100%, pl: none) = figure(image(path, width: w), caption: cap, placement: pl)
#import "diagrams.typ": diagram-data-path

// ============================================================
// BÌA
// ============================================================
// Theo trang bìa mẫu của Trường ĐHCN (khung viền đôi, logo, các dòng căn giữa).
// Khung đặt đúng vị trí như mẫu: cách mép trái 2,79 cm, mép trên 2,5 cm, rộng 16,23 cm, cao 25,45 cm.
#let navy = rgb(0, 31, 95)
#page(
  numbering: none,
  margin: (left: 2.79cm, top: 2.5cm, right: 21cm - 2.79cm - 16.23cm, bottom: 29.7cm - 2.5cm - 25.45cm),
)[
  #set text(font: ("Times New Roman", "Liberation Serif"), weight: "bold")
  #set par(justify: false, leading: 0.6em, first-line-indent: 0cm)
  // Khung viền đôi: đường mảnh bên ngoài, đường đậm bên trong
  #place(top + left, rect(width: 100%, height: 100%, stroke: 0.75pt + navy))
  #place(top + left, dx: 2.6pt, dy: 2.6pt, rect(width: 100% - 5.2pt, height: 100% - 5.2pt, stroke: 2.6pt + navy))

  #place(top + center, dy: 0.85cm, align(center, text(12pt)[ĐẠI HỌC QUỐC GIA HÀ NỘI \ #v(0.15cm) TRƯỜNG ĐẠI HỌC CÔNG NGHỆ]))
  #place(top + center, dy: 4.2cm, image("img/logo_uet.png", width: 3.34cm))
  #place(top + center, dy: 9.6cm, block(width: 13.5cm, align(center, text(18pt)[
    DURABILITY \& CRASH RECOVERY: \ SO SÁNH POSTGRESQL VÀ MYSQL INNODB
  ])))
  #place(top + center, dy: 12.3cm, align(center, text(14pt)[Báo cáo bài tập lớn môn Hệ quản trị cơ sở dữ liệu]))
  #place(top + center, dy: 15.2cm, align(center, text(14pt)[
    NHÓM 02 \
    #v(0.15cm)
    Sinh viên thực hiện \
    #v(0.2cm)
    #text(14pt)[
      Vũ Việt Anh – 24020033 \
      Phạm Tuấn Minh – 24020240 \
      Trần Minh Hiếu – 24020132
    ]
  ]))
  #place(bottom + center, dy: -1.6cm, text(12pt)[HÀ NỘI - 2026])
]

#include "mo_dau_tom_tat.typ"


// ============================================================
// MỤC LỤC + PHÂN CÔNG
// ============================================================
#[
  #set text(size: 12pt)
  #show outline.entry: set block(above: 0.35em, below: 0.35em)
  #outline(title: "Mục lục", indent: 1em, depth: 2)
]

#heading(level: 2, numbering: none, outlined: false)[Danh mục chữ viết tắt]

#table(
  columns: (auto, 1fr, auto, 1fr),
  stroke: 0.5pt,
  inset: 3.5pt,
  [*Viết tắt*], [*Ý nghĩa*], [*Viết tắt*], [*Ý nghĩa*],
  [CV], [Hệ số biến thiên], [MVCC], [Multi-Version Concurrency Control],
  [DBMS], [Hệ quản trị cơ sở dữ liệu], [PG], [PostgreSQL],
  [FPI], [Full-Page Image – ảnh trang đầy đủ], [RPO], [Recovery Point Objective],
  [GD], [Giao dịch], [RTO], [Recovery Time Objective],
  [HĐH], [Hệ điều hành], [SSD], [Solid-State Drive],
  [KVM], [Kernel-based Virtual Machine], [TPS], [Số giao dịch mỗi giây],
  [LSN], [Log Sequence Number], [WAL], [Write-Ahead Logging],
)

#include "mo_dau.typ"

// ============================================================
// PHẦN 1 – POSTGRESQL
// ============================================================
= PostgreSQL

== Tổng quan

PostgreSQL bắt nguồn từ dự án POSTGRES tại Đại học California, Berkeley (1986) do Michael Stonebraker dẫn dắt. Năm 1996 dự án được đổi tên thành PostgreSQL và trở thành phần mềm mã nguồn mở. Hiện nay PostgreSQL là một trong những hệ quản trị cơ sở dữ liệu quan hệ (RDBMS) mạnh mẽ nhất, tuân thủ phần lớn chuẩn SQL và nhiều tính năng hướng đối tượng.

Điểm khác biệt nổi bật so với MySQL là mô hình *object-relational*: PostgreSQL cho phép người dùng định nghĩa kiểu dữ liệu mới, toán tử, hàm và chỉ mục tùy biến. MySQL (đặc biệt với engine InnoDB) tập trung vào hiệu năng web và dễ triển khai, trong khi PostgreSQL hướng tới tính đúng đắn, khả năng mở rộng và tuân thủ chuẩn. Oracle và SQL Server là các hệ thương mại có nhiều tính năng enterprise tương tự, nhưng PostgreSQL cung cấp hầu hết các khả năng đó dưới giấy phép mở (PostgreSQL License – tương tự BSD) [3].

== Kiến trúc

PostgreSQL dùng mô hình *process-per-connection*: tiến trình chính (`postmaster`) lắng nghe kết nối và fork một `backend process` riêng cho mỗi client (cô lập lỗi tốt, tốn bộ nhớ hơn thread của MySQL). Các tiến trình nền chính gồm: *checkpointer* (ghi trang bẩn định kỳ và tạo checkpoint), *background writer* (ghi dần trang bẩn), *WAL writer* (đẩy WAL theo chu kỳ `wal_writer_delay`), và *autovacuum* (dọn phiên bản cũ MVCC) [3].

Bộ nhớ chia thành *Shared memory* (shared buffers, WAL buffers, lock table) và *Backend-private memory* (`work_mem`, `maintenance_work_mem`). Lưu trữ vật lý dưới `$PGDATA` gồm `base/` (dữ liệu bảng/chỉ mục dạng trang 8 KB, dữ liệu lớn tách sang TOAST), `pg_wal/` (các file WAL 16 MB) và `global/` (catalog toàn cục, `pg_control`).

#shot("img/H2_kien_truc_pg.png", [Sơ đồ kiến trúc tiến trình và bộ nhớ PostgreSQL: postmaster, backend, bộ nhớ chung, tiến trình nền và các thư mục dữ liệu.], w: 85%)

== Tính năng chính

PostgreSQL hỗ trợ nhiều kiểu dữ liệu nâng cao (JSONB, mảng, range, hstore, geometric) và chỉ mục phong phú (B-tree, GIN, GiST, BRIN). Cơ chế MVCC giúp đọc không bị chặn bởi ghi, hỗ trợ cô lập từ Read Committed đến Serializable (SSI), cùng khả năng mở rộng bằng PL/pgSQL, trigger, view và extension (PostGIS, `pg_stat_statements`…).

== Cài đặt, cấu hình và vận hành

Hai container `bench-pg` (`postgres:16`, cổng 5432) và `bench-mysql` (`mysql:8.4`, cổng 3306) chạy qua Docker Compose với cấu hình nền tương đương: `shared_buffers = 2GB`, `max_wal_size = 4GB`, `checkpoint_timeout = 5min`, `full_page_writes = on`, `fsync = on`, `synchronous_commit = on`.

#figure(
  grid(
    columns: 1,
    align: center,
    gutter: 8pt,
    image("img/P1_01_docker_ps.png", width: 70%),
    image("img/P1_02_cau_hinh_nap.png", width: 82%),
  ),
  caption: [Hai container PostgreSQL 16 và MySQL 8.4 (trên) và đối chiếu cấu hình nạp trước thí nghiệm (dưới).],
)

== Demo chức năng cơ bản

Các thao tác cơ bản được thực hiện trên PostgreSQL 16.16 (dữ liệu `pgbench` scale 50). Bảng dưới tóm tắt các thao tác SQL và vận hành đã demo; toàn bộ lệnh nằm trong `demo/part1_demo.sql` và ảnh chụp tương ứng nằm trong `report/img/` của repo. Hai mục con sau đó trình bày chi tiết các thao tác liên quan trực tiếp đến durability ở Phần 2.

#figure(
  table(
    columns: (3.3cm, 1fr, 1.7cm),
    align: (left, left, center),
    stroke: 0.5pt,
    inset: 4pt,
    table.header([*Thao tác*], [*Lệnh và kết quả*], [*Ảnh*]),
    [Tạo bảng, nạp và truy vấn], [Nạp 100.000 dòng vào `demo_customer` bằng `COPY ... FROM PROGRAM`; truy vấn gom nhóm trả về 1 nhóm (Ha Noi) gồm 100.000 khách hàng, số dư trung bình 4.995], [`P1_05`],
    [Kế hoạch thực thi], [`EXPLAIN ANALYZE`: tìm theo khóa chính dùng Index Scan, 1,236 ms; lọc `abalance > 1000` dùng Parallel Seq Scan, 7.956,85 ms (chậm hơn khoảng 6.400 lần)], [`P1_06`],
    [Phân quyền], [Tạo role `teller`, cấp `SELECT, UPDATE` trên `pgbench_accounts`; `\dp` hiển thị `teller=rw/postgres`], [`P1_09`],
    [Sao lưu, khôi phục], [`pg_dump -Fc` hai bảng, `pg_restore` vào database `restore_demo`: đủ 2 bảng, `pgbench_tellers` có 500 dòng], [`P1_11`],
    [Đo tải nhanh], [`pgbench` 4 client, 30 giây: 23.367 giao dịch, 0 lỗi, độ trễ trung bình 5,135 ms, 778,88 TPS], [`P1_12`],
    [Công cụ đồ họa], [DBeaver kết nối cổng 5432, hiển thị cây đối tượng và sơ đồ 5 bảng], [`P1_13`, `P1_14`],
  ),
  caption: [Các thao tác cơ bản đã demo trên PostgreSQL (lệnh trong `demo/part1_demo.sql`).],
)


=== Phiên bản, tham số độ bền và tiến trình nền

Máy chủ là PostgreSQL 16.16 với các tham số đúng thiết kế: `wal_level = replica`, `synchronous_commit = on`, `full_page_writes = on`, `shared_buffers = 2GB` và `data_checksums = on` (giúp phát hiện trang hỏng khi đọc). Bảng `pg_stat_activity` xác nhận các tiến trình nền liên quan trực tiếp đến durability (`checkpointer`, `background writer`, `walwriter`) cùng các tiến trình `autovacuum launcher` và `client backend`.

#figure(
  grid(
    columns: 1,
    align: center,
    gutter: 8pt,
    image("img/P1_03_phien_ban_tham_so.png", width: 82%),
    image("img/P1_04_tien_trinh.png", width: 100%),
  ),
  caption: [Phiên bản, tham số durability (trên) và các tiến trình nền qua `pg_stat_activity` (dưới).],
)

=== LSN, file WAL và thống kê checkpoint

Trước khi COMMIT, vị trí ghi WAL là `F/2D950208`. Sau một giao dịch `UPDATE` rồi `COMMIT`, vị trí này tăng lên `F/2D950310` (+264 byte cho bản ghi cập nhật và commit), nằm trong file `000000010000000F0000002D` (16 MB). Hai view `pg_stat_wal` và `pg_stat_bgwriter` ghi nhận 2.666.921 bản ghi WAL (178,9 MB), 172 FPI (`wal_fpi`), `wal_buffers_full = 0`, số lần `wal_write` (116.912) và `wal_sync` (116.909) gần bằng nhau; cùng 23 `checkpoints_timed` và 92 `checkpoints_req` (chủ yếu do script chạy `CHECKPOINT` thủ công trước mỗi lần đo của thí nghiệm A và B).

#figure(
  grid(
    columns: 1,
    align: center,
    gutter: 8pt,
    image("img/P1_07_wal_lsn.png", width: 100%),
    image("img/P1_08_thong_ke_wal.png", width: 100%),
  ),
  caption: [LSN trước/sau COMMIT (trên) và thống kê `pg_stat_wal` / `pg_stat_bgwriter` (dưới).],
)

#pagebreak()

// ============================================================
// PHẦN 2 – TÌM HIỂU VÀ THỰC NGHIỆM
// ============================================================
= Tìm hiểu và thực nghiệm về Durability \& Crash Recovery

== Đặt vấn đề

Thuộc tính *Durability* (ACID) đòi hỏi dữ liệu của giao dịch đã xác nhận COMMIT không được mất dù hệ thống sập ngay sau đó. Dữ liệu đi qua 4 tầng: (1) bộ đệm DBMS (`shared_buffers` / buffer pool) → (2) page cache HĐH (`write()`) → (3) cache bộ điều khiển đĩa → (4) bề mặt đĩa (`fsync()`). Theo đó, *crash tiến trình DBMS* (`kill -9`) chỉ mất tầng (1); *crash HĐH* (tắt nguồn ảo) mất thêm tầng (2); *mất điện thật* có thể mất cả tầng (3) nếu ổ không tôn trọng flush.

Ghi thẳng trang dữ liệu khi COMMIT rất chậm vì I/O ngẫu nhiên. *Write-Ahead Logging* (WAL) [4] khắc phục bằng cách ghi tuần tự vào log trước khi báo COMMIT, còn trang dữ liệu ghi sau (lazy). Tuy nhiên, trang DBMS (8 KB PostgreSQL, 16 KB InnoDB) lớn hơn đơn vị ghi nguyên tử của HĐH/ổ đĩa (4 KB); nếu sập giữa lúc ghi, trang bị *rách* (torn page) và log thay đổi không đủ sửa. Hai vấn đề độc lập này — *flush log khi COMMIT* và *bảo vệ trang* — được tách thành hai thí nghiệm A và B.

#figure(
  diagram-data-path(),
  kind: image,
  caption: [Đường đi của dữ liệu từ DBMS đến đĩa và phạm vi mất dữ liệu của từng loại sự cố.],
)

Ba câu hỏi nghiên cứu: (1) Chi phí hiệu năng (TPS, độ trễ) của việc chờ `fsync` log khi COMMIT? *(Thí nghiệm A)*; (2) Chi phí của cơ chế bảo vệ trang? *(Thí nghiệm B)*; (3) Khi crash thật xảy ra, giao dịch đã COMMIT có mất không, dữ liệu có nhất quán không và RTO bao lâu? *(Thí nghiệm C)*.

== Cơ chế của hai hệ

=== PostgreSQL – WAL và synchronous_commit

Mọi thay đổi sinh bản ghi trong *WAL buffers*. Khi COMMIT, backend ghi WAL ra đĩa và gọi `fsync`/`fdatasync` tùy cấu hình [3]:
- `synchronous_commit = on` (mặc định, bền vững): chờ WAL flush xuống đĩa rồi mới trả lời client.
- `synchronous_commit = off`: trả lời ngay khi bản ghi vào WAL buffers; `walwriter` flush định kỳ theo `wal_writer_delay` (200 ms, cửa sổ mất tối đa ~3 lần chu kỳ nhưng không rách trang). Khác hoàn toàn `fsync = off` (có thể hỏng DB).

*Group commit*: khi nhiều backend cùng chờ `WALWriteLock`, PostgreSQL gom lại thực hiện một lần `fsync` cho cả nhóm (giúp TPS tăng mạnh theo số client). File WAL (16 MB) nằm ở `pg_wal/` và được tái sử dụng theo checkpoint.

=== MySQL InnoDB – Redo log và innodb_flush_log_at_trx_commit

InnoDB ghi thay đổi vào *redo log* (vòng tròn, cố định) [2]: `1` (flush mỗi COMMIT — bền vững nhất), `2` (`write()` vào page cache mỗi COMMIT, `fsync()` mỗi ~1 giây — an toàn với crash tiến trình nhưng mất ~1 s khi sập HĐH), và `0` (ghi + flush mỗi ~1 giây — có thể mất ngay cả khi kill tiến trình). Binlog được tắt (`skip-log-bin`) để chỉ so sánh redo log với WAL.

=== Cấu hình bền vững dùng trong thí nghiệm

Cấu hình bền vững (`fsync = on`, `synchronous_commit = on`, `full_page_writes = on` cho PostgreSQL; `innodb_flush_log_at_trx_commit = 1`, `innodb_doublewrite = ON` cho InnoDB — chi tiết ở bảng B2) được giữ làm nền. Thí nghiệm A *chỉ* thay đổi tham số flush log và giữ nguyên bảo vệ trang để đo riêng chi phí chờ `fsync` khi COMMIT.

#include "tv2_2_2_bao_ve_trang.typ"

Thí nghiệm B (mục 2.5) đo chi phí này, và chỉ thay đổi cơ chế bảo vệ trang, giữ nguyên flush log chặt, để tách khỏi thí nghiệm A.

#include "tv3_2_2_checkpoint_phuc_hoi.typ"

#include "tv3_2_3_phuong_phap.typ"

== Kết quả thí nghiệm A

Thí nghiệm A đo chi phí hiệu năng của việc chờ `fsync` log khi COMMIT: chỉ thay đổi tham số flush log (PostgreSQL `on`/`off`; InnoDB `1`/`2`/`0`), giữ nguyên bảo vệ trang và tắt binlog. Tổng cộng 45 lần chạy (300 giây đo sau 60 giây làm nóng, ở 1, 8, 32 client, 3 lần lặp mỗi ô), xử lý 61.489.705 giao dịch.

=== Quy trình đo và tính đúng của dữ liệu

Trước mỗi loạt (một DBMS), script đưa dữ liệu về trạng thái ban đầu (`0|0|0|0|0`). Mỗi lần chạy gồm: khởi động lại DBMS; `CHECKPOINT` và reset thống kê WAL (PostgreSQL); làm nóng 60 giây; chụp thống kê trước; chạy `sysbench` 300 giây kèm `iostat` mỗi 10 giây; chụp thống kê sau; kiểm tra bất biến. Cả 45 lần chạy đều giữ đúng bất biến $A = T = B = H$ và 0 giao dịch lỗi (`ignored errors = 0`), kể cả ở cấu hình `off` và `=0`.

=== Bảng kết quả

#[
  #set text(size: 11pt)
  #figure(
    table(
      columns: (auto, auto, auto, auto, auto, auto, auto, auto),
      align: center,
      stroke: 0.5pt,
      inset: 4pt,
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
  #set text(size: 11pt)
  #figure(
    table(
      columns: (auto, auto, auto, auto, auto, auto),
      align: center,
      stroke: 0.5pt,
      inset: 4pt,
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
  #set text(size: 11pt)
  #figure(
    table(
      columns: (3.8cm, 1fr, 3cm),
      align: (left, left, center),
      stroke: 0.5pt,
      inset: 4pt,
      table.header([*Dự kiến theo lý thuyết*], [*Kết quả đo*], [*Đánh giá*]),
      [Ở 1 client với cấu hình bền vững, TPS xấp xỉ tốc độ fsync của ổ đĩa], [PostgreSQL `on`: 389 TPS (hai lần ổn định đạt 417, bằng 98% trần 424). MySQL `=1`: 214 TPS so với trần 210], [Khớp],
      [Tăng số client thì số fsync mỗi giao dịch giảm (group commit)], [PostgreSQL `on`: 1,000 → 0,270 → 0,090. MySQL `=1`: 1,391 → 0,251 → 0,064], [Khớp],
      [Cấu hình mềm cao hơn cấu hình bền vững nhiều lần], [PostgreSQL `off` gấp 13,4 đến 18,2 lần ở 1 và 8 client; MySQL `=0` gấp 6,2 đến 11,7 lần], [Khớp],
      [Khoảng cách thu hẹp khi tăng số client], [Thu hẹp ở 32 client (PostgreSQL còn 3,7 lần, MySQL còn 2,8 lần), nhưng với PostgreSQL khoảng cách ở 8 client (18,2 lần) lớn hơn ở 1 client (13,4 lần)], [Khớp một phần],
      [InnoDB `=2` gần `=0` ở tải thấp, đều cao hơn `=1`], [1 client: `=2` đạt 2.420, `=0` đạt 2.511, `=1` đạt 214 TPS. Thứ tự `=0` ≥ `=2` ≥ `=1` đúng ở cả ba mức client], [Khớp],
      [TPS tăng theo số client ở mọi cấu hình], [PostgreSQL `off` giảm từ 20.930 (8 client) xuống 12.773 (32 client); các cấu hình khác tăng], [Không khớp, cần giải thích (ý 6 phần phân tích)],
      [Cấu hình mềm gần như không có fsync mỗi giao dịch], [Từ 0,000 đến 0,002 fsync mỗi giao dịch], [Khớp],
      [Mỗi giao dịch của MySQL có khoảng 1 fsync khi `=1`], [1,391 fsync mỗi giao dịch ở 1 client, lớn hơn 1], [Không khớp, giải thích ở ý 1 phần phân tích],
    ),
    caption: [Đối chiếu dự đoán lý thuyết với kết quả thí nghiệm A.],
  )
]

=== Phân tích

*1. Với 1 client, TPS bị chặn đúng bằng tốc độ fsync của ổ đĩa.* Với PostgreSQL `on`, mỗi giao dịch dùng đúng 1,000 lần fsync; hai trong ba lần chạy đạt ~417 TPS (98% trần 424 của `fdatasync`), độ trễ p50 là 2,35 ms (khớp 1/424 s ≈ 2,36 ms). Với MySQL `=1`, TPS ổn định quanh 198 (một lần 246), gần trần 210 của `fsync`, p50 là 2,90 ms (trung bình ~4,7 ms ≈ 1/210 s). Sở dĩ InnoDB ghi nhận trung bình `1,391` fsync/giao dịch (298 fsync/giây) là do `Innodb_os_log_fsyncs` chỉ đếm `fsync()` trên file redo log; khi `=1`, cặp luồng `log_writer` và `log_flusher` kích hoạt `fsync()` mỗi khi `write_lsn` tiến lên (bao gồm cả các mini-transaction trước `COMMIT` và tác vụ nền), còn tốc độ 298 fsync/s có thể do ghi lô nhỏ khác kịch bản 8 KB cố định của `pg_test_fsync`.

*2. Group commit làm tăng TPS nhưng không làm tăng số fsync mỗi giây.* Ở PostgreSQL `on`, số fsync mỗi giây là 389, 310 và 308 khi số client là 1, 8 và 32 (~73% trần ổ đĩa), nhưng TPS vẫn tăng từ 1.149 lên 3.441 nhờ mỗi lần fsync phục vụ 3,7 giao dịch (8 client) và 11,2 giao dịch (32 client). Nhóm chỉ lấp đầy 46% (8 client) và 35% (32 client) do giao dịch đến không đồng bộ. Với MySQL `=1`, số giao dịch mỗi fsync tăng từ 4,0 lên 15,7, nhưng fsync/giây giảm từ 185 xuống 112 (~53% trần) vì ở 32 client đã bị nghẽn bởi tranh chấp khóa (ý 6).

*3. Cái giá của durability: bao nhiêu lần, và thay đổi theo số client.* Bảng sau là tỉ lệ TPS giữa cấu hình mềm và cấu hình bền vững.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: center,
    stroke: 0.5pt,
    inset: 5pt,
    table.header([*So sánh*], [*1 client*], [*8 client*], [*32 client*]),
    [PG `off` / `on`], [13,4×], [18,2×], [3,7×],
    [MySQL `=0` / `=1`], [11,7×], [6,2×], [2,8×],
    [MySQL `=2` / `=1`], [11,3×], [4,9×], [2,1×],
  ),
  caption: [Tỉ lệ TPS giữa cấu hình mềm và cấu hình bền vững.],
)

Khoảng cách lớn nhất ở tải thấp đến trung bình rồi thu hẹp ở 32 client nhờ group commit (riêng PG ở 8 client đạt đỉnh 20.930 TPS nên tỉ lệ tới 18,2×).

#figure(
  grid(
    columns: 1,
    align: center,
    gutter: 8pt,
    image("img/H5_fsync_per_txn.png", width: 66%),
    image("img/H3_tps_vs_clients.png", width: 90%),
  ),
  caption: [Số lần fsync mỗi giao dịch (trên) và thông lượng TPS theo cấu hình và số client (dưới).],
  placement: top,
)

*4. Độ trễ: cấu hình bền vững chậm hơn nhiều lần ở tải thấp.* Độ trễ p50 của PostgreSQL `on` là 2,35 / 4,82 / 4,94 ms ở 1 / 8 / 32 client, chậm hơn `off` (0,18 / 0,35 / 1,19 ms) từ 4,2 đến 13,8 lần. Với `on`, p50 ở 8 và 32 client (~4,8–4,9 ms) xấp xỉ gấp đôi một lần fsync, gợi ý giao dịch phải chờ đợt fsync đang chạy xong rồi mới đến nhóm mình. Đuôi độ trễ của MySQL `=1` dài hơn (p95 10,5–49,7 ms; p99 lên tới 178,4 ms ở 32 client).

#shot("img/H4_latency.png", [Độ trễ p50, p95, p99 theo cấu hình flush log.], w: 78%)

*5. MySQL `=2` nằm giữa `=1` và `=0`, và khoảng cách với `=0` rộng ra khi tăng tải.* Ở 1 client, `=2` đạt 2.420 TPS, gần `=0` (2.511) và cao hơn `=1` ~11 lần vì không chờ `fsync`. Ở 8 và 32 client, `=2` thấp hơn `=0` (3.607 so với 4.539, và 3.728 so với 4.893), do mỗi COMMIT của `=2` vẫn phải gọi `write()` đẩy log sang page cache, còn `=0` chỉ ghi định kỳ.

*6. Ở 32 client, hiệu năng bị giới hạn bởi tranh chấp khóa chứ không chỉ bởi fsync.* PostgreSQL `off` giảm từ 20.930 TPS (8 client) xuống 12.773 TPS (32 client) và p99 vọt từ 0,5 lên 52,9 ms (p95 chỉ 1,9 ms) do 32 client tranh chấp khóa dòng trên bảng `pgbench_branches` chỉ có 50 dòng. Với MySQL, p99 ở 32 client đều quanh 178–197 ms ở cả ba cấu hình và `=0` chỉ tăng 8% TPS từ 8 lên 32 client (4.539 lên 4.893).

*7. So sánh hai hệ, và phần chênh không đến từ flush.* Ở cấu hình bền vững, PostgreSQL `on` (389 / 1.149 / 3.441 TPS) cao hơn MySQL `=1` (214 / 735 / 1.760 TPS) 1,6–2,0 lần (khớp tỉ lệ trần `fdatasync`/`fsync` 424/210). Tuy nhiên ở cấu hình mềm, PostgreSQL `off` vẫn hơn MySQL `=0` tới 2,1–4,6 lần, nên chỉ nên so sánh tỉ lệ mềm/bền vững của từng hệ.

*8. Đánh đổi giữa hiệu năng (thí nghiệm A) và dữ liệu mất (thí nghiệm C).* Bảng sau đặt TPS thu được ở 8 client cạnh lượng dữ liệu bị mất khi sự cố ở thí nghiệm C (mục 2.6), để thấy cái giá thực sự của việc nới lỏng flush.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: center,
    stroke: 0.5pt,
    inset: 4pt,
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
  #set text(size: 11pt)
  #figure(
    table(
      columns: (auto, auto, auto, auto),
      align: center,
      stroke: 0.5pt,
      inset: 4pt,
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
  #set text(size: 10pt)
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
  #set text(size: 11pt)
  #figure(
    table(
      columns: (1.3fr, 1.7fr, auto),
      align: (left, left, center),
      stroke: 0.5pt,
      inset: 4pt,
      table.header([*Dự kiến trước khi đo (theo mục 2.2.4)*], [*Kết quả đo*], [*Đánh giá*]),
      [PostgreSQL: bật `full_page_writes` làm tăng mạnh lượng WAL, chủ yếu là ảnh trang], [WAL mỗi giao dịch tăng từ 402 lên 2.281 byte (5,7 lần); FPI chiếm 82%], [Khớp],
      [Với 5 triệu tài khoản cập nhật ngẫu nhiên, tỉ lệ FPI cao], [82% byte WAL là FPI; tổng WAL mỗi lần chạy khoảng 874 MB so với 141 MB], [Khớp],
      [FPI tập trung ngay sau checkpoint rồi giảm], [@fig-h7 (lần chạy r1): 8 đến 14 MB/giây trong khoảng 30 giây đầu của giai đoạn đo, về khoảng 0,6 MB/giây. Lần r2 và r3 đỉnh thấp hơn (khoảng 5 MB/giây) và giảm dần chậm hơn. Cả ba lần đều tăng lại khoảng 10 MB/giây sau checkpoint định kỳ], [Khớp một phần],
      [InnoDB: doublewrite làm mỗi trang flush bị ghi hai lần], [Lượng ghi qua doublewrite (10.945 byte) bằng lượng ghi trang dữ liệu (10.948 byte)], [Khớp],
      [InnoDB: redo log không đổi], [1.069 và 1.071 byte mỗi giao dịch], [Khớp],
      [Chi phí của InnoDB nhỏ nếu dữ liệu nằm gọn trong bộ đệm], [Mỗi giao dịch flush khoảng 0,67 trang nên chi phí đáng kể], [Không khớp],
      [TPS giảm khi bật bảo vệ trang], [PostgreSQL: không phân biệt được (1.294 so với 1.170, chồng lấn). InnoDB: tắt doublewrite tăng TPS 25,8% (884 so với 703), tức bật làm giảm khoảng 20%, nhưng hai khoảng giá trị chồng lấn], [Chưa kết luận được],
    ),
    caption: [Đối chiếu dự đoán lý thuyết với kết quả thí nghiệm B.],
  )
]

=== Phân tích

*1. PostgreSQL: chi phí nằm trong WAL, và gần như toàn bộ là ảnh trang đầy đủ.* Bật `full_page_writes` làm WAL tăng 5,7 lần (từ 402 lên 2.281 B/giao dịch; phần bản ghi thường giữ ~402–408 B, phần tăng là 1.871 B FPI chiếm 82%). Tổng ghi đĩa `iostat` tăng tương ứng từ 3.998,4 lên 5.882,6 B (+1.884 B, khớp 1.871 B FPI) và khớp mức 2.406 B/giao dịch của thí nghiệm A ở 8 client.

*2. Phân loại WAL cho biết FPI đến từ đâu.* Theo `pg_waldump`, tổng WAL mỗi lần chạy ~874 MB (bật) so với 141 MB (tắt); FPI chiếm 82% chủ yếu từ `Heap/HOT_UPDATE` (~47%), `Heap2/PRUNE` (~33%) và `XLOG/FPI_FOR_HINT` (~8% do bật `--data-checksums`), vì 5 triệu tài khoản cập nhật ngẫu nhiên khiến hầu hết giao dịch chạm trang chưa sửa sau checkpoint.

#figure(
  grid(
    columns: 1,
    align: center,
    gutter: 8pt,
    image("img/H6_page_protection_cost.png", width: 90%),
    image("img/H8_wal_composition.png", width: 66%),
  ),
  caption: [Lượng ghi mỗi giao dịch (trên) và thành phần WAL theo `pg_waldump` (dưới).],
  placement: top,
)

*3. Chi phí tập trung ngay sau checkpoint.* @fig-h7 vẽ lần chạy r1: khi bật `full_page_writes`, WAL đạt đỉnh 8–14 MB/s trong 30 giây đầu đo, giảm về ~0,6 MB/s từ giây 50 (r2, r3 đỉnh ~5 MB/s) và tăng lại ~10 MB/s ở mốc `checkpoint_timeout = 5min`. Điều này chứng tỏ FPI chỉ ghi ở lần sửa đầu sau mỗi checkpoint: checkpoint càng dày thì WAL càng phình nhưng RTO càng ngắn.

#shot("img/H7_wal_rate.png", [Tốc độ sinh WAL theo thời gian (lần chạy r1 của mỗi cấu hình): đỉnh sau mỗi checkpoint khi `full_page_writes = on`.], w: 78%) <fig-h7>

*4. TPS của PostgreSQL không phân biệt được hai cấu hình.* TPS đạt 1.294 (bật, CV 17,0%: 1.547,5 / 1.189,3 / 1.145,4) so với 1.170 (tắt: 1.197,9 / 1.116,2 / 1.196,8), p50 trùng 4,82 ms và fsync/giao dịch giữ 0,270–0,269: ở 8 client nút thắt vẫn là chờ fsync khi COMMIT chứ không phải ghi tuần tự WAL.

*5. InnoDB: chi phí nằm ở ghi trang dữ liệu, redo log không đổi.* Redo log giữ nguyên (1.069 vs 1.071 B/giao dịch). Với doublewrite ON, mỗi giao dịch ghi thêm 10.945 B qua doublewrite (0,668 trang 16 KB/giao dịch), bằng lượng ghi trang thật (10.948 B). Dù doublewrite ghi tuần tự theo lô, tổng ghi đĩa thực tế vẫn tăng 1,8 lần (từ 13.724 lên 24.749 B/giao dịch, hai nhóm tách rời hoàn toàn).

*6. TPS của InnoDB cho thấy xu hướng, chưa đủ kết luận.* Tắt doublewrite tăng TPS 25,8% (884 vs 703) và giảm p99 (63,1 vs 72,3 ms), nhưng CV lớn (17%–20%) và khoảng giá trị chồng lấn (619,2–866,8 vs 718,7–1.016,0).

*7. Chi phí ở hai vị trí khác nhau.* Chống rách trang tốn ~1,9 KB/giao dịch trong WAL (PostgreSQL) so với ~10,9 KB/giao dịch ở ghi trang dữ liệu (InnoDB), khiến tổng ghi đĩa InnoDB (24,7 KB) cao hơn 4,2 lần PostgreSQL (5,9 KB). Do đó PostgreSQL giảm FPI bằng cách giãn checkpoint (đánh đổi RTO), còn InnoDB cần tối ưu băng thông ghi trang.

=== Độ tin cậy số liệu

Ba trong bốn cấu hình có CV TPS 17%–20% (PG `fpw=on`: 1.547,5 / 1.189,3 / 1.145,4, CV 17,0%; PG `off`: 1.197,9 / 1.116,2 / 1.196,8, CV 4,0%; MySQL `ON`: 619,2 / 622,1 / 866,8, CV 20,2%; MySQL `OFF`: 917,2 / 718,7 / 1.016,0, CV 17,1%) do dao động hiệu năng của ổ SSD gắn ngoài qua USB 3 khi phải gánh đồng thời ghi trang và `fsync`, nên nhóm không kết luận về tác động lên TPS. Ngược lại, các chỉ số đếm byte (WAL, doublewrite, `iostat`) ổn định cao giữa các lần chạy. Thí nghiệm B chỉ đo chi phí ở 8 client trên workload cập nhật ngẫu nhiên 5 triệu tài khoản, không mô phỏng tạo rách trang thật (lợi ích bảo vệ trang giải thích ở mục 2.2.4).

#include "tv3_2_6_ket_qua_C.typ"

// ============================================================
// KẾT LUẬN
// ============================================================
#heading(level: 1, numbering: none)[Kết luận]

Báo cáo đã trả lời ba câu hỏi nghiên cứu đặt ra ở mục 2.1 bằng số liệu đo trên cùng một máy cho cả hai hệ. Tổng hợp kết quả ba thí nghiệm:

- *Thí nghiệm A (flush log):* Chờ `fsync` làm TPS cấu hình bền vững thấp hơn cấu hình mềm 3,7–18,2× (PostgreSQL `off`) và 2,8–11,7× (MySQL `=0`); group commit giảm xuống < 0,1 fsync/GD ở 32 client nhưng không triệt tiêu chi phí.
- *Thí nghiệm B (bảo vệ trang):* PostgreSQL trả chi phí vào WAL (tăng 5,7×, 82% là FPI sau checkpoint), InnoDB trả vào ghi đĩa qua doublewrite (tăng 1,8×, redo không đổi). Không tắt trên hệ thật; PG có thể tăng `checkpoint_timeout`/`max_wal_size`, InnoDB đặt `innodb_doublewrite_dir` trên ổ nhanh.
- *Thí nghiệm C (crash & phục hồi):* Cấu hình bền vững (`on`, `=1`) không mất giao dịch (0/12 lần); InnoDB `=2` an toàn khi kill tiến trình nhưng mất tới 2.674 GD (~552 ms) khi sập HĐH. Mọi cấu hình giữ bất biến 42/42 lần và không hỏng trang; RPO luôn dưới chu kỳ flush (≤ 197 ms PG `off`, ≤ 630 ms InnoDB `=2`/`=0`), RTO 7–19 s chủ yếu do khởi động sau redo.

Các kết quả đo khớp với phần lớn dự đoán rút ra từ lý thuyết; những điểm chưa khớp hoặc chưa đủ để kết luận đã được chỉ ra trong từng thí nghiệm. Từ đó, nhóm đề xuất cấu hình cho từng loại ứng dụng như bảng dưới.

#figure(
  numbering: none,
  table(
    columns: (1.4fr, 1.15fr, 0.75fr, 2.2fr),
    align: (left, left, left, left),
    stroke: 0.5pt,
    inset: 5pt,
    table.header([*Loại ứng dụng*], [*PostgreSQL*], [*MySQL InnoDB*], [*Căn cứ*]),
    [Tài chính, đơn hàng, mọi dữ liệu không được phép mất], [`synchronous_commit = on`], [`=1`], [Không mất giao dịch nào qua 12 lần crash; đổi lại TPS thấp hơn nhiều lần (thí nghiệm A)],
    [Log, số liệu theo dõi, dữ liệu tái tạo được; chấp nhận mất ~1 giây cuối khi máy sập], [`off`], [`=0`], [RPO tối đa ~0,2 s (PostgreSQL) và ~0,63 s (InnoDB); dữ liệu vẫn nhất quán; TPS cao hơn nhiều lần],
    [Chỉ lo tiến trình DBMS sập, hệ điều hành ổn định], [không có tương đương], [`=2`], [Không mất khi kill tiến trình (0/5 lần), nhưng mất tới 552 ms khi hệ điều hành sập; không dùng nếu không chắc về hệ điều hành],
  ),
  caption: [Bảng đề xuất cấu hình theo loại ứng dụng (bảng B4).],
)

Giới hạn của nghiên cứu: (1) đo trên một máy và một ổ SSD SATA gắn ngoài qua USB 3 (`write back`); (2) không mô phỏng mất điện vật lý thật và tắt binlog MySQL để so sánh công bằng với WAL; (3) số lần lặp ít (3 lần mỗi ô ở A/B, 3–5 lần crash ở C) nên RPO/RTO mang tính định hướng.

// ============================================================
// TÀI LIỆU THAM KHẢO
// ============================================================
#heading(level: 1, numbering: none)[Tài liệu tham khảo]
// Theo Phụ lục 04 của quy định trình bày: xếp theo ngôn ngữ, thứ tự ABC (họ tác giả hoặc tên cơ quan), số thứ tự trong ngoặc vuông.
#[
  #set par(first-line-indent: 0cm, hanging-indent: 1cm, justify: false)
  *Tiếng Anh*

  [1] libvirt Project, _virsh – management user interface_ (`virsh destroy`), https://libvirt.org/manpages/virsh.html.

  [2] Oracle Corporation, _MySQL 8.4 Reference Manual_, The InnoDB Storage Engine: Doublewrite Buffer; Redo Log; InnoDB Recovery, https://dev.mysql.com/doc/refman/8.4/en/.

  [3] PostgreSQL Global Development Group, _PostgreSQL 16 Documentation_, Reliability and the Write-Ahead Log; pg_waldump; amcheck, https://www.postgresql.org/docs/16/.

  [4] A. Silberschatz, H. F. Korth, S. Sudarshan, _Database System Concepts_, 7th ed., McGraw-Hill, 2019, chapters Physical Storage Systems and Recovery System.
]
