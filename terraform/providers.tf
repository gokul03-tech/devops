terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Optional remote state backend (create the storage account/container first):
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
