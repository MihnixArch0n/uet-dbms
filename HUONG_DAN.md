# Hướng dẫn thực hiện BTL: Durability & Crash Recovery (PostgreSQL vs MySQL InnoDB)

Cập nhật: 23/11/2026 · Dùng kèm bộ mã nguồn `btl-durability.zip` (repo GitHub của nhóm). Python và thư viện quản lý bằng uv (`pyproject.toml`). Phân công: TV1 thí nghiệm A, TV2 thí nghiệm B, TV3 thí nghiệm C.

## 1. Tổng quan

Nhóm có 5 ngày (23/11 đến 28/11) để chạy 3 thí nghiệm trên PostgreSQL và MySQL InnoDB, viết báo cáo PDF và nộp. Vì thời gian ngắn, mọi bước dưới đây được sắp theo thứ tự ưu tiên: làm đúng 3 thí nghiệm cốt lõi trước, phần mở rộng sau.

**Câu hỏi nghiên cứu của đề tài:** khi COMMIT trả về thành công, dữ liệu đã thực sự an toàn chưa, và cái giá về hiệu năng của sự an toàn đó là bao nhiêu trên hai hệ?

**Sản phẩm phải có (theo hướng dẫn của giảng viên):**

| Sản phẩm | Yêu cầu | Hạn |
| --- | --- | --- |
| Báo cáo PDF | 1 file, tên `NhomXX_TenDeTai_BaoCao.pdf`, nộp vào thư mục SharePoint của giảng viên | 28/11/2026 |
| Tài liệu bổ sung | Mã nguồn, script, cấu hình, dữ liệu kết quả, video demo trên GitHub hoặc Google Drive; mở quyền xem; điền link vào file tổng hợp của lớp trưởng | 28/11/2026 |
| Câu hỏi phản biện | Câu hỏi và nhận xét cho các nhóm được phân công | 29/11/2026 |
| Slide và demo | Chưa phải nộp, nhưng phải sẵn sàng: 10 đến 12 phút trình bày, 2 đến 3 phút hỏi đáp | Trước buổi thuyết trình đầu tiên |

**Cấu trúc báo cáo bắt buộc:**

- **Phần 1:** giới thiệu và cài đặt PostgreSQL. Trình bày tổng quát, chi tiết dẫn sang tài liệu bổ sung.
- **Phần 2:** vấn đề chuyên sâu. Bắt buộc có dữ liệu và thực nghiệm thật. Tập trung giải thích bản chất kỹ thuật và kết quả, không chỉ mô tả lý thuyết hay liệt kê thao tác.

**Điểm chấm** dựa trên mức độ hiểu DBMS, khả năng triển khai, chất lượng phân tích và kết quả thực nghiệm, không dựa trên số lượng tính năng hay độ phức tạp của công cụ. Nghĩa là: ít thí nghiệm nhưng thiết kế đúng và giải thích được thì tốt hơn nhiều thí nghiệm hời hợt.

## 2. Phân công và lịch làm việc

Mỗi thành viên sở hữu trọn một thí nghiệm trên **cả hai hệ**: chạy thử, chạy chính thức, phân tích, viết lý thuyết của cơ chế mà thí nghiệm đó đo, viết kết quả và trả lời câu hỏi về nó. Việc chung (Phần I, hạ tầng, ghép báo cáo, slide) chia sao cho khối lượng ba người gần bằng nhau.

| Thành viên | Thí nghiệm sở hữu | Lý thuyết phụ trách | Việc chung | Viết trong báo cáo |
| --- | --- | --- | --- | --- |
| TV1 | **A – chi phí flush log** (45 lần chạy, PostgreSQL và MySQL) | WAL và redo log, `synchronous_commit`, `innodb_flush_log_at_trx_commit`, group commit | Phần I (tìm hiểu, demo PostgreSQL); ghép báo cáo, xuất PDF, nộp | Phần 1; 2.1; 2.2 phần flush log; 2.4; 2.7 |
| TV2 | **B – chi phí bảo vệ trang** (12 lần chạy, PostgreSQL và MySQL, pg\_waldump) | Rách trang, Full-Page Writes, doublewrite buffer; bảng so sánh lý thuyết hai hệ | Slide toàn bài; kiểm chứng dữ liệu MySQL (5.3.2–5.3.3) | 2.2 phần bảo vệ trang và bảng so sánh; 2.5 |
| TV3 | **C – crash và phục hồi** (42 lần crash, hai mức sự cố, máy ảo) | Checkpoint, crash recovery (redo, undo), RPO/RTO | Máy đo, repo, Docker, máy ảo; sinh dữ liệu; công cụ crash và đối soát; video demo | 2.2 phần checkpoint và phục hồi; 2.3; 2.6 |

TV3 có thí nghiệm khó nhất và phần hạ tầng, nên không nhận thêm việc ghép báo cáo hay slide. Ba thí nghiệm dùng chung một máy đo, nên chạy lần lượt theo lịch dưới đây; người sở hữu thí nghiệm là người khởi động, theo dõi và kiểm tra kết quả của lượt chạy đó.

Cả nhóm cùng: đọc chéo báo cáo, chuẩn bị hỏi đáp, viết câu hỏi phản biện cho nhóm khác.

**Lịch theo ngày** (mỗi tối họp 15 phút: ai xong gì, đang kẹt gì):

| Ngày | TV1 – thí nghiệm A | TV2 – thí nghiệm B | TV3 – thí nghiệm C | Máy đo dùng cho |
| --- | --- | --- | --- | --- |
| T2 23/11 | Cài môi trường trên máy mình (4.3.2–4.3.4); đọc WAL, redo log, flush khi COMMIT | Cài môi trường trên máy mình; đọc Full-Page Writes, doublewrite | Máy đo, repo GitHub, Docker; dựng máy ảo | Cài đặt |
| T3 24/11 | Kiểm chứng PostgreSQL (5.3.2–5.3.3); chạy thử A; viết Phần I (nháp); **tối: khởi động A chính thức chạy qua đêm** | Kiểm chứng MySQL (5.3.2–5.3.3); chạy thử B; viết lý thuyết bảo vệ trang | Sinh dữ liệu (5.3.1); kiểm chứng công cụ crash (5.3.4); chạy thử C hai mức | Ban ngày: dữ liệu, chạy thử. Đêm: A (\~5 giờ) |
| T4 25/11 | Sáng: kiểm tra A xong, vẽ H3–H5; phân tích, viết kết quả A | **Sáng: chạy B chính thức (\~1,5 giờ)**; chiều: vẽ H6–H8, phân tích pg\_waldump | **Chiều tối: C mức tiến trình (\~1 giờ)** | Sáng: B. Chiều tối: C mức 1 |
| T5 26/11 | Viết lý thuyết flush log; hoàn thiện Phần I | Viết kết quả B, bảng so sánh lý thuyết; bắt đầu slide | **C mức hệ điều hành (\~1,5 giờ)**; bảng B3, H9; viết kết quả C, lý thuyết phục hồi | C mức 2 (máy ảo); chạy bù nếu thiếu |
| T6 27/11 | Viết 2.1, kết luận; ghép báo cáo | Slide; đọc chéo phần C | Viết phương pháp (2.3); đọc chéo phần A | Chạy lại ô bất thường |
| T7 28/11 | Sửa theo góp ý; xuất PDF, nộp, mở quyền link, gửi link cho lớp trưởng | Hoàn thiện slide; đọc chéo phần A | Đóng gói repo (12.4); quay video demo; đọc chéo phần B | Quay video |
| CN 29/11 | Câu hỏi phản biện; tổng hợp và nộp | Câu hỏi phản biện | Câu hỏi phản biện |  |

Mốc an toàn: hết ngày 25/11 phải có số liệu A, B và C mức tiến trình. Ai xong thí nghiệm của mình thì đọc chéo phần lệnh của hai thí nghiệm kia để có thể chạy thay khi cần. Nếu trễ, cắt bớt số cấu hình hoặc số mức tải, không cắt thí nghiệm C mức hệ điều hành (giảng viên đã yêu cầu).

## 3. Xử lý 3 nhận xét của giảng viên

Cả 3 nhận xét đều được giải quyết bằng thiết kế thí nghiệm, và báo cáo phải có một đoạn nói rõ đã xử lý từng nhận xét thế nào.

| Nhận xét | Vì sao giảng viên nêu | Cách nhóm xử lý |
| --- | --- | --- |
| 1. Phân biệt crash tiến trình, crash hệ điều hành, mất điện | Kill tiến trình (kể cả `docker kill`) không xóa page cache của hệ điều hành. Dữ liệu đã `write()` nhưng chưa `fsync()` vẫn sống, nên không chứng minh được việc mất giao dịch do chưa flush | Thí nghiệm C có hai mức tách riêng: (1) kill tiến trình DBMS; (2) tắt ngang máy ảo chạy DBMS, làm mất page cache của hệ điều hành khách. Mất điện thật (cache của ổ đĩa) nêu là giới hạn, giải thích bằng lý thuyết (Bước 6) |
| 2. Bất biến bốn tổng chỉ đúng nếu trạng thái khởi tạo và logic giao dịch bảo đảm; cần định nghĩa, kiểm chứng bằng script, đối soát số giao dịch thành công | Bất biến chỉ chứng minh tính nguyên tử. Nó không cho biết giao dịch đã xác nhận COMMIT có bị mất hay không: mất cả giao dịch thì bốn tổng vẫn bằng nhau | Định nghĩa hình thức bất biến; kiểm tra trạng thái ban đầu (tất cả bằng 0); mỗi giao dịch mang mã riêng `txn_id`; client ghi nhật ký các mã đã nhận xác nhận COMMIT; sau crash đối soát nhật ký với bảng lịch sử để đếm số giao dịch bị mất (Bước 1 và Bước 6) |
| 3. Tách thí nghiệm flush log khỏi thí nghiệm bảo vệ trang; xác định rõ cấu hình bền vững và cách đo RTO/RPO | Flush log và Full-Page Writes/doublewrite là hai cơ chế khác nhau, giải quyết hai loại lỗi khác nhau. Đổi cả hai cùng lúc thì không biết hiệu năng thay đổi do cái nào | Thí nghiệm A chỉ đổi tham số flush, giữ bảo vệ trang bật. Thí nghiệm B chỉ đổi bảo vệ trang, giữ flush chặt. Định nghĩa bằng bảng "cấu hình bền vững" cho mỗi hệ và công thức đo RTO, RPO (Bước 3 đến Bước 6) |

Một điểm cần hiểu trước khi làm: ở bài này RPO được đo bằng **số giao dịch đã xác nhận COMMIT với client nhưng không còn sau phục hồi** (và quy ra khoảng thời gian tương ứng), còn RTO là **thời gian từ lúc khởi động lại đến lúc DBMS nhận kết nối được**, tách thêm phần thời gian redo lấy từ log của DBMS.

## 4. Bước 0 – Môi trường chung (TV3 chủ trì, ngày 23/11)

Tất cả số liệu đưa vào báo cáo phải chạy trên **một máy đo duy nhất**, cùng phiên bản, cùng cấu hình. Ba người có thể viết và thử script trên máy riêng, nhưng lần chạy chính thức làm trên máy đo.

### 4.1. Chọn máy đo

1. Ưu tiên Linux cài thẳng (Ubuntu 22.04 hoặc 24.04), ổ SSD. Nếu chỉ có Windows: dùng WSL2, để dữ liệu Docker trong hệ file ext4 của WSL, không đặt dữ liệu dưới `/mnt/c`.
2. Không dùng Docker Desktop trên macOS cho số liệu chính: fsync đi qua máy ảo của Docker nên con số không phản ánh đĩa thật.
3. Ghi lại cấu hình vào `results/env/hardware.txt`: `lscpu`, `free -h`, `lsblk -o NAME,MODEL,ROTA,SIZE`, `uname -r`, loại hệ file (`df -T`), phiên bản Docker. Báo cáo phải có bảng này.
4. Đo tốc độ fsync của đĩa bằng `pg_test_fsync` (có sẵn trong image PostgreSQL), chạy trên đúng volume chứa dữ liệu. Con số "số lần fsync mỗi giây" là trần lý thuyết của TPS khi chạy 1 client với flush chặt, dùng để giải thích kết quả thí nghiệm A.

### 4.2. Cấu hình nền giống nhau cho hai hệ

| Mục | PostgreSQL | MySQL InnoDB | Lý do |
| --- | --- | --- | --- |
| Bộ đệm dữ liệu | `shared_buffers = 2GB` | `innodb_buffer_pool_size = 2G` | Bằng nhau; dữ liệu scale 50 (khoảng 0,75 GB) nằm gọn trong bộ đệm, nên chi phí đo được chủ yếu là ghi log |
| Dung lượng log trước checkpoint | `max_wal_size = 4GB`, `checkpoint_timeout = 5min` | `innodb_redo_log_capacity = 4G` | Tương đương; ghi lại nếu đổi |
| Binlog | (không có) | `disable_log_bin` | MySQL 8 bật binlog mặc định, thêm một lần fsync mỗi COMMIT. Tắt để chỉ so sánh redo log với WAL, và nêu rõ trong báo cáo |
| Checksum trang | `--data-checksums` khi khởi tạo | mặc định `crc32` | Để phát hiện trang hỏng sau crash |
| Ghi log phục hồi | `log_checkpoints = on`, `log_min_messages = info` | error log mặc định | Để đọc thời gian redo |

Các tham số còn lại để mặc định và ghi lại toàn bộ cấu hình thực tế bằng `SHOW ALL;` và `SHOW VARIABLES;` vào `results/env/`.

Cấu hình này đã nằm sẵn trong `docker/pg/postgresql.conf` và `docker/mysql/bench.cnf` của bộ mã.

### 4.3. Thực hiện chi tiết

#### 4.3.1. Bộ mã nguồn và quy ước

Mọi bước dùng bộ mã `btl-durability.zip` (đã gửi kèm trong cuộc trò chuyện). Quy ước trong các mục "Thực hiện chi tiết":

- Khối `bash` gõ trong terminal của máy đo (Ubuntu hoặc WSL2), đứng ở thư mục gốc `btl-durability/`, trừ khi ghi khác.
- Khối `sql` gõ trong `psql` hoặc `mysql`.
- `<...>` là chỗ cần thay bằng giá trị của nhóm.
- Mục **Kiểm tra** chưa đạt thì không đi tiếp, xem mục 14.3 (xử lý lỗi).

**Chú thích trước mỗi khối lệnh.** Mỗi khối lệnh có một dòng ghi: chạy ở đâu, ai chạy, có cần chụp màn hình không. Các nơi chạy:

| Ký hiệu | Nơi chạy | Cách mở |
| --- | --- | --- |
| **\[PowerShell\]** | PowerShell của Windows, quyền Administrator | Start → gõ PowerShell → chuột phải → Run as administrator. Chỉ dùng khi máy đo là WSL2 |
| **\[Ubuntu\]** | Terminal Ubuntu trên máy đo (WSL2, hoặc Ubuntu boot từ ổ rời) | WSL2: mở ứng dụng Ubuntu 24.04. Ubuntu thật: Ctrl+Alt+T. Luôn `cd ~/btl-durability` trước |
| **\[Ubuntu-tmux\]** | Như \[Ubuntu\] nhưng bên trong phiên tmux (cho lệnh chạy lâu) | `tmux new -s bench` (lần đầu) hoặc `tmux attach -t bench` |
| **\[Máy ảo\]** | Terminal bên trong máy ảo Ubuntu Server | Từ \[Ubuntu\] gõ `ssh bench@<VM_IP>`; hoặc gõ trực tiếp trong cửa sổ VirtualBox |
| **\[Cửa sổ VirtualBox\]** | Màn hình máy ảo trong VirtualBox (lúc cài Ubuntu) | Mở VirtualBox, chọn máy ảo `dbvm`, bấm Show |
| **\[Trình duyệt\]** | github.com, Google Drive |  |

Trên máy cá nhân của TV1 và TV2 (dùng để viết và thử script), \[Ubuntu\] là terminal Ubuntu trên máy mình; mọi lần chạy **chính thức** và mọi ảnh chụp kết quả đều làm trên máy đo.

**Chụp màn hình.** Khi dòng chú thích ghi "Chụp: Có", chụp phần kết quả (Windows: Win+Shift+S; Ubuntu: Shift+PrtSc rồi kéo vùng), lưu đúng tên file vào `report/img/` và commit. Trước khi chụp: phóng to chữ terminal (Ctrl + dấu cộng), xóa màn hình (`clear`), chạy lại lệnh để ảnh chỉ có lệnh và kết quả. Kết quả dài (ví dụ cấu hình máy) không chụp mà chép chữ từ file vào bảng trong báo cáo. Toàn bộ danh sách ảnh cần có nằm ở mục 12.5.

| File | Tác dụng |
| --- | --- |
| `docker/docker-compose.yml`, `docker/pg/postgresql.conf`, `docker/mysql/bench.cnf` | Hai DBMS và cấu hình nền ở mục 4.2 |
| `data/setup_data.sh`, `data/mysql_schema.sql` | Sinh dữ liệu pgbench scale 50, chép sang MySQL, đối chiếu, kiểm tra bất biến ban đầu |
| `workload/tpcb.lua` | Giao dịch TPC-B cho sysbench, chạy được trên cả hai hệ |
| `workload/crash_client.py` | Bơm tải và ghi nhật ký giao dịch đã xác nhận COMMIT (thí nghiệm C) |
| `scripts/common.sh` | Hàm dùng chung: chạy SQL, đổi tham số, khởi động lại, lấy chỉ số, kiểm tra bất biến |
| `scripts/run_expA.sh`, `run_expB.sh`, `run_expC.sh` | Chạy tự động từng thí nghiệm, ghi kết quả vào `results/raw/` |
| `scripts/reconcile.py`, `scripts/parse_recovery_log.py` | Đối soát sau crash (RPO), đọc thời gian redo từ log |
| `scripts/invariant.sql`, `scripts/reset_state.sql` | Bất biến; đưa dữ liệu về trạng thái ban đầu |
| `scripts/collect_env.sh` | Ghi cấu hình máy và toàn bộ tham số DBMS |
| `analysis/parse_results.py`, `analysis/plots.py` | Gom kết quả thành CSV, vẽ hình H3 đến H9, bảng B3 |
| `demo/part1_demo.sql` | Các truy vấn demo Phần I |
| `pyproject.toml, uv.lock` | Thư viện Python của bộ mã, quản lý bằng uv (uv sync cài, uv run chạy); uv.lock ghi phiên bản chính xác, tạo ở lần uv sync đầu tiên |

**Đã thử những gì:** các script phía PostgreSQL (đổi tham số, bất biến, lấy chỉ số, pg\_waldump, crash bằng kill -9, đọc log phục hồi, đối soát, vẽ hình) đã chạy thử với PostgreSQL 16 trên máy của Claude, không qua Docker. Trong lần thử, `synchronous_commit = off` mất 1 đến 13 giao dịch đã xác nhận sau kill -9, còn `on` không mất giao dịch nào; bất biến đúng cả hai. **Chưa thử:** phần MySQL, sysbench thật, Docker thật, máy ảo. Vì vậy ngày đầu phải chạy các bước thử ngắn (mục 5.3, 8.4, 10.8) trước khi chạy dài.

#### 4.3.2. Cài đặt máy đo (TV3, sáng 23/11)

Máy đo cần: Linux 64-bit, tối thiểu 4 nhân CPU, 12 GB RAM (16 GB nếu chạy thêm máy ảo), 60 GB đĩa trống trên SSD. Hai thành viên còn lại cài giống hệt trên máy mình để viết và thử script.

**a. Nếu máy dùng Windows: cài WSL2.** Mở PowerShell bằng quyền Administrator:

**Chạy ở:** \[PowerShell\] · **Ai:** người có máy Windows · **Chụp:** Không

```powershell
wsl --install -d Ubuntu-24.04
```

Khởi động lại máy, mở ứng dụng **Ubuntu 24.04**, đặt tên người dùng và mật khẩu. Bật systemd để Docker chạy như dịch vụ:

**Chạy ở:** \[Ubuntu\] · **Chụp:** Không

```bash
printf '[boot]\nsystemd=true\n' | sudo tee /etc/wsl.conf
```

Quay lại PowerShell chạy `wsl --shutdown`, rồi mở lại Ubuntu. Từ đây mọi lệnh gõ trong Ubuntu, luôn làm việc trong thư mục nhà `~`, không dùng `/mnt/c/...` (ổ Windows qua WSL rất chậm và fsync không đúng).

**b. Gói cơ bản** (`sysstat` cung cấp `iostat`):

**Chạy ở:** \[Ubuntu\] (máy đo và máy cá nhân của cả ba người) · **Chụp:** Không

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg git unzip sysstat tmux
```

**b2. uv** (quản lý Python và thư viện của bộ mã theo `pyproject.toml`; tự tải đúng phiên bản Python nếu máy chưa có, nên không cần cài `python3-venv` hay `pip`):

**Chạy ở:** \[Ubuntu\] (máy đo và máy cá nhân của cả ba người) · **Chụp:** Không

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env        # nạp uv vào PATH cho terminal hiện tại (terminal mở sau tự có)
uv --version                       # in ra uv 0.x
```

**c. Docker Engine và Docker Compose:**

**Chạy ở:** \[Ubuntu\], chạy lần lượt từng dòng (dòng `newgrp docker` mở một shell mới) · **Chụp:** Không

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
newgrp docker
```

Kiểm tra: `docker run --rm hello-world` in ra "Hello from Docker!"; `docker compose version` in ra v2.x.

**d. sysbench:**

**Chạy ở:** \[Ubuntu\] · **Chụp:** Không

```bash
sudo apt install -y sysbench
sysbench --version                            # 1.0.20 trở lên
sysbench --help | grep -A2 "pgsql options"    # phải có dòng: pgsql options
```

Không có dòng `pgsql options` thì sysbench thiếu driver PostgreSQL: xem mục 14.3.

**e. Chuẩn bị máy trước khi đo chính thức:** cắm sạc, chế độ hiệu năng cao, tắt ngủ; đóng trình duyệt, IDE, phần mềm đồng bộ trong lúc đo. Trên Linux cài thẳng có thể cố định tần số CPU: `sudo apt install -y linux-tools-common linux-tools-$(uname -r) && sudo cpupower frequency-set -g performance` (bỏ qua nếu lỗi hoặc dùng WSL2).

#### 4.3.3. Tạo repo GitHub từ bộ mã (TV3, 23/11)

1. Trên github.com bấm **New repository**, tên `btl-durability`, chọn Public (hoặc Private rồi mời giảng viên sau), **không** tích tạo README, bấm **Create repository**.
2. Trên máy đo, chép `btl-durability.zip` vào thư mục nhà rồi:

**Chạy ở:** \[Ubuntu\] trên máy đo, bắt đầu ở thư mục nhà `~` · **Ai:** TV3 · **Chụp:** Không. (Nếu file zip đang nằm trong Downloads của Windows và máy đo là WSL2, chép sang trước: `cp /mnt/c/Users/<tên>/Downloads/btl-durability.zip ~/`.)

```bash
cd ~ && unzip btl-durability.zip && cd btl-durability
chmod +x scripts/*.sh data/*.sh
git init -b main
git config user.name "<Tên bạn>"
git config user.email "<email-github>"
git add . && git commit -m "Bộ mã thí nghiệm ban đầu"
git remote add origin https://github.com/<tài-khoản>/btl-durability.git
git push -u origin main
```

Khi `git push` hỏi mật khẩu, dán **Personal access token** (GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic) → Generate new token, tích quyền `repo`), không dùng mật khẩu GitHub.

3. Mời hai thành viên: repo → **Settings → Collaborators → Add people**. Họ lấy code bằng `cd ~ && git clone https://github.com/<tài-khoản>/btl-durability.git && cd btl-durability`.
4. Cài thư viện Python bằng uv (mỗi máy một lần, và chạy lại sau mỗi lần `git pull` có đổi `pyproject.toml` hoặc `uv.lock`). `uv sync` đọc `pyproject.toml`, tạo thư mục `.venv/` và cài đúng các thư viện (psycopg, pymysql, cryptography, pandas, matplotlib). Không cần kích hoạt môi trường: lệnh Python gõ tay chạy qua `uv run python ...`, còn các script `.sh` tự dùng `.venv/bin/python`.

**Chạy ở:** \[Ubuntu\], thư mục `~/btl-durability` (máy đo và máy của từng người) · **Chụp:** Không

```bash
uv sync                            # lần đầu tạo .venv/ và uv.lock
uv run python -c "import psycopg, pymysql, pandas, matplotlib; print('OK')"    # in ra OK
```

Quy tắc chung: trước khi sửa thì `git pull`; sửa xong `git add <file> && git commit -m "<nội dung>" && git push`. Kết quả đo chính thức chỉ commit từ máy đo. Người chạy uv sync đầu tiên (TV3, trên máy đo) commit file uv.lock để cả nhóm dùng cùng phiên bản thư viện; thư mục .venv/ không commit. File CSV dữ liệu lớn đã nằm trong `.gitignore`.

#### 4.3.4. Khởi động hai DBMS và ghi cấu hình máy (TV3, 23/11)

Tạo bí danh `dc` cho gọn (dùng trong mọi mục sau):

**Chạy ở:** \[Ubuntu\] (mỗi máy một lần) · **Chụp:** Không

```bash
echo "alias dc='docker compose -f ~/btl-durability/docker/docker-compose.yml'" >> ~/.bashrc && source ~/.bashrc
```

**a. Tải image và khởi động:**

**Chạy ở:** \[Ubuntu\] trên máy đo · **Ai:** TV3 · **Chụp:** Có, kết quả `dc ps` (hai container "Up") → `report/img/P1_01_docker_ps.png`, dùng cho báo cáo mục 1.4 (cài đặt)

```bash
cd ~/btl-durability
dc pull                  # tải postgres:16 và mysql:8.4
dc up -d pg mysql
dc ps                    # cả hai STATUS là "Up"
dc logs -f mysql         # lần đầu ~1 phút; chờ "ready for connections ... port: 3306" rồi Ctrl+C
```

**b. Kiểm tra cấu hình đã được nạp:**

**Chạy ở:** \[Ubuntu\] trên máy đo · **Ai:** TV3 · **Chụp:** Có, kết quả hai lệnh → `report/img/P1_02_cau_hinh_nap.png`, dùng cho báo cáo mục 1.4 và 2.3 (chứng minh cấu hình nền đã áp dụng)

```bash
dc exec pg psql -U postgres -c "SHOW shared_buffers;" -c "SHOW data_checksums;" -c "SHOW synchronous_commit;" -c "SHOW full_page_writes;"
dc exec mysql mysql -uroot -pbench -e "SELECT @@innodb_buffer_pool_size/1024/1024/1024 AS buffer_gb, @@log_bin, @@innodb_doublewrite, @@innodb_flush_log_at_trx_commit, @@innodb_redo_log_capacity/1024/1024/1024 AS redo_gb;"
```

Kiểm tra: PostgreSQL in `2GB`, `on`, `on`, `on`; MySQL in `buffer_gb = 2`, `@@log_bin = 0`, `ON`, `1`, `redo_gb = 4`. Nếu `data_checksums` là `off`, volume đã tạo từ trước: `dc down -v` rồi `dc up -d pg mysql` lại.

**c. Đo tốc độ fsync của đĩa:**

**Chạy ở:** \[Ubuntu\] trên máy đo (khi không chạy việc gì khác) · **Ai:** TV3 · **Chụp:** Có, phần "Compare file sync methods using one 8kB write" → `report/img/M_01_pg_test_fsync.png`, dùng cho báo cáo mục 2.3 (môi trường đo) và 2.4 (giải thích TPS 1 client). File chữ đầy đủ tự lưu trong `results/env/pg_test_fsync.txt`

```bash
dc exec pg pg_test_fsync -s 5 -f /var/lib/postgresql/data/fsync_test.tmp | tee results/env/pg_test_fsync.txt
```

Đọc phần "Compare file sync methods using one 8kB write", dòng `fdatasync` (ops/sec): số lần fsync đĩa làm được mỗi giây, dùng để giải thích TPS của 1 client ở thí nghiệm A.

**d. Ghi cấu hình máy và tham số DBMS:**

**Chạy ở:** \[Ubuntu\] trên máy đo, cả hai container đang chạy · **Ai:** TV3 · **Chụp:** Không; mở `results/env/hardware.txt` chép CPU, RAM, ổ đĩa, hệ điều hành, phiên bản vào bảng B1 của báo cáo

```bash
bash scripts/collect_env.sh
ls results/env/          # hardware.txt pg_settings.txt pg_version.txt mysql_variables.txt mysql_version.txt pg_test_fsync.txt
git add results/env && git commit -m "Cấu hình máy đo" && git push
```

Trong `results/env/hardware.txt`, dòng `write_cache` là `write back` nghĩa là ổ có bộ đệm ghi; nhắc trong phần giới hạn của báo cáo (mất điện thật).

#### 4.3.5. Dựng máy ảo cho crash hệ điều hành (TV3, 23–24/11)

Máy ảo chạy DBMS; máy thật chạy công cụ bơm tải và ra lệnh tắt ngang máy ảo (dùng ở mục 10.8). Dùng VirtualBox vì chạy được trên cả Windows và Linux. Phần này chưa được thử, nên làm sớm để còn thời gian xử lý lỗi.

**a. Cài VirtualBox và tải Ubuntu Server**

**Chạy ở:** \[Ubuntu\] trên máy đo (Ubuntu thật) hoặc bộ cài Windows (nếu máy đo là WSL2) · **Ai:** TV3 · **Chụp:** Không

- Linux: `sudo apt install -y virtualbox` (hoặc bản 7.x từ virtualbox.org). Windows: tải bộ cài từ virtualbox.org.
- Trong BIOS phải bật ảo hóa (Intel VT-x hoặc AMD-V).
- Tải file ISO **Ubuntu Server 24.04 LTS** từ ubuntu.com/download/server.
- Nếu máy đo là WSL2: VirtualBox cài trên Windows; tạo lối tắt để gọi từ WSL: `sudo ln -s "/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" /usr/local/bin/VBoxManage`.

**b. Tạo máy ảo bằng dòng lệnh:**

**Chạy ở:** \[Ubuntu\] trên máy đo (WSL2 gọi được `VBoxManage` nhờ lối tắt ở bước a) · **Ai:** TV3 · **Chụp:** Không. Dòng cuối mở cửa sổ máy ảo để cài Ubuntu ở bước c.

```bash
VM=dbvm
ISO=~/Downloads/ubuntu-24.04-live-server-amd64.iso      # đường dẫn file ISO vừa tải
VBoxManage hostonlyif create                            # mạng riêng 192.168.56.0/24 (bỏ qua nếu đã có vboxnet0)
VBoxManage createvm --name $VM --ostype Ubuntu_64 --register
VBoxManage modifyvm $VM --cpus 4 --memory 6144 --nic1 nat --nic2 hostonly --hostonlyadapter2 vboxnet0
VBoxManage createmedium disk --filename "$HOME/VirtualBox VMs/$VM/$VM.vdi" --size 40960
VBoxManage storagectl $VM --name SATA --add sata --controller IntelAhci
VBoxManage storageattach $VM --storagectl SATA --port 0 --device 0 --type hdd --medium "$HOME/VirtualBox VMs/$VM/$VM.vdi"
VBoxManage storageattach $VM --storagectl SATA --port 1 --device 0 --type dvddrive --medium "$ISO"
VBoxManage startvm $VM
```

Trên Windows, card host-only tên là "VirtualBox Host-Only Ethernet Adapter" thay cho `vboxnet0`; có thể tạo máy ảo bằng giao diện với cùng thông số (4 CPU, 6 GB RAM, đĩa 40 GB, card 1 NAT, card 2 Host-only).

**Chạy ở:** \[Cửa sổ VirtualBox\] trong lúc cài, sau đó \[Máy ảo\] cho lệnh `ip` · **Ai:** TV3 · **Chụp:** Không. Ghi lại `<VM_IP>` vào nhóm chat để cả nhóm dùng.

**c. Cài Ubuntu trong máy ảo.** Chọn ngôn ngữ, để mạng mặc định, dùng toàn bộ đĩa, tạo người dùng `bench`, **tích Install OpenSSH server**, không chọn snap nào. Cài xong chọn Reboot Now. Đăng nhập rồi xem IP của card thứ hai bằng `ip -4 addr show enp0s8` (ví dụ `inet 192.168.56.101`). Nếu chưa có IP: `sudo dhclient enp0s8`, hoặc thêm card đó vào `/etc/netplan/50-cloud-init.yaml` với `dhcp4: true` rồi `sudo netplan apply`. Dưới đây gọi IP này là `<VM_IP>`.

**d. ssh không cần mật khẩu từ máy thật:**

**Chạy ở:** \[Ubuntu\] trên máy đo · **Ai:** TV3 · **Chụp:** Không. `ssh-copy-id` hỏi mật khẩu của `bench` một lần cuối.

```bash
ls ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
ssh-copy-id bench@<VM_IP>
ssh bench@<VM_IP> hostname        # in tên máy ảo, không hỏi mật khẩu
```

**e. Cài Docker và dựng DBMS trong máy ảo.** ssh vào máy ảo, chạy đúng các lệnh 4.3.2 b và c (gói cơ bản, Docker), cho phép `sudo` không hỏi mật khẩu bằng `echo "bench ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/bench`, rồi:

**Chạy ở:** \[Máy ảo\], bắt đầu ở thư mục nhà `/home/bench` · **Ai:** TV3 · **Chụp:** Không

```bash
git clone https://github.com/<tài-khoản>/btl-durability.git && cd btl-durability
sed -i 's/restart: "no"/restart: "always"/' docker/docker-compose.yml   # container tự chạy khi máy ảo bật lại
docker compose -f docker/docker-compose.yml up -d pg mysql
bash data/setup_data.sh 50          # sinh dữ liệu ngay trong máy ảo
cat results/env/data_check.txt
sudo systemctl enable docker
```

**f. Thử tắt ngang và bật lại (từ máy thật):**

**Chạy ở:** \[Ubuntu\] trên máy đo (không phải trong máy ảo) · **Ai:** TV3 · **Chụp:** Có, kết quả hai lệnh cuối (`docker ps` và log có dòng "automatic recovery in progress") → `report/img/M_02_vm_crash_recovery.png`, dùng cho báo cáo mục 2.3 (cách gây crash hệ điều hành)

```bash
VBoxManage controlvm dbvm poweroff                  # tắt ngang như rút nguồn máy ảo
VBoxManage startvm dbvm --type headless             # bật lại, không mở cửa sổ
until ssh bench@<VM_IP> true 2>/dev/null; do sleep 2; done
ssh bench@<VM_IP> "docker ps"                      # bench-pg và bench-mysql đã tự chạy lại
ssh bench@<VM_IP> "docker logs --tail 20 bench-pg"   # có dòng "automatic recovery in progress"
```

**Chạy ở:** \[Ubuntu\] trên máy đo, thư mục `~/btl-durability` (đã `uv sync`) · **Chụp:** Không

Kiểm tra máy thật kết nối được DBMS trong máy ảo: `uv run python -c "import psycopg; print(psycopg.connect(host='<VM_IP>', user='postgres', password='bench').execute('select 1').fetchone())"` (in ra `(1,)`).

**Giới hạn ghi trong báo cáo:** VirtualBox mặc định bỏ qua lệnh flush của máy ảo và để máy thật lưu đệm, nên (1) TPS đo trong máy ảo không so sánh được với thí nghiệm A, máy ảo chỉ dùng để đo mất dữ liệu; (2) tắt ngang máy ảo làm mất page cache của hệ điều hành khách (đúng điều cần thử), còn dữ liệu đã gửi xuống đĩa ảo thì vẫn còn, giống ổ đĩa không mất điện.

**Nếu máy đo là WSL2 và không ssh được tới `<VM_IP>`:** bật mạng mirrored (Windows 11) bằng file `C:\Users\<tên>\.wslconfig` chứa hai dòng `[wsl2]` và `networkingMode=mirrored`, rồi `wsl --shutdown`. Nếu vẫn không được, chạy công cụ bơm tải bằng Python trên Windows thay vì WSL, hoặc mượn một máy Linux.

## 5. Bước 1 – Dữ liệu ngân hàng và workload TPC-B (TV3 sinh dữ liệu; TV1, TV2 kiểm chứng; ngày 23–24/11)

Mục tiêu: hai hệ có cùng dữ liệu, chạy cùng một giao dịch bằng cùng một công cụ, và bất biến được kiểm chứng trước khi làm bất cứ thí nghiệm nào.

### 5.1. Giao dịch TPC-B dùng chung

Mỗi giao dịch mô phỏng một lần gửi hoặc rút tiền, giống hệt giao dịch mặc định của pgbench: chọn ngẫu nhiên tài khoản, giao dịch viên, chi nhánh và số tiền `delta` từ −5000 đến 5000, rồi cộng `delta` vào ba số dư và ghi một dòng lịch sử. Viết thành script sysbench `workload/tpcb.lua` để chạy được trên cả hai hệ với cùng một công cụ (file đã có sẵn trong bộ mã; script tự đọc scale từ dữ liệu để sinh mã tài khoản đúng phạm vi).

### 5.2. Định nghĩa bất biến (đáp ứng nhận xét 2)

Gọi A = tổng `abalance`, T = tổng `tbalance`, B = tổng `bbalance`, H = tổng `delta` trong bảng lịch sử.

1. **Trạng thái ban đầu:** sau khi sinh dữ liệu, A = T = B = H = 0. Phải chạy truy vấn và lưu kết quả để chứng minh, không giả định.
2. **Logic giao dịch:** mỗi giao dịch cộng cùng một `delta` vào cả bốn đại lượng trong **một** giao dịch.
3. **Kết luận:** nếu mọi giao dịch hoặc áp dụng đủ hoặc không áp dụng gì (tính nguyên tử), thì A = T = B = H luôn đúng. Một giao dịch chỉ được ghi một phần sẽ làm lệch các tổng.
4. **Giới hạn:** bất biến không phát hiện được việc mất trọn vẹn một giao dịch. Việc đó do bước đối soát ở Bước 6 đảm nhiệm.

Script `scripts/invariant.sql` (chạy được trên cả hai hệ):

```sql
SELECT (SELECT COALESCE(SUM(abalance), 0) FROM pgbench_accounts) AS a_sum,
       (SELECT COALESCE(SUM(tbalance), 0) FROM pgbench_tellers)  AS t_sum,
       (SELECT COALESCE(SUM(bbalance), 0) FROM pgbench_branches) AS b_sum,
       (SELECT COALESCE(SUM(delta), 0)    FROM pgbench_history)  AS h_sum,
       (SELECT COUNT(*)                   FROM pgbench_history)  AS h_count;
```

Trước mỗi loạt thí nghiệm, các script chạy `scripts/reset_state.sql` (xóa bảng lịch sử, đưa mọi số dư về 0) và dừng lại nếu bất biến chưa phải `0|0|0|0|0`.

### 5.3. Thực hiện chi tiết (TV3, TV1, TV2; 23–24/11)

#### 5.3.1. Sinh dữ liệu và chép sang MySQL

Cả hai container phải đang chạy (mục 4.3.4).

**Chạy ở:** \[Ubuntu\] trên máy đo · **Ai:** TV3 · **Chụp:** Có, kết quả `cat results/env/data_check.txt` → `report/img/M_03_doi_chieu_du_lieu.png`, dùng cho báo cáo mục 2.3 (dữ liệu hai hệ giống nhau, bất biến ban đầu bằng 0)

```bash
cd ~/btl-durability
bash data/setup_data.sh 50          # khoảng 5–15 phút
cat results/env/data_check.txt
```

Script làm 5 việc: chạy `pgbench -i -s 50` (5 triệu tài khoản), thêm cột `txn_id` vào bảng lịch sử (dùng cho thí nghiệm C), xuất 3 bảng ra CSV trong `data/`, tạo lược đồ tương đương (`data/mysql_schema.sql`) và nạp CSV vào MySQL bằng `LOAD DATA`, rồi đối chiếu số dòng, tổng khóa, bất biến ban đầu và kích thước hai hệ.

**Kiểm tra** trong `data_check.txt`: dòng `postgresql:` và `mysql:` của phần đối chiếu giống hệt nhau (`50|500|5000000|...`); hai dòng bất biến đều là `0|0|0|0|0`.

#### 5.3.2. Chạy thử workload 60 giây (kiểm chứng dương)

Các hàm trong `scripts/common.sh` dùng trong một `bash -c '...'` riêng (không `source` thẳng vào terminal, vì script bật chế độ thoát khi có lỗi).

**Chạy ở:** \[Ubuntu\] trên máy đo; chỉ bật DBMS đang thử (`dc stop mysql && dc start pg`, hoặc ngược lại) · **Ai:** TV1 với PostgreSQL, TV2 với MySQL · **Chụp:** Có, hai dòng `transactions:` và dòng `OK|...` → `report/img/M_04_kiem_chung_duong_pg.png` và `M_05_kiem_chung_duong_mysql.png`, dùng cho báo cáo mục 2.3 (kiểm chứng bất biến, trả lời nhận xét 2)

```bash
bash -c 'source scripts/common.sh
  db_file pg scripts/reset_state.sql > /dev/null
  run_sysbench pg 8 60 0 /tmp/test_pg.txt
  grep -E "transactions:|ignored errors" /tmp/test_pg.txt
  check_invariant pg'
```

Lặp lại với MySQL bằng cách thay `pg` thành `mysql` và `/tmp/test_pg.txt` thành `/tmp/test_my.txt`.

**Kiểm tra:** dòng cuối có dạng `OK|x|x|x|x|N`: bốn tổng bằng nhau, khác 0, và `N` (số dòng lịch sử) bằng số `transactions` sysbench báo. Chụp màn hình đưa vào báo cáo (mục phương pháp). So TPS với pgbench để chắc sysbench không là nút thắt (hai số nên cùng cỡ, lệch dưới khoảng 30%):

**Chạy ở:** \[Ubuntu\] trên máy đo, PostgreSQL đang bật · **Ai:** TV1 · **Chụp:** Không bắt buộc; ghi con số `tps` vào nhóm chat để so với sysbench

```bash
dc exec pg pgbench -U postgres -c 8 -j 4 -T 60 -P 10 postgres | tail -5
```

Lưu ý: bảng chi nhánh chỉ có 50 dòng, nên với số client lớn các giao dịch tranh khóa trên cùng dòng; điều này ảnh hưởng cả hai hệ và phải nêu khi giải thích TPS ở mức tải cao.

#### 5.3.3. Kiểm chứng âm: bất biến phát hiện được sai lệch

**Chạy ở:** \[Ubuntu\] trên máy đo · **Ai:** TV1 với PostgreSQL, TV2 với MySQL · **Chụp:** Có, một ảnh gồm cả dòng `FAIL|...` và dòng `OK|0|0|0|0|0` → `report/img/M_06_kiem_chung_am_pg.png` (và `M_07_kiem_chung_am_mysql.png`), dùng cho báo cáo mục 2.3

```bash
dc exec pg psql -U postgres -c "UPDATE pgbench_accounts SET abalance = abalance + 1 WHERE aid = 1;"
bash -c 'source scripts/common.sh; check_invariant pg'          # phải ra FAIL|...
bash -c 'source scripts/common.sh; db_file pg scripts/reset_state.sql >/dev/null; check_invariant pg'   # OK|0|0|0|0|0
```

Với MySQL: `dc exec mysql mysql -uroot -pbench bank -e "UPDATE pgbench_accounts SET abalance = abalance + 1 WHERE aid = 1;"` rồi hai lệnh trên với `mysql`. Chụp cả kết quả dương và âm đưa vào báo cáo.

#### 5.3.4. Kiểm chứng công cụ crash khi không crash

**Chạy ở:** \[Ubuntu\] trên máy đo, trong thư mục `~/btl-durability` · **Ai:** TV3 · **Chụp:** Có, ba con số cuối (số dòng ack, số dòng có `txn_id`, bất biến) → `report/img/M_08_kiem_chung_crash_client.png`, dùng cho báo cáo mục 2.3 (công cụ đối soát đáng tin)

```bash
bash -c 'source scripts/common.sh; db_file pg scripts/reset_state.sql >/dev/null'
uv run python workload/crash_client.py --db pg --threads 4 --duration 30 --out /tmp/nocrash
cat /tmp/nocrash.ack.* | wc -l
dc exec -T pg psql -U postgres -At -c "SELECT count(*) FROM pgbench_history WHERE txn_id IS NOT NULL;"
bash -c 'source scripts/common.sh; check_invariant pg'
rm -f /tmp/nocrash.*
```

**Kiểm tra:** hai con số đầu bằng nhau, bất biến `OK`. Làm lại với `--db mysql` (truy vấn đếm dùng `dc exec -T mysql mysql -uroot -pbench -N bank -e "..."`). Xong mục này thì môi trường đã đáng tin; từ đây mới chạy thí nghiệm dài.

## 6. Bước 2 – Viết Phần I báo cáo: giới thiệu, cài đặt và demo PostgreSQL (TV1, ngày 24–27/11)

PostgreSQL đã được cài và chạy ở mục 4.3.4 (bằng Docker). Bước này là tìm hiểu, chạy demo, chụp màn hình và viết Phần I của báo cáo; làm song song trong lúc máy đo chạy thí nghiệm.

Phần I trong báo cáo khoảng 5 đến 7 trang, trình bày tổng quát; hướng dẫn cài đặt chi tiết và ảnh chụp đầy đủ đưa vào `README.md` hoặc thư mục `docs/` trên GitHub rồi dẫn link. Ưu tiên những nội dung nối sang Phần II (tiến trình nền, bộ nhớ, file WAL) để báo cáo liền mạch.

### 6.1. Nội dung cần viết

| Mục | Nội dung | Độ dài |
| --- | --- | --- |
| 1.1. Tổng quan | Lịch sử ngắn (Berkeley POSTGRES đến PostgreSQL), mô hình đối tượng-quan hệ, vị trí so với MySQL, Oracle, SQL Server | Khoảng 0,5 trang |
| 1.2. Kiến trúc | Mô hình process-per-connection (postmaster, backend); tiến trình nền: checkpointer, background writer, WAL writer, autovacuum; bộ nhớ chung (shared buffers, WAL buffers) và bộ nhớ riêng (work\_mem); lưu trữ vật lý: PGDATA, `base/`, `pg_wal/`, heap file, trang 8 KB, TOAST; catalog hệ thống. Nên có một sơ đồ kiến trúc | 2 trang |
| 1.3. Tính năng chính | Kiểu dữ liệu (JSONB, array, range), chỉ mục (B-tree, GIN, GiST, BRIN), MVCC và VACUUM, mức cô lập, view, function, trigger, extension. Mỗi mục 2 đến 3 câu | 1 trang |
| 1.4. Cài đặt, cấu hình, vận hành | Cài bằng Docker (đúng cách nhóm dùng), file `postgresql.conf` và `pg_hba.conf`, các tham số nhóm đã chỉnh và lý do; tạo user, phân quyền | 1 trang |
| 1.5. Demo chức năng cơ bản | Xem danh sách demo bên dưới | 1 đến 2 trang ảnh chụp kèm giải thích |

### 6.2. Danh sách demo (chụp màn hình, lưu lệnh vào `demo/part1_demo.sql`)

1. Khởi động container, kết nối bằng `psql`, chạy `SELECT version();`.
2. Chạy `ps aux` trong container để thấy các tiến trình `checkpointer`, `background writer`, `walwriter`, `autovacuum launcher`. Đây là cầu nối sang Phần II.
3. Xem thư mục `pg_wal/` và các file WAL 16 MB; xem `SHOW wal_level; SHOW synchronous_commit; SHOW full_page_writes;`.
4. Tạo bảng, nạp dữ liệu bằng `COPY`, truy vấn và đọc `EXPLAIN ANALYZE` (seq scan so với index scan trên `pgbench_accounts`).
5. Sao lưu và khôi phục bằng `pg_dump` và `pg_restore`.
6. Giám sát: `pg_stat_activity`, `pg_stat_database`, `pg_stat_wal`.
7. Chạy `pgbench` ngắn 30 giây và đọc kết quả TPS, độ trễ.

### 6.3. Tài liệu đọc

- PostgreSQL 16 Documentation, các chương: Server Setup and Operation, Server Configuration, Monitoring Database Activity, Reliability and the Write-Ahead Log.
- Giáo trình Silberschatz, chương về lưu trữ vật lý và phục hồi, kết hợp slide môn học.
- Ghi nguồn mỗi khi lấy thông tin; danh sách tài liệu tham khảo đặt cuối báo cáo.

### 6.4. Thực hiện chi tiết (TV1, 24–25/11)

Mỗi bước chụp một ảnh màn hình, lưu vào `report/img/part1_<số>.png`.

**a. Chạy các truy vấn demo:**

**Chạy ở:** \[Ubuntu\] trên máy đo lúc không chạy thí nghiệm (hoặc trên máy TV1 đã cài giống hệt mục 4.3.2–4.3.4 và sinh dữ liệu 5.3.1) · **Ai:** TV1 · **Chụp:** Có, mỗi khối một ảnh, dùng cho báo cáo mục 1.2–1.5. Cách chụp từng khối: gõ `dc exec pg psql -U postgres` để vào dấu nhắc `postgres=#`, mở file `demo/part1_demo.sql` bằng trình soạn thảo, dán từng khối rồi chụp:

| Khối trong file | Tên ảnh | Mục báo cáo |
| --- | --- | --- |
| 1. Phiên bản và tham số độ bền | `P1_03_phien_ban_tham_so.png` | 1.4 |
| 2. Tiến trình (`pg_stat_activity`) | `P1_04_tien_trinh.png` | 1.2 (kiến trúc) |
| 3. Tạo bảng, `COPY`, truy vấn | `P1_05_copy_truy_van.png` | 1.5 |
| 4. Hai lệnh `EXPLAIN ANALYZE` | `P1_06_explain.png` | 1.5 |
| 5. LSN trước và sau COMMIT, tên file WAL | `P1_07_wal_lsn.png` | 1.2, dẫn sang Phần II |
| 6. `pg_stat_wal`, `pg_stat_bgwriter` | `P1_08_thong_ke_wal.png` | 1.5 |
| 7. Tạo role, phân quyền, `\dp` | `P1_09_phan_quyen.png` | 1.4 |
| 8. Dọn dẹp | không chụp |  |

Thoát psql bằng `\q`. Nếu chỉ cần chạy một lượt (không chụp) thì dùng ba lệnh dưới:

```bash
mkdir -p report/img
dc cp demo/part1_demo.sql pg:/tmp/part1_demo.sql
dc exec pg psql -U postgres -f /tmp/part1_demo.sql
```

Muốn chụp từng đoạn cho rõ: mở `dc exec pg psql -U postgres` rồi dán lần lượt từng khối trong file (8 khối: phiên bản và tham số độ bền; tiến trình nền trong `pg_stat_activity`; tạo bảng và `COPY`; `EXPLAIN ANALYZE`; vị trí WAL trước và sau COMMIT; thống kê WAL; phân quyền; dọn dẹp).

**b. Thư mục dữ liệu và file WAL:**

**Chạy ở:** \[Ubuntu\] · **Ai:** TV1 · **Chụp:** Có, cả ba lệnh trong một ảnh → `report/img/P1_10_thu_muc_du_lieu.png`, báo cáo mục 1.2 (lưu trữ vật lý)

```bash
dc exec pg ls /var/lib/postgresql/data
dc exec pg bash -c "ls -lh /var/lib/postgresql/data/pg_wal | head"
dc exec pg bash -c "ls /var/lib/postgresql/data/base"
```

Giải thích trong báo cáo: `base/` chứa dữ liệu từng database, `pg_wal/` chứa các file WAL 16 MB, `pg_xact/` lưu trạng thái commit, `global/pg_control` lưu vị trí checkpoint cuối.

**c. Sao lưu và khôi phục:**

**Chạy ở:** \[Ubuntu\] · **Ai:** TV1 · **Chụp:** Có, kết quả lệnh thứ 4 (`\dt` và `count`) → `report/img/P1_11_sao_luu_khoi_phuc.png`, báo cáo mục 1.5

```bash
dc exec pg pg_dump -U postgres -Fc -t pgbench_branches -t pgbench_tellers -f /tmp/demo.dump postgres
dc exec pg psql -U postgres -c "CREATE DATABASE restore_demo;"
dc exec pg pg_restore -U postgres -d restore_demo /tmp/demo.dump
dc exec pg psql -U postgres -d restore_demo -c "\dt" -c "SELECT count(*) FROM pgbench_tellers;"
dc exec pg psql -U postgres -c "DROP DATABASE restore_demo;"
```

**Chạy ở:** \[Ubuntu\] · **Ai:** TV1 · **Chụp:** Có, phần cuối kết quả pgbench (dòng `latency average` và `tps`) → `report/img/P1_12_pgbench.png`, báo cáo mục 1.5

**d. Đo hiệu năng nhanh bằng pgbench:** `dc exec pg pgbench -U postgres -c 4 -j 2 -T 30 -P 5 postgres`, đọc `tps` và `latency average`. Sau demo, đưa dữ liệu về sạch: `bash -c 'source scripts/common.sh; db_file pg scripts/reset_state.sql >/dev/null; check_invariant pg'`.

**e. Phần cài đặt viết trong báo cáo:** trình bày hai cách kèm lệnh ngắn gọn: (1) Docker như nhóm dùng (`docker-compose.yml`, mount `postgresql.conf`, volume dữ liệu, bật checksum bằng `POSTGRES_INITDB_ARGS`); (2) cài trực tiếp trên Ubuntu bằng `sudo apt install postgresql` rồi `sudo -u postgres psql`. Nêu các file cấu hình (`postgresql.conf`, `pg_hba.conf`) và bảng tham số nhóm đã đổi kèm lý do (mục 4.2). Chi tiết dài để ở README, báo cáo chỉ dẫn link.

## 7. Bước 3 – Lý thuyết Phần II (cả ba, chia theo cơ chế; đọc từ 23/11, viết ngày 26/11)

Lý thuyết chỉ viết đủ để giải thích kết quả thí nghiệm (khoảng 4 đến 6 trang). Mỗi cơ chế trả lời ba câu: nó chống loại lỗi nào, nó làm gì khi COMMIT hoặc khi ghi trang, nó tốn gì.

Lý thuyết chia theo cơ chế mà mỗi thí nghiệm đo, mỗi người viết cho **cả hai hệ**: TV1 viết 7.1 và các ý về WAL/redo log, tham số flush, group commit trong 7.2–7.3; TV2 viết các ý về rách trang, Full-Page Writes, doublewrite và bảng 7.4; TV3 viết các ý về checkpoint, crash recovery và bảng 7.5.

### 7.1. Đặt vấn đề (TV1 viết, mục 2.1 báo cáo)

- Durability trong ACID: giao dịch đã xác nhận COMMIT thì không được mất, kể cả khi hệ thống sập ngay sau đó.
- Đường đi của dữ liệu: bộ đệm của DBMS, rồi page cache của hệ điều hành (sau `write()`), rồi cache của ổ đĩa, rồi bề mặt lưu trữ (sau `fsync()`). Mỗi loại sự cố xóa một số tầng: crash tiến trình xóa bộ nhớ của DBMS; crash hệ điều hành xóa thêm page cache; mất điện có thể xóa cả cache của ổ đĩa nếu ổ không tôn trọng lệnh flush. Nên vẽ thành một hình trong báo cáo.
- Vì sao không ghi thẳng trang dữ liệu khi COMMIT: ghi ngẫu nhiên nhiều trang rất chậm; ghi tuần tự log rồi fsync một lần thì nhanh hơn. Đó là nguyên tắc write-ahead logging: log phải xuống đĩa trước trang dữ liệu tương ứng.
- Rách trang (torn page): trang của DBMS (8 KB ở PostgreSQL, 16 KB ở InnoDB) lớn hơn đơn vị ghi nguyên tử của hệ điều hành và ổ đĩa (thường 4 KB), nên sập giữa lúc ghi trang có thể để lại trang nửa cũ nửa mới mà log thay đổi không sửa được.
- Hai vấn đề độc lập: (1) mất giao dịch đã COMMIT do log chưa xuống đĩa, giải quyết bằng flush log; (2) trang hỏng do ghi dở, giải quyết bằng Full-Page Writes hoặc doublewrite. Đây là cơ sở để tách thí nghiệm A và B (nhận xét 3).

### 7.2. PostgreSQL

- **WAL:** mọi thay đổi sinh bản ghi WAL trong WAL buffers; khi COMMIT, backend ghi và fsync WAL đến vị trí (LSN) của bản ghi commit. File WAL 16 MB trong `pg_wal/`.
- **`synchronous_commit`:** `on` chờ WAL xuống đĩa rồi mới báo thành công; `off` báo thành công ngay, tiến trình WAL writer flush sau (chu kỳ `wal_writer_delay`, mặc định 200 ms). Tài liệu nêu cửa sổ mất tối đa khoảng 3 lần `wal_writer_delay`, nhưng dữ liệu vẫn nhất quán. Khác với `fsync = off` (có thể hỏng dữ liệu, không dùng trong thí nghiệm, chỉ nhắc trong lý thuyết).
- **Group commit:** nhiều backend cùng chờ thì một lần fsync phục vụ nhiều giao dịch; giải thích vì sao TPS tăng theo số client dù fsync chậm (`commit_delay`, `commit_siblings`).
- **Full-Page Writes:** lần sửa đầu tiên của mỗi trang sau checkpoint ghi cả ảnh 8 KB của trang vào WAL (full-page image). Khi phục hồi, ảnh này thay trang có thể bị rách. Chi phí: WAL phình to ngay sau mỗi checkpoint, càng nhiều khi checkpoint càng dày và ghi càng ngẫu nhiên.
- **Checkpoint:** ghi các trang bẩn xuống đĩa, ghi điểm bắt đầu redo. Kích hoạt theo `checkpoint_timeout` hoặc `max_wal_size`.
- **Crash recovery:** đọc checkpoint cuối trong `pg_control`, phát lại (redo) WAL từ điểm redo đến cuối WAL. Không có pha undo: giao dịch chưa COMMIT không hiển thị nhờ MVCC và trạng thái commit trong `pg_xact`. Log ghi "redo starts at ..." và "redo done at ...".

### 7.3. MySQL InnoDB

- **Redo log:** bản ghi redo trong log buffer, ghi ra các file redo (dung lượng `innodb_redo_log_capacity`), đánh số bằng LSN.
- **`innodb_flush_log_at_trx_commit`:** `1` ghi và fsync mỗi COMMIT; `2` ghi sang hệ điều hành mỗi COMMIT, fsync khoảng mỗi giây; `0` ghi và fsync khoảng mỗi giây. Chu kỳ là `innodb_flush_log_at_timeout` (mặc định 1 giây).
- **Doublewrite buffer:** trước khi ghi trang về vị trí thật, InnoDB ghi trang vào vùng doublewrite và fsync. Nếu trang thật bị rách, phục hồi lấy bản trong doublewrite. Chi phí: mỗi trang bị ghi hai lần, xảy ra khi flush trang chứ không nằm trong redo log.
- **Checkpoint:** InnoDB dùng fuzzy checkpoint, đẩy dần trang bẩn; điểm checkpoint quyết định lượng redo phải phát lại.
- **Crash recovery:** kiểm tra doublewrite, phát lại redo từ checkpoint LSN, rồi rollback các giao dịch chưa COMMIT bằng undo log (có thể chạy nền sau khi server đã nhận kết nối). Error log ghi "Starting crash recovery" và các dòng tiến độ.
- **Binlog:** nếu bật binlog, COMMIT còn phải ghi binlog (`sync_binlog`) và phối hợp hai log bằng 2PC nội bộ. Nhóm tắt binlog trong thí nghiệm và nêu đây là khác biệt so với cấu hình thực tế.

### 7.4. Bảng so sánh lý thuyết (TV2, mục 2.2 báo cáo)

| Khía cạnh | PostgreSQL | MySQL InnoDB |
| --- | --- | --- |
| Log phục hồi | WAL (redo) | Redo log + undo log |
| Điều khiển flush khi COMMIT | `synchronous_commit` (on / off) | `innodb_flush_log_at_trx_commit` (1 / 2 / 0) |
| Chống rách trang | Full-Page Writes: ảnh trang nằm trong WAL, sau mỗi checkpoint | Doublewrite buffer: ghi trang hai lần khi flush trang |
| Chi phí chống rách trang nằm ở | Khối lượng WAL, tăng theo tần suất checkpoint | Lượng ghi trang dữ liệu |
| Các pha phục hồi | Redo | Redo, rồi rollback bằng undo |
| Kích thước trang | 8 KB | 16 KB |

### 7.5. Cấu hình bền vững và kết quả dự kiến (đáp ứng nhận xét 3)

**Cấu hình bền vững** (giao dịch đã xác nhận không mất với mọi loại sự cố, giả sử ổ đĩa tôn trọng lệnh flush):

- PostgreSQL: `fsync = on`, `synchronous_commit = on`, `full_page_writes = on`.
- InnoDB: `innodb_flush_log_at_trx_commit = 1`, `innodb_doublewrite = ON`; khi có binlog thì thêm `sync_binlog = 1`.

**Kết quả dự kiến theo tài liệu** (thí nghiệm C sẽ kiểm chứng từng ô):

| Cấu hình | Crash tiến trình | Crash hệ điều hành |
| --- | --- | --- |
| PostgreSQL `synchronous_commit = on` | Không mất | Không mất |
| PostgreSQL `synchronous_commit = off` | Có thể mất (WAL chưa ghi nằm trong bộ nhớ chung, mất khi toàn bộ tiến trình chết) | Có thể mất |
| InnoDB `= 1` | Không mất | Không mất |
| InnoDB `= 2` | Không mất (log đã nằm trong page cache) | Có thể mất khoảng 1 giây cuối |
| InnoDB `= 0` | Có thể mất khoảng 1 giây cuối | Có thể mất khoảng 1 giây cuối |

Ô InnoDB `= 2` là bằng chứng rõ nhất cho nhận xét 1: chỉ kill tiến trình sẽ thấy "không mất gì" và kết luận sai. Trong mọi cấu hình trên, bất biến phải luôn đúng, vì chỉ mất trọn giao dịch chứ không mất một phần. Nếu số liệu đo được khác bảng này, ghi đúng số đo và tìm nguyên nhân, không sửa số cho khớp.

## 8. Bước 4 – Thí nghiệm A: chi phí flush log (TV1; chạy thử 24/11, chạy chính thức đêm 24/11)

Câu hỏi: đòi hỏi "COMMIT xong là đã xuống đĩa" làm giảm thông lượng và tăng độ trễ bao nhiêu, và vì sao khoảng cách thay đổi theo số client.

### 8.1. Thiết kế

| Thành phần | Giá trị |
| --- | --- |
| Biến thay đổi | PostgreSQL: `synchronous_commit` = on, off. InnoDB: `innodb_flush_log_at_trx_commit` = 1, 2, 0 |
| Giữ cố định | `full_page_writes = on`, `innodb_doublewrite = ON`, binlog tắt, cấu hình nền ở mục 4.4 |
| Mức tải | 1, 8, 32 client |
| Thời gian | 60 giây làm nóng + 300 giây đo (thiếu thời gian thì 120 giây đo) |
| Lặp lại | 3 lần mỗi ô; báo cáo trung bình và độ lệch chuẩn |
| Chỉ số đo | TPS; độ trễ P50, P95, P99; số lần fsync log mỗi giao dịch; số byte log mỗi giao dịch; ghi đĩa (iostat) |

Tổng: 2 × 3 × 3 = 18 lần chạy PostgreSQL và 3 × 3 × 3 = 27 lần chạy MySQL, khoảng 4,5 giờ với 300 giây mỗi lần. Viết script để chạy tự động qua đêm.

### 8.2. Quy trình mỗi lần chạy (`scripts/run_expA.sh`)

1. Đặt cấu hình rồi khởi động lại DBMS (để mọi lần chạy cùng xuất phát điểm):
   - PostgreSQL: `ALTER SYSTEM SET synchronous_commit = 'off';` rồi `docker compose restart pg`.
   - MySQL: sửa `bench.cnf` hoặc `SET PERSIST innodb_flush_log_at_trx_commit = 2;` rồi `docker compose restart mysql`.
2. Kiểm tra lại giá trị bằng `SHOW ...` và ghi vào đầu file kết quả.
3. PostgreSQL: chạy `CHECKPOINT;` và `SELECT pg_stat_reset_shared('wal');` để lần chạy nào cũng bắt đầu ngay sau checkpoint.
4. Ghi số liệu trước khi chạy:
   - PostgreSQL: `SELECT wal_records, wal_fpi, wal_bytes, wal_write, wal_sync FROM pg_stat_wal;`
   - MySQL: `SHOW GLOBAL STATUS WHERE Variable_name IN ('Innodb_os_log_written','Innodb_os_log_fsyncs','Innodb_data_fsyncs','Innodb_dblwr_pages_written','Innodb_pages_written');`
5. Chạy `iostat -x 10` nền, ghi ra file.
6. Chạy sysbench với `tpcb.lua` (lệnh ở mục 5.3) và số client tương ứng.
7. Ghi lại số liệu sau khi chạy (cùng truy vấn bước 4); lấy hiệu sau trừ trước, chia cho số giao dịch.
8. Chạy `invariant.sql`: bốn tổng phải bằng nhau (kiểm tra workload không lỗi).

### 8.3. Cần giải thích được trong báo cáo

- Với 1 client và cấu hình chặt, TPS bị chặn bởi số lần fsync mỗi giây của đĩa. So sánh với số đo `pg_test_fsync` ở mục 4.1.
- Khi tăng số client, số fsync mỗi giao dịch giảm dưới 1 nhờ group commit, nên khoảng cách giữa cấu hình chặt và cấu hình lỏng thu hẹp. Dùng số liệu fsync mỗi giao dịch để chứng minh, không chỉ nói.
- Độ trễ P99 thay đổi thế nào khi bỏ chờ fsync.
- InnoDB `= 2` và `= 0` gần nhau hay xa nhau về hiệu năng; liên hệ với chi phí gọi `write()` mỗi COMMIT.
- So sánh hai hệ ở cùng cấu hình bền vững; nếu chênh lệch, tìm nguyên nhân trong số byte log mỗi giao dịch và cách mỗi hệ xử lý tranh khóa trên bảng chi nhánh.

Biểu đồ cần có: TPS theo số client (mỗi cấu hình một đường, có thanh sai số); P99 theo cấu hình; số fsync mỗi giao dịch theo số client.

### 8.4. Thực hiện chi tiết (TV1; 24–25/11)

`scripts/run_expA.sh` tự làm toàn bộ quy trình mục 8.2: đưa dữ liệu về 0, với mỗi cấu hình × số client × lần lặp thì khởi động lại DBMS, checkpoint, chụp chỉ số, chạy sysbench, chụp chỉ số, kiểm tra bất biến, cuối cùng trả tham số về cấu hình bền vững.

**a. Chỉ bật một DBMS và dùng tmux** (thí nghiệm chạy hàng giờ, đóng terminal vẫn không dừng):

**Chạy ở:** \[Ubuntu\] trên máy đo; dòng đầu tạo phiên tmux, các dòng sau gõ bên trong nó · **Ai:** TV1 · **Chụp:** Không

```bash
tmux new -s bench            # thoát ra mà vẫn chạy: Ctrl+b rồi d; vào lại: tmux attach -t bench
cd ~/btl-durability && uv sync
dc stop mysql && dc start pg
```

**b. Chạy thử (khoảng 3 phút):**

**Chạy ở:** \[Ubuntu-tmux\] trên máy đo · **Ai:** TV1 · **Chụp:** Không (chạy thử, kết quả bị xóa sau đó)

```bash
CLIENTS=8 REPS=1 TIME=30 WARMUP=10 bash scripts/run_expA.sh pg
ls results/raw/
cat results/raw/A_pg_on_c8_r1.inv results/raw/A_pg_off_c8_r1.inv
uv run python analysis/parse_results.py
```

Kiểm tra: mỗi lần chạy có các file `.meta .before .after .txt .inv` (và `.iostat`); file `.inv` bắt đầu bằng `OK`; `parse_results.py` in bảng có cột `tps_mean`, `p99_ms_mean`, `log_fsyncs_per_txn_mean`; TPS của `off` cao hơn `on`. Sau đó xóa kết quả thử: `rm -f results/raw/A_* results/A_*.csv`.

**c. Chạy chính thức.** PostgreSQL 18 lần (khoảng 2 giờ), MySQL 27 lần (khoảng 3 giờ); có thể nối liền qua đêm:

**Chạy ở:** \[Ubuntu-tmux\] trên máy đo, dán cả ba dòng một lần rồi thoát tmux (Ctrl+b, d) để máy tự chạy · **Ai:** TV1 khởi động tối 24/11, sáng 25/11 TV1 kiểm tra `tmux attach -t bench` · **Chụp:** Không; mọi kết quả tự lưu trong `results/raw/` và log trong `results/logA_*.txt`. Không dùng máy đo cho việc khác trong lúc chạy.

```bash
bash scripts/run_expA.sh pg 2>&1 | tee results/logA_pg.txt
dc stop pg && dc start mysql && bash -c 'source scripts/common.sh; wait_ready mysql'
bash scripts/run_expA.sh mysql 2>&1 | tee results/logA_mysql.txt
```

Thiếu thời gian thì thêm `TIME=120` trước `bash` (giữ `REPS=3`). File log đặt tên `logA_...` ngoài `results/raw/`, vì bước phân tích đọc mọi file `A_*.txt` trong đó.

**d. Sau khi chạy xong:**

**Chạy ở:** \[Ubuntu\] trên máy đo, thư mục `~/btl-durability` · **Ai:** TV1 · **Chụp:** Không; hình H3, H4, H5 sinh ra trong `analysis/figures/` đưa thẳng vào báo cáo mục 2.4, số liệu lấy từ `results/A_summary.csv`

```bash
grep -c "^OK" results/raw/A_*.inv | grep -v ":1"    # không in gì = mọi lần đều OK
uv run python analysis/parse_results.py
uv run python analysis/plots.py                      # sinh H3, H4, H5 trong analysis/figures/
git add results analysis/figures && git commit -m "Kết quả thí nghiệm A" && git push
```

Nếu `parse_results.py` cảnh báo hệ số biến thiên trên 10% ở ô nào, chạy lại riêng ô đó, ví dụ MySQL cấu hình 2 với 32 client: `CONFIGS=2 CLIENTS=32 bash scripts/run_expA.sh mysql` (ghi đè 3 lần cũ của ô đó).

## 9. Bước 5 – Thí nghiệm B: chi phí bảo vệ trang (TV2; ngày 25/11)

Câu hỏi: chống rách trang tốn bao nhiêu, chi phí đó nằm ở đâu trên mỗi hệ, và phụ thuộc vào gì. Thí nghiệm này tách riêng khỏi thí nghiệm A theo nhận xét 3.

### 9.1. Thiết kế

| Thành phần | Giá trị |
| --- | --- |
| Biến thay đổi | PostgreSQL: `full_page_writes` = on, off. InnoDB: `innodb_doublewrite` = ON, OFF (đổi trong `bench.cnf`, khởi động lại) |
| Giữ cố định | Flush chặt: `synchronous_commit = on`, `innodb_flush_log_at_trx_commit = 1`; cấu hình nền mục 4.4 |
| Mức tải | 8 client (một mức, để tiết kiệm thời gian) |
| Thời gian, lặp lại | 60 giây làm nóng + 300 giây đo, 3 lần |
| Chỉ số đo | TPS, P99; PostgreSQL: byte WAL mỗi giao dịch, số full-page image (`wal_fpi`), tỷ lệ byte của full-page image trong WAL; InnoDB: số trang ghi qua doublewrite (`Innodb_dblwr_pages_written`), tổng trang ghi (`Innodb_pages_written`), byte ghi đĩa (iostat) |

`full_page_writes = off` và `innodb_doublewrite = OFF` chỉ dùng để đo chi phí. Báo cáo phải nói rõ: tắt chúng trên hệ thống thật có thể làm hỏng dữ liệu không phục hồi được khi crash hệ điều hành hoặc mất điện.

### 9.2. Quy trình

1. Đặt cấu hình, khởi động lại, kiểm tra giá trị.
2. PostgreSQL: `CHECKPOINT;`, `SELECT pg_stat_reset_shared('wal');`, ghi `SELECT pg_current_wal_lsn();` (LSN bắt đầu).
3. Trong lúc chạy sysbench, mỗi 10 giây lấy một mẫu `pg_stat_wal` (hoặc `SHOW GLOBAL STATUS` với MySQL) ghi ra CSV. Chuỗi này dùng để vẽ lượng log sinh ra theo thời gian.
4. Sau khi chạy: ghi LSN kết thúc, lấy hiệu số các chỉ số và chia cho số giao dịch.
5. PostgreSQL: phân tích thành phần WAL bằng `pg_waldump` trong container:

```bash
pg_waldump --stats=record --start=<LSN_bắt_đầu> --end=<LSN_kết_thúc> -p /var/lib/postgresql/data/pg_wal
```

Kết quả cho biết từng loại bản ghi chiếm bao nhiêu byte, tách riêng phần full-page image (cột FPI). Làm cho cả hai cấu hình on và off. (Các file WAL phải còn trong `pg_wal/`; nếu bị xóa sau checkpoint, chạy ngắn hơn hoặc tăng `wal_keep_size`.)

### 9.3. Thí nghiệm phụ B2: phụ thuộc vào checkpoint (PostgreSQL, nếu còn thời gian)

Giữ `full_page_writes = on`, chạy với `checkpoint_timeout` = 30 giây và 5 phút. Dự kiến checkpoint càng dày thì càng nhiều trang được "sửa lần đầu sau checkpoint", nên WAL càng phình. Đồng thời checkpoint dày làm thời gian phục hồi ngắn hơn (liên hệ RTO ở thí nghiệm C). Đây là trade-off đáng nêu trong kết luận.

### 9.4. Cần giải thích được trong báo cáo

- Biểu đồ lượng WAL theo thời gian: có đỉnh ngay sau mỗi checkpoint khi `full_page_writes = on` không; đối chiếu với thời điểm checkpoint trong log (`log_checkpoints = on`).
- Với dữ liệu tài khoản 5 triệu dòng và cập nhật ngẫu nhiên, hầu như mỗi giao dịch chạm một trang tài khoản khác nhau, nên tỷ lệ full-page image dự kiến cao. Kiểm tra bằng số liệu.
- InnoDB: chi phí doublewrite tỷ lệ với số trang được flush chứ không phải số giao dịch. Vì dữ liệu nằm gọn trong bộ đệm, số trang flush có thể ít và chi phí doublewrite nhỏ. Nếu vậy, nêu đây là khác biệt về vị trí chi phí giữa hai hệ (trong log so với trong ghi trang). Muốn thấy rõ hơn, chạy thêm một lần với bộ đệm nhỏ (256 MB) cho cả hai hệ.
- So sánh TPS on và off: nếu chênh nhỏ trong khi lượng ghi đĩa chênh lớn, giải thích bằng việc thời gian chờ fsync lúc COMMIT mới là nút thắt.

Biểu đồ cần có: cột byte log hoặc byte ghi đĩa mỗi giao dịch (on so với off, hai hệ); đường lượng WAL theo thời gian có đánh dấu checkpoint; cột thành phần WAL từ pg\_waldump.

### 9.5. Thực hiện chi tiết (TV2; 25/11)

`scripts/run_expB.sh` làm quy trình mục 9.2. Ngoài các file như thí nghiệm A, mỗi lần chạy có thêm `.samples` (chỉ số mỗi 10 giây), và với PostgreSQL có `.waldump` (thành phần WAL) và `.checkpoints` (thời điểm checkpoint).

**a. Chạy thử:**

**Chạy ở:** \[Ubuntu-tmux\] trên máy đo · **Ai:** TV2 · **Chụp:** Không (chạy thử)

```bash
dc stop mysql && dc start pg
REPS=1 TIME=30 WARMUP=10 SAMPLE=5 bash scripts/run_expB.sh pg
tail -3 results/raw/B_pg_on_c8_r1.waldump        # có dòng "Total", cột FPI size khác 0
tail -3 results/raw/B_pg_off_c8_r1.waldump       # FPI size gần như bằng 0
head -5 results/raw/B_pg_on_c8_r1.samples
rm -f results/raw/B_* results/B_*.csv
```

**b. Chạy chính thức** (mỗi hệ 6 lần, khoảng 40 phút):

**Chạy ở:** \[Ubuntu-tmux\] trên máy đo, dán cả ba dòng một lần · **Ai:** TV2 · **Chụp:** Không (kết quả tự lưu)

```bash
bash scripts/run_expB.sh pg 2>&1 | tee results/logB_pg.txt
dc stop pg && dc start mysql && bash -c 'source scripts/common.sh; wait_ready mysql'
bash scripts/run_expB.sh mysql 2>&1 | tee results/logB_mysql.txt
```

**c. Thí nghiệm phụ (nếu còn thời gian).** B2, tần suất checkpoint (mục 9.3): `EXTRA_PARAM=checkpoint_timeout EXTRA_VALUES="30s 5min" CONFIGS=on bash scripts/run_expB.sh pg`. Bộ đệm nhỏ để InnoDB phải flush trang nhiều hơn:

**Chạy ở:** \[Ubuntu-tmux\] trên máy đo, bật đúng DBMS tương ứng trước mỗi dòng · **Ai:** TV2 · **Chụp:** Không

```bash
EXTRA_PARAM=innodb_buffer_pool_size EXTRA_VALUES=268435456 bash scripts/run_expB.sh mysql     # 256 MB
EXTRA_PARAM=shared_buffers EXTRA_VALUES=256MB bash scripts/run_expB.sh pg
```

Tên file kết quả có thêm hậu tố (ví dụ `B_pg_on_checkpoint_timeout-30s_c8_r1`), bước phân tích tự tách nhóm.

**d. Sau khi chạy xong:**

**Chạy ở:** \[Ubuntu\] trên máy đo, thư mục `~/btl-durability` · **Ai:** TV2 · **Chụp:** Có, kết quả `tail -25 results/raw/B_pg_on_c8_r1.waldump` và `tail -25 results/raw/B_pg_off_c8_r1.waldump` đặt cạnh nhau → `report/img/R_B1_waldump_on_off.png`, báo cáo mục 2.5 (bằng chứng trực tiếp về full-page image). Hình H6, H7, H8 đưa thẳng vào báo cáo.

```bash
grep -L "^Total" results/raw/B_pg_*.waldump          # không in gì = mọi file waldump đều đủ
uv run python analysis/parse_results.py && uv run python analysis/plots.py   # sinh H6, H7, H8
git add results analysis/figures && git commit -m "Kết quả thí nghiệm B" && git push
```

**Lưu ý khi đọc pg\_waldump:** vì bật data checksums (để công bằng với InnoDB luôn có checksum trang), PostgreSQL ghi thêm bản ghi loại `XLOG/FPI_FOR_HINT` khi lần đầu đặt hint bit trên một trang sau checkpoint. Trong lần thử của Claude, loại này chiếm phần lớn dung lượng FPI. Hình H8 tách riêng nó; báo cáo cần giải thích đây vẫn là chi phí của cơ chế full-page image (với `full_page_writes = off` các bản ghi này không còn chứa ảnh trang). Nếu `pg_waldump` báo không tìm thấy file WAL, WAL đã bị xóa sau checkpoint: chạy lại với `TIME=120`.

## 10. Bước 6 – Thí nghiệm C: crash và phục hồi (TV3; ngày 24–26/11)

Câu hỏi: với từng cấu hình và từng loại sự cố, có giao dịch đã xác nhận COMMIT nào bị mất không (RPO), dữ liệu có còn nhất quán không, và phục hồi mất bao lâu (RTO). Đây là thí nghiệm trả lời trực tiếp nhận xét 1 và 2.

### 10.1. Công cụ bơm tải có nhật ký xác nhận (`workload/crash_client.py`)

sysbench không cho biết giao dịch nào đã được xác nhận, nên cần một client Python riêng, chạy trên máy thật (ngoài máy ảo). Mỗi luồng lặp:

1. Sinh `txn_id` duy nhất (ví dụ `thread_no * 10**9 + counter`).
2. Ghi `txn_id` vào file "đang gửi" trước khi gửi COMMIT.
3. Chạy đúng giao dịch TPC-B, lệnh INSERT lịch sử có thêm `txn_id`.
4. Khi COMMIT trả về thành công: ghi `txn_id` và thời điểm vào file "đã xác nhận" và `flush()` ngay.
5. Khi mất kết nối: ghi `txn_id` đang dở vào file "không rõ kết quả" rồi dừng luồng.

Công cụ này là `workload/crash_client.py` trong bộ mã (file "đang gửi" là `<tiền tố>.sent.<luồng>`, file "đã xác nhận" là `<tiền tố>.ack.<luồng>`). Cách kiểm chứng nó khi không crash ở mục 5.3.4.

### 10.2. Hai mức sự cố

| Mức | Cách gây sự cố | Mất gì | DBMS chạy ở đâu |
| --- | --- | --- | --- |
| 1. Crash tiến trình | `docker kill -s KILL <container>` khi đang có tải | Bộ nhớ của DBMS (bộ đệm, log buffer, WAL buffers). Page cache của hệ điều hành còn nguyên | Máy đo |
| 2. Crash hệ điều hành | `VBoxManage controlvm <VM> poweroff`, hoặc `echo c \| sudo tee /proc/sysrq-trigger` trong máy ảo | Thêm page cache của hệ điều hành khách: dữ liệu đã `write()` nhưng chưa `fsync()` | Máy ảo (Bước 0, mục 4.6), container có `restart: always` |
| 3. Mất điện thật | Không thực hiện | Thêm cache ghi của ổ đĩa, nếu ổ không tôn trọng lệnh flush | Chỉ phân tích lý thuyết; ghi trạng thái write cache của ổ máy đo (`cat /sys/block/<ổ>/queue/write_cache`) và nêu là giới hạn |

Lưu ý mức 2: đĩa ảo của máy ảo có thể được máy thật lưu đệm, nhưng với máy ảo khách điều này giống ổ đĩa đã nhận dữ liệu. Vì vậy mức 2 mô phỏng đúng crash hệ điều hành, chưa mô phỏng mất điện ổ đĩa.

### 10.3. Ma trận chạy

Cấu hình: PostgreSQL `synchronous_commit` on, off; InnoDB `innodb_flush_log_at_trx_commit` 1, 2, 0 (bảo vệ trang luôn bật). Mỗi cấu hình × 2 mức sự cố × 3 lần (5 lần cho các cấu hình có thể mất dữ liệu, vì việc mất phụ thuộc thời điểm crash). Khoảng 35 đến 40 lần crash, mỗi lần 3 đến 4 phút.

### 10.4. Quy trình mỗi lần crash (`scripts/run_expC.sh`)

1. Đưa dữ liệu về trạng thái ban đầu (mục 5.2), xác nhận `invariant.sql` cho toàn bộ bằng 0.
2. Đặt cấu hình, khởi động lại, `CHECKPOINT` (PostgreSQL) để mọi lần cùng điểm xuất phát.
3. Chạy `crash_client.py` với 8 luồng.
4. Sau một khoảng ngẫu nhiên từ 60 đến 120 giây, gây sự cố và ghi thời điểm `t_crash` (đồng hồ máy thật).
5. Khởi động lại: `docker compose start pg` (mức 1) hoặc bật lại máy ảo (mức 2). Ghi `t_start` lúc ra lệnh.
6. Thử kết nối mỗi 0,2 giây; lần đầu thành công ghi `t_ready`.
7. Chạy đối soát (mục 10.5) và kiểm tra hỏng dữ liệu (mục 10.6).
8. Lưu log của DBMS lần khởi động này (`docker compose logs pg` hoặc error log MySQL) vào `results/raw/`.

### 10.5. Đối soát và định nghĩa RPO, RTO (`scripts/reconcile.py`)

Gọi:

- **ACK** = tập `txn_id` trong các file "đã xác nhận";
- **INFLIGHT** = tập `txn_id` đã gửi COMMIT nhưng chưa nhận xác nhận lúc crash, tính bằng các `txn_id` trong file "đang gửi" trừ đi ACK;
- **PRESENT** = tập `txn_id` có trong `pgbench_history` sau phục hồi.

| Chỉ số | Công thức | Yêu cầu |
| --- | --- | --- |
| Giao dịch đã xác nhận bị mất (RPO theo số giao dịch) | \|ACK − PRESENT\| | Bằng 0 với cấu hình bền vững |
| RPO theo thời gian | `t_crash` trừ thời điểm xác nhận sớm nhất trong các giao dịch bị mất (0 nếu không mất) | So với dự kiến ở mục 7.5 |
| Đã COMMIT nhưng chưa kịp xác nhận | \|INFLIGHT ∩ PRESENT\| | Được phép; server đã commit nhưng crash trước khi trả lời client. Giải thích trong báo cáo |
| Giao dịch lạ | \|PRESENT − ACK − INFLIGHT\| | Phải bằng 0, nếu khác 0 là lỗi công cụ |
| Khớp số dòng | `COUNT(*)` của bảng lịch sử = \|PRESENT\| | Bảng lịch sử chỉ chứa giao dịch của công cụ |
| Bất biến | A = T = B = H | Luôn đúng với mọi cấu hình |
| RTO | `t_ready − t_start` | Ghi riêng phần redo lấy từ log DBMS |
| Thời gian redo | PostgreSQL: khoảng giữa "redo starts at" và "redo done at" (PostgreSQL 16 in cả thời gian elapsed). InnoDB: các dòng crash recovery trong error log |  |

Ở mức 2, `t_start` tính từ lúc DBMS bắt đầu khởi động (theo log) chứ không từ lúc bật máy ảo, để không tính thời gian khởi động hệ điều hành. Ghi cả hai con số.

`reconcile.py` in ra một dòng cho mỗi lần crash và nối vào `results/C_summary.csv`: hệ, mức sự cố, cấu hình, lần, |ACK|, |INFLIGHT|, |PRESENT|, số bị mất, RPO (ms), bất biến đúng/sai, RTO (s), thời gian redo (s).

### 10.6. Kiểm tra hỏng dữ liệu sau phục hồi

- PostgreSQL: `CREATE EXTENSION IF NOT EXISTS amcheck;` rồi `SELECT bt_index_check('pgbench_accounts_pkey');` (tương tự các chỉ mục khác); đọc toàn bộ bảng (`SELECT count(*)`) để các checksum được kiểm tra; tìm lỗi checksum trong log.
- MySQL: `CHECK TABLE pgbench_accounts, pgbench_tellers, pgbench_branches, pgbench_history;` và tìm lỗi trong error log.

### 10.7. Thí nghiệm phụ C2: RTO phụ thuộc lượng log cần redo (nếu còn thời gian)

Đặt checkpoint thưa (PostgreSQL `checkpoint_timeout = 30min`, `max_wal_size` lớn), bơm tải 1, 3, 5 phút rồi crash mức 1. Ghi lượng log từ checkpoint cuối đến lúc crash và thời gian redo. Làm tương tự với InnoDB. Kết quả cho thấy trade-off: checkpoint thưa giảm chi phí ghi (ít full-page image) nhưng tăng RTO.

### 10.8. Thực hiện chi tiết (TV3; mức tiến trình 25/11, mức hệ điều hành 26/11)

Mỗi lần gọi `bash scripts/run_expC.sh <hệ> <mức> <cấu hình> <lần>` là một lần crash trọn vẹn theo quy trình mục 10.4, kết thúc bằng đối soát mục 10.5 và nối một dòng vào `results/C_summary.csv`. Mỗi lần mất khoảng 2 đến 3 phút.

**a. Chạy thử một lần:**

**Chạy ở:** \[Ubuntu\] trên máy đo, thư mục `~/btl-durability` · **Ai:** TV3 · **Chụp:** Không (chạy thử)

```bash
uv sync                      # đảm bảo .venv/ có đủ thư viện; script tự dùng .venv/bin/python
dc stop mysql && dc start pg
MIN_LOAD=20 MAX_LOAD=30 bash scripts/run_expC.sh pg process off 0
```

Kiểm tra: cuối cùng in bảng "Đối soát" với "Giao dịch lạ = 0", "COUNT(\*) khớp: True", "Bất biến: OK", có số RTO và thời gian redo. Xóa lần thử: `rm -f results/raw/C_*_r0.* results/C_summary.csv`.

**b. Mức 1, crash tiến trình (trên máy đo).** Cấu hình bền vững lặp 3 lần, cấu hình lỏng lặp 5 lần; tổng 21 lần, khoảng 1 giờ:

**Chạy ở:** \[Ubuntu-tmux\] trên máy đo, thư mục `~/btl-durability` (đã `uv sync`); dán từng đoạn (PostgreSQL trước, MySQL sau) · **Ai:** TV3 · **Chụp:** Có, sau khi chạy xong (xem lệnh chụp ngay dưới khối này)

```bash
dc stop mysql && dc start pg
{ for r in 1 2 3; do bash scripts/run_expC.sh pg process on $r; done
  for r in 1 2 3 4 5; do bash scripts/run_expC.sh pg process off $r; done; } 2>&1 | tee results/logC_pg_process.txt

dc stop pg && dc start mysql && bash -c 'source scripts/common.sh; wait_ready mysql'
{ for r in 1 2 3; do bash scripts/run_expC.sh mysql process 1 $r; done
  for cfg in 2 0; do for r in 1 2 3 4 5; do bash scripts/run_expC.sh mysql process $cfg $r; done; done; } 2>&1 | tee results/logC_mysql_process.txt
```

**Ảnh cần chụp sau mức 1** (chạy ở \[Ubuntu\] trên máy đo, mỗi lệnh một ảnh):

```bash
grep -A9 "Đối soát C_pg_process_off_r1" results/logC_pg_process.txt        # -> R_C1_pg_off_tien_trinh.png
grep -A9 "Đối soát C_mysql_process_2_r1" results/logC_mysql_process.txt   # -> R_C2_mysql_2_tien_trinh.png
grep -E "interrupted|redo starts|redo done|ready to accept" results/raw/C_pg_process_on_r1.dblog            # -> R_C5_log_phuc_hoi_pg.png
grep -Ei "crash recovery|apply batch|ready for connections" results/raw/C_mysql_process_1_r1.dblog          # -> R_C6_log_phuc_hoi_mysql.png
```

Dùng cho báo cáo mục 2.6: R\_C1 cho thấy PostgreSQL `off` mất giao dịch nhưng bất biến vẫn đúng; R\_C2 cho thấy InnoDB `= 2` không mất khi chỉ kill tiến trình; R\_C5, R\_C6 là bằng chứng quá trình redo. Nếu lần `r1` không có giao dịch mất, chọn lần khác có mất (xem cột `lost` trong `results/C_summary.csv`).

**c. Mức 2, crash hệ điều hành (DBMS trong máy ảo, mục 4.3.5).** Trên máy thật, khai báo máy ảo cho script (thay `<VM_IP>`):

**Chạy ở:** \[Ubuntu-tmux\] trên máy đo, đúng phiên sẽ chạy các lệnh tiếp theo (biến `export` chỉ có tác dụng trong phiên đó); máy ảo `dbvm` đang bật · **Ai:** TV3 · **Chụp:** Không

```bash
export REMOTE="ssh bench@<VM_IP>"
export DB_HOST=<VM_IP>
export COMPOSE=/home/bench/btl-durability/docker/docker-compose.yml
export VM_CRASH_CMD="VBoxManage controlvm dbvm poweroff"
export VM_START_CMD="VBoxManage startvm dbvm --type headless"
```

Thử một lần với cấu hình dự kiến mất dữ liệu ở mức này, rồi chạy đủ:

**Chạy ở:** \[Ubuntu-tmux\] trên máy đo (không chạy trong máy ảo: script tự ssh vào máy ảo và tự tắt, bật máy ảo) · **Ai:** TV3 · **Chụp:** Có, sau khi chạy xong: `grep -A9 "Đối soát C_mysql_os_2_r1" results/logC_os.txt` → `report/img/R_C3_mysql_2_he_dieu_hanh.png` và `grep -A9 "Đối soát C_mysql_os_1_r1" results/logC_os.txt` → `report/img/R_C4_mysql_1_he_dieu_hanh.png`. Đặt R\_C2 và R\_C3 cạnh nhau trong báo cáo mục 2.6: cùng cấu hình `= 2`, kill tiến trình không mất còn crash hệ điều hành thì mất; đây là câu trả lời trực tiếp cho nhận xét 1.

```bash
MIN_LOAD=20 MAX_LOAD=30 bash scripts/run_expC.sh mysql os 2 0      # dự kiến có giao dịch bị mất
rm -f results/raw/C_*_r0.*

{ for r in 1 2 3; do bash scripts/run_expC.sh pg os on $r; done
  for r in 1 2 3 4 5; do bash scripts/run_expC.sh pg os off $r; done
  for r in 1 2 3; do bash scripts/run_expC.sh mysql os 1 $r; done
  for cfg in 2 0; do for r in 1 2 3 4 5; do bash scripts/run_expC.sh mysql os $cfg $r; done; done; } 2>&1 | tee results/logC_os.txt
```

Ở mức này cả hai container cùng chạy trong máy ảo (sau mỗi lần bật lại chúng tự khởi động), không ảnh hưởng việc đo mất dữ liệu. RTO ghi hai số: `rto_s` tính cả thời gian máy ảo khởi động, `rto_log_s` chỉ tính DBMS (dùng số này khi so sánh). Cách gây crash thay thế bằng kernel panic: `export VM_CRASH_CMD="timeout 5 ssh bench@<VM_IP> 'echo c | sudo tee /proc/sysrq-trigger'"` và `export VM_START_CMD="VBoxManage controlvm dbvm reset"`. Chạy xong thì bỏ khai báo: `unset REMOTE DB_HOST COMPOSE VM_CRASH_CMD VM_START_CMD`.

**d. Thí nghiệm phụ C2 (mục 10.7), trên máy đo:**

**Chạy ở:** \[Ubuntu-tmux\] trên máy đo, đã `unset` các biến máy ảo, PostgreSQL đang bật · **Ai:** TV3 · **Chụp:** Không (kết quả vào hình H9)

```bash
dc exec pg psql -U postgres -c "ALTER SYSTEM SET checkpoint_timeout = '30min';" -c "ALTER SYSTEM SET max_wal_size = '20GB';"
for t in 60 180 300; do MIN_LOAD=$t MAX_LOAD=$t bash scripts/run_expC.sh pg process on c2_$t; done
dc exec pg psql -U postgres -c "ALTER SYSTEM RESET checkpoint_timeout;" -c "ALTER SYSTEM RESET max_wal_size;" && dc restart pg
```

`run_expC.sh` giữ nguyên các tham số khác đã đặt bằng ALTER SYSTEM. Làm tương tự với MySQL bằng `innodb_redo_log_capacity` lớn (ví dụ `SET PERSIST innodb_redo_log_capacity = 16*1024*1024*1024;`). Hình H9 vẽ từ cột `redo_bytes` và `redo_s`.

**e. Sau khi chạy xong:**

**Chạy ở:** \[Ubuntu\] trên máy đo, thư mục `~/btl-durability` · **Ai:** TV3 · **Chụp:** Không; `results/C_table.md` chép thành bảng B3 trong báo cáo mục 2.6

```bash
column -s, -t results/C_summary.csv | less -S       # xem nhanh, q để thoát
uv run python analysis/plots.py                     # sinh results/C_table.md và H9
cat results/C_table.md
git add results analysis/figures && git commit -m "Kết quả thí nghiệm C" && git push
```

So từng ô của `C_table.md` với bảng dự kiến ở mục 7.5. Ô nào khác dự kiến thì mở log của lần đó (`results/raw/C_..._rN.dblog`, `.client.log`) để tìm nguyên nhân trước khi viết báo cáo.

## 11. Bước 7 – Phân tích và biểu đồ (TV3 viết script, mỗi người phân tích phần mình; ngày 25–26/11)

Mọi biểu đồ sinh từ `analysis/plots.py` đọc thẳng `results/raw/`, để chạy lại thí nghiệm là có biểu đồ mới, không chép số bằng tay.

### 11.1. Quy tắc xử lý số liệu

1. Mỗi ô thí nghiệm báo cáo trung bình và độ lệch chuẩn của 3 lần chạy, ghi rõ n = 3.
2. Nếu hệ số biến thiên (độ lệch chuẩn chia trung bình) vượt 10%, tìm nguyên nhân (checkpoint rơi vào giữa lần đo, máy đang chạy việc khác) rồi chạy lại, ghi lại việc chạy lại.
3. Không bỏ lần chạy nào vì "xấu" nếu không có nguyên nhân kỹ thuật được ghi lại.
4. Kết quả trái với dự kiến ở mục 7.5 giữ nguyên, đưa vào báo cáo kèm giải thích. Đây thường là phần giảng viên đánh giá cao.

### 11.2. Danh sách hình và bảng cho báo cáo

| Mã | Nội dung | Loại | Nguồn số liệu |
| --- | --- | --- | --- |
| H1 | Đường đi của dữ liệu khi COMMIT và tầng nào mất ở mỗi loại sự cố | Sơ đồ | Lý thuyết |
| H2 | Kiến trúc PostgreSQL | Sơ đồ | Phần I |
| B1 | Cấu hình máy đo và phiên bản | Bảng | `results/env/` |
| B2 | Cấu hình nền và cấu hình bền vững của hai hệ | Bảng | Mục 4.4, 7.5 |
| H3 | TPS theo số client, mỗi cấu hình flush một đường, thanh sai số | Biểu đồ đường | Thí nghiệm A |
| H4 | P50/P95/P99 theo cấu hình flush (ở 8 client) | Biểu đồ cột nhóm | Thí nghiệm A |
| H5 | Số fsync log mỗi giao dịch theo số client (group commit) | Biểu đồ đường | Thí nghiệm A |
| H6 | Byte log / byte ghi đĩa mỗi giao dịch: bảo vệ trang bật so với tắt, hai hệ | Biểu đồ cột | Thí nghiệm B |
| H7 | Lượng WAL theo thời gian có đánh dấu checkpoint | Biểu đồ đường | Thí nghiệm B |
| H8 | Thành phần WAL theo pg\_waldump (FPI và bản ghi thường) | Biểu đồ cột xếp chồng | Thí nghiệm B |
| B3 | Kết quả crash: cấu hình × mức sự cố → số giao dịch mất, RPO, bất biến, RTO (trung bình và khoảng) | Bảng | `C_summary.csv` |
| H9 | RTO / thời gian redo theo lượng log cần redo | Biểu đồ phân tán | Thí nghiệm C2 (nếu có) |
| B4 | Đề xuất cấu hình theo loại ứng dụng | Bảng | Kết luận |

Mỗi hình trong báo cáo có: tiêu đề nói ra kết luận (ví dụ "Group commit thu hẹp khoảng cách khi tăng số client"), đơn vị trên trục, chú thích cấu hình, và một đoạn 3 đến 5 câu giải thích ngay bên dưới theo khuôn: quan sát được gì (có số), vì sao (cơ chế), ý nghĩa thực tế.

### 11.3. Thực hiện chi tiết (cả nhóm, 26–27/11)

**Chạy ở:** \[Ubuntu\] (máy đo, hoặc máy bất kỳ sau khi `git pull` kết quả) · **Ai:** TV3, rồi mỗi người mở CSV của phần mình · **Chụp:** Không; dùng file hình và CSV

```bash
cd ~/btl-durability && git pull && uv sync
uv run python analysis/parse_results.py
uv run python analysis/plots.py
ls analysis/figures/       # H3_tps_vs_clients.png ... H9_redo_time.png
```

| File sinh ra | Dùng cho |
| --- | --- |
| `results/A_summary.csv` | Số liệu kết quả A (TPS, P50/P95/P99, fsync mỗi giao dịch; trung bình, độ lệch chuẩn, hệ số biến thiên) |
| `results/B_summary.csv`, `B_waldump.csv`, `B_samples.csv` | Số liệu kết quả B |
| `results/C_summary.csv`, `C_table.md` | Bảng B3 (dán `C_table.md` vào báo cáo rồi chỉnh) |
| `analysis/figures/H3` đến `H9` | Hình trong báo cáo và slide |

Mở CSV bằng Excel hoặc Google Sheets để đọc số. Mỗi con số trong báo cáo phải tìm lại được trong một file CSV.

## 12. Bước 8 – Viết báo cáo và nộp (cả nhóm viết 26–27/11, TV1 ghép và nộp 28/11)

Viết chung trên một file dùng chung (Google Docs hoặc Word trên OneDrive) để không phải ghép thủ công. Tổng khoảng 20 đến 25 trang, Phần II chiếm phần lớn.

### 12.1. Dàn ý báo cáo

| Mục | Nội dung | Người viết | Số trang |
| --- | --- | --- | --- |
| Bìa, mục lục, phân công | Tên nhóm, thành viên, bảng phân công công việc, link GitHub | TV1 | 2 |
| Phần 1. PostgreSQL | 1.1 đến 1.5 theo Bước 2; chi tiết dẫn link | TV1 | 5–7 |
| 2.1. Đặt vấn đề | Durability, các loại sự cố, hình H1, câu hỏi nghiên cứu | TV1 | 1–2 |
| 2.2. Cơ chế hai hệ | Mục 7.2, 7.3, bảng so sánh 7.4, cấu hình bền vững 7.5 | TV1 (WAL/redo log, flush khi COMMIT), TV2 (Full-Page Writes, doublewrite, bảng so sánh), TV3 (checkpoint, crash recovery) | 4–5 |
| 2.3. Phương pháp thực nghiệm | Máy đo (B1), dữ liệu, workload, bất biến và kiểm chứng, thiết kế A, B, C, cách đo RTO/RPO, đoạn trả lời 3 nhận xét của giảng viên | TV3 (phần chung); mỗi người viết thiết kế thí nghiệm của mình | 2–3 |
| 2.4. Kết quả thí nghiệm A | H3, H4, H5 và phân tích | TV1 | 2 |
| 2.5. Kết quả thí nghiệm B | H6, H7, H8 và phân tích | TV2 | 2 |
| 2.6. Kết quả thí nghiệm C | B3, H9, giải thích từng ô so với dự kiến | TV3 | 2–3 |
| 2.7. Kết luận và đề xuất | Trade-off độ bền, hiệu năng, RTO; bảng B4; giới hạn của nghiên cứu (không thử mất điện thật, một máy, binlog tắt) | TV1 tổng hợp, TV2 và TV3 góp ý | 1–2 |
| Tài liệu tham khảo, phụ lục | Tài liệu chính thức, giáo trình; phụ lục cấu hình đầy đủ, link tài liệu bổ sung | Cả nhóm | 1–2 |

### 12.2. Quy tắc viết

- Đúng yêu cầu giảng viên: giải thích bản chất và kết quả, không liệt kê thao tác. Các bước cài đặt và lệnh chi tiết để ở GitHub, báo cáo chỉ dẫn link.
- Mỗi kết luận có số liệu đi kèm và chỉ rõ hình/bảng nào.
- Thuật ngữ tiếng Anh giữ nguyên, lần đầu xuất hiện có chú thích tiếng Việt.
- Ghi nguồn cho mọi thông tin lấy từ tài liệu.
- Mỗi thành viên đọc chéo ít nhất một phần của người khác vào 27/11, kiểm tra: số trong văn bản khớp hình, hình khớp file kết quả.

### 12.3. Nộp (28/11)

- [ ] Xuất PDF, đặt tên `NhomXX_TenDeTai_BaoCao.pdf` (thay XX và tên đề tài viết không dấu, không khoảng trắng).
- [ ] Mở PDF kiểm tra: hình rõ, bảng không bị cắt, mục lục đúng trang, link bấm được.
- [ ] Tải lên thư mục SharePoint của giảng viên.
- [ ] GitHub: README có hướng dẫn chạy lại, đủ script, cấu hình, `results/` (số liệu thô và tóm tắt), hình, link video demo.
- [ ] Kiểm tra quyền truy cập: mở link bằng trình duyệt ẩn danh (không đăng nhập) để chắc người khác xem được.
- [ ] Điền link vào file tổng hợp của lớp trưởng.

### 12.4. Thực hiện chi tiết: đóng gói repo (TV3, 28/11)

**Chạy ở:** \[Ubuntu\] trên máy đo (hoặc máy có bản repo mới nhất) · **Ai:** TV3 · **Chụp:** Không

```bash
cp ~/Downloads/NhomXX_TenDeTai_BaoCao.pdf report/      # đường dẫn file PDF của nhóm
git pull
git add -A && git commit -m "Kết quả cuối, hình, báo cáo" && git push
git tag v1.0-nop-bai && git push --tags
```

- Đặt repo Public (Settings → General → Danger Zone → Change visibility), hoặc giữ Private và mời giảng viên vào Collaborators.
- Điền link video demo và link báo cáo vào mục "Kết quả" của `README.md`.
- Mở link GitHub và Google Drive bằng cửa sổ ẩn danh trước khi gửi lớp trưởng.

### 12.5. Danh sách ảnh chụp và hình cho báo cáo

Tất cả ảnh chụp lưu trong `report/img/`, hình biểu đồ trong `analysis/figures/`. Trước khi ghép báo cáo, TV1 đối chiếu đủ danh sách này.

| Tên file | Nội dung | Chụp ở mục | Người chụp | Dùng trong báo cáo |
| --- | --- | --- | --- | --- |
| `P1_01_docker_ps.png` | Hai container đang chạy | 4.3.4a | TV3 | 1.4 |
| `P1_02_cau_hinh_nap.png` | Tham số nền đã áp dụng trên hai hệ | 4.3.4b | TV3 | 1.4, 2.3 |
| `P1_03` đến `P1_09` | Các khối demo trong psql | 6.4a | TV1 | 1.2–1.5 |
| `P1_10_thu_muc_du_lieu.png` | PGDATA, `pg_wal/`, `base/` | 6.4b | TV1 | 1.2 |
| `P1_11_sao_luu_khoi_phuc.png` | `pg_dump` / `pg_restore` | 6.4c | TV1 | 1.5 |
| `P1_12_pgbench.png` | Kết quả pgbench 30 giây | 6.4d | TV1 | 1.5 |
| `M_01_pg_test_fsync.png` | Tốc độ fsync của đĩa máy đo | 4.3.4c | TV3 | 2.3, 2.4 |
| `M_02_vm_crash_recovery.png` | Máy ảo bật lại sau tắt ngang, DBMS tự phục hồi | 4.3.5f | TV3 | 2.3 |
| `M_03_doi_chieu_du_lieu.png` | Dữ liệu hai hệ giống nhau, bất biến ban đầu bằng 0 | 5.3.1 | TV3 | 2.3 |
| `M_04`, `M_05` | Kiểm chứng dương (PostgreSQL, MySQL) | 5.3.2 | TV1, TV2 | 2.3 |
| `M_06`, `M_07` | Kiểm chứng âm (PostgreSQL, MySQL) | 5.3.3 | TV1, TV2 | 2.3 |
| `M_08_kiem_chung_crash_client.png` | Công cụ đối soát khớp khi không crash | 5.3.4 | TV3 | 2.3 |
| `R_B1_waldump_on_off.png` | Thành phần WAL khi bật và tắt full\_page\_writes | 9.5d | TV2 | 2.5 |
| `R_C1` đến `R_C4` | Kết quả đối soát tiêu biểu (hai mức sự cố) | 10.8b, 10.8c | TV3 | 2.6 |
| `R_C5`, `R_C6` | Log phục hồi của hai hệ | 10.8b | TV3 | 2.6 |
| `H3` đến `H5` (biểu đồ) | Thí nghiệm A | 8.4d (tự sinh) | TV1 | 2.4 |
| `H6` đến `H8` (biểu đồ) | Thí nghiệm B | 9.5d (tự sinh) | TV2 | 2.5 |
| `H9` (biểu đồ), bảng B3 | Thí nghiệm C | 10.8e (tự sinh) | TV3 | 2.6 |

Bảng B1 (máy đo) chép chữ từ `results/env/hardware.txt`; bảng B2 (cấu hình) chép từ mục 4.2 và 7.5 của tài liệu này; không cần chụp. Hình H1 (đường đi dữ liệu) và H2 (kiến trúc PostgreSQL) vẽ tay bằng draw.io hoặc PowerPoint.

## 13. Bước 9 – Slide, demo, phản biện chéo, hỏi đáp (28–29/11 và trước buổi thuyết trình)

### 13.1. Slide (10 đến 12 phút, quá giờ bị trừ điểm)

| Phần | Số slide | Thời gian | Người nói |
| --- | --- | --- | --- |
| Giới thiệu đề tài, câu hỏi nghiên cứu | 1 | 0,5 phút | TV3 |
| PostgreSQL: kiến trúc, cài đặt (ngắn gọn theo yêu cầu) | 2 | 1,5 phút | TV1 |
| Vấn đề: đường đi của dữ liệu, các loại sự cố, rách trang (hình H1) | 1 | 1 phút | TV1 |
| Cơ chế hai hệ và bảng so sánh | 2 | 2 phút | TV1, TV2, TV3 (mỗi người phần cơ chế của thí nghiệm mình) |
| Thiết kế thí nghiệm, cách đo RTO/RPO, bất biến | 1 | 1 phút | TV3 |
| Kết quả A (H3, H5) | 1 | 1,5 phút | TV1 |
| Kết quả B (H6, H7) | 1 | 1 phút | TV2 |
| Kết quả C (B3) + video demo crash | 2 | 2,5 phút | TV3 |
| Kết luận, đề xuất cấu hình | 1 | 0,5 phút | TV2 |

Mỗi slide kết quả có tiêu đề là kết luận và một biểu đồ lớn. Tập nói ít nhất hai lần có bấm giờ.

### 13.2. Video demo (quay sẵn, 1,5 đến 2 phút)

Demo crash cần thời gian chuẩn bị nên quay trước, chiếu trực tiếp nếu còn thời gian. Kịch bản gợi ý: InnoDB `innodb_flush_log_at_trx_commit = 2`.

1. Chạy `crash_client.py`, màn hình hiện số giao dịch đã xác nhận tăng dần.
2. Kill tiến trình, khởi động lại, chạy đối soát: không mất giao dịch nào.
3. Lặp lại nhưng tắt ngang máy ảo: đối soát báo mất N giao dịch, bất biến vẫn đúng.
4. Chuyển sang `= 1`, tắt ngang máy ảo: không mất giao dịch.

Bốn cảnh này trả lời trực tiếp nhận xét 1 của giảng viên. Chèn chữ chú thích vào video, tải lên Google Drive và để link trong README.

**Thực hiện chi tiết (TV3, 28/11).** Công cụ quay: OBS Studio (obsproject.com), hoặc Win+Alt+R trên Windows, Ctrl+Alt+Shift+R trên Ubuntu. Chia màn hình hai terminal: trái chạy lệnh, phải xem `dc logs -f mysql`.

**Chạy ở:** \[Ubuntu\] trên máy đo (terminal thường, không dùng tmux cho dễ quay), thư mục `~/btl-durability` (đã `uv sync`); trước cảnh 3 đặt các biến máy ảo ở mục 10.8c trong cùng terminal · **Ai:** TV3 quay, TV2 làm phụ để giải thích · **Chụp:** Quay video thay vì chụp; chụp thêm một khung hình mỗi cảnh để đưa vào slide

```bash
# Cảnh 1-2: crash tiến trình với = 2 -> không mất giao dịch
MIN_LOAD=20 MAX_LOAD=20 bash scripts/run_expC.sh mysql process 2 demo1
# Cảnh 3: tắt ngang máy ảo với = 2 -> mất giao dịch, bất biến vẫn OK (đặt biến máy ảo ở mục 10.8c trước)
MIN_LOAD=20 MAX_LOAD=20 bash scripts/run_expC.sh mysql os 2 demo2
# Cảnh 4: = 1, tắt ngang máy ảo -> không mất
MIN_LOAD=20 MAX_LOAD=20 bash scripts/run_expC.sh mysql os 1 demo3
```

Phóng to chữ terminal (Ctrl + dấu cộng) để đọc được trên máy chiếu. Cắt còn 1,5 đến 2 phút, chèn chữ chú thích mỗi cảnh, tải lên Google Drive với quyền "Anyone with the link can view". Các lần demo có hậu tố `demo*`: xóa các dòng đó khỏi `results/C_summary.csv` trước khi vẽ bảng chính thức, hoặc quay demo sau khi đã lưu bảng.

### 13.3. Phản biện chéo (hạn 29/11)

1. Đọc báo cáo và GitHub của các nhóm được phân công, chia mỗi thành viên một phần.
2. Mỗi nhóm viết 3 đến 5 câu hỏi theo bốn hướng giảng viên nêu: cơ chế kỹ thuật, thiết kế thực nghiệm (biến nào được giữ cố định, số lần lặp, máy đo), tính đúng đắn (số liệu có khớp không, so sánh có công bằng không), cách giải thích kết quả.
3. Mỗi câu hỏi chỉ vào một trang, hình hoặc con số cụ thể trong báo cáo của họ.

### 13.4. Câu hỏi có thể bị hỏi và ý trả lời

Mỗi thành viên phải trả lời được các câu thuộc mảng mình, và nắm ý chính của các câu còn lại.

| Câu hỏi | Ý trả lời | Người trả lời |
| --- | --- | --- |
| Tắt `synchronous_commit` có làm hỏng dữ liệu không? | Không; WAL vẫn đi trước dữ liệu, chỉ mất các giao dịch cuối. Khác với `fsync = off`. Dẫn số liệu bất biến ở B3 | TV1 |
| Vì sao kill tiến trình không đủ để kiểm chứng mất dữ liệu? | Page cache còn nguyên; dẫn kết quả InnoDB `= 2` ở hai mức sự cố | TV3 |
| Vì sao PostgreSQL không cần doublewrite? | Full-page image nằm sẵn trong WAL, phục hồi dùng nó thay trang rách; đổi lại WAL lớn hơn sau checkpoint (H7) | TV2 |
| Vì sao PostgreSQL phục hồi không có pha undo? | MVCC: dòng của giao dịch chưa COMMIT không hiển thị, trạng thái ghi trong `pg_xact`; dọn sau bằng VACUUM | TV3 |
| Group commit là gì, bằng chứng đâu? | Một lần fsync cho nhiều COMMIT; số fsync mỗi giao dịch giảm khi tăng client (H5) | TV1 |
| Kết quả có phụ thuộc phần cứng không? | Có, TPS tuyệt đối phụ thuộc độ trễ fsync của đĩa (dẫn `pg_test_fsync`); xu hướng và so sánh tương đối mới là kết luận | TV3 |
| Vì sao tắt binlog của MySQL? | Để so sánh redo log với WAL cùng điều kiện; thực tế có binlog và `sync_binlog = 1` thì thêm một lần fsync, nêu trong giới hạn | TV1 |
| Vì sao không dùng `sysbench oltp_write_only` cho MySQL? | Để hai hệ chạy cùng một giao dịch, cùng dữ liệu, cùng công cụ, và cùng bất biến | TV1 |
| Bất biến chứng minh được gì, không chứng minh được gì? | Chứng minh tính nguyên tử; không phát hiện mất trọn giao dịch, vì vậy có bước đối soát `txn_id` | TV3 |
| Cấu hình bền vững có bảo đảm RPO = 0 khi mất điện thật không? | Chỉ khi ổ đĩa tôn trọng lệnh flush (hoặc có tụ bảo vệ cache); nhóm không thử mất điện thật, nêu là giới hạn | TV3 |
| Docker có làm sai kết quả fsync không? | Trên Linux, volume nằm trên hệ file của máy thật nên fsync đi thẳng xuống đĩa; vì vậy không dùng Docker Desktop trên macOS | TV1 |
| Checkpoint dày hay thưa thì tốt hơn? | Trade-off: dày thì RTO ngắn nhưng nhiều full-page image và ghi nhiều; thưa thì ngược lại (B2, C2) | TV2, TV3 |

## 14. Checklist cuối và rủi ro

### 14.1. Rủi ro và phương án dự phòng

| Rủi ro | Dấu hiệu | Phương án |
| --- | --- | --- |
| sysbench không có driver PostgreSQL | `sysbench --help` không có `pgsql` | Dùng pgbench với giao dịch mặc định cho PostgreSQL và viết cùng giao dịch bằng Python (đa luồng) cho cả hai hệ để đối chiếu; nêu rõ trong báo cáo |
| Không dựng được máy ảo | VirtualBox lỗi do ảo hóa phần cứng bị tắt | Bật ảo hóa trong BIOS; hoặc dùng Multipass/QEMU; hoặc mượn một máy Linux cũ chạy DBMS và rút nguồn/kernel panic máy đó. Không bỏ mức 2 vì giảng viên đã yêu cầu |
| Không đủ thời gian chạy thí nghiệm A | Chưa xong A vào tối 25/11 | Giảm thời gian đo còn 120 giây, giữ 3 lần lặp; bỏ mức 32 client nếu cần. Không giảm còn 1 lần lặp |
| Số liệu dao động mạnh | Hệ số biến thiên trên 10% | Đóng ứng dụng khác, cắm sạc laptop, tắt chế độ tiết kiệm pin, chạy lại |
| Không quan sát được mất dữ liệu ở cấu hình lỏng | Số giao dịch mất luôn bằng 0 | Tăng số lần crash lên 5 đến 10, crash khi tải cao nhất. Nếu vẫn 0, báo cáo đúng số đo và giải thích (ví dụ đĩa ảo của máy ảo ghi đồng bộ), không sửa số |
| Bất biến sai sau crash | Bốn tổng lệch | Kiểm tra trước hết công cụ và bước đưa về trạng thái ban đầu; nếu công cụ đúng thì đây là phát hiện quan trọng, giữ lại toàn bộ log và báo ngay cho cả nhóm |
| Thành viên bận đột xuất | Trễ mốc ngày | Ba thí nghiệm dùng chung bộ script và máy đo; mỗi người đã đọc phần lệnh của hai thí nghiệm kia nên chạy thay được; họp tối để phát hiện sớm |

### 14.2. Checklist trước khi nộp

- [ ] File `results/env/` có cấu hình máy, phiên bản, toàn bộ tham số DBMS.
- [ ] Bất biến được kiểm chứng: trạng thái ban đầu bằng 0, chạy thường khớp, kiểm chứng âm phát hiện được lệch.
- [ ] Công cụ crash được kiểm chứng khi không crash: ACK khớp bảng lịch sử.
- [ ] Thí nghiệm A: đủ 2 + 3 cấu hình × 3 mức tải × 3 lần.
- [ ] Thí nghiệm B: đủ on/off × 2 hệ × 3 lần, có pg\_waldump.
- [ ] Thí nghiệm C: đủ 5 cấu hình × 2 mức sự cố, có `C_summary.csv` và log phục hồi.
- [ ] Báo cáo có đoạn trả lời từng nhận xét của giảng viên.
- [ ] Mỗi hình có tiêu đề kết luận, đơn vị, đoạn giải thích; số trong văn bản khớp hình.
- [ ] Phần giới hạn nêu: một máy đo, không thử mất điện thật, binlog tắt, dữ liệu nằm gọn trong bộ đệm.
- [ ] PDF đúng tên, đã nộp SharePoint; GitHub và video mở quyền xem; link đã gửi lớp trưởng.
- [ ] Slide sẵn sàng, đã tập bấm giờ dưới 12 phút; video demo chạy được trên máy thuyết trình; đã thử HDMI.
- [ ] Câu hỏi phản biện cho nhóm khác đã nộp trước 29/11.

### 14.3. Xử lý lỗi thường gặp

| Hiện tượng | Nguyên nhân | Cách xử lý |
| --- | --- | --- |
| `permission denied ... docker.sock` | Người dùng chưa thuộc nhóm docker | `sudo usermod -aG docker $USER` rồi đăng xuất, đăng nhập lại (hoặc `newgrp docker`) |
| `port is already allocated` khi `dc up` | Máy đã có PostgreSQL/MySQL cài sẵn dùng cổng 5432/3306 | `sudo systemctl stop postgresql mysql`, hoặc đổi cổng trong `docker-compose.yml` |
| `data_checksums` là `off` | Volume cũ tạo trước khi có tham số checksum | `dc down -v` rồi `dc up -d pg mysql` và sinh lại dữ liệu |
| sysbench không có `pgsql options` | Bản đóng gói thiếu driver PostgreSQL | Biên dịch: `sudo apt install -y make automake libtool pkg-config libaio-dev libmysqlclient-dev libpq-dev libssl-dev && git clone https://github.com/akopytov/sysbench && cd sysbench && ./autogen.sh && ./configure --with-pgsql && make -j && sudo make install` |
| PyMySQL báo `cryptography package is required` | MySQL 8 dùng `caching_sha2_password` | Chạy `uv sync` (thư viện `cryptography` đã khai báo trong `pyproject.toml`), rồi chạy lại bằng `uv run python ...` |
| `ModuleNotFoundError: psycopg` | Chưa chạy uv sync, hoặc chạy bằng python3 của hệ thống thay vì uv run | `uv sync` trong `~/btl-durability`; chạy Python bằng `uv run python ...` thay vì `python3 ...` |
| `LOAD DATA` báo `secure-file-priv` | File không nằm trong thư mục cho phép | `dc exec mysql mysql -uroot -pbench -e "SELECT @@secure_file_priv"` phải là `/var/lib/mysql-files/`; `dc exec mysql ls /var/lib/mysql-files/import` phải thấy file CSV |
| MySQL không khởi động lại sau khi đổi tham số | Giá trị sai trong `mysqld-auto.cnf` (do `SET PERSIST`) | `dc stop mysql && docker run --rm -v docker_mydata:/v alpine rm -f /v/mysqld-auto.cnf && dc start mysql` |
| PostgreSQL không khởi động lại sau khi đổi tham số | Giá trị sai trong `postgresql.auto.conf` (do `ALTER SYSTEM`) | `dc stop pg && docker run --rm -v docker_pgdata:/v alpine sh -c ": > /v/postgresql.auto.conf" && dc start pg`; xem lỗi bằng `dc logs --tail 30 pg` |
| Script dừng với `TIMEOUT chờ ...` | DBMS chưa lên (đang phục hồi lâu hoặc lỗi cấu hình) | `dc ps`, `dc logs --tail 50 <pg hoặc mysql>` |
| File `.inv` là `FAIL` ở thí nghiệm A hoặc B | Giao dịch lỗi giữa chừng, hoặc dữ liệu chưa đưa về 0 | Xem `ignored errors` trong file `.txt`; chạy lại mục 5.3.2 |
| `pg_waldump: could not find file` | WAL đã bị xóa sau checkpoint | Chạy lại lần đó với `TIME=120`, hoặc tăng `wal_keep_size` nếu đĩa còn trống |
| Đĩa đầy | WAL giữ lại 8 GB, bảng lịch sử phình to | `docker system df`; `bash -c 'source scripts/common.sh; db_file pg scripts/reset_state.sql'`; giảm `wal_keep_size` |
| TPS rất thấp trên WSL2 | Repo hoặc dữ liệu nằm trên `/mnt/c` | Chuyển repo về `~` trong Ubuntu |
| Sau khi bật lại máy ảo, ssh không vào được | IP máy ảo đổi | Đặt IP tĩnh trong `/etc/netplan/*.yaml` cho `enp0s8` (`addresses: [192.168.56.10/24]`), `sudo netplan apply` |
| Container trong máy ảo không tự chạy lại | Chưa đổi `restart: "always"` hoặc Docker chưa bật cùng máy | Làm lại lệnh `sed` và `sudo systemctl enable docker` ở mục 4.3.5e, rồi `docker compose ... up -d` |
| Công cụ crash treo lâu sau khi tắt máy ảo | Kết nối TCP không bị đóng khi máy ảo tắt ngang | Bình thường: script tự dừng client sau 10 giây |
| Còn vướng mà không rõ nguyên nhân |  | Chạy lại với `bash -x scripts/<tên>.sh ...` để xem từng lệnh, gửi đoạn log cuối cho cả nhóm |

### 14.4. Dọn máy sau khi xong

Chỉ làm sau khi đã báo cáo và thuyết trình xong: `dc down -v` (xóa container và dữ liệu), `VBoxManage unregistervm dbvm --delete` (xóa máy ảo).
