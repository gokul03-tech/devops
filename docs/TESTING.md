# Testing

## Backend

Install `backend/requirements.txt`, then run:

```bash
cd backend
pytest -q --cov=matching --cov=app --cov-report=term-missing
```

Pytest uses a fresh in-memory SQLite database per test. The suite covers registration/login, password hashing, JWT auth, profile validation, skill creation/removal, mutual matching priority and filters, session transitions and access control, review eligibility/uniqueness, and the complete registration-to-review flow. Matching reached 100% coverage in the checked local run; the API and matching modules reached 91% combined coverage.

## Frontend

```bash
cd frontend
npm ci
npm test
npm run build
```

Vitest checks route protection and the authenticated navigation shell. The Vite build creates `frontend/dist`, which Nginx serves in production.

## Local API smoke test

With Flask running on `127.0.0.1:5000`, from the repository root run:

```bash
bash scripts/smoke_test.sh
```

The script uses curl to register two isolated users, add skills, verify the match, request and accept a session, complete it, submit a review, and check `/api/health`. Override the target with `BASE_URL=http://host:port bash scripts/smoke_test.sh`.

## Infrastructure and shell checks

```bash
cd terraform
terraform fmt -check -recursive
terraform init
terraform validate
```

If installed, run ShellCheck against `scripts/smoke_test.sh`, `deploy/setup-vm.sh`, `deploy/deploy.sh`, and `jenkins/setup-jenkins.sh`. `bash -n` provides a syntax-only check.
