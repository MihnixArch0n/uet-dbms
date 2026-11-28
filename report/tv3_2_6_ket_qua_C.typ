#import "flexcap.typ": fcap
// ============================================================
// MỤC 2.6: KẾT QUẢ THÍ NGHIỆM C (TV3)
// Chèn sau mục 2.5 (kết quả thí nghiệm B) bằng:
//   #include "tv3_2_6_ket_qua_C.typ"
// Số liệu: results/C_summary.csv (42 dòng), results/C_table.md
// Ảnh: img/R_C1 ... R_C6, img/H9_redo_time.png
//   (H9 sinh ở analysis/figures/, cần chép sang report/img/)
// ============================================================

#let shot(path, cap, w: 100%) = figure(image(path, width: w), caption: cap)
// Bảng: chữ nhỏ hơn, không căn đều hai bên (tránh khoảng trắng giãn trong ô hẹp)
#show table: set text(size: 11pt)
#show table: set par(justify: false)

== Kết quả thí nghiệm C

Thí nghiệm C gồm 42 lần crash (21 lần kill tiến trình DBMS trên máy đo, 21 lần ngắt nguồn máy ảo), với hơn 12 triệu xác nhận COMMIT được đối soát với dữ liệu sau phục hồi.

=== Tính đúng của dữ liệu sau phục hồi

Ở cả 42 lần, bất biến $A = T = B = H$ luôn đúng, không có giao dịch lạ, số dòng bảng lịch sử khớp, `amcheck` / `CHECK TABLE` không phát hiện trang hỏng. Hai hệ chỉ làm *mất trọn vẹn* một số giao dịch cuối, không bao giờ áp dụng dở dang một giao dịch.

=== Bảng tổng hợp

#figure(
  table(
    columns: (auto, auto, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr),
    align: (x, y) => if y == 0 { center + horizon } else { (left, left, center, right, right, right, right, right).at(x) },
    stroke: 0.5pt,
    inset: 4pt,
    table.header([*Mức*], [*Cấu hình*], [*Số lần mất*], [*Tổng GD mất*], [*GD mất nhiều nhất / lần*], [*RPO lớn nhất*], [*RTO (log)*], [*Thời gian redo*]),
    [Tiến trình], [PG `on`], [0 / 3], [0], [0], [0], [9,9 s], [0,61 s],
    [Tiến trình], [PG `off`], [5 / 5], [80], [69], [20 ms], [11,1 s], [1,21 s],
    [Tiến trình], [MySQL `=1`], [0 / 3], [0], [0], [0], [18,1 s], [8,54 s],
    [Tiến trình], [MySQL `=2`], [0 / 5], [0], [0], [0], [19,2 s], [9,02 s],
    [Tiến trình], [MySQL `=0`], [4 / 5], [118], [108], [19 ms], [18,5 s], [8,55 s],
    [HĐH], [PG `on`], [0 / 3], [0], [0], [0], [8,7 s], [1,88 s],
    [HĐH], [PG `off`], [5 / 5], [2.687], [897], [197 ms], [10,6 s], [3,81 s],
    [HĐH], [MySQL `=1`], [0 / 3], [0], [0], [0], [8,9 s], [1,40 s],
    [HĐH], [MySQL `=2`], [5 / 5], [4.926], [2.674], [552 ms], [11,6 s], [2,36 s],
    [HĐH], [MySQL `=0`], [5 / 5], [8.071], [3.517], [630 ms], [7,4 s], [2,45 s],
  ),
  caption: fcap([Kết quả 42 lần crash, bảng B3 (`results/C_summary.csv`).], [Kết quả 42 lần crash, bảng B3 (`results/C_summary.csv`). "Tiến trình": kill tiến trình DBMS; "HĐH": ngắt nguồn máy ảo chạy DBMS. "GD mất": giao dịch đã được xác nhận COMMIT nhưng không còn sau phục hồi. RTO theo log và thời gian redo là trung vị, chỉ tính thời gian của DBMS (không gồm thời gian máy ảo khởi động).]),
)

=== Đối chiếu với kết quả dự kiến

#figure(
  table(
    columns: (2.3cm, 1fr, 1fr, 1fr, 1fr),
    align: (left, left, left, left, left),
    stroke: 0.5pt,
    inset: 4pt,
    table.header([*Cấu hình*], [*Dự kiến: crash tiến trình*], [*Đo được*], [*Dự kiến: crash hệ điều hành*], [*Đo được*]),
    [PG `on`], [Không mất], [Không mất (0/3) ✓], [Không mất], [Không mất (0/3) ✓],
    [PG `off`], [Có thể mất], [Mất ở 5/5 lần, tối đa 20 ms ✓], [Có thể mất], [Mất ở 5/5 lần, tối đa 197 ms ✓],
    [MySQL `=1`], [Không mất], [Không mất (0/3) ✓], [Không mất], [Không mất (0/3) ✓],
    [MySQL `=2`], [Không mất], [Không mất (0/5) ✓], [Có thể mất khoảng 1 giây cuối], [Mất ở 5/5 lần, tối đa 552 ms ✓],
    [MySQL `=0`], [Có thể mất khoảng 1 giây cuối], [Mất ở 4/5 lần, tối đa 19 ms ✓], [Có thể mất khoảng 1 giây cuối], [Mất ở 5/5 lần, tối đa 630 ms ✓],
  ),
  caption: fcap([So sánh kết quả đo với bảng kết quả dự kiến theo tài liệu (mục 2.2).], [So sánh kết quả đo với bảng kết quả dự kiến theo tài liệu (mục 2.2). Mọi ô đều khớp.]),
)

=== Phân tích

*1. Cấu hình bền vững giữ đúng cam kết.* PostgreSQL `on` và InnoDB `=1` không mất giao dịch đã xác nhận nào qua 12 lần crash, kể cả khi ngắt nguồn. 54 giao dịch "đang dở" vẫn được commit (server đã ghi bản ghi commit nhưng sập trước khi trả lời), nên client cần cơ chế kiểm tra lại khi mất kết nối lúc COMMIT.

*2. Cùng cấu hình, hai loại sự cố cho kết quả trái ngược.* InnoDB `=2` không mất gì khi kill tiến trình (0/5) nhưng mất tới 2.674 giao dịch (\~0,55 s) ở 5/5 lần ngắt nguồn, vì `=2` chỉ `write()` vào page cache, còn `fsync()` mỗi giây. Do đó không thể chỉ kiểm thử bằng kill tiến trình.

#figure(
  grid(
    columns: 1,
    gutter: 6pt,
    image("img/R_C2_mysql_2_tien_trinh.png", width: 80%),
    image("img/R_C3_mysql_2_he_dieu_hanh.png", width: 80%),
  ),
  caption: [InnoDB `=2`: kill tiến trình không mất giao dịch (trên) vs ngắt nguồn máy ảo mất 2.674 giao dịch, RPO \~552 ms (dưới).],
)

*3. Cấu hình lỏng mất nhiều hơn hẳn khi HĐH sập, nhưng RPO luôn dưới chu kỳ flush.* PG `off` mất tối đa 69 giao dịch (20 ms) khi kill tiến trình so với 897 (197 ms) khi ngắt nguồn; InnoDB `=0` là 108 (19 ms) so với 3.517 (630 ms). Mọi RPO đều dưới giới hạn lý thuyết (600 ms với PG, 1 s với InnoDB); tỉ lệ mất nhỏ (≤ 0,95%) nhưng vẫn không chấp nhận được với hệ tài chính.

*4. Thời gian phục hồi.* RTO (trung vị theo log) của PostgreSQL là 9–11 s, chủ yếu do checkpoint kết thúc phục hồi; InnoDB 18–19 s khi kill tiến trình và 7–12 s trên máy ảo, chủ yếu do khởi tạo bộ đệm 2 GB. Khi kill tiến trình, PostgreSQL redo \~900 MB trong \~1 s nhờ page cache còn nguyên, còn InnoDB mất 7–12 s cho 23–65 MB vì đọc trang trực tiếp từ đĩa (`O_DIRECT`); trên máy ảo thì ngược lại.

#shot("img/H9_redo_time.png", [Thời gian redo theo lượng log cần phát lại, 42 lần crash.], w: 64%) <fig-h9>

#figure(
  grid(
    columns: 1,
    gutter: 6pt,
    image("img/R_C5_log_phuc_hoi_pg.png", width: 80%),
    image("img/R_C6_log_phuc_hoi_mysql.png", width: 80%),
  ),
  caption: [Log phục hồi sau khi kill tiến trình: PostgreSQL (`redo starts/done at`, trên) và InnoDB (dưới).],
)

=== Ghi chú kỹ thuật

Ở lượt ngắt nguồn đầu tiên, phân vùng máy ảo bị đầy nên nhóm mở rộng lên 38 GB và chạy lại toàn bộ 21 lần. Một lần InnoDB `=2` có RTO bất thường (29,4 s) nên bảng B3 dùng trung vị. Công cụ bơm tải viết bằng Python chỉ đạt \~3.500–5.000 TPS, nên không dùng TPS ở thí nghiệm C để so với thí nghiệm A.

// ============================================================
// GỢI Ý CHO MỤC 2.7 (TV1 tổng hợp) – TV3 góp ý, không in ra
// ------------------------------------------------------------
// - Cấu hình bền vững (PG on, InnoDB =1) không mất giao dịch nào qua 12 lần crash ở cả hai
//   mức sự cố; cái giá là TPS thấp hơn nhiều lần (thí nghiệm A).
// - InnoDB =2 là "bẫy": an toàn với crash tiến trình nhưng mất tới khoảng 0,55 s giao dịch khi
//   hệ điều hành sập. Chỉ dùng khi chấp nhận được mất dữ liệu lúc máy sập.
// - Mọi cấu hình đều giữ được tính nhất quán (bất biến đúng 42/42 lần): cấu hình lỏng đánh
//   đổi độ đầy đủ chứ không đánh đổi tính đúng của dữ liệu.
// - RPO đo được luôn dưới chu kỳ flush định kỳ: khoảng 200 ms với PG off, khoảng 0,6 s với
//   InnoDB =0/=2.
// - RTO khoảng 10 đến 20 s, chủ yếu là các bước khởi động sau redo (checkpoint kết thúc phục
//   hồi của PG, khởi tạo bộ đệm của InnoDB), không chỉ là thời gian phát lại log.
// - Giới hạn chung: một máy đo, ổ SSD gắn ngoài; không thử mất điện thật; binlog MySQL tắt.
//
// TÀI LIỆU THAM KHẢO BỔ SUNG (đưa vào danh sách chung):
// - PostgreSQL 16 Documentation – WAL Internals; Asynchronous Commit;
//   https://www.postgresql.org/docs/16/wal-internals.html, .../wal-async-commit.html
// - PostgreSQL 16 Documentation – amcheck. https://www.postgresql.org/docs/16/amcheck.html
// - MySQL 8.4 Reference Manual – InnoDB Recovery; InnoDB Checkpoints; Redo Log.
//   https://dev.mysql.com/doc/refman/8.4/en/innodb-recovery.html
// - libvirt / QEMU – virsh destroy (ngắt nguồn máy ảo). https://libvirt.org/manpages/virsh.html
// ============================================================
