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

variable "synapse_workspace_name" {
  description = "Name of the Azure Synapse workspace."
  type        = string
  default     = "synwksynlabuks001"
}

variable "synapse_managed_resource_group_name" {
  description = "Name of the managed resource group created for the Synapse workspace."
  type        = string
  default     = "rg-synapse-managed-uksouth"
}

variable "synapse_sql_admin_login" {
  description = "Administrator login for the Synapse workspace SQL endpoint."
  type        = string
  default     = "sqladminsynlab"
}

variable "synapse_sql_admin_password" {
  description = "Administrator password for the Synapse workspace SQL endpoint."
  type        = string
  sensitive   = true
}

variable "synapse_managed_virtual_network_enabled" {
  description = "Whether to enable the Synapse managed virtual network."
  type        = bool
  default     = false
}

variable "synapse_public_network_access_enabled" {
  description = "Whether public network access is enabled for the Synapse workspace."
  type        = bool
  default     = true
}

locals {
  storage_account_name = "stsynlab${random_string.storage_suffix.result}"
  filesystem_name      = "synapse"
}

resource "azurerm_resource_group" "synapse_lab" {
  name     = "rg-synapse-lab-uks"
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
