// ============================================================
// TÓM TẮT VÀ LỜI CAM ĐOAN (không đánh số trang)
// Theo Phụ lục 03 của quy định trình bày: tiêu đề 13 pt đậm, nội dung khoảng 360 từ cỡ 12 pt,
// từ khóa in đậm nghiêng, tối đa 4 cụm.
// ============================================================

#page[
  #align(center, text(13pt, weight: "bold")[TÓM TẮT])
  #v(0.6cm)
  #set text(size: 12pt)

  *Tóm tắt:* Thuộc tính bền vững (Durability) trong ACID yêu cầu giao dịch đã được xác nhận COMMIT không bị mất khi hệ thống gặp sự cố. Báo cáo tìm hiểu và so sánh bằng thực nghiệm cách PostgreSQL 16 và MySQL 8.4 (engine InnoDB) bảo đảm thuộc tính này thông qua ba nhóm cơ chế: ghi nhật ký trước (WAL, redo log) cùng chính sách đẩy log xuống đĩa khi COMMIT; bảo vệ trang dữ liệu khỏi bị ghi rách (Full-Page Writes và Doublewrite Buffer); checkpoint và phục hồi sau sự cố. Ba thí nghiệm được thực hiện trên cùng một máy đo, hai hệ chạy trong container với cấu hình nền tương đương và cùng tập dữ liệu, mỗi lần chạy đều kiểm chứng bất biến của dữ liệu. Thí nghiệm A đo chi phí chờ `fsync` log khi COMMIT: ở cấu hình bền vững, thông lượng thấp hơn cấu hình nới lỏng từ 3,7 đến 18,2 lần với PostgreSQL và từ 2,8 đến 11,7 lần với InnoDB; group commit giảm số lần `fsync` mỗi giao dịch xuống dưới 0,1 ở 32 client nhưng không triệt tiêu được chi phí này. Thí nghiệm B cho thấy PostgreSQL trả chi phí bảo vệ trang vào WAL (lượng WAL mỗi giao dịch tăng 5,7 lần, 82% là ảnh trang đầy đủ ghi ngay sau checkpoint), còn InnoDB trả vào lượng ghi đĩa qua doublewrite trong khi redo log không đổi. Thí nghiệm C gây 42 lần sự cố ở hai mức, kill tiến trình DBMS và ngắt nguồn máy ảo KVM, rồi đối chiếu từng giao dịch đã được xác nhận với dữ liệu sau phục hồi. Cấu hình bền vững không mất giao dịch nào; InnoDB với `innodb_flush_log_at_trx_commit = 2` an toàn khi kill tiến trình nhưng mất tới 2.674 giao dịch (khoảng 552 ms) khi hệ điều hành sập. Mọi cấu hình đều giữ đúng bất biến và không hỏng trang, lượng dữ liệu mất luôn nằm trong một chu kỳ flush, thời gian phục hồi từ 7 đến 19 giây. Từ các kết quả này, báo cáo đề xuất cấu hình phù hợp cho từng loại ứng dụng.

  #v(0.3cm)
  *_Từ khóa:_* Durability, Crash Recovery, Write-Ahead Logging, PostgreSQL và MySQL InnoDB.
]

#page[
  #align(center, text(13pt, weight: "bold")[LỜI CAM ĐOAN])
  #v(0.6cm)

  Chúng em xin cam đoan báo cáo này là kết quả tìm hiểu và thực nghiệm của Nhóm 02. Các số liệu, hình ảnh và kết quả đo trong báo cáo do nhóm tự thực hiện trên máy đo của nhóm, được lưu đầy đủ trong repository của đề tài và không sao chép từ công trình của người khác. Mọi nội dung tham khảo từ tài liệu, công trình của người khác đều được trích dẫn và ghi rõ trong mục Tài liệu tham khảo. Nếu có sai phạm, chúng em xin hoàn toàn chịu trách nhiệm.

  #v(0.8cm)
  #align(right)[_Hà Nội, tháng 11 năm 2026_]
]
