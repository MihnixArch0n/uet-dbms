// ============================================================
// MỤC 2.2 (phần của TV2): BẢO VỆ TRANG DỮ LIỆU
// Chèn vào mục "== Cơ chế của hai hệ", ngay sau phần flush log (TV1)
// và trước phần checkpoint/phục hồi (tv3_2_2_checkpoint_phuc_hoi.typ):
//   #include "tv2_2_2_bao_ve_trang.typ"
// ============================================================

#show table: set text(size: 11pt)
#show table: set par(justify: false)

=== Bảo vệ trang dữ liệu (Full-Page Writes và Doublewrite Buffer) <sec-bao-ve-trang>

WAL đảm bảo thay đổi đã được đẩy ra log trước COMMIT, nhưng không chống được *rách trang* (torn page): trang dữ liệu (8 KB PostgreSQL, 16 KB InnoDB) lớn hơn đơn vị ghi nguyên tử của HĐH/ổ đĩa (512 B – 4 KB), nên nếu sập giữa lúc ghi, trang sẽ nửa cũ nửa mới và log thay đổi mức dòng không đủ sửa. Hai hệ giải quyết theo hai hướng khác nhau:

==== PostgreSQL – Full-Page Writes (`full_page_writes`)

Khi `full_page_writes = on` (mặc định), ở *lần sửa đầu tiên* của mỗi trang sau mỗi checkpoint, PostgreSQL ghi toàn bộ nội dung trang (Full-Page Image – FPI, tối đa 8 KB) vào WAL [3]. Khi phục hồi từ redo point của checkpoint gần nhất, FPI ghi đè trang có thể bị rách trước khi áp dụng các bản ghi redo tiếp theo.
- *Chu kỳ checkpoint:* Sau mỗi checkpoint, hàng loạt trang sửa lần đầu tạo đỉnh WAL (tăng mạnh khi `checkpoint_timeout` = `5min` / `max_wal_size` = `4GB` ngắn).
- *Ảnh hưởng của `--data-checksums` / `wal_log_hints`:* Khi bật checksum (như cấu hình nhóm), cả việc đánh dấu *hint bits* lần đầu sau checkpoint cũng phải ghi FPI (`XLOG/FPI_FOR_HINT`).
- *Khi tắt (`off`):* Giảm mạnh WAL nhưng có nguy cơ hỏng dữ liệu khi sập HĐH/mất điện; chỉ tắt nếu lớp lưu trữ ghi nguyên tử 8 KB (như ZFS).

==== MySQL InnoDB – Doublewrite Buffer (`innodb_doublewrite`)

InnoDB ghi các trang bẩn vào vùng đệm trung gian *doublewrite buffer* (`#ib_*` trong `innodb_doublewrite_dir`) thành từng lô tuần tự lớn với một lần `fsync()` [2] *trước khi* ghi vào tablespace đích, nhờ đó tránh nhân đôi I/O ngẫu nhiên và có bản sao nguyên vẹn để cứu trang rách khi phục hồi. Các chế độ MySQL 8.4: `ON`/`DETECT_AND_RECOVER` (mặc định, ghi và sửa trang), `DETECT_ONLY` (chỉ ghi metadata phát hiện), và `OFF` (tắt hoàn toàn, đổi sang/từ `OFF` cần restart).

==== So sánh hai cơ chế bảo vệ trang

#figure(
  table(
    columns: (auto, 1fr, 1fr),
    align: (left, left, left),
    stroke: 0.5pt,
    inset: 4pt,
    table.header([*Tiêu chí*], [*PostgreSQL (`full_page_writes`)*], [*MySQL InnoDB (`innodb_doublewrite`)*]),
    [Kích thước trang], [8 KB], [16 KB],
    [Nơi lưu bản sao trang], [Ghi trực tiếp vào luồng WAL (FPI)], [Ghi vào file doublewrite riêng (`#ib_*`)],
    [Thời điểm bảo vệ], [Chỉ lần sửa đầu tiên của trang sau mỗi checkpoint], [Mỗi lần đẩy trang bẩn từ buffer pool xuống đĩa],
    [Ảnh hưởng của checkpoint], [Mạnh: tạo đỉnh WAL ngay sau mỗi checkpoint], [Gián tiếp qua tốc độ đẩy trang bẩn (fuzzy checkpoint)],
    [Tính chất I/O phụ thêm], [Tăng dung lượng WAL tuần tự (và chi phí lưu trữ/archiving)], [Nhân đôi lượng ghi trang (một lượt tuần tự vào dblwr + một lượt vào tablespace)],
    [Rủi ro khi tắt], [Rách trang không sửa được khi crash OS / mất điện], [Rách trang không sửa được khi crash OS / mất điện],
  ),
  caption: [So sánh cơ chế chống rách trang giữa PostgreSQL 16 và MySQL 8.4 InnoDB.],
)
