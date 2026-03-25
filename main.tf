terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  storage_account_name = "stsynlab${random_string.storage_suffix.result}"
  filesystem_name      = "synapse"
}

resource "azurerm_resource_group" "synapse_lab" {
  name     = "rg-synapse-lab-uksouth"
  location = "UK South"

  tags = {
    workload    = "synapse-lab"
    environment = "lab"
  }
}

resource "random_string" "storage_suffix" {
  length  = 8
  upper   = false
  special = false
  numeric = true
}

resource "azurerm_storage_account" "synapse_lab" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.synapse_lab.name
  location                 = azurerm_resource_group.synapse_lab.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true

  tags = azurerm_resource_group.synapse_lab.tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "synapse" {
  name               = local.filesystem_name
  storage_account_id = azurerm_storage_account.synapse_lab.id
}

output "resource_group_name" {
  value = azurerm_resource_group.synapse_lab.name
}

output "storage_account_name" {
  value = azurerm_storage_account.synapse_lab.name
}

output "data_lake_filesystem_name" {
  value = azurerm_storage_data_lake_gen2_filesystem.synapse.name
}
