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

Thí nghiệm C gồm 42 lần crash: 21 lần kill tiến trình DBMS trên máy đo và 21 lần ngắt nguồn máy ảo đang chạy DBMS. Trong toàn bộ thí nghiệm, công cụ bơm tải nhận được hơn 12 triệu xác nhận COMMIT, và mọi giao dịch đã xác nhận đều được đối soát với dữ liệu còn lại sau phục hồi.

=== Tính đúng của dữ liệu sau phục hồi

Ở *cả 42 lần* crash với mọi cấu hình, bất biến $A = T = B = H$ luôn đúng, không có giao dịch lạ, số dòng bảng lịch sử khớp số `txn_id` tìm thấy, và `amcheck` (PostgreSQL) / `CHECK TABLE` (MySQL) không phát hiện trang hỏng. Hai hệ chỉ làm *mất trọn vẹn* một số giao dịch cuối (chỉ phát lại giao dịch có commit trong log bền vững), chưa từng áp dụng dở dang giao dịch nào.

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
  caption: [Kết quả 42 lần crash, bảng B3 (`results/C_summary.csv`). "Tiến trình": kill tiến trình DBMS; "HĐH": ngắt nguồn máy ảo chạy DBMS. "GD mất": giao dịch đã được xác nhận COMMIT nhưng không còn sau phục hồi. RTO theo log và thời gian redo là trung vị, chỉ tính thời gian của DBMS (không gồm thời gian máy ảo khởi động).],
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
  caption: [So sánh kết quả đo với bảng kết quả dự kiến theo tài liệu (mục 2.2). Mọi ô đều khớp.],
)

=== Phân tích

*1. Cấu hình bền vững giữ đúng cam kết.* PostgreSQL `synchronous_commit = on` và InnoDB `innodb_flush_log_at_trx_commit = 1` không làm mất giao dịch đã xác nhận nào ở cả 12 lần crash (kể cả khi ngắt nguồn hệ điều hành). Tổng cộng có 54 giao dịch thuộc nhóm "đang dở lúc crash nhưng đã commit": server đã ghi bản ghi commit xuống đĩa nhưng sập trước khi kịp trả lời client; dữ liệu vẫn đầy đủ và không sai, client chỉ cần cơ chế kiểm tra lại hoặc mã giao dịch chống trùng khi mất kết nối lúc COMMIT.

*2. Cùng một cấu hình, hai loại sự cố cho kết quả trái ngược.* Với InnoDB `=2`, kill tiến trình không mất giao dịch (0/5 lần), nhưng ngắt nguồn HĐH mất tới 2.674 giao dịch (~0,55 giây cuối) ở cả 5/5 lần, do `=2` chỉ `write()` vào page cache mỗi COMMIT còn `fsync()` chạy mỗi giây — chứng minh không thể chỉ thử bằng kill tiến trình.

#figure(
  grid(
    columns: 2,
    gutter: 8pt,
    image("img/R_C2_mysql_2_tien_trinh.png", width: 94%),
    image("img/R_C3_mysql_2_he_dieu_hanh.png", width: 94%),
  ),
  caption: [InnoDB `=2`: kill tiến trình không mất giao dịch (trái) vs ngắt nguồn máy ảo mất 2.674 giao dịch, RPO ~552 ms (phải).],
)

*3. Các cấu hình lỏng mất nhiều hơn hẳn khi hệ điều hành sập.* PostgreSQL `off` mất tối đa 69 giao dịch (20 ms) khi kill tiến trình (chỉ mất phần trong WAL buffers, vì WAL writer đẩy mỗi 200 ms) so với 897 giao dịch (197 ms) khi ngắt nguồn HĐH; InnoDB `=0` tương ứng 108 giao dịch (19 ms) và 3.517 giao dịch (630 ms).

*4. RPO luôn nằm trong giới hạn lý thuyết.* Mọi RPO đo được đều dưới chu kỳ flush định kỳ (PG `off`: ≤ 197 ms < 600 ms; InnoDB `=2`/`=0`: ≤ 552 / 630 ms < 1 s). Dù tỉ lệ giao dịch mất nhỏ (≤ 0,95%), mất 0,5 giây giao dịch đã xác nhận vẫn không chấp nhận được với hệ tài chính.

*5. Thời gian phục hồi.* RTO theo log (trung vị) của PostgreSQL là 9–11 giây (phát lại 600–1.050 MB WAL trong 0,6–4,3 giây, phần lớn thời gian còn lại là checkpoint kết thúc phục hồi), còn InnoDB là 18–19 giây khi kill tiến trình và 7–12 giây trên máy ảo (redo chỉ 12–100 MB nhờ fuzzy checkpoint nhưng khởi tạo bộ đệm 2 GB và plugin tốn thời gian).

#shot("img/H9_redo_time.png", [H9 – Thời gian redo theo lượng log cần phát lại, 42 lần crash.], w: 76%)

Hình H9 cho thấy khi kill tiến trình trên máy thật, InnoDB mất 7–12 giây để redo 23–65 MB do đọc trang trực tiếp từ đĩa (`O_DIRECT`), trong khi PostgreSQL redo ~900 MB trong ~1 giây nhờ page cache còn nguyên; trên máy ảo thì ngược lại (page cache khách mất, đĩa ảo được máy thật đệm).

#figure(
  grid(
    columns: 2,
    gutter: 8pt,
    image("img/R_C5_log_phuc_hoi_pg.png", width: 94%),
    image("img/R_C6_log_phuc_hoi_mysql.png", width: 94%),
  ),
  caption: [Log phục hồi sau khi kill tiến trình: PostgreSQL (`redo starts/done at`, trái) và InnoDB (phải).],
)

*6. Quan hệ với thí nghiệm A.* Trong cùng thời gian bơm tải, cấu hình lỏng nhận được nhiều xác nhận hơn cấu hình bền vững ~3–4 lần (nhưng nhỏ hơn chênh lệch ở thí nghiệm A vì `crash_client.py` viết bằng Python bị giới hạn ở ~3.500–5.000 TPS, nên không dùng TPS ở đây để so với thí nghiệm A). Đặt cạnh nhau, hai thí nghiệm cho thấy rõ đánh đổi: cấu hình lỏng tăng thông lượng nhiều lần, đổi lại có thể mất vài trăm mili giây giao dịch đã xác nhận khi hệ điều hành sập.

=== Sự cố trong quá trình đo và ghi chú kỹ thuật

VirtualBox không chạy trên kernel 7.0 có Secure Boot nên nhóm dùng KVM (`virsh destroy`); ở lượt HĐH đầu tiên phân vùng VM (19 GB) bị đầy nên đã mở rộng lên 38 GB và chạy lại toàn bộ 21 lần (13 dòng RTO/redo MySQL đọc từ log JSON qua `scripts/fix_mysql_os_dblog.py`). Do lần InnoDB `=2` đầu tiên ở mức HĐH có RTO 29,4 giây (redo bình thường 2,9 giây), bảng B3 dùng trung vị thay cho trung bình.

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
