# Jenkins setup and job configuration

## Install on Ubuntu 22.04

Run from the repository root on the VM after Terraform provisioning and the PeerLearn VM bootstrap:

```bash
sudo bash jenkins/setup-jenkins.sh
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Complete the unlock/setup wizard. The installer enables Jenkins, installs Java 17 plus Temurin Java 21 for current Jenkins LTS, installs Node.js 20 and build tools, and preinstalls the required plugins. Current Jenkins LTS requires Java 21 to run; Java 17 remains available on the VM, but Jenkins is explicitly configured to use Java 21.

Required plugins:

- Git
- GitHub
- Pipeline (the installer installs `workflow-aggregator`)
- SSH Agent
- Credentials Binding
- Workspace Cleanup (used by `cleanWs()` in the pipeline)

## Create the VM SSH credential

1. In Jenkins, open **Manage Jenkins → Credentials → System → Global credentials (unrestricted) → Add Credentials**.
2. Set **Kind** to **SSH Username with private key**.
3. Set **Scope** to **Global**, **Username** to the VM's `admin_username` (for example `azureuser`), and **ID** to `azure-vm-ssh`.
4. Choose **Enter directly** under Private Key and paste the private key whose public key Terraform installed on the VM. Keep this private key in Jenkins Credentials; never commit it to Git.
5. Save.

## Create the Pipeline job

1. Select **New Item**, enter a job name, choose **Pipeline**, and save.
2. In **General**, enable **GitHub project** and provide the repository URL if desired.
3. In **Pipeline**, choose **Pipeline script from SCM**, choose **Git**, set the repository URL and repository credentials if private, set **Branch Specifier** to `*/main`, and set **Script Path** to `Jenkinsfile`.
4. Save. Build parameters `VM_HOST` (public VM IP or DNS), `VM_USER` (SSH username), and optional `VM_SSH_HOST` (SSH override) are declared by the Jenkinsfile; set values when running the job or configure them as job parameters. When Jenkins and PeerLearn share one VM, use `VM_SSH_HOST=127.0.0.1` to avoid public-IP hairpin routing; `VM_HOST` remains the public address used by the health check.
5. Run **Build Now** once to check out, test, package, deploy, and verify the application.

The pipeline also polls SCM every two minutes as a fallback. Deploy and Verify stages run only for `main`; other branches still build, test, and archive the release. On the first deploy, the pipeline captures the VM SSH host key into its own `known_hosts` file using `ssh-keyscan`, then enforces `StrictHostKeyChecking=yes` for transfer and deployment.
