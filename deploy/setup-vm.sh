#!/usr/bin/env bash
# One-time Ubuntu 22.04 bootstrap. Safe to rerun.
set -euo pipefail
if [[ "${EUID}" -ne 0 ]]; then echo "Run with sudo: sudo bash setup-vm.sh" >&2; exit 1; fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gnupg nginx python3 python3-venv python3-pip rsync openssl
if ! node --version 2>/dev/null | grep -q '^v20\.'; then
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg
  chmod a+r /etc/apt/keyrings/nodesource.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
  apt-get update
  apt-get install -y nodejs
fi
if ! id peerlearn >/dev/null 2>&1; then useradd --system --home-dir /opt/peerlearn --shell /usr/sbin/nologin peerlearn; fi
install -d -o peerlearn -g peerlearn /opt/peerlearn/backend /var/lib/peerlearn
install -d -o www-data -g www-data /var/www/peerlearn
if [[ ! -f /etc/peerlearn.env ]]; then
  install -m 0600 -o root -g root /dev/null /etc/peerlearn.env
  printf 'SECRET_KEY=%s\nDATABASE_PATH=/var/lib/peerlearn/peerlearn.db\n' "$(openssl rand -hex 32)" > /etc/peerlearn.env
fi
install -m 0644 "$(dirname "$0")/peerlearn.service" /etc/systemd/system/peerlearn.service
install -m 0644 "$(dirname "$0")/nginx.conf" /etc/nginx/sites-available/peerlearn
ln -sfn /etc/nginx/sites-available/peerlearn /etc/nginx/sites-enabled/peerlearn
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl daemon-reload
systemctl enable nginx peerlearn
systemctl restart nginx
echo "VM bootstrap complete. Deploy a release to start PeerLearn."
