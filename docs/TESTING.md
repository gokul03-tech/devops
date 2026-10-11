# Testing and verification

## Backend tests

From the repository root:

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pytest -q
```

The API tests cover registration/login, password hashing, JWT checks, profile and availability validation, skill associations, mutual-match ranking and filters, session status transitions and permissions, reviews, history, and the end-to-end API flow. `test_seed.py` checks that the first seed returns its generated password and a second seed leaves accounts unchanged. Most API tests use in-memory SQLite; the seed test uses a temporary SQLite file.

## Frontend tests and production build

```bash
cd frontend
npm ci
npm run test -- --run
npm run build
```

Vitest with React Testing Library checks the login form, signed-out redirect, mutual-exchange match card, and valid session action buttons. `npm run build` writes the optimized SPA to `frontend/dist/`, which is copied to `/var/www/peerlearn` on deployment.

## HTTP smoke test

Start the API at port 5000 (or use another `BASE_URL`), then run from the repository root:

```bash
bash scripts/smoke_test.sh
```

The smoke script uses curl and parses responses with jq when installed, otherwise Python's JSON library. It registers two unique users, explicitly logs both in, adds reciprocal teach/learn skills, verifies the match type is `Mutual Exchange`, creates a session, accepts and completes it, submits a review, and verifies the completed session in `/api/history`. It prints a PASS line per step and exits nonzero on failure.

To run the local development app and database seed together, use `bash scripts/run_local.sh`; press Ctrl+C to stop both servers. On systems that restrict local loopback networking, run the curl smoke test in an unrestricted shell/VM.

## Terraform checks

From `terraform/`:

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

The AzureRM provider must be downloaded during init. No `terraform apply` is part of validation because it provisions billable Azure resources. Use the instructions in `terraform/README.md` only when intentionally deploying.

## Shell and pipeline review

Syntax-check shell scripts with:

```bash
bash -n scripts/run_local.sh scripts/smoke_test.sh deploy/setup-vm.sh deploy/deploy.sh deploy/rollback.sh jenkins/setup-jenkins.sh
```

Run `shellcheck` on the same files if installed. A Jenkinsfile can be checked using the Jenkins Declarative Pipeline linter at **Manage Jenkins → Tools and Actions → Declarative Pipeline Linter** or by POSTing it to the controller's `/pipeline-model-converter/validate` endpoint. The pipeline also executes the app's tests and deploy health check on its configured Jenkins host.
