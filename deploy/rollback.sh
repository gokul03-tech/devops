#!/usr/bin/env bash
# Restore code from the newest saved snapshot without touching the SQLite database.
set -euo pipefail
APP_ROOT=/opt/peerlearn
RELEASES="$APP_ROOT/releases"
if [[ "${EUID}" -ne 0 ]]; then echo "Run with sudo: sudo bash rollback.sh" >&2; exit 1; fi
LATEST="$(find "$RELEASES" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r | head -n 1)"
if [[ -z "$LATEST" ]]; then echo "No saved release snapshot exists." >&2; exit 1; fi
SNAPSHOT="$RELEASES/$LATEST"
if [[ ! -f "$SNAPSHOT/backend/app.py" || ! -f "$SNAPSHOT/frontend/dist/index.html" ]]; then
  echo "Snapshot is incomplete: $SNAPSHOT" >&2; exit 1
fi
rsync -a --delete "$SNAPSHOT/backend/" "$APP_ROOT/backend/"
rsync -a --delete "$SNAPSHOT/frontend/dist/" /var/www/peerlearn/
chown -R peerlearn:peerlearn "$APP_ROOT/backend"
chown -R www-data:www-data /var/www/peerlearn
systemctl restart peerlearn
nginx -t
systemctl reload nginx
echo "Restored application code from $SNAPSHOT. The database was not changed."
