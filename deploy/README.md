# VM deployment files

`setup-vm.sh` is the idempotent Ubuntu 22.04 bootstrap. It installs Nginx and the Python/Node host packages, creates the `peerlearn` service account and persistent database directory, writes `/etc/peerlearn.env` only when absent, and installs the systemd/Nginx configuration.

After Jenkins transfers a release tarball to the VM, the pipeline unpacks it and invokes the deploy script:

```bash
mkdir -p /tmp/peerlearn-release
tar -xzf /tmp/peerlearn-release.tar.gz -C /tmp/peerlearn-release
sudo bash /tmp/peerlearn-release/deploy/deploy.sh /tmp/peerlearn-release
```

If `deploy.sh` is already on the VM, it can accept the `.tar.gz` path directly. Deploy snapshots the current backend and frontend build under `/opt/peerlearn/releases/`, keeps the SQLite file in `/var/lib/peerlearn/`, restarts the three-worker Gunicorn service bound to `127.0.0.1:8000`, reloads Nginx, and checks `/api/health`. To restore the newest saved code snapshot:

```bash
sudo peerlearn-rollback
```

The bootstrap and deployment scripts require root privileges on Ubuntu. They were syntax-checked in this workspace; no local Ubuntu VM or Docker runtime was available for an actual host deployment test.
