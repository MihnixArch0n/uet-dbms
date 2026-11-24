# Hướng dẫn demo khi thuyết trình: Durability & Crash Recovery (PostgreSQL vs MySQL InnoDB)

Dùng kèm `Huong_dan_BTL_Durability.md` và bộ mã trong repo `uet-dbms` (Python quản lý bằng uv: chạy `uv sync` một lần trước khi demo). Ký hiệu nơi chạy lệnh giống tài liệu chính:
**[Ubuntu]** = terminal Ubuntu trên máy đo hoặc laptop thuyết trình, đứng trong `~/uet-dbms`;
`dc` = bí danh `docker compose -f ~/uet-dbms/docker/docker-compose.yml` (mục 4.3.4).

## 1. Tổng quan

Demo trả lời câu hỏi chính của đề tài: **COMMIT xong thì dữ liệu đã an toàn chưa, và an toàn thì tốn bao nhiêu?**

Thời gian thuyết trình 10–12 phút, trong đó dành **3–4 phút cho demo**:

| Thứ tự | Phần demo | Hình thức | Thời lượng | Người thực hiện |
| --- | --- | --- | --- | --- |
| 1 | Cái giá của fsync (TPS khi bật và tắt flush đồng bộ) | Trực tiếp | ~1 phút | TV1 gõ lệnh, TV1 nói |
| 2 | Crash và mất dữ liệu ở hai mức sự cố | Video quay sẵn | ~2 phút | TV3 điều khiển, TV2 nói |
| 3 | Log phục hồi sau crash (dự phòng, nếu còn thời gian) | Trực tiếp | ~30 giây | TV3 |

Phần I (giới thiệu, cài đặt PostgreSQL) không demo trực tiếp: dùng ảnh chụp P1_xx trên slide.

Lý do dùng video cho phần crash: tắt ngang máy ảo trước lớp dễ trục trặc, và phải chờ máy ảo khởi động lại (30–60 giây). Hai demo trực tiếp còn lại chạy nhanh, không crash máy, nên an toàn.

## 2. Vị trí demo trong bài thuyết trình

| Slide | Nội dung | Demo đi kèm |
| --- | --- | --- |
| Cơ chế WAL / redo log, flush khi COMMIT | Lý thuyết | — |
| Kết quả thí nghiệm A (H3, H5) | TPS theo cấu hình flush | **Demo 1** chạy ngay trước khi chiếu H3 |
| Kết quả thí nghiệm C (bảng B3) | Mất giao dịch theo cấu hình × mức sự cố | **Video (demo 2)** chiếu trước bảng B3 |
| Kết luận | Đề xuất cấu hình | **Demo 3** chỉ khi còn thời gian |

## 3. Demo 1 (trực tiếp): cái giá của fsync

**Mục tiêu:** khán giả thấy ngay TPS tăng mạnh khi bỏ chờ fsync lúc COMMIT.

**Chạy ở:** [Ubuntu] trên laptop thuyết trình, container PostgreSQL đã bật sẵn và đã có dữ liệu pgbench.

```bash
# 1. Cấu hình bền vững (mặc định): synchronous_commit = on
dc exec pg psql -U postgres -c "SHOW synchronous_commit;"
dc exec pg pgbench -U postgres -c 1 -T 10 postgres | grep -E "tps|latency average"

# 2. Bỏ chờ fsync khi COMMIT
dc exec pg psql -U postgres -c "ALTER SYSTEM SET synchronous_commit = off;" -c "SELECT pg_reload_conf();"
dc exec pg pgbench -U postgres -c 1 -T 10 postgres | grep -E "tps|latency average"

# 3. Trả lại cấu hình bền vững (bắt buộc làm ngay sau demo)
dc exec pg psql -U postgres -c "ALTER SYSTEM RESET synchronous_commit;" -c "SELECT pg_reload_conf();"
```

**Lời nói gợi ý:**
- Trước lệnh 1: "Mỗi COMMIT ở đây phải chờ WAL được fsync xuống đĩa. Với 1 client, số giao dịch mỗi giây gần như bằng số lần đĩa fsync được mỗi giây."
- Sau lệnh 2: "Khi tắt synchronous_commit, PostgreSQL báo COMMIT thành công ngay, WAL được ghi sau vài trăm mili giây. TPS tăng [đọc số], độ trễ giảm [đọc số]."
- Chuyển slide H3: "Đây là kết quả đầy đủ với 1, 8, 32 client trên cả hai hệ. Khoảng cách thu hẹp khi tăng client nhờ group commit (H5). Câu hỏi tiếp theo là: tắt đi thì mất gì? Đó là phần video."

**Kiểm tra trước khi lên:** chạy thử cả ba lệnh ít nhất một lần trên laptop thuyết trình; ghi lại hai con số TPS để nếu demo lỗi vẫn nói được.

## 4. Demo 2 (video quay sẵn): crash và mất dữ liệu

**Mục tiêu:** chứng minh (1) chỉ kill tiến trình là không đủ để kiểm tra độ bền (trả lời nhận xét 1 của giảng viên); (2) cấu hình lỏng chỉ mất trọn giao dịch cuối, dữ liệu không hỏng (bất biến luôn đúng).

### 4.1. Các cảnh trong video

| Cảnh | Cấu hình | Sự cố | Kết quả mong đợi trên màn hình | Thời lượng sau khi cắt |
| --- | --- | --- | --- | --- |
| Mở đầu | — | — | Chữ: "Bơm tải TPC-B 8 luồng, client ghi lại mọi giao dịch đã được xác nhận COMMIT" | 5 giây |
| 1 | MySQL `innodb_flush_log_at_trx_commit = 2` | Kill tiến trình (`docker kill -s KILL`) | Đối soát: **mất 0**, bất biến OK | 25 giây |
| 2 | MySQL `= 2` | Tắt ngang máy ảo | Đối soát: **mất N > 0**, bất biến vẫn OK | 35 giây |
| 3 | MySQL `= 1` | Tắt ngang máy ảo | Đối soát: **mất 0**, bất biến OK | 25 giây |
| 4 (tùy chọn) | PostgreSQL `synchronous_commit = off` | Kill tiến trình | Mất vài giao dịch, bất biến OK | 25 giây |
| Kết | — | — | Chữ: tóm tắt ba cảnh trong một bảng nhỏ | 5 giây |

Tổng khoảng 1,5–2 phút sau khi cắt (bỏ đoạn chờ bơm tải và chờ khởi động lại).

### 4.2. Lệnh quay

**Chạy ở:** [Ubuntu] trên máy đo, terminal thường (không dùng tmux cho dễ quay), đã chạy `uv sync` trong `~/uet-dbms` (script tự dùng `.venv/bin/python` của uv, không cần kích hoạt môi trường). Máy ảo `dbvm` đang bật (mục 4.3.5 tài liệu chính).

Chuẩn bị màn hình: phóng to chữ terminal (Ctrl + dấu cộng, cỡ 16–18), xóa màn hình (`clear`). Chia đôi màn hình: trái là terminal chạy lệnh, phải là terminal xem log (`dc logs -f mysql` cho cảnh 1).

```bash
# Cảnh 1: crash tiến trình, MySQL = 2 (DBMS chạy trên máy đo)
dc stop pg; dc start mysql
MIN_LOAD=20 MAX_LOAD=20 bash scripts/run_expC.sh mysql process 2 demo1

# Cảnh 2 và 3: crash hệ điều hành (DBMS trong máy ảo). Khai báo máy ảo trong CÙNG terminal:
export REMOTE="ssh bench@<VM_IP>"
export DB_HOST=<VM_IP>
export COMPOSE=/home/bench/uet-dbms/docker/docker-compose.yml
export VM_CRASH_CMD="VBoxManage controlvm dbvm poweroff"
export VM_START_CMD="VBoxManage startvm dbvm --type headless"
MIN_LOAD=20 MAX_LOAD=20 bash scripts/run_expC.sh mysql os 2 demo2      # cảnh 2
MIN_LOAD=20 MAX_LOAD=20 bash scripts/run_expC.sh mysql os 1 demo3      # cảnh 3
unset REMOTE DB_HOST COMPOSE VM_CRASH_CMD VM_START_CMD

# Cảnh 4 (tùy chọn): PostgreSQL off, crash tiến trình
dc stop mysql; dc start pg
MIN_LOAD=20 MAX_LOAD=20 bash scripts/run_expC.sh pg process off demo4
```

Nếu cảnh 2 không mất giao dịch nào (có thể xảy ra vì phụ thuộc thời điểm crash), quay lại cảnh đó với `demo2b`, `demo2c`... đến khi thấy mất. Khi trình bày phải nói rõ: số giao dịch mất thay đổi theo từng lần, xem bảng B3 cho số liệu đầy đủ.

Sau khi quay xong, xóa các dòng `demo*` khỏi `results/C_summary.csv` (hoặc quay sau khi đã lưu bảng B3 chính thức) để không lẫn vào số liệu báo cáo.

### 4.3. Dựng video

1. Công cụ quay: OBS Studio (obsproject.com), hoặc Win+Alt+R trên Windows, Ctrl+Alt+Shift+R trên Ubuntu.
2. Cắt bỏ đoạn chờ bơm tải và chờ khởi động lại, chỉ giữ: lúc ra lệnh crash, lúc khởi động lại, bảng "Đối soát".
3. Chèn chữ chú thích đầu mỗi cảnh (cấu hình + loại sự cố) và khoanh đỏ các dòng "MẤT giao dịch đã xác nhận" và "Bất biến".
4. Xuất MP4 1080p. Tải lên Google Drive (quyền "Anyone with the link can view"), dán link vào `README.md` và báo cáo. **Đồng thời chép file MP4 vào laptop thuyết trình** để không phụ thuộc mạng.

### 4.4. Lời nói gợi ý khi chiếu

- Mở đầu: "Client bơm giao dịch chuyển tiền và ghi lại mọi giao dịch đã được DBMS xác nhận COMMIT. Sau crash, nhóm so nhật ký này với dữ liệu còn lại để đếm giao dịch đã xác nhận mà bị mất."
- Cảnh 1: "Cấu hình 2: log được ghi sang hệ điều hành ở mỗi COMMIT nhưng mỗi giây mới fsync. Kill tiến trình MySQL: không mất gì, vì log vẫn nằm trong page cache của hệ điều hành."
- Cảnh 2: "Cùng cấu hình đó, nhưng tắt ngang cả máy ảo, page cache mất theo: mất [N] giao dịch đã xác nhận. Nếu chỉ thử kill tiến trình, ta sẽ kết luận sai rằng cấu hình 2 an toàn."
- Cảnh 3: "Cấu hình 1 fsync ở mỗi COMMIT: tắt ngang máy ảo cũng không mất."
- Kết: "Trong mọi trường hợp bất biến đều đúng: dữ liệu không hỏng, chỉ mất trọn những giao dịch cuối. Đây là cái giá đổi lấy TPS cao hơn ở demo trước."

## 5. Demo 3 (trực tiếp, dự phòng): log phục hồi sau crash

**Mục tiêu:** cho thấy quy trình crash recovery (redo) thật, khớp với phần lý thuyết. Chỉ làm khi còn thời gian.

**Chạy ở:** [Ubuntu] trên laptop thuyết trình, container PostgreSQL đang bật.

```bash
dc exec -d pg pgbench -U postgres -c 4 -T 30 postgres     # tạo tải ở chế độ nền
sleep 5
docker kill -s KILL bench-pg                               # crash tiến trình
dc start pg && sleep 5
dc logs --tail 20 pg | grep -E "interrupted|redo starts|redo done|ready to accept"
```

Khán giả thấy: "database system was interrupted", "redo starts at ...", "redo done at ... elapsed: ... s", "database system is ready to accept connections".

**Lời nói gợi ý:** "Sau crash, PostgreSQL đọc vị trí checkpoint cuối trong pg_control, phát lại WAL từ đó tới cuối, mất [đọc số] giây, rồi mới nhận kết nối. Không có pha undo vì nhờ MVCC, giao dịch chưa COMMIT không hiển thị."

Sau demo, đưa dữ liệu về sạch: `bash -c 'source scripts/common.sh; db_file pg scripts/reset_state.sql >/dev/null'`.

## 6. Phương án dự phòng

| Sự cố khi thuyết trình | Xử lý |
| --- | --- |
| Demo 1 lỗi hoặc container chưa chạy | Chuyển ngay sang slide có ảnh chụp kết quả demo 1 đã chụp sẵn, đọc hai con số TPS đã ghi |
| Video không phát được | Mở file MP4 bằng trình phát khác (VLC); nếu vẫn lỗi, chiếu các ảnh R_C1–R_C4 trên slide và nói theo |
| Mạng chậm | Không dùng link Drive, chỉ dùng file MP4 trên máy |
| Hết thời gian | Bỏ demo 3; video có thể chỉ chiếu cảnh 2 và 3 |
| Bị hỏi lúc đang demo | Trả lời ngắn, xin phép trả lời đầy đủ ở phần hỏi đáp |

Không ngồi sửa lỗi trước lớp: chuyển sang phương án dự phòng trong vòng 10–15 giây.

## 7. Chuẩn bị trước buổi thuyết trình

**Một ngày trước:**
- [ ] Video đã dựng xong, có chú thích, đã chép vào laptop thuyết trình và tải lên Drive.
- [ ] Laptop thuyết trình đã cài Docker và uv, có repo, đã chạy `uv sync` và `dc up -d pg` và `bash data/setup_data.sh` (hoặc chỉ `dc exec pg pgbench -U postgres -i -s 10 postgres` cho nhẹ).
- [ ] Chạy thử demo 1 và demo 3 trên laptop đó, ghi lại kết quả và chụp ảnh làm dự phòng.
- [ ] Các lệnh demo dán sẵn trong một file `demo/live_demo.sh` hoặc file text để copy.
- [ ] Tập toàn bộ phần demo có bấm giờ ít nhất hai lần; người nói khớp lời với video.

**Trước giờ thuyết trình 15 phút:**
- [ ] Cắm sạc, tắt thông báo, tắt chế độ ngủ.
- [ ] `dc up -d pg`, chờ PostgreSQL sẵn sàng; kiểm tra `SHOW synchronous_commit;` đang là `on`.
- [ ] Mở sẵn terminal đã phóng to chữ, `clear`; mở sẵn file video ở trình phát.
- [ ] Thử máy chiếu: chữ terminal đọc được từ cuối phòng.

## 8. Câu hỏi dễ bị hỏi ngay sau demo

| Câu hỏi | Ý trả lời |
| --- | --- |
| Tắt synchronous_commit / dùng cấu hình 2 có làm hỏng dữ liệu không? | Không. WAL vẫn được ghi trước dữ liệu; chỉ mất trọn các giao dịch cuối. Bất biến trong mọi lần crash đều đúng (bảng B3). Khác với `fsync = off`, cấu hình đó mới có thể làm hỏng dữ liệu |
| Vì sao cảnh 1 và cảnh 2 khác nhau? | Kill tiến trình không xóa page cache của hệ điều hành; log đã `write()` vẫn còn và được ghi xuống đĩa sau. Tắt ngang máy ảo thì page cache mất, phần chưa fsync mất theo |
| Cấu hình 1 có chắc không mất khi mất điện thật không? | Chỉ khi ổ đĩa tôn trọng lệnh flush (hoặc có tụ bảo vệ bộ đệm). Nhóm không thử mất điện thật; đây là giới hạn của nghiên cứu |
| Làm sao biết giao dịch nào đã được xác nhận? | Client ghi `txn_id` vào file ngay sau khi COMMIT trả về; sau crash đối chiếu với `txn_id` còn trong bảng lịch sử |
| Giao dịch đang COMMIT dở lúc crash thì tính thế nào? | Được tính riêng (INFLIGHT): có thể đã commit hoặc chưa, đều hợp lệ vì client chưa được xác nhận |
| Vì sao số giao dịch mất mỗi lần khác nhau? | Phụ thuộc thời điểm crash so với lần fsync định kỳ (mỗi giây với InnoDB, vài trăm mili giây với PostgreSQL); vì vậy cấu hình lỏng được lặp 5 lần |
