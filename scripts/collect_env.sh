#!/usr/bin/env bash
# Ghi lại cấu hình máy đo, phiên bản phần mềm và toàn bộ tham số DBMS vào results/env/
# Dùng: bash scripts/collect_env.sh   (cả hai container đang chạy)
source "$(dirname "$0")/common.sh"
ENV="$ROOT/results/env"; mkdir -p "$ENV"
{
  echo "# Máy đo - $(date -Iseconds)"
  echo "## CPU"; lscpu | grep -E 'Model name|^CPU\(s\)|Thread|Core|Socket|MHz' || true
  echo "## Bộ nhớ"; free -h
  echo "## Ổ đĩa"; lsblk -d -o NAME,MODEL,ROTA,SIZE,TYPE || true
  echo "## Bộ nhớ đệm ghi của ổ (write back = có cache ghi)"
  for f in /sys/block/*/queue/write_cache; do echo "$f: $(cat "$f")"; done 2>/dev/null || true
  echo "## Hệ điều hành"; uname -a; (lsb_release -ds 2>/dev/null || cat /etc/os-release | head -2)
  echo "## Hệ file chứa dữ liệu Docker"; df -T "$(docker info -f '{{.DockerRootDir}}' 2>/dev/null || echo /var/lib/docker)" || true
  echo "## Docker"; docker --version; docker compose version
  echo "## sysbench"; sysbench --version || true
  echo "## Python (uv)"; uv --version 2>/dev/null || echo "chưa cài uv"; "$PY" --version
} > "$ENV/hardware.txt" 2>&1
pg_sql "SELECT version();" > "$ENV/pg_version.txt"
pg_sql "SELECT name, setting, unit, source FROM pg_settings ORDER BY name;" > "$ENV/pg_settings.txt"
my_sql "SELECT VERSION();" > "$ENV/mysql_version.txt"
my_sql "SHOW GLOBAL VARIABLES;" > "$ENV/mysql_variables.txt"
log "Đã ghi vào $ENV: hardware.txt, pg_version.txt, pg_settings.txt, mysql_version.txt, mysql_variables.txt"
