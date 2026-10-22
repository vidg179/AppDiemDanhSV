#!/usr/bin/env bash
# Chạy trên VPS (Ubuntu/Debian, quyền root). Chạy lại nhiều lần vẫn an toàn.
set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo ">> Cài Docker..."
  curl -fsSL https://get.docker.com | sh
fi

# Chỉ mở cổng nếu tường lửa ufw đang bật; không tự bật ufw để tránh tự khóa SSH.
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw allow 80/tcp >/dev/null
  ufw allow 443/tcp >/dev/null
  ufw allow 443/udp >/dev/null
fi

# VPS RAM nhỏ: thêm 1 GB swap cho đỡ thiếu bộ nhớ.
if [ "$(free -m | awk '/^Mem:/ {print $2}')" -lt 1500 ] && [ -z "$(swapon --show)" ]; then
  echo ">> Tạo swap 1 GB..."
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo ">> Server sẵn sàng."
