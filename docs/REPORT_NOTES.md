# Report notes (ready to adapt)

## Objectives

PeerLearn implements a full-stack peer-learning exchange: students maintain teach/learn profiles, discover learning partners, coordinate sessions, and leave reviews after completion. The project packages the app for an Azure Ubuntu VM, provisions the host with Terraform, and automates build/test/deployment with Jenkins.

## Tools used and why

| Tool | Use |
| --- | --- |
| React, Vite, Tailwind CSS, React Router | Responsive single-page application, development proxy, component styling, navigation |
| Flask, Flask-SQLAlchemy, PyJWT, Werkzeug | JSON API, relational data mapping, token auth, password hashing |
| SQLite | Small self-contained demo database stored outside code deploys |
| pytest, Vitest, React Testing Library | API behavior, UI behavior, route, match, and session-action checks |
| Nginx, Gunicorn, systemd | Serve the static SPA, proxy the API, run Flask reliably as a service |
| Terraform and AzureRM | Reproducibly define Azure networking, firewall, public address, and Ubuntu VM |
| Jenkins, SSH Agent, SCP | Test, package, deploy releases, and verify the health endpoint |
| curl and jq/Python | Exercise the API end to end from shell and report each step |

## Terraform resources

| Resource | Purpose |
| --- | --- |
| `azurerm_resource_group` | Groups the PeerLearn Azure resources |
| `azurerm_virtual_network` and `azurerm_subnet` | Private VM network and subnet |
| `azurerm_network_security_group` | Restricts SSH/Jenkins ingress and allows HTTP/HTTPS |
| `azurerm_network_interface_security_group_association` | Applies the NSG to the VM NIC |
| `azurerm_public_ip` | Static Standard public IPv4 address with optional DNS label |
| `azurerm_network_interface` | Attaches the subnet and public IP to the VM |
| `azurerm_linux_virtual_machine` | Ubuntu 22.04 VM with SSH key auth, Standard_LRS OS disk, and cloud-init |

## Jenkins pipeline stages

| Stage | Work |
| --- | --- |
| Checkout | Fetch the selected repository revision |
| Backend Build & Test | Create Python venv, install requirements, run pytest |
| Frontend Build & Test | Run `npm ci`, Vitest, and the Vite production build |
| Package | Create and archive a tar.gz containing backend, frontend build, and deploy scripts |
| Deploy | On `main`, transfer with SSH/SCP and run the VM deploy script using `azure-vm-ssh` |
| Verify | On `main`, retry `GET http://$VM_HOST/api/health` and fail if unhealthy |

The pipeline polls SCM every two minutes and accepts GitHub push webhooks. Host keys are added to the Jenkins user's `known_hosts` using `ssh-keyscan` on first contact and then checked strictly.

## Assessment requirements 1–4

The exact assessment rubric text was not included with the project prompt. The mapping below groups the requested deliverables into four work packages; adjust the requirement labels if the rubric numbers different criteria.

| Requirement | Implementation evidence |
| --- | --- |
| 1. Full-stack peer-learning application | `backend/app.py`, `backend/matching.py`, `frontend/src/`, `backend/tests/`, `frontend/src/components.test.jsx` |
| 2. Azure infrastructure as code | `terraform/providers.tf`, `terraform/variables.tf`, `terraform/main.tf`, `terraform/outputs.tf`, `terraform/cloud-init.sh` |
| 3. Linux deployment and local integration | `deploy/`, `scripts/run_local.sh`, `scripts/smoke_test.sh`, `README.md` |
| 4. Automated CI/CD and project documentation | `Jenkinsfile`, `jenkins/`, `docs/`, `terraform/README.md` |

## Screenshots checklist

- Registration and login forms.
- Dashboard recommended partners, upcoming sessions, and counts.
- Profile details, availability slots, and teach/learn skills.
- Find-partner search and a Mutual Exchange match card.
- Session request modal with date/time and optional meeting link.
- Incoming/outgoing session tabs and valid actions/status badges.
- Completed session review and taught/learned history.
- Successful Jenkins pipeline with all stages and health verification.
- Terraform plan/resource outputs (redact account identifiers if required by the course).
- Deployed app open in a browser at the Azure app URL.

## Challenges and lessons learned

- Seed data needs to be repeatable without silently resetting user passwords; the seed CLI now reports a generated password only on first creation.
- JWT signing configuration must remain stable across deployments, so the VM keeps its generated secret in `/etc/peerlearn.env`.
- SQLite data must stay outside code release directories; deploy snapshots only the prior application code.
- Session permissions and valid status transitions belong in the API, with the frontend hiding actions that are invalid for the current participant/status.
- Azure NSGs, VM firewalls, and Jenkins webhooks must agree on allowed sources; exposing Jenkins broadly increases risk.
- Jenkins LTS currently needs Java 21, so the VM has Java 17 installed as requested while Jenkins uses Temurin 21.
- `db.create_all()` is not a schema migration mechanism; future schema changes need explicit migrations and backups.

## Future improvements

- PostgreSQL plus database migrations for concurrent production use.
- HTTPS with a real domain and automated certificate renewal.
- Docker/container deployment where operational requirements justify it.
- Monitoring, centralized logs, backups, and alerts.
- Secure, httpOnly cookie token storage and stronger production security headers.
- Calendar integrations, email notifications, and browser-level end-to-end tests.
