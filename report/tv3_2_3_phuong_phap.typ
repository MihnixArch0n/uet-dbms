// ============================================================
// MỤC 2.3: PHƯƠNG PHÁP THỰC NGHIỆM (TV3 viết phần chung và thiết kế thí nghiệm C)
// Thay toàn bộ mục "== Phương pháp thực nghiệm (tóm tắt phần liên quan đến A)"
// trong bản nháp của TV1 bằng:
//   #include "tv3_2_3_phuong_phap.typ"
// Ảnh dùng trong mục: img/M_01, M_02, M_03, M_04, M_06, M_08
// ============================================================

#let shot(path, cap, w: 100%) = figure(image(path, width: w), caption: cap)
// Bảng: chữ nhỏ hơn, không căn đều hai bên (tránh khoảng trắng giãn trong ô hẹp)
#show table: set text(size: 9.5pt)
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
    inset: 6pt,
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

Con số fsync ở bảng B1 là giới hạn trên của thông lượng khi chỉ có một client và mỗi COMMIT phải chờ một lần fsync. Nó được dùng để giải thích kết quả thí nghiệm A (mục 2.4).

#shot("img/M_01_pg_test_fsync.png", [Tốc độ đồng bộ đĩa của máy đo theo `pg_test_fsync`.], w: 85%)

*Máy ảo cho crash hệ điều hành.* Mức sự cố thứ hai của thí nghiệm C cần tắt ngang cả hệ điều hành đang chạy DBMS, nên hai hệ được đặt trong một máy ảo trên chính máy đo. Nhóm dự kiến dùng VirtualBox, nhưng mô-đun nhân của VirtualBox không biên dịch được với kernel 7.0 khi Secure Boot đang bật, nên chuyển sang KVM/QEMU quản lý bằng libvirt. KVM có sẵn trong nhân Linux và có một ưu điểm cho thí nghiệm: lệnh flush của máy ảo được chuyển xuống đĩa của máy thật, nên dữ liệu đã fsync trong máy ảo thực sự nằm trên đĩa.

#figure(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: 0.5pt,
    inset: 6pt,
    table.header([*Thành phần*], [*Cấu hình*]),
    [Ảo hóa], [KVM/QEMU, quản lý bằng libvirt],
    [Tài nguyên], [4 vCPU, 8 GB RAM, đĩa ảo qcow2 40 GB đặt trên cùng ổ SSD của máy đo],
    [Hệ điều hành khách], [Ubuntu Server 24.04 LTS],
    [Hệ quản trị], [Cùng image Docker và cùng file cấu hình như trên máy đo; container tự khởi động lại khi máy ảo bật (`restart: always`)],
    [Gây sự cố / bật lại], [`virsh destroy dbvm` (ngắt nguồn đột ngột) / `virsh start dbvm`],
  ),
  caption: [Máy ảo dùng cho mức sự cố hệ điều hành, bảng B1b.],
)

#shot("img/M_02_vm_crash_recovery.png", [Sau khi máy ảo bị ngắt nguồn và bật lại, hai container tự khởi động, PostgreSQL phát hiện lần tắt không sạch và tự phục hồi (phát lại khoảng 640 MB WAL trong 2,76 giây).])

=== Dữ liệu

Dữ liệu là lược đồ ngân hàng của pgbench (chuẩn TPC-B) với hệ số scale 50: 50 chi nhánh, 500 giao dịch viên, 5.000.000 tài khoản, cùng bảng lịch sử giao dịch ban đầu rỗng. Bảng lịch sử có thêm cột `txn_id` để đối soát ở thí nghiệm C. Dữ liệu được sinh một lần trong PostgreSQL bằng `pgbench -i -s 50`, xuất ra CSV và nạp nguyên vẹn sang MySQL, nên hai hệ chứa đúng cùng một bộ dữ liệu (khoảng 755 MB trong PostgreSQL và 603 MB trong MySQL). Với bộ đệm 2 GB mỗi hệ, toàn bộ dữ liệu nằm gọn trong bộ nhớ, nên chi phí đo được chủ yếu là chi phí ghi log và ghi trang chứ không phải đọc dữ liệu.

#shot("img/M_03_doi_chieu_du_lieu.png", [Đối chiếu dữ liệu hai hệ sau khi nạp: số dòng và các tổng khóa giống hệt nhau, bất biến ban đầu bằng 0 trên cả hai hệ.])

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
    inset: 6pt,
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

Gọi $A$ là tổng số dư tài khoản, $T$ là tổng số dư giao dịch viên, $B$ là tổng số dư chi nhánh và $H$ là tổng `delta` trong bảng lịch sử.

1. *Trạng thái ban đầu:* sau khi sinh dữ liệu, $A = T = B = H = 0$. Điều này được kiểm tra bằng truy vấn và lưu lại (hình đối chiếu dữ liệu ở phần Dữ liệu), không giả định.
2. *Logic giao dịch:* mỗi giao dịch cộng cùng một `delta` vào cả bốn đại lượng, trong một giao dịch duy nhất.
3. *Hệ quả:* nếu mọi giao dịch hoặc được áp dụng toàn bộ, hoặc không được áp dụng gì (tính nguyên tử), thì $A = T = B = H$ luôn đúng. Một giao dịch chỉ được ghi một phần sẽ làm lệch các tổng.
4. *Giới hạn:* bất biến không phát hiện được việc mất trọn vẹn một giao dịch, vì khi đó bốn tổng vẫn bằng nhau. Việc phát hiện mất giao dịch do bước đối soát của thí nghiệm C đảm nhận.

Script kiểm tra bất biến được kiểm chứng theo hai chiều trên máy đo. *Kiểm chứng dương:* sau 60 giây chạy workload, bốn tổng bằng nhau và số dòng lịch sử bằng đúng số giao dịch sysbench báo. *Kiểm chứng âm:* cố ý sửa số dư của một tài khoản thì script báo `FAIL`. Hai kiểm chứng này được làm cho cả PostgreSQL (hình dưới) và MySQL.

#figure(
  grid(
    columns: 1,
    gutter: 10pt,
    image("img/M_04_kiem_chung_duong_pg.png", width: 100%),
    image("img/M_06_kiem_chung_am_pg.png", width: 100%),
  ),
  caption: [Kiểm chứng script bất biến trên PostgreSQL. Trên: dữ liệu đúng sau khi chạy tải (`OK`). Dưới: cố ý làm lệch một số dư (`FAIL`), rồi đưa dữ liệu về trạng thái ban đầu.],
)

Trước mỗi lần chạy, script đưa dữ liệu về trạng thái ban đầu (xóa bảng lịch sử, đưa mọi số dư về 0) và dừng lại nếu bất biến chưa phải `0|0|0|0|0`.

=== Tóm tắt thiết kế ba thí nghiệm

#figure(
  table(
    columns: (auto, 1fr, 1fr, 1fr),
    align: (left, left, left, left),
    stroke: 0.5pt,
    inset: 6pt,
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
    inset: 6pt,
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

Công cụ được kiểm chứng khi không có sự cố: sau 30 giây chạy, số giao dịch đã xác nhận đúng bằng số dòng có `txn_id` trong bảng lịch sử, và bất biến đúng (hình dưới).

#shot("img/M_08_kiem_chung_crash_client.png", [Kiểm chứng công cụ đối soát khi không crash: 24.005 giao dịch đã xác nhận, 24.005 dòng trong bảng lịch sử, bất biến `OK`.])

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
    inset: 6pt,
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
    inset: 6pt,
    table.header([*Nhận xét*], [*Cách xử lý trong thiết kế*]),
    [1. Phân biệt crash tiến trình, crash hệ điều hành và mất điện], [Kill tiến trình không xóa page cache của hệ điều hành: dữ liệu đã `write()` nhưng chưa `fsync()` vẫn còn, nên không chứng minh được việc mất giao dịch do chưa flush. Thí nghiệm C có hai mức tách riêng: kill tiến trình DBMS, và ngắt nguồn máy ảo chạy DBMS (mất page cache của hệ điều hành khách). Mất điện thật, liên quan bộ đệm ghi của ổ đĩa, được nêu là giới hạn và giải thích bằng lý thuyết.],
    [2. Bất biến cần được định nghĩa, kiểm chứng bằng script, và cần đối soát số giao dịch thành công], [Bất biến được định nghĩa hình thức, trạng thái ban đầu được kiểm tra bằng truy vấn, script được kiểm chứng cả chiều dương lẫn chiều âm. Vì bất biến không phát hiện được việc mất trọn vẹn giao dịch, mỗi giao dịch mang mã `txn_id` và client ghi nhật ký các mã đã được xác nhận; sau crash, nhật ký được đối soát với bảng lịch sử để đếm chính xác số giao dịch bị mất.],
    [3. Tách thí nghiệm flush log khỏi thí nghiệm bảo vệ trang; xác định cấu hình bền vững và cách đo RTO/RPO], [Thí nghiệm A chỉ đổi tham số flush, giữ bảo vệ trang bật; thí nghiệm B chỉ đổi bảo vệ trang, giữ flush chặt. Cấu hình bền vững được định nghĩa ở bảng B2. RPO và RTO được định nghĩa bằng công thức ở bảng trên và đo cho từng lần crash.],
  ),
  caption: [Đối chiếu nhận xét của giảng viên với thiết kế thí nghiệm.],
)
