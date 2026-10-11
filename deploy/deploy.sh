#!/usr/bin/env bash
# Deploy a packaged release directory; database state remains outside the release.
set -euo pipefail
RELEASE_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
APP_ROOT=/opt/peerlearn
VENV="$APP_ROOT/venv"
if [[ "${EUID}" -ne 0 ]]; then echo "Run with sudo: sudo bash deploy.sh [release-directory]" >&2; exit 1; fi
for required in "$RELEASE_DIR/backend/app.py" "$RELEASE_DIR/backend/requirements.txt" "$RELEASE_DIR/frontend/dist/index.html"; do
  if [[ ! -f "$required" ]]; then echo "Missing release file: $required" >&2; exit 1; fi
done
install -d -o peerlearn -g peerlearn "$APP_ROOT/backend" /var/lib/peerlearn /var/www/peerlearn
if [[ ! -x "$VENV/bin/python" ]]; then python3 -m venv "$VENV"; fi
rsync -a --delete "$RELEASE_DIR/backend/" "$APP_ROOT/backend/"
chown -R peerlearn:peerlearn "$APP_ROOT/backend" "$VENV" /var/lib/peerlearn
"$VENV/bin/pip" install --disable-pip-version-check -r "$APP_ROOT/backend/requirements.txt"
# create_all initializes missing tables without deleting existing rows.
runuser -u peerlearn -- env DATABASE_PATH=/var/lib/peerlearn/peerlearn.db \
  JWT_SECRET="$(sed -n 's/^JWT_SECRET=//p' /etc/peerlearn.env | head -n 1)" \
  "$VENV/bin/python" -c 'from app import app, db; app.app_context().push(); db.create_all()'
rsync -a --delete "$RELEASE_DIR/frontend/dist/" /var/www/peerlearn/
chown -R www-data:www-data /var/www/peerlearn
systemctl restart peerlearn
nginx -t
systemctl reload nginx
for attempt in $(seq 1 12); do
  if curl --fail --silent http://127.0.0.1/api/health | grep -q '"status":"ok"'; then echo "PeerLearn deployment is healthy."; exit 0; fi
  sleep 2
done
echo "PeerLearn health check failed. Check: journalctl -u peerlearn -n 100" >&2
exit 1
