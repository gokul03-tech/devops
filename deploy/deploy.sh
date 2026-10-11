#!/usr/bin/env bash
# Install an unpacked release directory or tar.gz; keep application snapshots for rollback.
set -euo pipefail
APP_ROOT=/opt/peerlearn
VENV="$APP_ROOT/venv"
RELEASES="$APP_ROOT/releases"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
INPUT="${1:-}"
TEMP_DIR=""
if [[ "${EUID}" -ne 0 ]]; then echo "Run with sudo: sudo bash deploy.sh <release-directory|release.tar.gz>" >&2; exit 1; fi
if [[ -z "$INPUT" ]]; then echo "Usage: deploy.sh <release-directory|release.tar.gz>" >&2; exit 2; fi
if [[ -f "$INPUT" && "$INPUT" == *.tar.gz ]]; then
  TEMP_DIR="$(mktemp -d /tmp/peerlearn-release.XXXXXX)"
  tar -xzf "$INPUT" -C "$TEMP_DIR"
  # A single top-level folder in the archive is accepted for convenience.
  if [[ ! -f "$TEMP_DIR/backend/app.py" && -f "$TEMP_DIR"/*/backend/app.py ]]; then
    INPUT="$(dirname "$(find "$TEMP_DIR" -mindepth 2 -path '*/backend/app.py' -print -quit)" | sed 's#/backend$##')"
  else
    INPUT="$TEMP_DIR"
  fi
elif [[ ! -d "$INPUT" ]]; then
  echo "Release must be a directory or .tar.gz archive: $INPUT" >&2; exit 2
fi
cleanup() { [[ -z "$TEMP_DIR" ]] || rm -rf -- "$TEMP_DIR"; }
trap cleanup EXIT
RELEASE_DIR="$(cd "$INPUT" && pwd)"
for required in "$RELEASE_DIR/backend/app.py" "$RELEASE_DIR/backend/requirements.txt" "$RELEASE_DIR/frontend/dist/index.html"; do
  if [[ ! -f "$required" ]]; then echo "Missing release file: $required" >&2; exit 1; fi
done
install -d -o peerlearn -g peerlearn "$APP_ROOT/backend" "$RELEASES" /var/lib/peerlearn
install -d -o www-data -g www-data /var/www/peerlearn
if [[ ! -x "$VENV/bin/python" ]]; then python3 -m venv "$VENV"; fi
# Save the last live code before overwriting it. SQLite stays in /var/lib/peerlearn.
if [[ -f "$APP_ROOT/backend/app.py" && -f /var/www/peerlearn/index.html ]]; then
  SNAPSHOT="$RELEASES/$STAMP"
  install -d -o peerlearn -g peerlearn "$SNAPSHOT/backend" "$SNAPSHOT/frontend/dist"
  rsync -a "$APP_ROOT/backend/" "$SNAPSHOT/backend/"
  rsync -a /var/www/peerlearn/ "$SNAPSHOT/frontend/dist/"
  chown -R peerlearn:peerlearn "$SNAPSHOT"
  echo "Saved previous release at $SNAPSHOT"
fi
rsync -a --delete "$RELEASE_DIR/backend/" "$APP_ROOT/backend/"
chown -R peerlearn:peerlearn "$APP_ROOT/backend" "$VENV" /var/lib/peerlearn
"$VENV/bin/pip" install --disable-pip-version-check -r "$APP_ROOT/backend/requirements.txt"
# Source the root-owned environment file so app configuration matches Gunicorn.
set -a
# shellcheck disable=SC1091
. /etc/peerlearn.env
set +a
runuser -u peerlearn -- env DATABASE_PATH="${DATABASE_PATH:-/var/lib/peerlearn/peerlearn.db}" \
  SECRET_KEY="${SECRET_KEY:-${JWT_SECRET:-}}" \
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
