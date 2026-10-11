# Decisions and assumptions

- The workspace started without Git metadata, so Git was initialized to honor the requested phase commits.
- SQLite is the sole database. `DATABASE_PATH` selects its file; production stores it under `/var/lib/peerlearn` so code releases never replace user data.
- `db.create_all()` initializes absent tables during local startup/deploy. It does not alter existing tables; schema changes beyond additive table initialization need an explicit migration plan.
- Availability is stored as comma-separated text to keep the assessment model simple; API callers send and receive a list of slots.
- Session proposal time is a free-form string; the UI currently proposes “To be agreed” from partner search and participants can agree offline.
- Skills are added to the shared catalog when first used. Skill names are matched case-insensitively, while the stored display spelling is retained.
- Seed accounts use a random password printed only when accounts are created. Existing seed accounts are not silently reset on reruns.
- The seed command returns the generated demo password to its CLI entry point; a regression test covers first-run credential reporting and idempotent reruns.
- `SECRET_KEY` is the deployment and local configuration name for JWT signing. `JWT_SECRET` remains a fallback for existing local setups.
- The Azure VM defaults to `Standard_B2s` because the same VM is intended to host Jenkins and the app. Set a smaller size and disable Jenkins if separating CI or optimizing cost.
- Jenkins 2.555.1 and newer require Java 21. The requested Java 17 runtime would prevent current Jenkins LTS from starting, so the installer uses Temurin 21 on Ubuntu 22.04. This follows the current Jenkins support policy: [Jenkins Linux installation](https://www.jenkins.io/doc/book/installing/linux/) and [Java support policy](https://www.jenkins.io/doc/book/platform-information/support-policy-java/).
- Port 8080 is enabled by default for Jenkins only when `jenkins_allowed_cidrs` is supplied. Restrict this to your public admin IP and GitHub webhook source ranges.
- The default Jenkins-on-app-VM pipeline uses `VM_HOST=127.0.0.1` to avoid relying on public-IP hairpin routing; `VM_IP` is still the public health-check address.
- Terraform state remains local by default. The optional Azure Storage backend example is commented in `terraform/providers.tf`.
- Azure provisioning and GitHub webhook setup require the user's own Azure subscription and GitHub repository. No cloud resources or webhook are created by this repository build.
