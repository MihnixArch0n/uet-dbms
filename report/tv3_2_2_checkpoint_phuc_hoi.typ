// ============================================================
// MỤC 2.2 (phần của TV3): CHECKPOINT VÀ PHỤC HỒI SAU SỰ CỐ
// Chèn vào cuối mục "== Cơ chế của hai hệ", sau phần flush log (TV1)
// và phần Full-Page Writes / doublewrite (TV2):
//   #include "tv3_2_2_checkpoint_phuc_hoi.typ"
// ============================================================

=== Checkpoint và phục hồi sau sự cố

*Checkpoint* ghi các trang bẩn xuống đĩa và đánh dấu vị trí bắt đầu phục hồi trong log, giúp rút ngắn lượng log cần phát lại khi khởi động lại [4].

*PostgreSQL* [3] kích hoạt checkpoint theo `checkpoint_timeout` (5 phút), `max_wal_size` (4 GB) hoặc lệnh `CHECKPOINT`, rải I/O trong `checkpoint_completion_target` (0,9) và lưu redo point vào `global/pg_control`. Khi phục hồi, PostgreSQL: (1) đọc `pg_control`; (2) phát lại WAL từ redo point (`redo starts at` → `redo done at`), dùng FPI ghi đè trang rách; (3) ghi checkpoint kết thúc phục hồi rồi nhận kết nối. PostgreSQL không có pha undo vì MVCC (`pg_xact`) ẩn giao dịch chưa COMMIT để VACUUM dọn sau.

*MySQL InnoDB* dùng *fuzzy checkpoint* [2] (đẩy dần trang bẩn theo LSN, giới hạn bởi `innodb_redo_log_capacity` = 4 GB). Khi phục hồi, InnoDB: (1) khôi phục trang rách từ doublewrite; (2) phát lại redo log từ checkpoint LSN (`Starting crash recovery` → `Apply batch completed`); (3) rollback giao dịch chưa COMMIT bằng undo log (có thể chạy nền). Cả hai hệ đều chỉ giữ trọn vẹn các giao dịch đã có bản ghi commit trong log bền vững, nên bất biến bốn tổng luôn đúng sau phục hồi.

*RPO, RTO và đánh đổi:* *RPO* (dữ liệu xác nhận bị mất) bằng 0 ở cấu hình bền vững, còn ở cấu hình lỏng bị chặn bởi chu kỳ flush (~3 × `wal_writer_delay` = 600 ms ở PG; ~`innodb_flush_log_at_timeout` = 1 s ở InnoDB). *RTO* (thời gian phục hồi) gồm thời gian redo cộng chi phí khởi động. Checkpoint càng dày thì RTO càng ngắn nhưng PG sinh càng nhiều FPI (thí nghiệm B).
