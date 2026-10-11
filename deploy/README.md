# VM deployment files

`setup-vm.sh` is the idempotent Ubuntu 22.04 bootstrap. It installs Nginx and the Python/Node host packages, creates the `peerlearn` service account and persistent database directory, writes `/etc/peerlearn.env` only when absent, and installs the systemd/Nginx configuration.

After the repository's Jenkins package stage transfers a release tarball to the VM, the deployment script accepts the archive directly:

```bash
mkdir -p /tmp/peerlearn-release
tar -xzf /tmp/peerlearn-release.tar.gz -C /tmp/peerlearn-release
sudo bash /tmp/peerlearn-release/deploy/deploy.sh /tmp/peerlearn-release
```

The deployment script also accepts the `.tar.gz` path directly. It snapshots the current backend and frontend build under `/opt/peerlearn/releases/`, keeps the SQLite file in `/var/lib/peerlearn/`, restarts Gunicorn, reloads Nginx, and checks `/api/health`. To restore the newest saved code snapshot:

```bash
sudo bash deploy/rollback.sh
```

The bootstrap and deployment scripts require root privileges on Ubuntu. They were syntax-checked in this workspace; no local Ubuntu VM or Docker runtime was available for an actual host deployment test.
