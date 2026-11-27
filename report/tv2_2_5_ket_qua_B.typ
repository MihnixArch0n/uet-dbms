// ============================================================
// MỤC 2.5 (phần của TV2): KẾT QUẢ THÍ NGHIỆM B & KIỂM CHỨNG MYSQL
// Chèn vào báo cáo chính giữa mục 2.4 (Kết quả A) và mục 2.6 (Kết quả C):
//   #include "tv2_2_5_ket_qua_B.typ"
// Ảnh dùng trong mục:
//   img/M_05_kiem_chung_duong_mysql.png, img/M_07_kiem_chung_am_mysql.png,
//   img/H6_page_protection_cost.png, img/H7_wal_rate.png,
//   img/H8_wal_composition.png, img/R_B1_waldump_on_off.png
// ============================================================

#let shot(path, cap, w: 100%) = figure(image(path, width: w), caption: cap)
#show table: set text(size: 9.5pt)
#show table: set par(justify: false)

== Kết quả thí nghiệm B

Thí nghiệm B đo riêng chi phí hiệu năng và chi phí ghi dữ liệu của cơ chế bảo vệ chống rách trang ở cả hai hệ quản trị, trong khi giữ cố định cơ chế flush log ở cấu hình bền vững (`synchronous_commit = on` trên PostgreSQL và `innodb_flush_log_at_trx_commit = 1` trên MySQL InnoDB). Trước khi chạy đo chính thức, nhóm thực hiện kiểm chứng tính đúng đắn của script bất biến trên MySQL (tương tự kiểm chứng trên PostgreSQL ở mục 2.3).

=== Kiểm chứng bất biến trên MySQL (D1)

Hàm `check_invariant` (gọi `scripts/invariant.sql`) xuất kết quả gồm 6 trường phân cách bởi dấu `|`: `<trạng_thái>|<SUM(abalance)>|<SUM(tbalance)>|<SUM(bbalance)>|<SUM(delta)>|<COUNT(*)>`, trong đó 4 giá trị ở giữa là tổng số dư của 3 bảng tài khoản/giao dịch viên/chi nhánh và tổng `delta` trong bảng lịch sử `pgbench_history`, còn trường cuối là tổng số dòng của bảng lịch sử.

- *Kiểm chứng dương (D1.1):* Chạy tải giao dịch TPC-B bằng sysbench với 8 client trong 60 giây trên MySQL ở trạng thái sạch (`A = T = B = H = 0` sau `reset_state.sql`). Kết quả ghi nhận `70.756` giao dịch (`1.179,09 TPS`), `ignored errors: 0`, và hàm kiểm tra bất biến trả về `OK|-107122|-107122|-107122|-107122|70756`. Do mỗi giao dịch cộng một lượng `delta` ngẫu nhiên trong `[-5000, +5000]` trên nền khởi tạo bằng `0`, tổng tích lũy sau `70.756` giao dịch mang giá trị âm (`-107.122`); bốn tổng khớp nhau tuyệt đối và số dòng lịch sử trùng khớp chính xác với số giao dịch của sysbench.
- *Kiểm chứng âm (D1.2):* Cố tình cộng lệch `+1` vào `abalance` của tài khoản `aid = 1` ngoài giao dịch TPC-B, làm riêng `SUM(abalance)` tăng từ `-107122` lên `-107121` trong khi ba tổng còn lại giữ nguyên. Script kiểm tra lập tức phát hiện sai lệch và báo `FAIL|-107121|-107122|-107122|-107122|70756`. Sau khi chạy `reset_state.sql`, kiểm tra lại trả về `OK|0|0|0|0|0`.

#figure(
  grid(
    columns: 1,
    gutter: 8pt,
    image("img/M_05_kiem_chung_duong_mysql.png", width: 100%),
    image("img/M_07_kiem_chung_am_mysql.png", width: 100%),
  ),
  caption: [Kiểm chứng bất biến bốn tổng trên MySQL. Trên (D1.1): `70.756` giao dịch, `ignored errors: 0`, bất biến `OK`. Dưới (D1.2): phát hiện sai lệch `+1` (`FAIL`) và trở về `OK|0|0|0|0|0` sau khi reset.],
)

=== Thiết kế và bảng kết quả thí nghiệm B

Mỗi hệ quản trị được đo ở 2 cấu hình bật và tắt bảo vệ trang (`full_page_writes` `on`/`off` trên PostgreSQL; `innodb_doublewrite` `ON`/`OFF` trên MySQL InnoDB), cố định `8` client, `60` giây làm nóng (warmup) và `300` giây đo chính thức, lặp lại `3` lần cho mỗi cấu hình (tổng cộng 12 lần chạy, tổng hợp trong `results/B_summary.csv`). Cả 12/12 lần chạy đều vượt qua kiểm tra bất biến với trạng thái `OK` và không ghi nhận lỗi giao dịch (`errors = 0`).

#figure(
  {
    set text(size: 8.5pt)
    table(
      columns: (auto, auto, auto, auto, auto, auto, auto, auto),
      align: (left, center, center, center, center, center, center, center),
      stroke: 0.5pt,
      inset: 4.5pt,
      table.header(
        [*Cấu hình*], [*TPS (CV)*], [*p50 (ms)*], [*p95 (ms)*], [*p99 (ms)*],
        [*Log / txn (B)*], [*Bảo vệ / txn (B)*], [*Ghi đĩa / txn (B)*]
      ),
      [PG `fpw = on`], [1.294 (17,0%)], [4,82], [9,74], [33,8], [2.280,5], [1.871,4 (FPI)], [5.882,6],
      [PG `fpw = off`], [1.170 (4,0%)], [4,82], [10,44], [46,4], [401,7], [0,0], [3.998,4],
      [MySQL `dblwr = ON`], [703 (20,2%)], [6,91], [23,83], [72,3], [1.068,6], [10.945,0 (dblwr)], [24.749,0],
      [MySQL `dblwr = OFF`], [884 (17,1%)], [6,91], [14,50], [63,1], [1.071,4], [0,0], [13.723,6],
    )
  },
  caption: [Tổng hợp kết quả thí nghiệm B (8 client, 300 giây, trung bình 3 lần lặp; dữ liệu từ `results/B_summary.csv`). Cột *Bảo vệ / txn* là dung lượng FPI trong WAL với PostgreSQL và dung lượng ghi qua doublewrite với MySQL; cột *Ghi đĩa / txn* là tổng lượng ghi tầng thiết bị khối đo bằng `iostat` (gồm log, doublewrite, trang dữ liệu và metadata hệ file) chia cho số giao dịch.],
)

=== Hình ảnh kết quả

#shot("img/H6_page_protection_cost.png", [H6 – Chi phí bảo vệ trang: lượng ghi trên mỗi giao dịch (KB/giao dịch) tách theo thành phần giữa PostgreSQL và MySQL InnoDB.])

#shot("img/H7_wal_rate.png", [H7 – Tốc độ sinh WAL theo thời gian ở PostgreSQL (`r1`): đỉnh tăng vọt ngay sau checkpoint thủ công trước warmup và sau checkpoint định kỳ ở giây ~240 (`checkpoint_timeout = 5min`).])

#shot("img/H8_wal_composition.png", [H8 – Thành phần bản ghi WAL theo `pg_waldump`: FPI chiếm 82% tổng dung lượng WAL khi `full_page_writes = on` và bằng 0% khi `off`.], w: 88%)

#shot("img/R_B1_waldump_on_off.png", [Ảnh chụp đầu ra `pg_waldump` trên lần chạy `r1` của PostgreSQL khi bật (`on`, trên) và tắt (`off`, dưới) `full_page_writes`.], w: 92%)

=== Phân tích

*1. Chi phí dung lượng WAL của Full-Page Writes rất lớn (gấp 5,68 lần).* Khi bật `full_page_writes`, lượng WAL sinh ra trên mỗi giao dịch của PostgreSQL đạt trung bình `2.280,5 B/txn`, trong khi khi tắt chỉ còn `401,7 B/txn`. Theo phân tích chi tiết từ `pg_waldump` (`results/B_waldump.csv` và hình H8), riêng phần ảnh trang đầy đủ (FPI) chiếm `1.871,4 B/txn` — tương đương *82,1%* tổng dung lượng WAL khi bật. Kéo theo đó, tổng lượng ghi xuống ổ đĩa đo bằng `iostat` tăng từ `3.998,4 B/txn` lên `5.882,6 B/txn` (+47,1%). Kết quả này cũng giải thích hiện tượng biến động byte log theo thời gian/lần chạy ở PostgreSQL trong thí nghiệm A (mục 2.4).

*2. Tốc độ sinh WAL tạo đỉnh rõ rệt sau mỗi checkpoint.* Hình H7 cho thấy đường biểu diễn của `full_page_writes = off` gần như đi ngang ổn định quanh mức ~`0,6 MB/s` suốt 300 giây đo. Ngược lại, khi `full_page_writes = on`, tốc độ sinh WAL đạt đỉnh `13,5 MB/s` ở đầu giai đoạn đo (ngay sau checkpoint thủ công và warmup) rồi nhanh chóng giảm về mức nền ~`0,6 MB/s` sau khoảng 40–50 giây khi hầu hết các trang nóng (`pgbench_branches`, `pgbench_tellers` và các trang mục lục/chỉ mục hay cập nhật) đã được ghi FPI ít nhất một lần. Đến khoảng giây `240`, ngay khi `checkpoint_timeout = 5min` kích hoạt checkpoint định kỳ, tốc độ WAL lập tức vọt lên lại mức ~`10,1 MB/s`. Chu kỳ lặp lại này chứng minh cơ chế chỉ ghi FPI ở lần sửa đầu sau mỗi checkpoint.

*3. Ảnh hưởng phụ từ checksum và `XLOG/FPI_FOR_HINT`.* Do cụm PostgreSQL của nhóm được khởi tạo với `--data-checksums`, mọi cập nhật hint bits trên trang sau checkpoint đều phải ghi FPI. Theo thống kê `pg_waldump` trong `results/B_waldump.csv`, tổng dung lượng bản ghi `XLOG/FPI_FOR_HINT` trong một đợt chạy 300 giây khi `full_page_writes = on` dao động từ `4,87 MB` (`4.867.648` byte ở `r1`, khớp ảnh chụp `R_B1`) đến `87,15 MB` (`87.154.118` byte ở `r3`), trong khi khi `off` chỉ ghi phần record nhỏ (`0,21 MB`–`0,81 MB`). Điều này cho thấy việc bật checksum dữ liệu làm khuếch đại thêm dung lượng WAL khi kết hợp với Full-Page Writes.

*4. Chi phí I/O ghi kép của Doublewrite Buffer ở MySQL InnoDB.* Ở MySQL, bật hay tắt `innodb_doublewrite` hầu như không làm thay đổi dung lượng redo log (`1.068,6 B/txn` khi `ON` so với `1.071,4 B/txn` khi `OFF`), vì doublewrite hoạt động trên tầng ghi trang bẩn chứ không nhúng trang vào redo log. Tuy nhiên, khi bật `ON`, lượng ghi qua vùng doublewrite đạt `10.945,0 B/txn` — gần như bằng đúng lượng ghi trang vào tablespace (`10.948,3 B/txn`). Nhờ bỏ được lượt ghi đệm này khi chuyển sang `OFF`, tổng lượng ghi đĩa thực tế (`iostat`) giảm từ `24.749,0 B/txn` xuống còn `13.723,6 B/txn` (giảm *44,5%*). So sánh chéo giữa hai hệ trên cùng workload 8 client (hình H6), tổng ghi đĩa thực tế trên mỗi giao dịch của InnoDB ở cấu hình bền vững (`24,7 KB/txn`) cao hơn khoảng *4,2 lần* so với PostgreSQL (`5,9 KB/txn`) do kích thước trang 16 KB lớn gấp đôi và cơ chế ghi mọi trang bẩn qua doublewrite mỗi lần flush.

*5. Tác động lên thông lượng (TPS), độ trễ và độ tin cậy số liệu.* Ở mức tải 8 client với cấu hình flush log chặt, nút thắt hiệu năng chính vẫn là độ trễ `fsync` của mỗi lần COMMIT (đã chỉ ra ở thí nghiệm A), nên tác động của bảo vệ trang lên TPS không lớn bằng tác động lên dung lượng ghi đĩa:
- Với MySQL, tắt `innodb_doublewrite` giúp TPS trung bình tăng từ `703` lên `884 TPS` (+25,8%) và p99 giảm từ `72,3 ms` xuống `63,1 ms`.
- Với PostgreSQL, p50 giữ nguyên `4,82 ms`, còn TPS trung bình của `on` (`1.294 TPS`) thậm chí nhỉnh hơn `off` (`1.170 TPS`) do lần chạy `B_pg_on_c8_r1` đạt `1.547,5 TPS` (trong khi `r2` và `r3` đạt `1.189,3` và `1.145,4 TPS`).
- *Lưu ý độ tin cậy:* 3 trên 4 ô của thí nghiệm B có hệ số biến thiên CV cao (`17,0%` với PG `on`; `20,2%` và `17,1%` với MySQL `ON`/`OFF`), phản ánh dao động hiệu năng của ổ SSD gắn ngoài qua USB 3 khi phải gánh cả ghi trang và `fsync` đồng thời. Do đó, các con số chênh lệch về TPS và p99 chỉ mang tính tham khảo định hướng; kết luận vững chắc nhất của thí nghiệm B nằm ở chi phí ghi log/ghi đĩa (`5,68×` dung lượng WAL ở PostgreSQL và `44,5%` tổng ghi đĩa ở MySQL), vốn ổn định qua các lần lặp.

// ============================================================
// GỢI Ý CHO MỤC 2.7 (TV1 tổng hợp) – TV2 góp ý, không in ra
// ------------------------------------------------------------
// - Bảo vệ chống rách trang có chi phí ghi dữ liệu rõ rệt nhưng là đánh đổi bắt buộc cho
//   hệ thống giao dịch quan trọng: tắt full_page_writes hoặc innodb_doublewrite không làm
//   mất giao dịch trong điều kiện bình thường, nhưng để lại nguy cơ hỏng trang không phục
//   hồi được khi crash OS hoặc mất điện.
// - PostgreSQL trả giá bằng dung lượng WAL (tăng 5,68×, FPI chiếm ~82% WAL và tạo đỉnh
//   sau mỗi checkpoint); do đó tăng checkpoint_timeout / max_wal_size giúp giảm tần suất
//   ghi FPI, đánh đổi với thời gian redo (RTO) dài hơn ở thí nghiệm C.
// - MySQL InnoDB trả giá bằng lượng ghi đĩa qua doublewrite (~10,9 KB/txn, chiếm ~44,5%
//   tổng ghi đĩa thực tế); trong thực tế có thể đặt innodb_doublewrite_dir trên ổ đĩa
//   nhanh riêng biệt hoặc cân nhắc lưu trữ hỗ trợ ghi nguyên tử.
// - Ở cấu hình flush log chặt (8 client), nút thắt TPS chủ yếu vẫn nằm ở fsync lúc COMMIT
//   (thí nghiệm A) hơn là ở cơ chế bảo vệ trang.
//
// TÀI LIỆU THAM KHẢO BỔ SUNG (đưa vào danh sách chung):
// - PostgreSQL Global Development Group. PostgreSQL 16 Documentation –
//   Write Ahead Log (full_page_writes, wal_log_hints).
//   https://www.postgresql.org/docs/16/runtime-config-wal.html
// - Oracle Corporation. MySQL 8.4 Reference Manual – 17.6.4 Doublewrite Buffer
//   (innodb_doublewrite). https://dev.mysql.com/doc/refman/8.4/en/innodb-doublewrite-buffer.html
// ============================================================
