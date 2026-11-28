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
  // Trang bìa và phần đầu (Tóm tắt, Lời cam đoan, Mục lục, Danh mục) không đánh số;
  // đánh số liên tục 1, 2, 3... bắt đầu từ Mở đầu.
  numbering: none,
)
// Nội dung: Times New Roman 13 pt (Liberation Serif là phông thay thế cùng kích thước chữ).
#set text(font: ("Times New Roman", "Liberation Serif"), size: 13pt, lang: "vi")
// Giãn dòng 1,3 lines như Word: khoảng cách hai dòng = 1,3 × 1,15 em ≈ 1,49 em,
// tức leading 0,83 em (Typst đo từ chân dòng trên tới đỉnh chữ hoa dòng dưới). Cách đoạn thêm 6 pt.
#set par(justify: true, leading: 0.83em, spacing: 0.83em + 6pt, first-line-indent: (amount: 1cm, all: true))
#show raw: set text(size: 0.85em)
// Đánh số theo quy định: "Chương 1.", rồi 1.1., 1.1.1.
#set heading(
  supplement: [Mục],
  numbering: (..n) => {
    let a = n.pos()
    if a.len() == 1 { "Chương " + str(a.first()) + "." } else { a.map(str).join(".") + "." }
  },
)
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
#show figure: set block(breakable: false)
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
#import "flexcap.typ": fcap, in-outline
#show outline: it => { in-outline.update(true); it; in-outline.update(false) }

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

// Danh mục các bảng và các hình (phần đầu, không đánh số trang)
#[
  #set text(size: 12pt)
  #set par(first-line-indent: 0cm, leading: 0.55em)
  #show outline.entry: set block(above: 0.7em, below: 0.7em)
  #pagebreak(weak: true)
  #heading(level: 2, numbering: none, outlined: false)[Danh mục các bảng]
  #outline(title: none, target: figure.where(kind: table))
  #v(0.4cm)
  #heading(level: 2, numbering: none, outlined: false)[Danh mục các hình]
  #outline(title: none, target: figure.where(kind: image))
]

#set page(numbering: "1")
#counter(page).update(1)
#include "mo_dau.typ"

// ============================================================
// PHẦN 1 – POSTGRESQL
// ============================================================
= PostgreSQL

== Tổng quan

PostgreSQL bắt nguồn từ dự án POSTGRES tại Đại học California, Berkeley (1986) do Michael Stonebraker dẫn dắt, đổi tên và mở mã nguồn năm 1996. Đây là hệ quản trị cơ sở dữ liệu quan hệ – đối tượng: người dùng có thể định nghĩa kiểu dữ liệu, toán tử, hàm và chỉ mục mới. So với MySQL InnoDB (thiên về hiệu năng web, dễ triển khai), PostgreSQL hướng tới tính đúng đắn, khả năng mở rộng và tuân thủ chuẩn SQL, cung cấp phần lớn tính năng của các hệ thương mại như Oracle, SQL Server dưới giấy phép mở tương tự BSD [3].

== Kiến trúc

PostgreSQL dùng mô hình *process-per-connection*: tiến trình chính (`postmaster`) lắng nghe kết nối và fork một `backend process` riêng cho mỗi client (cô lập lỗi tốt, tốn bộ nhớ hơn thread của MySQL). Các tiến trình nền chính gồm: *checkpointer* (ghi trang bẩn định kỳ và tạo checkpoint), *background writer* (ghi dần trang bẩn), *WAL writer* (đẩy WAL theo chu kỳ `wal_writer_delay`), và *autovacuum* (dọn phiên bản cũ MVCC) [3].

Bộ nhớ chia thành *Shared memory* (shared buffers, WAL buffers, lock table) và *Backend-private memory* (`work_mem`, `maintenance_work_mem`). Lưu trữ vật lý dưới `$PGDATA` gồm `base/` (dữ liệu bảng/chỉ mục dạng trang 8 KB, dữ liệu lớn tách sang TOAST), `pg_wal/` (các file WAL 16 MB) và `global/` (catalog toàn cục, `pg_control`).

#shot("img/H2_kien_truc_pg.png", [Sơ đồ kiến trúc tiến trình và bộ nhớ PostgreSQL: postmaster, backend, bộ nhớ chung, tiến trình nền và các thư mục dữ liệu.], w: 72%)

== Tính năng chính

PostgreSQL hỗ trợ nhiều kiểu dữ liệu nâng cao (JSONB, mảng, range, hstore, geometric) và chỉ mục phong phú (B-tree, GIN, GiST, BRIN). Cơ chế MVCC giúp đọc không bị chặn bởi ghi, hỗ trợ cô lập từ Read Committed đến Serializable (SSI), cùng khả năng mở rộng bằng PL/pgSQL, trigger, view và extension (PostGIS, `pg_stat_statements`…).

== Cài đặt, cấu hình và vận hành

Hai container `bench-pg` (`postgres:16`, cổng 5432) và `bench-mysql` (`mysql:8.4`, cổng 3306) chạy qua Docker Compose với cấu hình nền tương đương: `shared_buffers = 2GB`, `max_wal_size = 4GB`, `checkpoint_timeout = 5min`, `full_page_writes = on`, `fsync = on`, `synchronous_commit = on`.

#figure(
  grid(
    columns: 1,
    align: center,
    gutter: 8pt,
    image("img/P1_01_docker_ps.png", width: 60%),
    image("img/P1_02_cau_hinh_nap.png", width: 66%),
  ),
  caption: [Hai container PostgreSQL 16 và MySQL 8.4 (trên) và đối chiếu cấu hình nạp trước thí nghiệm (dưới).],
)

== Demo chức năng cơ bản

Các thao tác cơ bản được demo trên PostgreSQL 16.16 (dữ liệu `pgbench` scale 50); lệnh nằm trong `demo/part1_demo.sql`, ảnh chụp trong `report/img/`.

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

Máy chủ chạy đúng các tham số thiết kế (`synchronous_commit = on`, `full_page_writes = on`, `shared_buffers = 2GB`, `data_checksums = on`); `pg_stat_activity` xác nhận các tiến trình nền `checkpointer`, `background writer`, `walwriter`.

#figure(
  grid(
    columns: 1,
    align: center,
    gutter: 8pt,
    image("img/P1_03_phien_ban_tham_so.png", width: 64%),
    image("img/P1_04_tien_trinh.png", width: 80%),
  ),
  caption: [Phiên bản, tham số durability (trên) và các tiến trình nền qua `pg_stat_activity` (dưới).],
)

=== LSN, file WAL và thống kê checkpoint

Một giao dịch `UPDATE` rồi `COMMIT` đẩy vị trí WAL từ `F/2D950208` lên `F/2D950310` (+264 byte), trong file `000000010000000F0000002D` (16 MB). `pg_stat_wal` cho thấy `wal_write` (116.912) gần bằng `wal_sync` (116.909), tức gần như mỗi lần ghi WAL đều kèm một lần flush; `pg_stat_bgwriter` ghi 23 checkpoint định kỳ và 92 checkpoint theo yêu cầu (do script chạy `CHECKPOINT` trước mỗi lần đo).

#figure(
  grid(
    columns: 1,
    align: center,
    gutter: 8pt,
    image("img/P1_07_wal_lsn.png", width: 78%),
    image("img/P1_08_thong_ke_wal.png", width: 78%),
  ),
  caption: [LSN trước/sau COMMIT (trên) và thống kê `pg_stat_wal` / `pg_stat_bgwriter` (dưới).],
)

// ============================================================
// PHẦN 2 – TÌM HIỂU VÀ THỰC NGHIỆM
// ============================================================
= Tìm hiểu và thực nghiệm về Durability \& Crash Recovery

== Đặt vấn đề <sec-dat-van-de>

Thuộc tính *Durability* (ACID) đòi hỏi dữ liệu của giao dịch đã xác nhận COMMIT không được mất dù hệ thống sập ngay sau đó. Dữ liệu đi qua 4 tầng: (1) bộ đệm DBMS (`shared_buffers` / buffer pool) → (2) page cache HĐH (`write()`) → (3) cache bộ điều khiển đĩa → (4) bề mặt đĩa (`fsync()`). Theo đó, *crash tiến trình DBMS* (`kill -9`) chỉ mất tầng (1); *crash HĐH* (tắt nguồn ảo) mất thêm tầng (2); *mất điện thật* có thể mất cả tầng (3) nếu ổ không tôn trọng flush.

Ghi thẳng trang dữ liệu khi COMMIT rất chậm vì I/O ngẫu nhiên. *Write-Ahead Logging* (WAL) [4] khắc phục bằng cách ghi tuần tự vào log trước khi báo COMMIT, còn trang dữ liệu ghi sau (lazy). Tuy nhiên, trang DBMS (8 KB PostgreSQL, 16 KB InnoDB) lớn hơn đơn vị ghi nguyên tử của HĐH/ổ đĩa (4 KB); nếu sập giữa lúc ghi, trang bị *rách* (torn page) và log thay đổi không đủ sửa. Hai vấn đề độc lập này — *flush log khi COMMIT* và *bảo vệ trang* — được tách thành hai thí nghiệm A và B.

#figure(
  diagram-data-path(),
  kind: image,
  caption: [Đường đi của dữ liệu từ DBMS đến đĩa và phạm vi mất dữ liệu của từng loại sự cố.],
) <fig-path>

Ba câu hỏi nghiên cứu: (1) Chi phí hiệu năng (TPS, độ trễ) của việc chờ `fsync` log khi COMMIT? *(Thí nghiệm A)*; (2) Chi phí của cơ chế bảo vệ trang? *(Thí nghiệm B)*; (3) Khi crash thật xảy ra, giao dịch đã COMMIT có mất không, dữ liệu có nhất quán không và RTO bao lâu? *(Thí nghiệm C)*.

== Cơ chế của hai hệ <sec-co-che>

=== PostgreSQL – WAL và synchronous_commit

Mọi thay đổi sinh bản ghi trong *WAL buffers*. Khi COMMIT, backend ghi WAL ra đĩa và gọi `fsync`/`fdatasync` tùy cấu hình [3]:
- `synchronous_commit = on` (mặc định, bền vững): chờ WAL flush xuống đĩa rồi mới trả lời client.
- `synchronous_commit = off`: trả lời ngay khi bản ghi vào WAL buffers; `walwriter` flush định kỳ theo `wal_writer_delay` (200 ms, cửa sổ mất tối đa \~3 lần chu kỳ nhưng không rách trang). Khác hoàn toàn `fsync = off` (có thể hỏng DB).

*Group commit*: khi nhiều backend cùng chờ `WALWriteLock`, PostgreSQL gom lại thực hiện một lần `fsync` cho cả nhóm (giúp TPS tăng mạnh theo số client). File WAL (16 MB) nằm ở `pg_wal/` và được tái sử dụng theo checkpoint.

=== MySQL InnoDB – Redo log và innodb_flush_log_at_trx_commit

InnoDB ghi thay đổi vào *redo log* (vòng tròn, cố định) [2]: `1` (flush mỗi COMMIT — bền vững nhất), `2` (`write()` vào page cache mỗi COMMIT, `fsync()` mỗi \~1 giây — an toàn với crash tiến trình nhưng mất \~1 s khi sập HĐH), và `0` (ghi + flush mỗi \~1 giây — có thể mất ngay cả khi kill tiến trình). Binlog được tắt (`skip-log-bin`) để chỉ so sánh redo log với WAL.

=== Cấu hình bền vững dùng trong thí nghiệm

Cấu hình bền vững (`fsync = on`, `synchronous_commit = on`, `full_page_writes = on` cho PostgreSQL; `innodb_flush_log_at_trx_commit = 1`, `innodb_doublewrite = ON` cho InnoDB — chi tiết ở @tab-cfg) được giữ làm nền. Thí nghiệm A *chỉ* thay đổi tham số flush log và giữ nguyên bảo vệ trang để đo riêng chi phí chờ `fsync` khi COMMIT; tương tự, Thí nghiệm B (@sec-expB) *chỉ* thay đổi cơ chế bảo vệ trang và giữ nguyên flush log chặt để tách riêng hai chi phí này.

#include "tv2_2_2_bao_ve_trang.typ"

#include "tv3_2_2_checkpoint_phuc_hoi.typ"

#include "tv3_2_3_phuong_phap.typ"

== Kết quả thí nghiệm A <sec-expA>

Thí nghiệm A chỉ thay đổi tham số flush log (PostgreSQL `on`/`off`; InnoDB `1`/`2`/`0`), giữ nguyên bảo vệ trang: 45 lần chạy (1, 8, 32 client; 3 lần mỗi ô; đo 300 giây sau 60 giây làm nóng), tổng 61.489.705 giao dịch.

=== Quy trình đo và tính đúng của dữ liệu

Mỗi lần chạy: khởi động lại DBMS; `CHECKPOINT` và reset thống kê WAL (PostgreSQL); làm nóng; chụp thống kê; chạy `sysbench` 300 giây kèm `iostat`; chụp thống kê; kiểm tra bất biến. Cả 45 lần đều giữ đúng $A = T = B = H$ và 0 giao dịch lỗi, kể cả ở `off` và `=0`.

=== Bảng kết quả

#[
  #set text(size: 11pt)
  #figure(
    table(
      columns: (auto, auto, auto, auto, auto, auto, auto, auto),
      align: center,
      stroke: 0.5pt,
      inset: 3.5pt,
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
    caption: fcap([Kết quả thí nghiệm A: giá trị trung bình của 3 lần chạy (`results/A_summary.csv`).], [Kết quả thí nghiệm A: giá trị trung bình của 3 lần chạy (`results/A_summary.csv`). CV là hệ số biến thiên của TPS giữa 3 lần.]),
  )
]

#[
  #set text(size: 11pt)
  #figure(
    table(
      columns: (auto, auto, auto, auto, auto, auto),
      align: center,
      stroke: 0.5pt,
      inset: 3.5pt,
      table.header([*Cấu hình*], [*Clients*], [*fsync mỗi giây*], [*Giao dịch mỗi fsync*], [*Nhóm lấp đầy so với số client*], [*So với trần fsync của ổ đĩa*]),
      [PG `on`], [1], [389], [1,0], [100%], [92%],
      [PG `on`], [8], [310], [3,7], [46%], [73%],
      [PG `on`], [32], [308], [11,2], [35%], [73%],
      [MySQL `=1`], [1], [298], [0,7], [72%], [142%],
      [MySQL `=1`], [8], [185], [4,0], [50%], [88%],
      [MySQL `=1`], [32], [112], [15,7], [49%], [53%],
    ),
    caption: fcap([Hiệu quả group commit ở cấu hình bền vững.], [Hiệu quả group commit ở cấu hình bền vững. "fsync mỗi giây" = TPS × fsync mỗi giao dịch; trần fsync của ổ: 424 lần/giây với `fdatasync` (PostgreSQL), 210 lần/giây với `fsync` (MySQL).]),
  )
]

=== Đối chiếu với kết quả dự kiến

#[
  #set text(size: 11pt)
  #figure(
    table(
      columns: (3.8cm, 1fr, 2.6cm),
      align: (left, left, center),
      stroke: 0.5pt,
      inset: 3.5pt,
      table.header([*Dự kiến theo lý thuyết*], [*Kết quả đo*], [*Đánh giá*]),
      [1 client, cấu hình bền vững: TPS ≈ tốc độ fsync của ổ], [PG `on`: 389 TPS (hai lần đạt 417, 98% trần 424); MySQL `=1`: 214 so với trần 210], [Khớp],
      [Tăng client thì fsync mỗi giao dịch giảm (group commit)], [PG `on`: 1,000 → 0,270 → 0,090; MySQL `=1`: 1,391 → 0,251 → 0,064], [Khớp],
      [Cấu hình mềm nhanh hơn nhiều lần, khoảng cách thu hẹp khi tăng client], [PG `off` gấp 13,4× / 18,2× / 3,7×; MySQL `=0` gấp 11,7× / 6,2× / 2,8× (1 / 8 / 32 client)], [Khớp một phần (PG ở 8 client lớn hơn 1 client)],
      [InnoDB: `=0` ≥ `=2` ≥ `=1`, `=2` gần `=0` ở tải thấp], [1 client: 2.511 / 2.420 / 214 TPS; thứ tự đúng ở cả ba mức], [Khớp],
      [TPS tăng theo số client], [PG `off` giảm từ 20.930 (8 client) xuống 12.773 (32 client)], [Không khớp (ý 4)],
      [MySQL `=1`: khoảng 1 fsync mỗi giao dịch], [1,391 ở 1 client], [Không khớp (ý 1)],
    ),
    caption: [Đối chiếu dự đoán lý thuyết với kết quả thí nghiệm A.],
  )
]

=== Phân tích

*1. Với 1 client, TPS bị chặn bởi tốc độ fsync của ổ.* PostgreSQL `on` dùng đúng 1 fsync mỗi giao dịch, p50 2,35 ms khớp 1/424 s. MySQL `=1` đạt \~198–246 TPS, sát trần 210 của `fsync`. Số 1,391 fsync/giao dịch của InnoDB là do `Innodb_os_log_fsyncs` đếm mọi lần `fsync()` file redo, gồm cả mini-transaction trước COMMIT và tác vụ nền.

*2. Group commit tăng TPS nhưng không tăng số fsync mỗi giây.* PostgreSQL `on` giữ \~310 fsync/giây (73% trần) ở 8 và 32 client, TPS vẫn tăng 1.149 → 3.441 nhờ mỗi fsync phục vụ 3,7 rồi 11,2 giao dịch. MySQL `=1` gom tới 15,7 giao dịch/fsync nhưng fsync/giây giảm còn 112 do tranh chấp khóa (ý 4).

#figure(
  grid(
    columns: 1,
    align: center,
    gutter: 6pt,
    image("img/H5_fsync_per_txn.png", width: 58%),
    image("img/H3_tps_vs_clients.png", width: 78%),
  ),
  caption: [Số lần fsync mỗi giao dịch (trên) và thông lượng TPS theo cấu hình và số client (dưới).],
  placement: top,
)

*3. Độ trễ và vị trí của `=2`.* p50 của PG `on` (2,35 / 4,82 / 4,94 ms) chậm hơn `off` 4,2–13,8 lần; ở 8 và 32 client p50 ≈ hai lần fsync, tức giao dịch phải chờ đợt fsync đang chạy xong. MySQL `=1` có đuôi dài (p99 tới 178,4 ms). `=2` gần `=0` ở 1 client nhưng thấp hơn ở 8 và 32 client vì mỗi COMMIT vẫn gọi `write()`.

#shot("img/H4_latency.png", [Độ trễ p50, p95, p99 theo cấu hình flush log.], w: 66%)

*4. Ở 32 client, nút thắt là tranh chấp khóa.* PG `off` giảm từ 20.930 xuống 12.773 TPS, p99 vọt từ 0,5 lên 52,9 ms do 32 client tranh nhau 50 dòng của `pgbench_branches`; MySQL có p99 \~178–197 ms ở cả ba cấu hình.

*5. So sánh hai hệ.* Ở cấu hình bền vững PostgreSQL nhanh hơn MySQL 1,6–2,0 lần, khớp tỉ lệ trần `fdatasync`/`fsync` (424/210). Ở cấu hình mềm PostgreSQL vẫn nhanh hơn 2,1–4,6 lần, nên chỉ nên so tỉ lệ mềm/bền vững trong từng hệ.

*6. Đánh đổi hiệu năng và dữ liệu mất.* Ghép với kết quả thí nghiệm C:

#figure(
  table(
    columns: (auto, auto, auto, auto),
    align: center,
    stroke: 0.5pt,
    inset: 3.5pt,
    table.header([*Cấu hình mềm*], [*TPS so với bền vững (8 client)*], [*Mất khi kill tiến trình*], [*Mất khi HĐH sập (lớn nhất)*]),
    [PG `off`], [18,2×], [69 GD, 20 ms], [897 GD, 197 ms],
    [MySQL `=0`], [6,2×], [108 GD, 19 ms], [3.517 GD, 630 ms],
    [MySQL `=2`], [4,9×], [0], [2.674 GD, 552 ms],
  ),
  caption: fcap([Đánh đổi TPS và dữ liệu mất.], [Đánh đổi TPS và dữ liệu mất. Cấu hình bền vững không mất giao dịch nào ở cả hai mức sự cố (thí nghiệm C).]),
)

PG `off` là lựa chọn rẻ nhất nếu chấp nhận mất vài trăm mili giây dữ liệu cuối; `=2` an toàn khi chỉ tiến trình sập nhưng vẫn mất \~0,5 s khi HĐH sập.

=== Độ tin cậy số liệu

Năm ô có CV trên 10%, phần lớn ở 1 client do một lần chạy lệch (PG `on`: 417, 416, 334; MySQL `=1`: 246, 195, 201); MySQL `=1` ở 32 client (CV 23,5%: 1.710, 1.373, 2.195) chịu ảnh hưởng của tranh chấp khóa.

== Kết quả thí nghiệm B <sec-expB>

Thí nghiệm B chỉ thay đổi bảo vệ trang (PostgreSQL `full_page_writes`, InnoDB `innodb_doublewrite`), giữ flush log ở mức bền vững: 12 lần chạy (2 cấu hình mỗi hệ, 3 lần lặp, 8 client, đo 300 giây sau 60 giây làm nóng). Cấu hình tắt chỉ dùng để đo chi phí; trên hệ thật, tắt bảo vệ trang có thể làm hỏng dữ liệu khi HĐH sập hoặc mất điện.

=== Quy trình đo và kiểm chứng bất biến

Mỗi lần chạy bắt đầu từ dữ liệu ban đầu trong container vừa khởi động lại; PostgreSQL chạy thêm `CHECKPOINT` rồi dùng `pg_waldump --stats=record` phân loại WAL giữa hai mốc LSN; InnoDB ghi số trang flush và doublewrite; cả hai dùng `iostat` đo lượng ghi đĩa. Cả 12 lần đều giữ đúng bất biến và 0 lỗi; hàm kiểm tra bất biến cũng được kiểm chứng hai chiều trên MySQL (`OK` sau 70.756 giao dịch, `FAIL` khi cố ý lệch 1 đơn vị).

=== Bảng kết quả

#[
  #set text(size: 10pt)
  #show table: set par(justify: false)
  #figure(
    table(
      columns: (auto, auto, auto, auto, auto, auto, auto, auto),
      align: (left, center, center, center, center, center, center, center),
      stroke: 0.5pt,
      inset: 3.5pt,
      table.header([*Cấu hình*], [*TPS (CV)*], [*p50 (ms)*], [*p95 (ms)*], [*p99 (ms)*], [*Log mỗi giao dịch (B)*], [*Bảo vệ mỗi giao dịch (B)*], [*Ghi đĩa mỗi giao dịch (B)*]),
      [PG `fpw = on`], [1.294 (17,0%)], [4,82], [9,74], [33,8], [2.280,5], [1.871,4 (FPI)], [5.882,6],
      [PG `fpw = off`], [1.170 (4,0%)], [4,82], [10,44], [46,4], [401,7], [0], [3.998,4],
      [MySQL `dblwr = ON`], [703 (20,2%)], [6,91], [23,83], [72,3], [1.068,6], [10.945,0 (doublewrite)], [24.749,0],
      [MySQL `dblwr = OFF`], [884 (17,1%)], [6,91], [14,50], [63,1], [1.071,4], [0], [13.723,6],
    ),
    caption: fcap([Kết quả thí nghiệm B ở 8 client, trung bình 3 lần chạy (`results/B_summary.csv`).], [Kết quả thí nghiệm B ở 8 client, trung bình 3 lần chạy (`results/B_summary.csv`). "Log": WAL hoặc redo log; "Bảo vệ": FPI trong WAL hoặc lượng ghi qua doublewrite; "Ghi đĩa": tổng ghi đo bằng `iostat` chia cho số giao dịch.]),
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
      inset: 3.5pt,
      table.header([*Dự kiến (@sec-bao-ve-trang)*], [*Kết quả đo*], [*Đánh giá*]),
      [PG: bật FPW làm WAL tăng mạnh, chủ yếu là ảnh trang], [WAL mỗi giao dịch 402 → 2.281 B (5,7×), FPI chiếm 82%; mỗi lần chạy 874 MB so với 141 MB], [Khớp],
      [FPI tập trung ngay sau checkpoint], [8–14 MB/s trong 30 giây đầu rồi về \~0,6 MB/s, tăng lại sau checkpoint định kỳ (r2, r3 đỉnh thấp hơn)], [Khớp một phần],
      [InnoDB: mỗi trang flush ghi hai lần, redo không đổi], [Doublewrite 10.945 B ≈ ghi trang 10.948 B; redo 1.069 và 1.071 B], [Khớp],
      [Chi phí InnoDB nhỏ khi dữ liệu nằm gọn trong bộ đệm], [\~0,67 trang flush mỗi giao dịch, chi phí đáng kể], [Không khớp],
      [TPS giảm khi bật bảo vệ trang], [PG: 1.294 so với 1.170, chồng lấn; InnoDB: tắt tăng 25,8% (884 so với 703) nhưng chồng lấn], [Chưa kết luận được],
    ),
    caption: [Đối chiếu dự đoán lý thuyết với kết quả thí nghiệm B.],
  )
]

=== Phân tích

*1. PostgreSQL trả chi phí bằng WAL.* Phần bản ghi thường giữ \~402 B/giao dịch, phần tăng 1.871 B là FPI; ghi đĩa `iostat` tăng đúng tương ứng (+1.884 B). FPI đến chủ yếu từ `Heap/HOT_UPDATE` (\~47%), `Heap2/PRUNE` (\~33%) và `XLOG/FPI_FOR_HINT` (\~8%, do bật checksum), vì cập nhật ngẫu nhiên 5 triệu tài khoản khiến hầu hết giao dịch chạm trang chưa sửa sau checkpoint.

#figure(
  grid(
    columns: 1,
    align: center,
    gutter: 6pt,
    image("img/H6_page_protection_cost.png", width: 76%),
    image("img/H8_wal_composition.png", width: 58%),
  ),
  caption: [Lượng ghi mỗi giao dịch (trên) và thành phần WAL theo `pg_waldump` (dưới).],
  placement: top,
)

*2. Chi phí tập trung sau checkpoint.* @fig-h7 cho thấy FPI chỉ ghi ở lần sửa đầu của trang sau mỗi checkpoint: checkpoint càng dày thì WAL càng phình nhưng RTO càng ngắn.

#shot("img/H7_wal_rate.png", [Tốc độ sinh WAL theo thời gian (lần chạy r1 của mỗi cấu hình): đỉnh sau mỗi checkpoint khi `full_page_writes = on`.], w: 66%) <fig-h7>

*3. InnoDB trả chi phí bằng ghi trang.* Redo không đổi, nhưng mỗi giao dịch ghi thêm 10.945 B qua doublewrite (0,668 trang 16 KB), khiến tổng ghi đĩa tăng 1,8 lần (13.724 → 24.749 B). Tính trên mỗi giao dịch, InnoDB ghi đĩa nhiều hơn PostgreSQL 4,2 lần (24,7 KB so với 5,9 KB).

*4. TPS chưa phân biệt được.* PostgreSQL có p50 trùng 4,82 ms và fsync mỗi giao dịch giữ 0,27 ở cả hai cấu hình: ở 8 client nút thắt vẫn là chờ fsync khi COMMIT. InnoDB tắt doublewrite tăng TPS 25,8% và giảm p99 (63,1 so với 72,3 ms), nhưng khoảng giá trị ba lần chạy chồng lấn.

=== Độ tin cậy số liệu

TPS có CV 17–20% ở ba trong bốn cấu hình do ổ SSD gắn ngoài qua USB 3 dao động khi vừa ghi trang vừa `fsync`, nên nhóm không kết luận về TPS; các chỉ số đếm byte (WAL, doublewrite, `iostat`) ổn định giữa các lần chạy. Thí nghiệm không tạo rách trang thật nên chỉ đo chi phí, không đo lợi ích.

#include "tv3_2_6_ket_qua_C.typ"

// ============================================================
// KẾT LUẬN
// ============================================================
#heading(level: 1, numbering: none)[Kết luận]

Báo cáo đã trả lời ba câu hỏi nghiên cứu đặt ra ở @sec-dat-van-de bằng số liệu đo trên cùng một máy cho cả hai hệ. Tổng hợp kết quả ba thí nghiệm:

- *Thí nghiệm A (flush log):* Chờ `fsync` làm TPS cấu hình bền vững thấp hơn cấu hình mềm 3,7–18,2× (PostgreSQL `off`) và 2,8–11,7× (MySQL `=0`); group commit giảm xuống < 0,1 fsync/GD ở 32 client nhưng không triệt tiêu chi phí.
- *Thí nghiệm B (bảo vệ trang):* PostgreSQL trả chi phí vào WAL (tăng 5,7×, 82% là FPI sau checkpoint), InnoDB trả vào ghi đĩa qua doublewrite (tăng 1,8×, redo không đổi). Không tắt trên hệ thật; PG có thể tăng `checkpoint_timeout`/`max_wal_size`, InnoDB đặt `innodb_doublewrite_dir` trên ổ nhanh.
- *Thí nghiệm C (crash & phục hồi):* Cấu hình bền vững (`on`, `=1`) không mất giao dịch (0/12 lần); InnoDB `=2` an toàn khi kill tiến trình nhưng mất tới 2.674 GD (\~552 ms) khi sập HĐH. Mọi cấu hình giữ bất biến 42/42 lần và không hỏng trang; RPO luôn dưới chu kỳ flush (≤ 197 ms PG `off`, ≤ 630 ms InnoDB `=2`/`=0`), RTO 7–19 s chủ yếu do khởi động sau redo.

Các kết quả đo khớp với phần lớn dự đoán rút ra từ lý thuyết; những điểm chưa khớp hoặc chưa đủ để kết luận đã được chỉ ra trong từng thí nghiệm. Từ đó, nhóm đề xuất cấu hình cho từng loại ứng dụng như bảng dưới.

#figure(
  numbering: none,
  outlined: false,
  table(
    columns: (1.4fr, 1.15fr, 0.75fr, 2.2fr),
    align: (left, left, left, left),
    stroke: 0.5pt,
    inset: 5pt,
    table.header([*Loại ứng dụng*], [*PostgreSQL*], [*MySQL InnoDB*], [*Căn cứ*]),
    [Tài chính, đơn hàng, mọi dữ liệu không được phép mất], [`synchronous_commit = on`], [`=1`], [Không mất giao dịch nào qua 12 lần crash; đổi lại TPS thấp hơn nhiều lần (thí nghiệm A)],
    [Log, số liệu theo dõi, dữ liệu tái tạo được; chấp nhận mất \~1 giây cuối khi máy sập], [`off`], [`=0`], [RPO tối đa \~0,2 s (PostgreSQL) và \~0,63 s (InnoDB); dữ liệu vẫn nhất quán; TPS cao hơn nhiều lần],
    [Chỉ lo tiến trình DBMS sập, hệ điều hành ổn định], [không có tương đương], [`=2`], [Không mất khi kill tiến trình (0/5 lần), nhưng mất tới 552 ms khi hệ điều hành sập; không dùng nếu không chắc về hệ điều hành],
  ),
  caption: [Bảng đề xuất cấu hình theo loại ứng dụng.],
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
