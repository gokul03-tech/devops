# Azure VM infrastructure

This Terraform configuration creates an Ubuntu 22.04 VM, static public IP, VNet/subnet, NIC, and an NSG. SSH and Jenkins access are restricted to the CIDRs you provide. HTTP and HTTPS are public. VM initialization installs the host packages and OpenJDK 17; the Jenkins installer configures its supported Java runtime separately.

## Prerequisites

- Azure CLI, Terraform 1.5+, and an Azure subscription with permission to create resources.
- An SSH key pair. The VM accepts key authentication only.
- A public IPv4 CIDR for SSH and a restricted CIDR for Jenkins, such as your admin address `/32`. GitHub webhook source ranges must also be reachable if GitHub hosts the Jenkins webhook sender.

## Provision

From this directory, run the following commands. Edit `terraform.tfvars` first: set your SSH public key path, your real allowed CIDRs, and a globally unique optional DNS label.

```bash
az login
az account show
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out peerlearn.tfplan
terraform apply peerlearn.tfplan
terraform output
```

The outputs include the app URL, Jenkins URL, public IP, and SSH command. The DNS label is optional and Azure requires it to be globally unique. If Terraform reports that the label is already taken, change or clear `dns_label` and apply again.

## Remote state (optional)

The commented `backend "azurerm"` block in `providers.tf` can be enabled after creating an Azure Storage account and blob container. Fill in the backend resource group, account, container, and key, then run `terraform init -migrate-state`.

## Cleanup

Destroying the configuration deletes the VM, public IP, networking, and resource group. Save any data you need first. The external application database path used by the VM is on its OS disk in `/var/lib/peerlearn`; deleting the VM deletes that database unless you backed it up separately.

```bash
terraform plan -destroy
terraform destroy
```
