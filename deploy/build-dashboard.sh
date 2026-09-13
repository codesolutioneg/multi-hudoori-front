#!/usr/bin/env bash
# Build Hudoori Multi dashboard only — never the single-company /root/hodouri trees.
set -euo pipefail

APP_DIR="/root/hudoori-multi/dashboard"
API_URL="https://hr-api.hudoori.code-solution.org"
APP_ENV="${1:-prod}"

cd "$APP_DIR"
flutter pub get
flutter build web --release --no-tree-shake-icons \
  --dart-define=BIOTIME_API_URL="$API_URL" \
  --dart-define=BIOTIME_PIN_LOCALHOST=false \
  --dart-define=BIOTIME_APP_ENV="$APP_ENV"

WEB_DIR="$APP_DIR/build/web"

cat > "$WEB_DIR/tunnel-url.json" <<EOF
{
  "apiUrl": "$API_URL",
  "frontendUrl": "https://hr.hudoori.code-solution.org",
  "updatedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "note": "Hudoori Multi web build",
  "appEnv": "$APP_ENV"
}
EOF

echo "Built Multi dashboard → $WEB_DIR"
echo "API: $API_URL"
echo "Front: https://hr.hudoori.code-solution.org"
