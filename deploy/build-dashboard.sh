#!/usr/bin/env bash
# Build Hudoori Multi dashboard only — never the single-company /root/hodouri trees.
set -euo pipefail

APP_DIR="/opt/hudoori-multi/dashboard"
# Default: hudoori.net production. Pass API URL as 2nd arg to override.
APP_ENV="${1:-prod}"
API_URL="${2:-https://hudoori.net}"
DEST="${3:-/var/www/hudoori-app}"

export PATH="/opt/flutter/bin:${PATH}"

cd "$APP_DIR"
flutter pub get
flutter build web --release --no-tree-shake-icons --base-href /app/ \
  --dart-define=BIOTIME_API_URL="$API_URL" \
  --dart-define=BIOTIME_PIN_LOCALHOST=false \
  --dart-define=BIOTIME_APP_ENV="$APP_ENV"

WEB_DIR="$APP_DIR/build/web"

cat > "$WEB_DIR/tunnel-url.json" <<EOF
{
  "apiUrl": "$API_URL",
  "frontendUrl": "https://hudoori.net/app",
  "updatedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "note": "Hudoori Multi web build",
  "appEnv": "$APP_ENV"
}
EOF

rsync -a --delete "$WEB_DIR/" "$DEST/"

echo "Built Multi dashboard → $WEB_DIR"
echo "Deployed → $DEST"
echo "API: $API_URL"
echo "Front: https://hudoori.net/app"
