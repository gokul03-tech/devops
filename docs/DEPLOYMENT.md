# Zero-to-live deployment runbook

This runbook provisions a single Azure Ubuntu 22.04 VM for the app and Jenkins. Confirm expected Azure charges before creating resources. `Standard_B2s` is the configured default; actual availability and cost vary by region and subscription.

## Prerequisites

- Azure CLI, Terraform 1.5+, Git, SSH, and `curl` on the workstation.
- An Azure subscription with permission to create a resource group, VNet, NSG, public IP, NIC, and VM.
- A GitHub repository containing this project and an SSH key pair for the VM.
- Your current public IPv4 CIDR for SSH and a chosen CIDR for inbound Jenkins port 8080.

## 1. Log in and prepare the SSH key

```bash
az login
az account show --output table
ssh-keygen -t ed25519 -f ~/.ssh/peerlearn_azure -C peerlearn-azure
```

If a suitable key already exists, use it instead. Keep the private key private and never add it to Git. The Terraform VM resource installs the public key and disables password authentication.

## 2. Create the Azure VM

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`: set `ssh_public_key_path` to the absolute path to your public key file, `allowed_ssh_cidr` to your admin public address with `/32`, `allowed_jenkins_cidr` to the intended source for TCP 8080, a unique `prefix`, and optionally a globally unique lowercase `dns_label`. Terraform does not expand `~` inside `file()`.

```bash
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan -out peerlearn.tfplan
terraform apply peerlearn.tfplan
terraform output
```

The `app_url`, `jenkins_url`, `public_ip`, and `ssh_command` outputs are the connection details. HTTP 80 and HTTPS 443 are public in the NSG; SSH 22 and Jenkins 8080 are restricted. `allowed_jenkins_cidr` takes one CIDR. If GitHub's webhook source range is not included, webhook delivery will be blocked; the configured Poll SCM trigger remains available, or you can add narrowly scoped webhook NSG rules as a tracked Terraform change.

Do not run `terraform destroy` until you have backed up any data you need. The Terraform state is local by default. For team use, create Azure Storage and enable the commented backend in `terraform/providers.tf` before using `terraform init -migrate-state`.

## 3. SSH into the VM and run the app bootstrap

Copy the bootstrap artifacts from the repository to the VM, then run the script:

```bash
VM_IP="$(terraform output -raw public_ip)"
VM_USER="azureuser" # replace with admin_username from terraform.tfvars
scp -i ~/.ssh/peerlearn_azure ../deploy/setup-vm.sh ../deploy/nginx.conf ../deploy/peerlearn.service "$VM_USER@$VM_IP:/tmp/"
ssh -i ~/.ssh/peerlearn_azure "$VM_USER@$VM_IP" 'sudo bash /tmp/setup-vm.sh'
```

`setup-vm.sh` installs Python/venv/pip, Nginx, rsync, Node.js 20 and supporting packages; creates the non-root `peerlearn` app account and directories; creates `/etc/peerlearn.env` only if absent with a random `SECRET_KEY` and `DATABASE_PATH=/var/lib/peerlearn/peerlearn.db`; and enables Nginx/systemd. The database remains outside the release tree at `/var/lib/peerlearn/peerlearn.db`.

## 4. Install Jenkins and create the SSH credential

```bash
scp -i ~/.ssh/peerlearn_azure ../jenkins/setup-jenkins.sh "$VM_USER@$VM_IP:/tmp/"
ssh -i ~/.ssh/peerlearn_azure "$VM_USER@$VM_IP" 'sudo bash /tmp/setup-jenkins.sh'
ssh -i ~/.ssh/peerlearn_azure "$VM_USER@$VM_IP" 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'
```

Open `http://<VM_IP>:8080`, unlock Jenkins, and finish its wizard. The installer adds Java 17 plus Temurin Java 21, Node.js 20, Git, Python tools, Jenkins LTS, and the required plugins. Jenkins currently needs Java 21 to run; Java 17 remains installed for the VM as requested. See [jenkins/README.md](../jenkins/README.md) for plugin names and details.

In **Manage Jenkins → Credentials → System → Global credentials → Add Credentials**, create:

- Kind: **SSH Username with private key**
- ID: `azure-vm-ssh`
- Username: the Terraform `admin_username`
- Private key: the matching private key for the VM's installed public key

The Linux admin user needs to use `sudo` for `deploy.sh`; the default Ubuntu cloud admin account has that ability.

## 5. Create the Pipeline job and configure GitHub

1. In Jenkins select **New Item → Pipeline**.
2. Under **Pipeline**, select **Pipeline script from SCM**, select Git, enter the repository URL, set the branch to `*/main`, and use `Jenkinsfile` as the script path. Supply SCM credentials if the repository is private.
3. Jenkinsfile parameters: set `VM_HOST` to the VM public IP/DNS, `VM_USER` to `admin_username`, and `VM_SSH_HOST` to `127.0.0.1` when Jenkins shares the VM. `VM_HOST` is used for the public HTTP check; the override avoids public-IP hairpin SSH routing.
4. Select **Build Now** on the main branch. The stages checkout, test backend, test/build frontend, package/archive the release, deploy over SSH, and verify `/api/health`.
5. On GitHub go to **Repository Settings → Webhooks → Add webhook** and set:
   - Payload URL: `http://<JENKINS_IP>:8080/github-webhook/`
   - Content type: `application/json`
   - Events: **Just the push event**
6. Save and verify a successful delivery in GitHub's **Recent Deliveries** tab.

Jenkins polls every two minutes as a backup if a webhook cannot reach it. A local-only Jenkins can use Poll SCM. A webhook from GitHub needs a reachable URL, such as an appropriately secured temporary ngrok URL; see [docs/JENKINS_WEBHOOK.md](JENKINS_WEBHOOK.md). Keep inbound port 8080 narrow. The Terraform input supports one CIDR, so a deployment that needs multiple GitHub webhook ranges must add those rules explicitly in Terraform.

## 6. Verify the first deployment

```bash
curl --fail "http://$VM_IP/api/health"
```

Expected JSON:

```json
{"status":"ok"}
```

Open `http://<VM_IP>` in a browser and register an account. The Jenkins deploy step stores the previous backend and static frontend files under `/opt/peerlearn/releases/`; `/var/lib/peerlearn/peerlearn.db` stays out of each code deployment. To restore the newest saved app code on the VM:

```bash
sudo peerlearn-rollback
```

## 7. Demonstrate continuous deployment

Edit a visible UI string in `frontend/src/pages.jsx`, commit it, and push to GitHub's `main` branch. Confirm that the GitHub webhook reports successful delivery, then watch the Jenkins build stages through Verify. Refresh the app in a browser after the health check succeeds; the updated string should be visible.

## Troubleshooting

| Symptom | Checks and recovery |
| --- | --- |
| SSH denied or timed out | Confirm the right private key and username, that `allowed_ssh_cidr` matches your current public IP, and that NSG TCP 22 is open. Check `ssh -vvv`. |
| NSG blocks the app or Jenkins | Verify rules for TCP 80/443 and the configured restricted CIDR for TCP 8080. Terraform's Jenkins variable accepts one CIDR. |
| GitHub webhook does not fire | Check the repository's Recent Deliveries response, exact `/github-webhook/` URL, `application/json`, push event, plugin, VM reachability, and NSG port 8080. Poll SCM still runs every two minutes. |
| Nginx returns 502 | Run `sudo nginx -t`, `sudo systemctl status peerlearn`, `sudo journalctl -u peerlearn -n 100`, and verify Gunicorn is bound to `127.0.0.1:8000`. |
| Gunicorn does not start | Check `sudo systemctl status peerlearn`, `sudo journalctl -u peerlearn -n 100`, `/etc/peerlearn.env`, `/opt/peerlearn/venv`, and Python package installation. |
| Permission error during deployment | Check ownership of `/opt/peerlearn/backend`, `/opt/peerlearn/venv`, `/var/www/peerlearn`, and `/var/lib/peerlearn`; the app service runs as `peerlearn`. |
| Reviews, users, or skills disappear | Confirm `DATABASE_PATH` is `/var/lib/peerlearn/peerlearn.db`, not a file under the release path. Back up this file independently. |
| Main branch does not deploy | Check the branch specifier, `BRANCH_NAME`/SCM branch detection, build parameters, Jenkins credential ID `azure-vm-ssh`, and `VM_SSH_HOST`. |

`db.create_all()` creates missing tables but is not a schema migration system. Back up the database before future schema changes.

## Cleanup

Deleting Azure resources can remove billable resources, but it also deletes the VM's OS disk and the SQLite database stored there. Back up `/var/lib/peerlearn/peerlearn.db` and any needed SSH keys/artifacts first. From `terraform/`:

```bash
terraform plan -destroy
terraform destroy
```

Check the Azure portal afterward to confirm no billable public IP, disk, or resource group resources remain. **Cost warning:** leaving the VM or public IP running continues to incur charges; verify your subscription's current pricing before and after deployment.
