#!/usr/bin/env bash
set -euo pipefail

SCRIPT_SOURCE="${BASH_SOURCE[0]}"
if command -v readlink >/dev/null 2>&1; then
  RESOLVED_SOURCE="$(readlink -f "$SCRIPT_SOURCE" 2>/dev/null || true)"
  if [[ -n "$RESOLVED_SOURCE" ]]; then
    SCRIPT_SOURCE="$RESOLVED_SOURCE"
  fi
fi

ROOT_DIR="$(cd -- "$(dirname -- "$SCRIPT_SOURCE")/.." && pwd -P)"
TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT

DB_DIR="$TMP_HOME/.config/gas"
DB_PATH="$DB_DIR/apps.db"
mkdir -p "$DB_DIR"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "sqlite3 wajib ada untuk smoke deploy preview." >&2
  exit 1
fi

sqlite3 "$DB_PATH" "
CREATE TABLE IF NOT EXISTS apps (
  project_dir TEXT PRIMARY KEY,
  app_type TEXT,
  port INTEGER,
  pm2_name TEXT,
  health_path TEXT,
  env_file TEXT,
  start_file TEXT,
  run_mode TEXT,
  node_version TEXT,
  npm_version TEXT,
  go_version TEXT,
  svelte_strategy TEXT,
  deps_mode TEXT,
  verify_status TEXT,
  verify_message TEXT,
  updated_at TEXT
);

INSERT OR REPLACE INTO apps (project_dir, app_type, port, pm2_name, svelte_strategy, deps_mode, run_mode, updated_at) VALUES
  ('/srv/apps/marbot-web', 'vite', 3000, 'marbot-web', 'auto', 'auto', 'direct', '2026-03-13T10:00:00Z'),
  ('/srv/apps/diraaax-frontend', 'next', 4001, 'diraaax-frontend', 'auto', 'auto', 'direct', '2026-03-13T10:01:00Z'),
  ('/srv/apps/diraaax-backend', 'node', 4000, 'diraaax-backend', 'auto', 'auto', 'direct', '2026-03-13T10:02:00Z'),
  ('/srv/apps/simpeg-api', 'node', 5000, 'simpeg-api', 'auto', 'auto', 'direct', '2026-03-13T10:03:00Z');
"

sqlite3 "$DB_PATH" "UPDATE apps SET health_path='/api/health' WHERE pm2_name='diraaax-backend';"

echo "== single-app preview =="
HOME="$TMP_HOME" "$ROOT_DIR/bin/gas" deploy preview --no-ui \
  --app marbot-web \
  --domain app.example.test \
  --mode single-app \
  --ssl none \
  --yes | tee /tmp/gas-smoke-single-app.out >/dev/null

grep -q "managed by gas" /tmp/gas-smoke-single-app.out
grep -q "proxy_pass http://127.0.0.1:3000;" /tmp/gas-smoke-single-app.out

echo "== frontend-backend-split preview =="
HOME="$TMP_HOME" "$ROOT_DIR/bin/gas" deploy preview --no-ui \
  --frontend diraaax-frontend \
  --backend diraaax-backend \
  --domain split.example.test \
  --mode frontend-backend-split \
  --uploads /srv/apps/uploads \
  --ssl none \
  --yes | tee /tmp/gas-smoke-split.out >/dev/null

grep -q "proxy_pass http://127.0.0.1:4001;" /tmp/gas-smoke-split.out
grep -q "location /api/ {" /tmp/gas-smoke-split.out
grep -q "proxy_pass http://127.0.0.1:4000;" /tmp/gas-smoke-split.out
grep -q "alias /srv/apps/uploads;" /tmp/gas-smoke-split.out

echo "== frontend-backend-split preview (certbot-nginx) =="
HOME="$TMP_HOME" "$ROOT_DIR/bin/gas" deploy preview --no-ui \
  --frontend diraaax-frontend \
  --backend diraaax-backend \
  --domain split-ssl.example.test \
  --mode frontend-backend-split \
  --ssl certbot-nginx \
  --yes | tee /tmp/gas-smoke-split-ssl.out >/dev/null

grep -q "listen 443 ssl" /tmp/gas-smoke-split-ssl.out
grep -q "ssl_certificate /etc/letsencrypt/live/split-ssl.example.test/fullchain.pem;" /tmp/gas-smoke-split-ssl.out
grep -q "proxy_pass http://127.0.0.1:4001;" /tmp/gas-smoke-split-ssl.out
grep -q "proxy_pass http://127.0.0.1:4000;" /tmp/gas-smoke-split-ssl.out
test "$(grep -c 'return 301 https://split-ssl.example.test\$request_uri;' /tmp/gas-smoke-split-ssl.out)" -eq 2

echo "== frontend-backend-split preview (strip-prefix explicit) =="
HOME="$TMP_HOME" "$ROOT_DIR/bin/gas" deploy preview --no-ui \
  --frontend diraaax-frontend \
  --backend diraaax-backend \
  --domain split-strip.example.test \
  --mode frontend-backend-split \
  --backend-route /api/ \
  --backend-base-path / \
  --backend-strip-prefix yes \
  --ssl none \
  --yes | tee /tmp/gas-smoke-split-strip.out >/dev/null

grep -Fq 'rewrite ^/api/?(.*)$ /$1 break;' /tmp/gas-smoke-split-strip.out
grep -q "proxy_pass http://127.0.0.1:4000;" /tmp/gas-smoke-split-strip.out

echo "== custom-multi-location preview =="
HOME="$TMP_HOME" "$ROOT_DIR/bin/gas" deploy preview --no-ui \
  --domain custom.example.test \
  --mode custom-multi-location \
  --location '/=proxy:marbot-web' \
  --location '/api/=proxy:simpeg-api' \
  --location '/uploads/=alias:/srv/public/uploads' \
  --ssl none \
  --yes | tee /tmp/gas-smoke-custom.out >/dev/null

grep -q "proxy_pass http://127.0.0.1:3000;" /tmp/gas-smoke-custom.out
grep -q "proxy_pass http://127.0.0.1:5000;" /tmp/gas-smoke-custom.out
grep -q "alias /srv/public/uploads;" /tmp/gas-smoke-custom.out

rm -f /tmp/gas-smoke-single-app.out /tmp/gas-smoke-split.out /tmp/gas-smoke-split-ssl.out /tmp/gas-smoke-split-strip.out /tmp/gas-smoke-custom.out
echo "Smoke deploy preview OK"
