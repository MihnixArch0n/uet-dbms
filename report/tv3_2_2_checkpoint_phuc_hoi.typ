// ============================================================
// MỤC 2.2 (phần của TV3): CHECKPOINT VÀ PHỤC HỒI SAU SỰ CỐ
// Chèn vào cuối mục "== Cơ chế của hai hệ", sau phần flush log (TV1)
// và phần Full-Page Writes / doublewrite (TV2):
//   #include "tv3_2_2_checkpoint_phuc_hoi.typ"
// ============================================================

=== Checkpoint và phục hồi sau sự cố

Write-ahead logging bảo đảm giao dịch đã COMMIT không mất, nhưng nếu chỉ có log thì sau mỗi sự cố hệ thống phải phát lại toàn bộ log từ lúc khởi tạo. *Checkpoint* giới hạn khối lượng đó: tại một thời điểm, hệ quản trị ghi các trang bẩn (dirty page) trong bộ đệm xuống đĩa và ghi lại vị trí trong log mà từ đó việc phục hồi phải bắt đầu. Phần log trước vị trí này không còn cần cho phục hồi và có thể được tái sử dụng.

*PostgreSQL.* Checkpoint được kích hoạt khi hết `checkpoint_timeout` (nhóm dùng 5 phút), khi lượng WAL sinh ra vượt `max_wal_size` (4 GB), hoặc khi có lệnh `CHECKPOINT`. Để tránh dồn I/O, tiến trình checkpointer rải việc ghi trang trong khoảng `checkpoint_completion_target` (0,9) của chu kỳ. Vị trí bắt đầu phục hồi (redo point, một LSN) được ghi vào file `global/pg_control`. Khi khởi động sau sự cố, PostgreSQL:

1. đọc `pg_control` để biết checkpoint cuối và redo point;
2. phát lại (redo) mọi bản ghi WAL từ redo point đến cuối WAL hợp lệ, trong đó ảnh trang đầy đủ (full-page image) thay thế các trang có thể bị rách;
3. ghi một checkpoint kết thúc phục hồi (end-of-recovery checkpoint) rồi mới nhận kết nối.

PostgreSQL không có pha undo. Giao dịch chưa COMMIT lúc sự cố vẫn để lại phiên bản dòng trong bảng, nhưng nhờ MVCC và trạng thái giao dịch lưu trong `pg_xact`, các phiên bản này không bao giờ hiển thị và sẽ được VACUUM dọn sau. Log của PostgreSQL ghi rõ các mốc `redo starts at`, `redo done at` kèm thời gian đã chạy; nhóm dùng các dòng này để đo thời gian redo.

*MySQL InnoDB.* InnoDB dùng *fuzzy checkpoint*: không dừng hệ thống để ghi toàn bộ trang bẩn, mà liên tục đẩy dần trang bẩn theo thứ tự LSN và tiến điểm checkpoint (checkpoint LSN) lên. Dung lượng redo log (`innodb_redo_log_capacity`, nhóm dùng 4 GB) giới hạn khoảng cách giữa checkpoint LSN và LSN hiện tại: khi redo log gần đầy, InnoDB buộc phải flush trang nhanh hơn. Khi khởi động sau sự cố, InnoDB:

1. kiểm tra vùng doublewrite và khôi phục các trang bị rách từ bản sao ở đó;
2. đọc redo log từ checkpoint LSN và áp dụng các bản ghi redo (log ghi `Starting crash recovery`, `Applying a batch of ... redo log records`, `Apply batch completed`);
3. rollback các giao dịch chưa COMMIT bằng undo log. Bước này có thể chạy nền sau khi server đã nhận kết nối.

Như vậy hai hệ khác nhau ở cấu trúc phục hồi: PostgreSQL chỉ có redo, còn InnoDB có redo rồi undo. Cả hai đều chỉ khôi phục trọn vẹn những giao dịch có bản ghi commit đã nằm trong log bền vững; giao dịch nào không có thì biến mất trọn vẹn. Đây là lý do bất biến bốn tổng (mục 2.3) phải luôn đúng sau phục hồi, kể cả với cấu hình không bền vững.

*RPO, RTO và đánh đổi của checkpoint.* Hai chỉ số dùng để đánh giá khả năng chịu sự cố:

- *RPO* (Recovery Point Objective): lượng dữ liệu đã xác nhận nhưng bị mất. Với cấu hình bền vững, RPO phải bằng 0. Với cấu hình lỏng, RPO bị chặn bởi chu kỳ flush log định kỳ (khoảng 3 × `wal_writer_delay` = 600 ms ở PostgreSQL, khoảng `innodb_flush_log_at_timeout` = 1 giây ở InnoDB).
- *RTO* (Recovery Time Objective): thời gian từ lúc khởi động lại đến khi hệ thống phục vụ được. RTO gồm thời gian redo, tỉ lệ với lượng log từ checkpoint cuối, cộng các việc khác khi khởi động.

Checkpoint càng dày thì log cần redo càng ít và RTO càng ngắn, nhưng hệ thống phải ghi trang thường xuyên hơn và với PostgreSQL sinh nhiều ảnh trang đầy đủ hơn (chi phí đo ở thí nghiệm B). Checkpoint càng thưa thì ngược lại. Thí nghiệm C (mục 2.6) đo trực tiếp RPO và RTO của từng cấu hình.
