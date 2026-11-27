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
#show table: set par(justify: false)

== Phương pháp thực nghiệm

Mục này mô tả những gì dùng chung cho cả ba thí nghiệm: máy đo, dữ liệu, workload, cách kiểm chứng tính đúng, và thiết kế chi tiết của thí nghiệm C. Thiết kế thí nghiệm A và B được trình bày ngắn ở đây và chi tiết hơn trong mục kết quả tương ứng (2.4 và 2.5). Mọi lệnh và script nằm trong repo của nhóm; báo cáo chỉ giải thích cách làm và lý do.

=== Máy đo và môi trường

Tất cả số liệu chính thức được đo trên *một máy duy nhất*, cùng phiên bản phần mềm và cùng cấu hình, để số liệu của ba thí nghiệm so sánh được với nhau. Hai hệ quản trị chạy trong Docker với cùng giới hạn tài nguyên (4 CPU, 6 GB RAM mỗi container); trong mỗi lần đo chỉ một hệ được bật để hai hệ không tranh tài nguyên.

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
  caption: [Cấu hình máy đo, bảng B1 (chép từ `results/env/hardware.txt`).],
)

Con số fsync ở bảng B1 là giới hạn trên của thông lượng khi chỉ có 1 client và mỗi COMMIT phải chờ một lần fsync, dùng để giải thích kết quả thí nghiệm A (mục 2.4).

*Máy ảo cho crash hệ điều hành.* Để tắt ngang cả hệ điều hành đang chạy DBMS, hai hệ được đặt trong máy ảo KVM/QEMU (quản lý bằng `libvirt`, do VirtualBox không biên dịch được mô-đun nhân trên kernel 7.0 khi bật Secure Boot). Lệnh flush của máy ảo KVM được chuyển thẳng xuống đĩa máy thật nên dữ liệu đã `fsync` thực sự nằm trên đĩa.

#figure(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: 0.5pt,
    inset: 4.5pt,
    table.header([*Thành phần*], [*Cấu hình*]),
    [Ảo hóa], [KVM/QEMU, quản lý bằng libvirt],
    [Tài nguyên], [4 vCPU, 8 GB RAM, đĩa ảo qcow2 40 GB đặt trên cùng ổ SSD của máy đo],
    [Hệ điều hành khách], [Ubuntu Server 24.04 LTS],
    [Hệ quản trị], [Cùng image Docker và cùng file cấu hình như trên máy đo; container tự khởi động lại khi máy ảo bật (`restart: always`)],
    [Gây sự cố / bật lại], [`virsh destroy dbvm` (ngắt nguồn đột ngột) / `virsh start dbvm`],
  ),
  caption: [Máy ảo dùng cho mức sự cố hệ điều hành, bảng B1b.],
)

=== Dữ liệu

Dữ liệu là lược đồ ngân hàng của pgbench (chuẩn TPC-B, scale 50): 50 chi nhánh, 500 giao dịch viên, 5.000.000 tài khoản, cùng bảng lịch sử ban đầu rỗng (thêm cột `txn_id` để đối soát ở thí nghiệm C). Dữ liệu sinh một lần trong PostgreSQL bằng `pgbench -i -s 50`, xuất CSV và nạp nguyên vẹn sang MySQL (~755 MB trong PostgreSQL, ~603 MB trong MySQL), đối chiếu số dòng và các tổng ban đầu bằng 0 trên cả hai hệ. Với bộ đệm 2 GB mỗi hệ, toàn bộ dữ liệu nằm gọn trong bộ nhớ nên chi phí đo được chủ yếu là ghi log và ghi trang.

=== Workload

Mỗi giao dịch mô phỏng một lần gửi hoặc rút tiền theo đúng giao dịch mặc định của pgbench: chọn ngẫu nhiên một tài khoản, một giao dịch viên, một chi nhánh và số tiền `delta` trong khoảng từ −5000 đến 5000; cộng `delta` vào ba số dư; đọc lại số dư tài khoản; ghi một dòng vào bảng lịch sử. Năm câu lệnh này nằm trong *một* giao dịch.

- Thí nghiệm A và B đo hiệu năng, nên dùng sysbench với script `workload/tpcb.lua` để cùng một công cụ chạy được trên cả hai hệ.
- Thí nghiệm C cần biết chính xác giao dịch nào đã được xác nhận, nên dùng công cụ riêng `workload/crash_client.py` (mô tả ở phần thiết kế thí nghiệm C).

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
  caption: [Cấu hình nền của hai hệ, bảng B2. Đây cũng là *cấu hình bền vững*; mỗi thí nghiệm chỉ thay đổi đúng tham số đang nghiên cứu.],
)

=== Bất biến và kiểm chứng tính đúng

Gọi $A, T, B$ là tổng số dư tài khoản, giao dịch viên, chi nhánh và $H$ là tổng `delta` bảng lịch sử. Ban đầu $A = T = B = H = 0$ (kiểm tra bằng truy vấn). Vì mỗi giao dịch cộng cùng một `delta` vào cả bốn đại lượng trong một giao dịch nguyên tử, bất biến $A = T = B = H$ luôn đúng (riêng mất trọn vẹn giao dịch được phát hiện qua đối soát ở thí nghiệm C). Script kiểm tra đã được kiểm chứng hai chiều trên cả PostgreSQL (hình dưới) và MySQL: chạy tải 60 giây trả về `OK`, cố ý sửa một số dư báo ngay `FAIL`.

#figure(
  grid(
    columns: 2,
    gutter: 8pt,
    image("img/M_04_kiem_chung_duong_pg.png", width: 94%),
    image("img/M_06_kiem_chung_am_pg.png", width: 94%),
  ),
  caption: [Kiểm chứng script bất biến trên PostgreSQL: dữ liệu đúng (`OK`, trái) và cố ý làm lệch một số dư (`FAIL`, phải).],
)

Ở thí nghiệm B và C, trước mỗi lần chạy, script đưa dữ liệu về trạng thái ban đầu (xóa bảng lịch sử, đưa mọi số dư về 0) và dừng lại nếu bất biến chưa phải `0|0|0|0|0`. Ở thí nghiệm A việc này chỉ làm một lần trước mỗi loạt (mỗi DBMS), nên dữ liệu tích lũy qua các lần chạy trong loạt (mục 2.4).

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
  caption: [Tóm tắt thiết kế ba thí nghiệm. Tên tham số cụ thể ở bảng B2; thiết kế chi tiết của A và B ở mục 2.4 và 2.5.],
)

Thời gian đo 300 giây được chọn để mỗi lần chạy chứa ít nhất một chu kỳ checkpoint (`checkpoint_timeout = 5min`). Nếu đo ngắn hơn, có lần chạy có checkpoint, có lần không, và số liệu sẽ lệch. Với mỗi ô, nhóm báo cáo giá trị trung bình của 3 lần lặp kèm hệ số biến thiên (CV); ô nào có CV trên 10% được ghi chú trong phần kết quả.

=== Thiết kế thí nghiệm C: crash và phục hồi

Câu hỏi: với từng cấu hình flush và từng loại sự cố, có giao dịch *đã được xác nhận COMMIT* nào bị mất không (RPO), dữ liệu có còn nhất quán không, và phục hồi mất bao lâu (RTO)?

*Hai mức sự cố.* Mỗi loại sự cố xóa một số tầng khác nhau trên đường đi của dữ liệu (mục 2.1), nên được thử riêng:

#figure(
  table(
    columns: (2.6cm, 1fr, 1fr, 2.6cm),
    align: (left, left, left, left),
    stroke: 0.5pt,
    inset: 4.5pt,
    table.header([*Mức*], [*Cách gây sự cố*], [*Dữ liệu bị xóa*], [*Chạy trên*]),
    [1. Crash tiến trình], [`docker kill -s KILL` container DBMS khi đang có tải], [Bộ nhớ của DBMS (bộ đệm, WAL buffers, log buffer). Page cache của hệ điều hành còn nguyên], [Máy đo],
    [2. Crash hệ điều hành], [Ngắt nguồn máy ảo (`virsh destroy`) khi đang có tải], [Thêm page cache của hệ điều hành khách: dữ liệu đã `write()` nhưng chưa `fsync()`], [Máy ảo KVM],
    [3. Mất điện thật], [Không thực hiện], [Thêm bộ đệm ghi của ổ đĩa nếu ổ không tôn trọng lệnh flush], [Chỉ phân tích lý thuyết],
  ),
  caption: [Ba mức sự cố và phạm vi thí nghiệm.],
)

*Ma trận chạy.* Năm cấu hình (PostgreSQL `on`, `off`; InnoDB `=1`, `=2`, `=0`) nhân hai mức sự cố. Cấu hình bền vững chạy 3 lần; cấu hình có thể mất dữ liệu chạy 5 lần, vì việc mất phụ thuộc thời điểm crash. Tổng cộng 2 × (3 + 5 + 3 + 5 + 5) = 42 lần crash.

*Công cụ bơm tải có nhật ký xác nhận.* sysbench không cho biết giao dịch nào đã được xác nhận, nên nhóm viết `workload/crash_client.py`, chạy trên máy thật (ngoài phạm vi sự cố) với 8 luồng. Mỗi giao dịch mang một mã `txn_id` duy nhất, được ghi vào bảng lịch sử cùng với giao dịch. Mỗi luồng ghi hai nhật ký, ghi từng dòng xuống file ngay lập tức:

- nhật ký *đã gửi*: `txn_id` ngay *trước* khi gửi COMMIT;
- nhật ký *đã xác nhận*: `txn_id` và thời điểm ngay *sau* khi COMMIT trả về thành công.

Công cụ được kiểm chứng khi không có sự cố: sau 30 giây chạy, số giao dịch đã xác nhận đúng bằng số dòng có `txn_id` trong bảng lịch sử (24.005 giao dịch), và bất biến `OK`.

*Quy trình mỗi lần crash* (`scripts/run_expC.sh`):

1. Đặt tham số flush, khởi động lại DBMS, đưa dữ liệu về trạng thái ban đầu và xác nhận bất biến bằng 0; với PostgreSQL chạy thêm `CHECKPOINT` để mọi lần có cùng điểm xuất phát.
2. Chạy công cụ bơm tải 8 luồng trong một khoảng ngẫu nhiên từ 60 đến 120 giây, rồi gây sự cố và ghi thời điểm $t_"crash"$.
3. Khởi động lại DBMS (mức 1) hoặc bật lại máy ảo (mức 2), ghi thời điểm ra lệnh $t_"start"$.
4. Thử kết nối mỗi 0,2 giây; lần đầu thành công ghi $t_"ready"$.
5. Lưu log của DBMS ở lần khởi động này, đọc các mốc phục hồi.
6. Đối soát, kiểm tra bất biến và kiểm tra hỏng dữ liệu.

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
    [RTO (máy thật)], [$t_"ready" - t_"start"$], [Ở mức 2 bao gồm cả thời gian máy ảo khởi động],
    [RTO theo log DBMS], [từ dòng khởi động đầu tiên đến dòng sẵn sàng nhận kết nối trong log], [Chỉ tính DBMS; dùng khi so sánh các cấu hình],
    [Thời gian redo], [PostgreSQL: thời gian ghi ở dòng `redo done at`. InnoDB: từ dòng `Starting crash recovery` đến `Apply batch completed`], [Phần phát lại log trong RTO],
  ),
  caption: [Định nghĩa các chỉ số của thí nghiệm C (`scripts/reconcile.py`, `scripts/parse_recovery_log.py`).],
)

*Kiểm tra hỏng dữ liệu.* Với PostgreSQL: chạy `bt_index_check` (extension `amcheck`) trên các chỉ mục khóa chính, đọc toàn bộ bảng để mọi checksum trang được kiểm tra, và tìm lỗi checksum trong log. Với MySQL: `CHECK TABLE` trên cả bốn bảng.

=== Cách nhóm xử lý ba nhận xét của giảng viên

#figure(
  table(
    columns: (4.2cm, 1fr),
    align: (left, left),
    stroke: 0.5pt,
    inset: 5pt,
    table.header([*Nhận xét*], [*Cách xử lý trong thiết kế*]),
    [1. Phân biệt crash tiến trình, HĐH và mất điện], [Thí nghiệm C tách 2 mức: `docker kill` (còn page cache) và `virsh destroy` máy ảo KVM (mất page cache). Mất điện thật (bộ đệm ổ đĩa) nêu trong giới hạn và giải thích lý thuyết.],
    [2. Định nghĩa/kiểm chứng bất biến & đối soát giao dịch], [Định nghĩa $A = T = B = H$, kiểm chứng script hai chiều (`OK`/`FAIL`), và gán `txn_id` ghi nhật ký client để đối soát chính xác giao dịch mất sau crash.],
    [3. Tách thí nghiệm flush khỏi bảo vệ trang; rõ cấu hình bền vững & RPO/RTO], [Thí nghiệm A chỉ đổi flush (giữ bảo vệ trang), B chỉ đổi bảo vệ trang (giữ flush chặt). Cấu hình bền vững (bảng B2) và công thức RPO/RTO đo cho từng lần crash.],
  ),
  caption: [Đối chiếu nhận xét của giảng viên với thiết kế thí nghiệm.],
)
