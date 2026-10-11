# Report notes

- **Objective:** Build a demonstrable campus peer-learning exchange with matching, session coordination, and post-session feedback.
- **Tools:** React, Vite, Tailwind CSS, Flask, Flask-SQLAlchemy, Flask-CORS, PyJWT, Werkzeug, SQLite, Gunicorn, Nginx, systemd, Terraform, Azure VM, Jenkins, pytest, and Vitest.
- **Application capabilities:** Password-hashed accounts; JWT-protected endpoints; teach/learn profiles; mutual-first peer ranking; permission-checked session lifecycle; one review per participant for completed sessions.
- **Terraform resources:** Resource group, virtual network, subnet, network security group and rules, static Standard public IP, network interface, network interface/NSG association, and Ubuntu 22.04 Linux virtual machine with SSH-key-only access and cloud-init.
- **Pipeline stages:** Checkout; backend dependency install and pytest coverage gate; frontend `npm ci`, Vitest, and production build; release tarball/archive; SSH/SCP deployment; retrying `/api/health` verification.
- **Screenshots checklist:** Registration/login; dashboard; profile skills; mutual exchange result; incoming request; accepted/completed session; review/history; Jenkins successful pipeline; Terraform resource summary; deployed app in browser.
- **Challenges and lessons:** Keep SQLite outside deployed code; keep session permissions enforced on the server; make matching deterministic and independently testable; ensure public Jenkins access is CIDR-restricted; align Jenkins' Java runtime with the current supported release.
- **Future improvements:** PostgreSQL for concurrent production use; schema migrations; HTTPS and domain name; secure cookie-based tokens; richer calendar availability; email notifications; automated browser-level tests; Docker only if deployment requirements later change.
