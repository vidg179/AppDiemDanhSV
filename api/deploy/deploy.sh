#!/usr/bin/env bash
# Deploy API lên VPS bằng 1 lệnh (chạy trong Git Bash trên máy Windows):
#   bash deploy/deploy.sh root@<IP-VPS>
# Mặc định tên miền là <IP-có-gạch-ngang>.sslip.io (miễn phí, có HTTPS).
# Có tên miền riêng thì chạy: DOMAIN=api.ten-mien.com bash deploy/deploy.sh root@<IP-VPS>
set -euo pipefail

HOST="${1:?Cách dùng: bash deploy/deploy.sh root@<IP-VPS>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IP="${HOST#*@}"
DOMAIN="${DOMAIN:-${IP//./-}.sslip.io}"
OUT="$ROOT/bin/deploy-publish"
REMOTE_DIR=/opt/bakhi-api

[ -f "$ROOT/firebase-key.json" ] || { echo "Thiếu firebase-key.json ở thư mục project"; exit 1; }
[ -f "$ROOT/deploy/.env" ] || { echo "Thiếu deploy/.env (copy từ deploy/.env.example rồi điền)"; exit 1; }

echo ">> [1/4] Build API (Release)..."
rm -rf "$OUT"
dotnet publish "$ROOT/BaKhi_API.csproj" -c Release -o "$OUT/app" --nologo -v quiet
[ -f "$OUT/app/firebase-key.json" ] || { echo "firebase-key.json không được đóng gói"; exit 1; }
cp "$ROOT/deploy/Dockerfile" "$ROOT/deploy/docker-compose.yml" "$ROOT/deploy/Caddyfile" "$ROOT/deploy/.env" "$OUT/"

echo ">> [2/4] Chuẩn bị server $HOST (lần đầu sẽ cài Docker, mất 1-2 phút)..."
ssh "$HOST" 'bash -s' < "$ROOT/deploy/setup-server.sh"

echo ">> [3/4] Tải code lên và khởi động..."
tar -C "$OUT" -czf - . | ssh "$HOST" "set -e
  mkdir -p $REMOTE_DIR && rm -rf $REMOTE_DIR/app
  tar -xzf - -C $REMOTE_DIR
  echo 'DOMAIN=$DOMAIN' >> $REMOTE_DIR/.env
  chmod 600 $REMOTE_DIR/.env
  cd $REMOTE_DIR
  docker compose up -d --build --remove-orphans
  docker image prune -f >/dev/null"

echo ">> [4/4] Chờ API khởi động..."
for _ in $(seq 1 30); do
  if curl -fsS -o /dev/null "https://$DOMAIN/swagger/v1/swagger.json" 2>/dev/null; then
    echo ">> XONG! API: https://$DOMAIN"
    echo ">> Swagger: https://$DOMAIN/swagger"
    exit 0
  fi
  sleep 3
done
echo ">> Chưa gọi được https://$DOMAIN. Xem log bằng lệnh:"
echo "   ssh $HOST 'cd $REMOTE_DIR && docker compose logs --tail 50'"
exit 1
