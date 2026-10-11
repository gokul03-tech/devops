#cloud-config
package_update: true
packages:
  - ca-certificates
  - curl
  - nginx
  - python3
  - python3-venv
  - python3-pip
  - rsync
  - openssl
runcmd:
  - [bash, -lc, "id peerlearn >/dev/null 2>&1 || useradd --system --home-dir /opt/peerlearn --shell /usr/sbin/nologin peerlearn"]
  - [install, -d, -o, peerlearn, -g, peerlearn, /opt/peerlearn/backend, /var/lib/peerlearn]
  - [install, -d, -o, www-data, -g, www-data, /var/www/peerlearn]
  - [bash, -lc, "if [ ! -f /etc/peerlearn.env ]; then printf 'JWT_SECRET=%s\\nDATABASE_PATH=/var/lib/peerlearn/peerlearn.db\\n' \"$(openssl rand -hex 32)\" > /etc/peerlearn.env; chmod 600 /etc/peerlearn.env; fi"]
  - [systemctl, enable, --now, nginx]
