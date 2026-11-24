-- Lược đồ TPC-B trong MySQL, tương đương bảng do pgbench tạo trong PostgreSQL.
DROP TABLE IF EXISTS pgbench_history, pgbench_accounts, pgbench_tellers, pgbench_branches;

CREATE TABLE pgbench_branches (
  bid      INT NOT NULL PRIMARY KEY,
  bbalance INT,
  filler   CHAR(88)
) ENGINE=InnoDB;

CREATE TABLE pgbench_tellers (
  tid      INT NOT NULL PRIMARY KEY,
  bid      INT,
  tbalance INT,
  filler   CHAR(84)
) ENGINE=InnoDB;

CREATE TABLE pgbench_accounts (
  aid      INT NOT NULL PRIMARY KEY,
  bid      INT,
  abalance INT,
  filler   CHAR(84)
) ENGINE=InnoDB;

-- Không có khóa chính, giống pgbench (InnoDB tự thêm khóa ẩn).
-- txn_id dùng cho thí nghiệm C.
CREATE TABLE pgbench_history (
  tid    INT,
  bid    INT,
  aid    INT,
  delta  INT,
  mtime  TIMESTAMP NULL,
  filler CHAR(22),
  txn_id BIGINT
) ENGINE=InnoDB;
