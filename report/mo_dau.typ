// ============================================================
// MỞ ĐẦU – số trang bắt đầu từ 1 tại bao_cao_tong_hop.typ
// ============================================================

#heading(level: 1, numbering: none)[Mở đầu]

*Tính cần thiết của đề tài.* Các ứng dụng như ngân hàng hay quản lý đơn hàng đòi hỏi dữ liệu đã xác nhận không bị mất, nhưng bảo đảm độ bền có chi phí hiệu năng đáng kể, và cả PostgreSQL lẫn MySQL InnoDB đều cho phép nới lỏng độ bền bằng tham số cấu hình. Người vận hành cần số liệu cụ thể để biết mỗi lựa chọn đổi được bao nhiêu hiệu năng và chấp nhận bao nhiêu rủi ro mất dữ liệu.

*Ý nghĩa khoa học và thực tiễn.* Về khoa học, đề tài kiểm chứng bằng đo đạc các cơ chế ghi nhật ký trước, bảo vệ trang và phục hồi sau sự cố [4]. Về thực tiễn, kết quả là bảng đề xuất cấu hình theo loại ứng dụng, kèm kịch bản đo có thể chạy lại.

*Đối tượng và phạm vi nghiên cứu.* PostgreSQL 16 và MySQL 8.4 LTS (InnoDB) ở cấu hình bền vững và các cấu hình nới lỏng của bốn tham số `synchronous_commit`, `innodb_flush_log_at_trx_commit`, `full_page_writes`, `innodb_doublewrite`; sự cố ở mức tiến trình DBMS và mức hệ điều hành.

*Phương pháp nghiên cứu.* Tìm hiểu tài liệu chính thức của hai hệ [2], [3], rút ra dự đoán trước khi đo, sau đó đo bằng ba thí nghiệm A, B, C trên cùng một máy, kiểm chứng tính đúng của dữ liệu sau mỗi lần chạy và đối chiếu kết quả với dự đoán.

*Nội dung và bố cục.* Chương 1 giới thiệu PostgreSQL: kiến trúc, tính năng, cài đặt và demo các chức năng cơ bản. Chương 2 trình bày cơ chế bảo đảm độ bền của hai hệ, phương pháp thực nghiệm và kết quả ba thí nghiệm. Phần Kết luận tóm tắt các kết quả chính, đề xuất cấu hình theo loại ứng dụng và nêu giới hạn của nghiên cứu.

#heading(level: 2, numbering: none)[Phân công công việc]

#table(
  columns: (auto, 1fr, auto),
  align: (left, left, center),
  stroke: 0.5pt,
  inset: 4.5pt,
  [*Thành viên*], [*Nội dung chính*], [*Phần báo cáo*],
  [TV1 – Vũ Việt Anh], [Kiểm chứng PostgreSQL, thí nghiệm A (chi phí flush log), chương 1, lý thuyết WAL/flush, ghép báo cáo], [Chương 1, 2.1, 2.2 (phần flush), 2.4, Kết luận],
  [TV2 – Phạm Tuấn Minh], [Kiểm chứng MySQL, thí nghiệm B (bảo vệ trang), lý thuyết Full-Page Writes / doublewrite, slide], [2.2 (phần bảo vệ trang), 2.5],
  [TV3 – Trần Minh Hiếu], [Chuẩn bị máy đo, sinh dữ liệu, máy ảo, thí nghiệm C (crash recovery), video demo], [2.2 (checkpoint và phục hồi), 2.3, 2.6],
)

Mã nguồn, dữ liệu, kết quả đo và video demo thí nghiệm C (3 phút 42 giây) lưu tại #link("https://github.com/MihnixArch0n/uet-dbms").
