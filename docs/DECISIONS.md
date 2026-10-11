# Decisions and assumptions

This document consolidates assumptions used across the implementation phases.

## Application and API

- The existing Phase 1 Flask API is the source of truth for route paths and JSON shapes. Frontend API requests always use the `/api` base path.
- The browser stores the bearer JWT in `localStorage`; authenticated API calls send `Authorization: Bearer <token>`. A 401 clears local auth and redirects to `/login`.
- Passwords are hashed with Werkzeug. There is no password reset, email verification, or role system in this assessment application.
- SQLite is the project database. The app accepts `DATABASE_URL` or `DATABASE_PATH`; VM deploys set `DATABASE_PATH=/var/lib/peerlearn/peerlearn.db`.
- `SECRET_KEY` is the preferred JWT signing environment variable. `JWT_SECRET` remains a compatibility fallback, and the app uses a process-generated key if neither variable is set. Production must keep a stable configured key in `/etc/peerlearn.env`.
- Availability is a list in the API and a comma-separated string in the SQLite user row. Profile input accepts comma-separated availability slots.
- Skill names share a global catalog and are matched case-insensitively; display capitalization from the first creation is retained.
- A mutual exchange means the requester teaches at least one skill that the candidate wants to learn. The matching score adds 3 for that exchange, 1 per shared availability slot, and 1 for matching non-empty departments.
- Session times are free-form strings in the backend. The frontend sends a `datetime-local` value. The backend does not perform timezone conversion or validate that the time is in the future.
- A session partner must teach the requested skill. Only the invited partner can accept/reject; either participant can cancel Pending/Accepted sessions or complete Accepted sessions.
- Either session participant may submit one rating (1–5) and feedback after completion. Reviews are unique per `(session_id, reviewer_id)`.
- The history endpoint includes only completed sessions. It returns the session and its reviews; the UI labels the requested skill as taught by the invited partner and learned by the requester.
- `db.create_all()` creates tables that do not exist but does not migrate modified columns. Future schema changes need an explicit migration plan and a backup.
- Seed demo users share one random password on first creation. The CLI prints it once; subsequent seed runs preserve account passwords. A regression test covers the return behavior and idempotent repeat.

## Local development and integration

- `scripts/run_local.sh` runs from Bash on Linux/macOS or a compatible environment. It creates `backend/.venv`, installs Python dependencies, seeds the default database, ensures frontend packages exist, and starts Flask on `:5000` and Vite on `:5173`.
- The local default DB path is relative to the backend working directory (`backend/peerlearn.db`). Production instead uses the absolute `/var/lib/peerlearn/peerlearn.db` path.
- `scripts/smoke_test.sh` requires curl and Python for fallback JSON parsing; jq is optional. It creates uniquely named accounts and skills rather than modifying the demo accounts.
- The Windows sandbox used for this implementation blocks connections to a local Flask listener. Pytest covers the equivalent flow in-process, but the curl smoke script could not be completed against localhost in this environment.
- No local Ubuntu VM or Docker engine was available for a real bootstrap/deploy dry run. Deployment scripts were syntax checked; an actual Azure deploy requires the user's Azure account.

## Deployment and cloud

- The target is one Ubuntu 22.04 Azure VM with Nginx on 80/443, Gunicorn bound to `127.0.0.1:8000`, and app files under `/opt/peerlearn` and `/var/www/peerlearn`.
- `setup-vm.sh` generates a random `SECRET_KEY` only if `/etc/peerlearn.env` is absent. Deploy snapshots backend/static code under `/opt/peerlearn/releases/`; it never places the database inside release files. Rollback restores code only.
- The service account is `peerlearn`; Nginx static files belong to `www-data`. The VM admin account retains sudo access for deployments.
- The Terraform example opens SSH and Jenkins to the configured CIDRs, and HTTP/HTTPS publicly. Its current `allowed_jenkins_cidr` accepts one CIDR; covering multiple GitHub webhook ranges may require adding tracked NSG rules. Keep administrative ingress narrow.
- Terraform state is local by default. The Azure Storage remote backend example is commented until the user creates the storage account/container. No `terraform apply` was performed.
- The optional DNS label must be globally unique in Azure. Public IP remains the address fallback when no label is configured.
- The assessment materials do not include the exact numbered requirements 1–4. `REPORT_NOTES.md` maps the requested app, infrastructure, deployment, and CI/CD work into four categories as a clearly stated assumption.

## Jenkins and validation

- Jenkins and the app can share one VM for this demonstration. `VM_HOST` is the public address for HTTP health checks; `VM_SSH_HOST=127.0.0.1` can avoid public-IP hairpin routing for same-VM SSH.
- `VM_HOST`, `VM_USER`, and optional `VM_SSH_HOST` are Jenkins build parameters. The deployment private key stays in credential ID `azure-vm-ssh`. The pipeline bootstraps `known_hosts` with `ssh-keyscan` on first connection and then uses strict checking.
- Jenkins LTS 2.555.1 and newer requires Java 21. The host bootstrap installs Java 17 as requested and Temurin 21 for the current Jenkins runtime. See [Jenkins Java support policy](https://www.jenkins.io/doc/book/platform-information/support-policy-java/) and [the 2.555.1 release notes](https://www.jenkins.io/changelog/2.555.1/).
- The pipeline uses `githubPush()` and polls SCM every two minutes. Deploy and Verify stages are gated to `main`.
- Terraform `fmt -check`, `init -backend=false`, and `validate` were run successfully. `terraform apply` was intentionally not run. Frontend tests/build and backend pytest passed. Jenkinsfile lint was not run because no Jenkins controller or Groovy executable was available; the declarative pipeline was reviewed. ShellCheck was not installed.
