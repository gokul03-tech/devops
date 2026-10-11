# Deployment runbook: Azure VM and Jenkins

This assessment deployment uses one Ubuntu 22.04 `Standard_B2s` VM for PeerLearn and Jenkins. It is a low-setup demonstration layout; a separate Jenkins VM or local Jenkins is also possible. Azure resources incur charges according to your subscription and region. Review Azure pricing before applying.

## 1. Prerequisites

- Azure CLI signed into a subscription with permission to create a resource group, networking, public IP, and VM.
- Terraform 1.5 or newer, Git, SSH, and `curl` on your workstation.
- A GitHub repository containing this project.
- The public IPv4 CIDR from which you will SSH to the VM.

Log in and confirm the target subscription:

```bash
az login
az account show --output table
export ARM_SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
```

Generate an SSH key if you do not already have a dedicated key. Keep the private file private and never commit it:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/peerlearn_azure -C peerlearn-azure
```

## 2. Provision the VM with Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`: choose a unique lowercase `prefix`, set the full absolute path to the SSH **public** key, set `allowed_ssh_cidr` to your public address with `/32`, and set `jenkins_allowed_cidrs` for port 8080. Terraform does not expand `~` in `file()`. To allow webhooks while restricting Jenkins, get GitHub's current `hooks` ranges from [the GitHub Meta API](https://api.github.com/meta) and include those plus your admin address in the list; for a short-lived assessment demo only, `0.0.0.0/0` works with Jenkins authentication enabled. Keep port 22 restricted.

Then format, validate, and review the plan:

```bash
terraform fmt -recursive
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan -out peerlearn.tfplan
terraform apply peerlearn.tfplan
```

`terraform.tfvars`, plan files, and local state are ignored by Git. Local state is suitable for this assessment only. For shared/team work, configure an Azure Storage account and container first, then enable the commented `backend "azurerm"` block in `terraform/providers.tf` and run `terraform init -migrate-state`.

Capture the outputs:

```bash
VM_IP="$(terraform output -raw public_ip)"
VM_USER="$(grep '^admin_username' terraform.tfvars | cut -d'=' -f2 | tr -d ' \"')"
terraform output
```

If that simple `grep` does not match your formatting, use the `admin_username` value directly from `terraform.tfvars`.

## 3. Bootstrap the application VM

Copy and run the idempotent bootstrap script:

```bash
scp -i ~/.ssh/peerlearn_azure ../deploy/setup-vm.sh ../deploy/nginx.conf ../deploy/peerlearn.service "$VM_USER@$VM_IP:/tmp/"
ssh -i ~/.ssh/peerlearn_azure "$VM_USER@$VM_IP" 'sudo bash /tmp/setup-vm.sh'
```

The script installs Nginx, Python, Node.js 20, the `peerlearn` service account and directories, and the systemd/Nginx configuration. It creates `/etc/peerlearn.env` once with a random JWT secret and the persistent SQLite path. It does not replace that file on reruns.

## 4. Install Jenkins on the same VM

Jenkins shares the app VM by default to avoid the cost of another VM. A B2s instance is recommended for the combined workload. Port 8080 must be reachable from GitHub webhook senders and your browser; restrict its NSG source ranges where practical. The app remains on port 80.

```bash
scp -i ~/.ssh/peerlearn_azure ../jenkins/setup-jenkins.sh "$VM_USER@$VM_IP:/tmp/"
ssh -i ~/.ssh/peerlearn_azure "$VM_USER@$VM_IP" 'sudo bash /tmp/setup-jenkins.sh'
```

The script installs Java 21, Git, Python tooling, Node.js 20, Jenkins LTS, and the Git, GitHub, Pipeline, SSH Agent, and Credentials Binding plugins. Java 21 is used because current Jenkins LTS no longer starts on Java 17; see [Jenkins' current installation guide](https://www.jenkins.io/doc/book/installing/linux/).

Open `http://<VM_IP>:8080`, unlock Jenkins with the initial administrator password (`sudo cat /var/lib/jenkins/secrets/initialAdminPassword` on the VM), and finish the first-run wizard. Create a Jenkins credential:

- Kind: **SSH Username with private key**
- ID: `azure-vm-ssh`
- Username: the Terraform `admin_username`
- Private key: the matching private key for the public key supplied to Terraform

The VM user's SSH key must be authorized (Terraform installs its public half). The Ubuntu cloud admin user can use `sudo` for `deploy.sh`.

In **Manage Jenkins → System → Global properties**, add these environment variables:

| Name | Value |
| --- | --- |
| `VM_IP` | Public IP output from Terraform, used for the HTTP health check |
| `VM_HOST` | `127.0.0.1` when Jenkins is on the app VM; use the VM's reachable SSH host if Jenkins is elsewhere |
| `VM_USER` | Terraform `admin_username` |

No secret is stored in those variables. The private key stays in the Jenkins credential store.

## 5. Create the Jenkins Pipeline job and webhook

1. In Jenkins choose **New Item → Pipeline** and give the job a name such as `peerlearn`.
2. Under **Pipeline**, select **Pipeline script from SCM**, choose Git, enter the GitHub clone URL and branch, and set the script path to `Jenkinsfile`. Add SCM credentials only if the repository is private.
3. Save and run **Build Now** once. Watch the console through Checkout, Backend Build & Test, Frontend Build & Test, Package, Deploy, and Verify. The first build may need to approve the Jenkins controller's access to the GitHub repository.
4. In GitHub open **Settings → Webhooks → Add webhook**. Set the payload URL to `http://<JENKINS_IP>:8080/github-webhook/`, content type to `application/json`, and select **Just the push event**. Save it and confirm GitHub reports a successful delivery.

The Jenkinsfile also polls SCM every two minutes as a fallback if the webhook cannot reach Jenkins. For local Jenkins without a public address, use Poll SCM or expose only the webhook endpoint through a temporary tunnel such as ngrok and use that tunnel URL in GitHub.

## 6. First deploy and verify

The first successful Pipeline run transfers a compressed release over SSH, installs Python dependencies in `/opt/peerlearn/venv`, initializes missing SQLite tables, installs the frontend build into `/var/www/peerlearn`, restarts the systemd service, reloads Nginx, and checks the health endpoint.

```bash
curl --fail "http://$VM_IP/api/health"
```

Expected response:

```json
{"status":"ok"}
```

Open `http://<VM_IP>` and register a student account. For a CD demonstration, change a visible line of UI copy in `frontend/src/pages.jsx`, commit and push to GitHub, then watch GitHub's webhook delivery and the Jenkins build. The new frontend appears after the pipeline's deployment and health verification succeed.

## Local Jenkins alternative

Run `jenkins/setup-jenkins.sh` on an Ubuntu host (or an Ubuntu/WSL environment where systemd and inbound routing work). Install the same credential and environment values. Set `VM_HOST` to the Azure app VM's reachable IP/DNS. If GitHub cannot reach your Jenkins host, leave Poll SCM enabled or use a temporary webhook tunnel. The Azure VM NSG must still allow SSH from the Jenkins host.

## Troubleshooting

| Symptom | Checks |
| --- | --- |
| Terraform cannot authenticate | Run `az login`, verify `az account show`, and confirm the correct subscription is selected. |
| SSH times out | Confirm `allowed_ssh_cidr` matches your current public IP, port 22 is allowed in the NSG, and the correct private key is selected. |
| Setup script did not finish | Run `sudo cloud-init status --long`, inspect `/var/log/cloud-init-output.log`, then rerun `setup-vm.sh`. |
| App health check fails | Run `sudo systemctl status peerlearn`, `sudo journalctl -u peerlearn -n 100`, and `sudo nginx -t`. Check `/etc/peerlearn.env` permissions and database directory ownership. |
| Frontend loads but API fails | Confirm Gunicorn listens on `127.0.0.1:8000`, inspect `/etc/nginx/sites-enabled/peerlearn`, then `sudo systemctl reload nginx`. |
| Jenkins service will not start | Run `java -version`, `sudo systemctl status jenkins`, and `sudo journalctl -u jenkins -n 100`. Current Jenkins needs Java 21 or newer. |
| GitHub webhook times out | Check the GitHub delivery details, port 8080 NSG source rules, Jenkins URL, and **GitHub hook trigger for GITScm polling**/Pipeline webhook plugin configuration. Poll SCM remains a fallback. |
| Pipeline SSH fails | Verify the `azure-vm-ssh` username/private key pair, `VM_HOST`, SSH host key prompt, and that the VM login can run `sudo` without an interactive password. |
| Deployment succeeds but health check fails | Inspect the `Deploy` console output and VM service logs. The release only initializes missing DB tables; it does not migrate changed columns. |
