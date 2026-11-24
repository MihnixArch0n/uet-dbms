// ============================================================
// MẪU BÁO CÁO – PHẦN CỦA TV1
// Đề tài: Durability & Crash Recovery (PostgreSQL vs MySQL InnoDB)
// Phiên bản nháp – 24/11/2026
// Lưu ý: Số liệu thí nghiệm A hiện chỉ là chạy thử (TIME=30s, 1 rep).
//        Cần thay bằng kết quả chính thức sau khi máy đo chạy xong.
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

== Demo chức năng cơ bản

Các thao tác demo được thực hiện trên máy đo (hoặc máy đã cài môi trường tương đương) và chụp màn hình lưu trong `report/img/`. Danh sách chính:

1. Kiểm tra phiên bản và tham số độ bền (`SHOW synchronous_commit`, `SHOW full_page_writes`…).
2. Quan sát tiến trình nền qua `pg_stat_activity` và `ps aux`.
3. Tạo bảng, nạp dữ liệu bằng `COPY`, chạy `EXPLAIN ANALYZE`.
4. Theo dõi LSN trước/sau COMMIT và tên file WAL đang ghi.
5. Sao lưu/khôi phục bằng `pg_dump` / `pg_restore`.
6. Chạy `pgbench` ngắn và đọc TPS, latency.

#figure(
  box(width: 100%, height: 3.2cm, stroke: 0.6pt + gray, inset: 1em)[
    #align(center + horizon)[_\[Ảnh P1_03 – Phiên bản và tham số độ bền\]_]
  ],
  caption: [Kiểm tra phiên bản PostgreSQL và các tham số liên quan đến durability.],
)

#figure(
  box(width: 100%, height: 3.2cm, stroke: 0.6pt + gray, inset: 1em)[
    #align(center + horizon)[_\[Ảnh P1_04 – Tiến trình nền\]_]
  ],
  caption: [Các tiến trình checkpointer, background writer, walwriter đang chạy.],
)

#figure(
  box(width: 100%, height: 3.2cm, stroke: 0.6pt + gray, inset: 1em)[
    #align(center + horizon)[_\[Ảnh P1_07 – LSN và file WAL\]_]
  ],
  caption: [Vị trí LSN trước và sau một giao dịch COMMIT.],
)

(Các ảnh còn lại P1_05, P1_06, P1_08–P1_12 sẽ được bổ sung sau khi chụp trên máy đo.)

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

| Hệ | Cấu hình bền vững |
|----|-------------------|
| PostgreSQL | `fsync = on`, `synchronous_commit = on`, `full_page_writes = on` |
| MySQL InnoDB | `innodb_flush_log_at_trx_commit = 1`, `innodb_doublewrite = ON` |

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

#text(fill: red, weight: "bold")[
  \[Lưu ý: Các số liệu dưới đây lấy từ lần chạy *thử* ngày 24/11 (TIME=30 s, REPS=1, chỉ clients=8). \
  Cần thay thế hoàn toàn bằng kết quả chính thức sau khi máy đo chạy xong (dự kiến sáng 25/11).\]
]

=== Số liệu chạy thử

#table(
  columns: (auto, auto, auto, auto, auto, auto),
  align: center,
  stroke: 0.5pt,
  inset: 6pt,
  [*Cấu hình*], [*Clients*], [*TPS*], [*p50 (ms)*], [*p99 (ms)*], [*fsync/txn*],
  [PG `synchronous_commit=on`], [8], [1220], [5.77], [20.7], [0.55],
  [PG `synchronous_commit=off`], [8], [11615], [0.64], [1.37], [0.0006],
)

Quan sát sơ bộ từ dữ liệu thử:

- Khi tắt chờ fsync (`off`), TPS tăng khoảng *9,5 lần* so với cấu hình bền vững.
- Độ trễ p99 giảm từ ~21 ms xuống ~1,4 ms.
- Số lần fsync trên mỗi giao dịch gần như bằng 0 khi `off` (WAL writer làm việc bất đồng bộ), trong khi cấu hình `on` cần khoảng 0,55 fsync/giao dịch (nhờ group commit, không phải 1.0).

Các con số này phù hợp với kỳ vọng lý thuyết: chi phí chính của durability nằm ở `fsync` log. Group commit giúp giảm số lần fsync thực tế xuống dưới 1 khi có nhiều client đồng thời.

=== Phân tích dự kiến (sẽ cập nhật sau khi có đủ số liệu)

Sau khi có đầy đủ kết quả (clients 1/8/32, cả PostgreSQL và MySQL), các hình sau sẽ được đưa vào:

- *Hình H3*: TPS theo cấu hình flush và số client.
- *Hình H4*: Độ trễ (p50/p95/p99).
- *Hình H5*: Số fsync log / giao dịch và số byte log / giao dịch.

Dự kiến các kết luận chính:

1. Với 1 client, TPS của cấu hình chặt bị chặn bởi tốc độ fsync của đĩa (có thể đối chiếu với `pg_test_fsync`).
2. Khi tăng số client, group commit làm giảm chi phí fsync trên mỗi giao dịch, TPS tăng nhưng không tuyến tính.
3. MySQL với `innodb_flush_log_at_trx_commit = 2` sẽ nằm giữa `1` và `0`, phản ánh việc chỉ flush định kỳ.
4. Khoảng cách hiệu năng giữa cấu hình bền vững và cấu hình “mềm” là cái giá phải trả cho durability.

#figure(
  box(width: 100%, height: 4cm, stroke: 0.6pt + gray, inset: 1em)[
    #align(center + horizon)[_\[Hình H3 – TPS theo cấu hình flush (sẽ thay bằng hình thật)\]_]
  ],
  caption: [Throughput (TPS) của PostgreSQL và MySQL dưới các mức flush log khác nhau.],
)

== Kết luận và đề xuất (nháp – TV1 tổng hợp)

Thí nghiệm A cho thấy chi phí của việc đảm bảo durability bằng flush log là rất đáng kể: trên cùng một workload TPC-B, việc chờ fsync có thể làm giảm TPS gần một bậc độ lớn. Group commit giảm bớt gánh nặng nhưng không xóa bỏ hoàn toàn.

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
    Các mục 2.3 (phương pháp đầy đủ), 2.5, 2.6 và bảng so sánh A5.4 sẽ do TV2/TV3 bổ sung.\
    Số liệu thí nghiệm A cần cập nhật sau khi chạy chính thức trên máy đo.
  ]
]
