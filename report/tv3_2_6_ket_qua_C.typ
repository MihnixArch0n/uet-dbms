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
#show table: set text(size: 9.5pt)
#show table: set par(justify: false)

== Kết quả thí nghiệm C

Thí nghiệm C gồm 42 lần crash: 21 lần kill tiến trình DBMS trên máy đo và 21 lần ngắt nguồn máy ảo đang chạy DBMS. Trong toàn bộ thí nghiệm, công cụ bơm tải nhận được hơn 12 triệu xác nhận COMMIT, và mọi giao dịch đã xác nhận đều được đối soát với dữ liệu còn lại sau phục hồi.

=== Tính đúng của dữ liệu sau phục hồi

Ở *cả 42 lần* crash, với *mọi* cấu hình:

- bất biến $A = T = B = H$ luôn đúng;
- không có giao dịch lạ (giao dịch có trong bảng mà công cụ chưa từng gửi);
- số dòng của bảng lịch sử khớp với số `txn_id` tìm thấy;
- kiểm tra chỉ mục và checksum của PostgreSQL (`amcheck`) và `CHECK TABLE` của MySQL đều không phát hiện trang hỏng.

Nghĩa là cả hai hệ chỉ làm *mất trọn vẹn* một số giao dịch cuối, chưa lần nào để lại một giao dịch được áp dụng một phần, kể cả ở các cấu hình không bền vững. Kết quả này đúng như lý thuyết ở mục 2.2: phục hồi chỉ phát lại những giao dịch có bản ghi commit trong log bền vững, và phát lại đến một điểm nhất quán.

=== Bảng tổng hợp

#figure(
  table(
    columns: (auto, auto, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr),
    align: (x, y) => if y == 0 { center + horizon } else { (left, left, center, right, right, right, right, right).at(x) },
    stroke: 0.5pt,
    inset: 5pt,
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
    inset: 5pt,
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

*2. Cùng một cấu hình, hai loại sự cố cho kết quả trái ngược.* Với InnoDB `=2`, kill tiến trình không làm mất giao dịch nào ở cả 5 lần, nhưng ngắt nguồn hệ điều hành làm mất giao dịch ở cả 5 lần, nhiều nhất 2.674 giao dịch (~0,55 giây cuối). Lý do: với `=2`, mỗi COMMIT ghi log sang page cache của hệ điều hành (`write()`), còn `fsync()` chỉ chạy khoảng mỗi giây. Kill tiến trình không xóa page cache nên log vẫn được hệ điều hành ghi xuống đĩa; ngắt nguồn thì phần chưa `fsync()` mất theo page cache. Đây là câu trả lời trực tiếp cho nhận xét 1 của giảng viên: nếu chỉ thử bằng kill tiến trình, ta sẽ kết luận sai rằng `=2` an toàn như `=1`.

#figure(
  grid(
    columns: 2,
    gutter: 8pt,
    image("img/R_C2_mysql_2_tien_trinh.png", width: 100%),
    image("img/R_C3_mysql_2_he_dieu_hanh.png", width: 100%),
  ),
  caption: [InnoDB `=2`. Trái: kill tiến trình, 396.227 giao dịch đã xác nhận, không mất giao dịch nào. Phải: ngắt nguồn máy ảo, mất 2.674/281.183 giao dịch (RPO ~552 ms), bất biến vẫn đúng.],
)

*3. Các cấu hình lỏng mất nhiều hơn hẳn khi hệ điều hành sập.* PostgreSQL `off` mất tối đa 69 giao dịch (20 ms) khi kill tiến trình, nhưng tối đa 897 giao dịch (197 ms) khi ngắt nguồn. InnoDB `=0` mất tối đa 108 giao dịch (19 ms) và 3.517 giao dịch (630 ms) tương ứng. Khi kill tiến trình, chỉ phần log còn nằm trong bộ nhớ của DBMS (WAL buffers, log buffer) bị mất. Phần này nhỏ vì log liên tục được đẩy sang hệ điều hành (WAL writer ghi mỗi 200 ms; các luồng ghi log InnoDB đẩy theo đợt). Khi ngắt nguồn, phần đã ghi sang hệ điều hành nhưng chưa `fsync()` cũng mất, nên cửa sổ mất dài hơn.

*4. RPO luôn nằm trong giới hạn lý thuyết.* Mọi RPO đo được đều nhỏ hơn chu kỳ flush định kỳ của hệ tương ứng: PostgreSQL `off` tối đa 197 ms, so với giới hạn khoảng 3 × `wal_writer_delay` = 600 ms; InnoDB `=2` và `=0` tối đa 552 ms và 630 ms, so với giới hạn khoảng 1 giây (`innodb_flush_log_at_timeout`). Tỉ lệ giao dịch bị mất trên tổng số giao dịch đã xác nhận cũng nhỏ, tối đa 0,95% (InnoDB `=2`, lần chạy ở hình trên). Tuy nhiên, cần nhìn RPO theo thời gian chứ không theo tỉ lệ: với một hệ thống ngân hàng, mất 0,5 giây giao dịch đã báo thành công vẫn là không chấp nhận được.

*5. Thời gian phục hồi.* RTO theo log DBMS (trung vị) của PostgreSQL khoảng 9 đến 11 giây, của InnoDB khoảng 18 đến 19 giây khi kill tiến trình và 7 đến 12 giây trong máy ảo. RTO không chỉ là thời gian redo:

- PostgreSQL phát lại khoảng 600 đến 1.050 MB WAL chỉ trong 0,6 đến 4,3 giây, nhưng sau đó phải ghi một checkpoint kết thúc phục hồi (ghi mọi trang bẩn xuống đĩa) rồi mới nhận kết nối; phần này chiếm phần lớn RTO.
- InnoDB có lượng redo cần phát lại nhỏ hơn nhiều (12 đến 100 MB tùy lần chạy) vì fuzzy checkpoint liên tục tiến điểm checkpoint, nhưng phần còn lại của quá trình khởi động (khởi tạo bộ đệm 2 GB, kiểm tra doublewrite, các plugin) chiếm thời gian đáng kể.
- Giữa các cấu hình trong cùng một mức sự cố, RTO chênh nhau ít. Cấu hình flush không ảnh hưởng nhiều đến thời gian phục hồi; điều quyết định là lượng log từ checkpoint cuối và cách hệ quản trị khởi động.

#shot("img/H9_redo_time.png", [H9 – Thời gian redo theo lượng log cần phát lại, 42 lần crash.], w: 80%)

Hình H9 cho thấy thời gian redo không chỉ phụ thuộc lượng log. Khi kill tiến trình trên máy đo, InnoDB mất 7–12 giây để phát lại chỉ 23–65 MB redo, trong khi PostgreSQL phát lại ~900 MB trong ~1 giây. Nguyên nhân là InnoDB đọc trang trực tiếp từ đĩa (`O_DIRECT`, bỏ qua page cache) nên mỗi trang là một lần đọc ngẫu nhiên trên SSD gắn ngoài, còn PostgreSQL đọc qua page cache vốn vẫn còn nguyên sau khi kill tiến trình. Trong máy ảo, PostgreSQL redo chậm hơn (page cache khách đã mất), còn InnoDB nhanh hơn (đĩa ảo được máy thật lưu đệm). Vì môi trường hai mức khác nhau, nhóm chỉ so sánh RTO giữa các cấu hình trong cùng một mức.

#figure(
  grid(
    columns: 2,
    gutter: 8pt,
    image("img/R_C5_log_phuc_hoi_pg.png", width: 100%),
    image("img/R_C6_log_phuc_hoi_mysql.png", width: 100%),
  ),
  caption: [Log phục hồi sau khi kill tiến trình. Trái: PostgreSQL (`redo starts at`, `redo done at`). Phải: InnoDB (`Starting crash recovery`, áp dụng các lô redo).],
)

*6. Quan hệ với thí nghiệm A.* Trong cùng thời gian bơm tải, cấu hình lỏng nhận được nhiều xác nhận hơn cấu hình bền vững ~3–4 lần (nhưng nhỏ hơn chênh lệch ở thí nghiệm A vì `crash_client.py` viết bằng Python bị giới hạn ở ~3.500–5.000 TPS, nên không dùng TPS ở đây để so với thí nghiệm A). Đặt cạnh nhau, hai thí nghiệm cho thấy rõ đánh đổi: cấu hình lỏng tăng thông lượng nhiều lần, đổi lại có thể mất vài trăm mili giây giao dịch đã xác nhận khi hệ điều hành sập.

=== Sự cố trong quá trình đo và ghi chú kỹ thuật

- *Ảo hóa và hết đĩa VM:* VirtualBox không chạy được trên kernel 7.0 có Secure Boot nên dùng KVM (`virsh destroy`). Ở lượt chạy mức HĐH đầu tiên, phân vùng VM (19 GB) bị đầy giữa chừng; nhóm đã mở rộng lên 38 GB và chạy lại toàn bộ 21 lần (mọi số liệu Bảng B3 lấy từ lượt chạy lại; 13 dòng RTO/redo của MySQL được đọc trực tiếp từ log JSON bằng `scripts/fix_mysql_os_dblog.py`).
- *Ngoại lệ về RTO:* Lần InnoDB `=2` đầu tiên ở mức HĐH có RTO theo log 29,4 giây (gấp ~2,5 lần các lần khác dù redo bình thường 2,9 giây), nên bảng B3 dùng trung vị thay cho trung bình. (Các giới hạn chung về mất điện thật và số lần lặp được tổng hợp ở mục 2.7.)

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
