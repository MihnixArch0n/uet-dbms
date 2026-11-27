// ============================================================
// MỤC 2.2 (phần của TV2): BẢO VỆ TRANG DỮ LIỆU
// Chèn vào mục "== Cơ chế của hai hệ", ngay sau phần flush log (TV1)
// và trước phần checkpoint/phục hồi (tv3_2_2_checkpoint_phuc_hoi.typ):
//   #include "tv2_2_2_bao_ve_trang.typ"
// ============================================================

#show table: set text(size: 11pt)
#show table: set par(justify: false)

=== Bảo vệ trang dữ liệu (Full-Page Writes và Doublewrite Buffer)

Cơ chế WAL chỉ đảm bảo dữ liệu thay đổi ở mức logic/vật lý (physical-logical redo) đã được đẩy ra nhật ký trước khi COMMIT, nhưng không tự bảo vệ được *trang dữ liệu* khi trang đó đang được ghi dở xuống thiết bị lưu trữ. Kích thước một trang của hệ quản trị CSDL (8 KB ở PostgreSQL và 16 KB ở MySQL InnoDB) lớn hơn đơn vị ghi nguyên tử phổ biến của hệ điều hành và ổ đĩa (thường là 512 byte hoặc 4 KB). Nếu hệ điều hành sập hoặc mất điện đúng lúc trang đang được ghi, trên đĩa sẽ xuất hiện trạng thái *rách trang* (torn page / partial page write): một phần trang mang nội dung mới, phần còn lại vẫn giữ nội dung cũ. Khi khởi động lại, các bản ghi thay đổi mức dòng không đủ thông tin để tái tạo trang nền bị hỏng này.

Để xử lý triệt để nguy cơ rách trang, PostgreSQL và MySQL InnoDB chọn hai hướng thiết kế khác nhau: PostgreSQL nhúng ảnh trang vào chính luồng WAL (*Full-Page Writes*), còn InnoDB dùng một vùng đệm ghi kép tách biệt (*Doublewrite Buffer*).

==== PostgreSQL - Full-Page Writes (`full_page_writes`)

Theo tài liệu chính thức của PostgreSQL 16, khi tham số `full_page_writes` ở trạng thái `on` (mặc định), ở *lần sửa đổi đầu tiên* của mỗi trang dữ liệu sau một lần checkpoint, server ghi *toàn bộ nội dung trang* (Full-Page Image - FPI, tối đa 8 KB trước khi nén) vào WAL. Trong pha phục hồi sau sự cố, PostgreSQL bắt đầu phát lại WAL từ redo point của checkpoint gần nhất; mọi trang bị sửa sau checkpoint đó đều có một bản FPI nguyên vẹn nằm trong WAL, giúp ghi đè hoàn toàn các trang có thể bị rách trước khi áp dụng các bản ghi thay đổi tiếp theo.

Các đặc điểm vận hành quan trọng của cơ chế này:

- *Liên hệ trực tiếp với chu kỳ checkpoint:* Vì trạng thái "đã có FPI hay chưa" được đặt lại sau mỗi checkpoint, ngay sau khi checkpoint hoàn tất sẽ xuất hiện một đợt tăng vọt dung lượng WAL do hàng loạt trang nóng bị sửa lần đầu đều phải ghi kèm FPI. Khoảng cách giữa các checkpoint (`checkpoint_timeout`, nhóm dùng `5min`; `max_wal_size`, nhóm dùng `4GB`) càng ngắn thì chi phí FPI càng lớn.
- *Tác động của `--data-checksums` và `wal_log_hints`:* Khi CSDL bật kiểm tra tổng kiểm (checksums) lúc khởi tạo - như cấu hình của nhóm - hoặc bật `wal_log_hints = on`, ngay cả những cập nhật không trọng yếu như đánh dấu *hint bits* (trạng thái khả kiến giao dịch trên header của tuple) ở lần đầu sau checkpoint cũng bắt buộc ghi FPI vào WAL qua bản ghi `XLOG/FPI_FOR_HINT`. Điều này đảm bảo checksum của trang luôn khớp khi phục hồi.
- *Đánh đổi khi tắt:* Đặt `full_page_writes = off` giúp giảm mạnh lượng WAL sinh ra và áp lực I/O tuần tự, nhưng làm tăng rủi ro hỏng dữ liệu âm thầm hoặc không thể phục hồi sau sự cố hệ điều hành/mất điện. Tài liệu PostgreSQL khuyến cáo chỉ tắt khi lớp lưu trữ hoặc hệ thống tập tin (như ZFS) đảm bảo ghi nguyên tử trọn vẹn từng trang 8 KB.

==== MySQL InnoDB - Doublewrite Buffer (`innodb_doublewrite`)

Khác với PostgreSQL, MySQL 8.4 InnoDB không nhúng ảnh trang vào redo log mà sử dụng *doublewrite buffer*: một vùng lưu trữ trung gian nơi InnoDB ghi các trang bẩn được đẩy ra từ buffer pool *trước khi* ghi chúng vào đúng vị trí trong các file dữ liệu tablespace. Nếu tiến trình `mysqld`, hệ điều hành hoặc hệ thống lưu trữ gặp sự cố giữa lúc ghi trang vào tablespace, InnoDB sẽ tìm bản sao nguyên vẹn của trang trong doublewrite buffer để khôi phục trong quá trình crash recovery.

Theo tài liệu MySQL 8.4, dù mỗi trang bẩn được ghi hai lần, doublewrite buffer không làm tăng gấp đôi số lượng thao tác I/O ngẫu nhiên: dữ liệu được ghi vào các file doublewrite (`#ib_*` trong `innodb_doublewrite_dir`, mặc định nằm cùng thư mục dữ liệu) thành từng lô tuần tự lớn chỉ với một lần gọi `fsync()`, sau đó mới ghi ra các vị trí đích trong tablespace.

Các chế độ cấu hình của `innodb_doublewrite` trong MySQL 8.4:

- `ON` / `DETECT_AND_RECOVER` (mặc định): ghi đầy đủ nội dung trang vào doublewrite buffer và dùng chúng để sửa các trang ghi dở khi phục hồi.
- `DETECT_ONLY`: chỉ ghi metadata vào doublewrite buffer để phát hiện trang rách, không ghi nội dung trang và không tự phục hồi trang.
- `OFF`: tắt hoàn toàn doublewrite buffer (chỉ nên dùng khi benchmark hoặc trên phần cứng hỗ trợ ghi nguyên tử như Fusion-io NVMFS). Trong MySQL 8.4, có thể đổi động giữa `ON`/`DETECT_AND_RECOVER` và `DETECT_ONLY`, nhưng chuyển đổi giữa bật và `OFF` bắt buộc phải khởi động lại server.

==== So sánh hai cơ chế bảo vệ trang

#figure(
  table(
    columns: (auto, 1fr, 1fr),
    align: (left, left, left),
    stroke: 0.5pt,
    inset: 6pt,
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
