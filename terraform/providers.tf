terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 4.81.0"
    }
  }

  # Optional remote state backend: first create an Azure Storage account and container,
  # then fill in these values and run `terraform init -migrate-state`.
  # backend "azurerm" {
  #   resource_group_name  = "peerlearn-tfstate-rg"
  #   storage_account_name = "<unique-storage-account>"
  #   container_name       = "tfstate"
  #   key                  = "peerlearn.terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
}
