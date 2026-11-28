#import "flexcap.typ": fcap
// ============================================================
// MỤC 2.3: PHƯƠNG PHÁP THỰC NGHIỆM (TV3 viết phần chung và thiết kế thí nghiệm C)
// Thay toàn bộ mục "== Phương pháp thực nghiệm (tóm tắt phần liên quan đến A)"
// trong bản nháp của TV1 bằng:
//   #include "tv3_2_3_phuong_phap.typ"
// Ảnh dùng trong mục: img/M_01, M_02, M_03, M_04, M_06, M_08
// ============================================================

#let shot(path, cap, w: 100%) = figure(image(path, width: w), caption: cap)
// Bảng: chữ nhỏ hơn, không căn đều hai bên (tránh khoảng trắng giãn trong ô hẹp)
#show table: set text(size: 11pt)
#show table: set par(justify: false, leading: 0.55em)

== Phương pháp thực nghiệm

Mục này mô tả phần dùng chung cho ba thí nghiệm và thiết kế chi tiết của thí nghiệm C; mọi lệnh và script nằm trong repo của nhóm.

=== Máy đo và môi trường

Mọi số liệu được đo trên *một máy duy nhất*. Hai hệ chạy trong Docker với cùng giới hạn tài nguyên (4 CPU, 6 GB RAM mỗi container), mỗi lần đo chỉ bật một hệ.

#figure(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: 0.5pt,
    inset: 4.5pt,
    table.header([*Thành phần*], [*Cấu hình*]),
    [CPU], [AMD Ryzen AI 9 HX 370, 12 nhân / 24 luồng],
    [Bộ nhớ], [30 GiB],
    [Ổ chứa dữ liệu], [SSD SATA HS-SSD-C100 240 GB (không có DRAM cache), gắn ngoài qua USB 3 (UASP), hệ file ext4; bộ đệm ghi của ổ: `write back`],
    [Tốc độ fsync của ổ], [`fdatasync` 424 lần/giây (2,36 ms/lần), `fsync` 210 lần/giây (đo bằng `pg_test_fsync`)],
    [Hệ điều hành], [Ubuntu 24.04.5 LTS, kernel 7.0.0],
    [Container], [Docker 29.10, Docker Compose 5.8],
    [Hệ quản trị], [PostgreSQL 16.16 (image `postgres:16`), MySQL 8.4.13 (image `mysql:8.4`)],
    [Công cụ đo], [sysbench 1.0.20 (thí nghiệm A, B); Python 3.14 với psycopg 3 và PyMySQL (thí nghiệm C)],
  ),
  caption: [Cấu hình máy đo (chép từ `results/env/hardware.txt`).],
) <tab-hw>

Tốc độ fsync ở bảng trên là trần thông lượng khi 1 client và mỗi COMMIT chờ một lần fsync (@sec-expA).

*Máy ảo cho crash hệ điều hành.* Hai hệ được đặt trong máy ảo KVM/QEMU quản lý bằng libvirt (4 vCPU, 8 GB RAM, đĩa qcow2 40 GB trên cùng ổ SSD, Ubuntu Server 24.04, cùng image và cấu hình Docker). Sự cố được gây bằng `virsh destroy` (ngắt nguồn đột ngột) [1] rồi bật lại bằng `virsh start`; lệnh flush của máy ảo được chuyển thẳng xuống đĩa máy thật nên dữ liệu đã `fsync` thực sự nằm trên đĩa.

=== Dữ liệu

Lược đồ ngân hàng của pgbench (TPC-B, scale 50): 50 chi nhánh, 500 giao dịch viên, 5.000.000 tài khoản và bảng lịch sử (thêm cột `txn_id` để đối soát ở thí nghiệm C). Dữ liệu sinh bằng `pgbench -i -s 50`, xuất CSV và nạp nguyên vẹn sang MySQL; với bộ đệm 2 GB, toàn bộ dữ liệu nằm gọn trong bộ nhớ nên chi phí đo được chủ yếu là ghi log và ghi trang.

=== Workload

Mỗi giao dịch là một lần gửi/rút tiền của pgbench: cộng số tiền ngẫu nhiên `delta` vào số dư tài khoản, giao dịch viên, chi nhánh và ghi một dòng lịch sử, tất cả trong *một* giao dịch. Thí nghiệm A và B dùng sysbench với `workload/tpcb.lua` để chạy được trên cả hai hệ; thí nghiệm C dùng công cụ riêng `workload/crash_client.py`.

=== Cấu hình nền

#figure(
  table(
    columns: (3.2cm, 1fr, 1fr),
    align: (left, left, left),
    stroke: 0.5pt,
    inset: 4.5pt,
    table.header([*Mục*], [*PostgreSQL*], [*MySQL InnoDB*]),
    [Bộ đệm dữ liệu], [`shared_buffers = 2GB`], [`innodb_buffer_pool_size = 2G`],
    [Log trước checkpoint], [`max_wal_size = 4GB`, `checkpoint_timeout = 5min`], [`innodb_redo_log_capacity = 4G`],
    [Flush log khi COMMIT], [`synchronous_commit = on`, `fsync = on`], [`innodb_flush_log_at_trx_commit = 1`],
    [Chu kỳ flush nền], [`wal_writer_delay = 200ms`], [`innodb_flush_log_at_timeout = 1`],
    [Chống rách trang], [`full_page_writes = on`], [`innodb_doublewrite = ON`],
    [Checksum trang], [Bật khi khởi tạo (`--data-checksums`)], [Mặc định (`crc32`)],
    [Binlog], [(không có)], [Tắt (`skip-log-bin`) để chỉ so sánh redo log với WAL],
    [Ghi log phục hồi], [`log_checkpoints = on`], [`log_error_verbosity = 3`],
  ),
  caption: fcap([Cấu hình nền của hai hệ.], [Cấu hình nền của hai hệ. Đây cũng là *cấu hình bền vững*; mỗi thí nghiệm chỉ thay đổi đúng tham số đang nghiên cứu.]),
) <tab-cfg>

=== Bất biến và kiểm chứng tính đúng

Gọi $A, T, B$ là tổng số dư tài khoản, giao dịch viên, chi nhánh và $H$ là tổng `delta` bảng lịch sử. Ban đầu cả bốn bằng 0, và vì mỗi giao dịch cộng cùng `delta` vào cả bốn một cách nguyên tử nên $A = T = B = H$ luôn phải đúng. Script kiểm tra được kiểm chứng hai chiều: chạy tải trả về `OK`, cố ý sửa một số dư báo ngay `FAIL`.

#figure(
  grid(
    columns: 1,
    gutter: 8pt,
    image("img/M_04_kiem_chung_duong_pg.png", width: 78%),
    image("img/M_06_kiem_chung_am_pg.png", width: 78%),
  ),
  caption: [Kiểm chứng script bất biến trên PostgreSQL: dữ liệu đúng (`OK`, trên) và cố ý làm lệch một số dư (`FAIL`, dưới).],
)

Trước mỗi lần chạy (thí nghiệm B, C) hoặc mỗi loạt (thí nghiệm A), script đưa dữ liệu về trạng thái ban đầu và dừng nếu bất biến chưa bằng 0.

=== Tóm tắt thiết kế ba thí nghiệm

#figure(
  table(
    columns: (auto, 1fr, 1fr, 1fr),
    align: (left, left, left, left),
    stroke: 0.5pt,
    inset: 4.5pt,
    table.header([], [*A – Chi phí flush log*], [*B – Chi phí bảo vệ trang*], [*C – Crash và phục hồi*]),
    [Thay đổi], [Tham số flush log (PostgreSQL on/off; InnoDB 1/2/0) và số client (1, 8, 32)], [Bảo vệ trang bật/tắt (PostgreSQL Full-Page Writes; InnoDB doublewrite); 8 client], [5 cấu hình flush × 2 mức sự cố],
    [Giữ cố định], [Bảo vệ trang bật], [Flush log chặt], [Bảo vệ trang bật, 8 luồng tải],
    [Số lần chạy], [45 (3 lần mỗi ô, đo 300 s sau 60 s warmup)], [12 (3 lần mỗi ô, đo 300 s sau 60 s warmup)], [42 lần crash],
    [Đo], [TPS, độ trễ, số fsync và byte log mỗi giao dịch], [Byte WAL, ảnh trang, byte ghi đĩa mỗi giao dịch, TPS], [Giao dịch mất, RPO, RTO, thời gian redo, bất biến, hỏng dữ liệu],
  ),
  caption: fcap([Tóm tắt thiết kế ba thí nghiệm.], [Tóm tắt thiết kế ba thí nghiệm. Tên tham số cụ thể ở @tab-cfg; thiết kế chi tiết của A và B ở @sec-expA và @sec-expB]),
)

Đo 300 giây để mỗi lần chạy chứa ít nhất một chu kỳ checkpoint (`checkpoint_timeout = 5min`). Mỗi ô báo cáo trung bình 3 lần lặp kèm hệ số biến thiên (CV).

=== Thiết kế thí nghiệm C: crash và phục hồi

Thí nghiệm C trả lời: với từng cấu hình flush và từng loại sự cố, có giao dịch *đã xác nhận COMMIT* nào bị mất không (RPO), dữ liệu có nhất quán không và phục hồi mất bao lâu (RTO). Hai mức sự cố được thử riêng vì xóa các tầng khác nhau trên đường đi của dữ liệu (@fig-path): *crash tiến trình* (`docker kill -s KILL` trên máy đo, mất bộ nhớ của DBMS, page cache còn nguyên) và *crash hệ điều hành* (`virsh destroy` máy ảo, mất thêm page cache của HĐH khách). Mất điện thật (mất cả bộ đệm ghi của ổ nếu ổ không tôn trọng lệnh flush) chỉ được phân tích lý thuyết.

*Ma trận chạy.* Năm cấu hình (PostgreSQL `on`, `off`; InnoDB `=1`, `=2`, `=0`) nhân hai mức sự cố. Cấu hình bền vững chạy 3 lần; cấu hình có thể mất dữ liệu chạy 5 lần, vì việc mất phụ thuộc thời điểm crash. Tổng cộng 2 × (3 + 5 + 3 + 5 + 5) = 42 lần crash.

*Công cụ bơm tải có nhật ký xác nhận.* `crash_client.py` chạy trên máy thật (ngoài phạm vi sự cố) với 8 luồng; mỗi giao dịch mang một `txn_id` duy nhất ghi vào bảng lịch sử. Mỗi luồng ghi ngay xuống file `txn_id` *trước* khi gửi COMMIT (nhật ký đã gửi) và *sau* khi COMMIT trả về (nhật ký đã xác nhận). Khi không có sự cố, số giao dịch đã xác nhận khớp đúng số dòng trong bảng lịch sử (24.005).

*Quy trình mỗi lần crash* (`scripts/run_expC.sh`): đặt tham số, khởi động lại DBMS, đưa dữ liệu về ban đầu (PostgreSQL chạy thêm `CHECKPOINT`); bơm tải 60–120 giây ngẫu nhiên rồi gây sự cố; khởi động lại DBMS hoặc máy ảo, thử kết nối mỗi 0,2 giây để đo thời gian sẵn sàng; lưu log phục hồi; đối soát và kiểm tra hỏng dữ liệu.

*Đối soát.* Gọi ACK là tập `txn_id` đã được xác nhận, SENT là tập đã gửi COMMIT, PRESENT là tập `txn_id` còn trong bảng lịch sử sau phục hồi. Từ đó:

#figure(
  table(
    columns: (2.9cm, 4.6cm, 1fr),
    align: (left, left, left),
    stroke: 0.5pt,
    inset: 4.5pt,
    table.header([*Chỉ số*], [*Công thức*], [*Ý nghĩa và yêu cầu*]),
    [Giao dịch bị mất], [ACK ∖ PRESENT], [Đã xác nhận với client nhưng không còn. Phải bằng 0 với cấu hình bền vững],
    [Đang dở lúc crash], [SENT ∖ ACK], [Đã gửi COMMIT nhưng chưa nhận trả lời. Có thể đã commit hoặc chưa; cả hai đều hợp lệ],
    [Giao dịch lạ], [PRESENT ∖ (ACK ∪ SENT)], [Phải bằng 0; khác 0 nghĩa là công cụ hoặc bước đưa dữ liệu về ban đầu có lỗi],
    [Khớp số dòng], [`COUNT(*)` = \|PRESENT\|], [Bảng lịch sử chỉ chứa giao dịch của lần chạy này],
    [RPO theo thời gian], [lần xác nhận cuối cùng − lần xác nhận sớm nhất trong số giao dịch bị mất], [Độ dài khoảng thời gian có giao dịch đã xác nhận bị mất; 0 nếu không mất],
    [RTO theo log DBMS], [từ dòng khởi động đầu tiên đến dòng sẵn sàng nhận kết nối trong log], [Chỉ tính DBMS; dùng khi so sánh các cấu hình],
    [Thời gian redo], [PostgreSQL: thời gian ghi ở dòng `redo done at`. InnoDB: từ dòng `Starting crash recovery` đến `Apply batch completed`], [Phần phát lại log trong RTO],
  ),
  caption: [Định nghĩa các chỉ số của thí nghiệm C (`scripts/reconcile.py`, `scripts/parse_recovery_log.py`).],
)

*Kiểm tra hỏng dữ liệu:* PostgreSQL chạy `bt_index_check` (`amcheck`), đọc toàn bộ bảng để kiểm tra checksum trang; MySQL chạy `CHECK TABLE` trên bốn bảng.

