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
  default     = true
}

variable "synapse_public_network_access_enabled" {
  description = "Whether public network access is enabled for the Synapse workspace."
  type        = bool
  default     = true
}

variable "synapse_workspace_firewall_rule_name" {
  description = "Name of the Synapse workspace firewall rule for client access."
  type        = string
  default     = "allow-current-client-ip"
}

variable "synapse_workspace_firewall_start_ip_address" {
  description = "Start IP address for the Synapse workspace firewall rule."
  type        = string
  default     = "178.255.71.207"
}

variable "synapse_workspace_firewall_end_ip_address" {
  description = "End IP address for the Synapse workspace firewall rule."
  type        = string
  default     = "178.255.71.207"
}

variable "synapse_spark_pool_name" {
  description = "Name of the Synapse Spark pool."
  type        = string
  default     = "spark01"
}

variable "synapse_spark_node_size_family" {
  description = "Node size family for the Synapse Spark pool."
  type        = string
  default     = "MemoryOptimized"
}

variable "synapse_spark_node_size" {
  description = "Node size for the Synapse Spark pool."
  type        = string
  default     = "Small"
}

variable "synapse_spark_cache_size" {
  description = "Cache size for the Synapse Spark pool."
  type        = number
  default     = 100
}

variable "synapse_spark_autoscale_min_node_count" {
  description = "Minimum node count for Spark pool autoscale."
  type        = number
  default     = 3
}

variable "synapse_spark_autoscale_max_node_count" {
  description = "Maximum node count for Spark pool autoscale."
  type        = number
  default     = 3
}

variable "synapse_spark_autopause_delay_in_minutes" {
  description = "Idle time in minutes before the Spark pool auto-pauses."
  type        = number
  default     = 15
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

resource "azurerm_synapse_workspace" "synapse_lab" {
  name                                 = var.synapse_workspace_name
  resource_group_name                  = azurerm_resource_group.synapse_lab.name
  location                             = azurerm_resource_group.synapse_lab.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.synapse.id
  managed_resource_group_name          = var.synapse_managed_resource_group_name
  managed_virtual_network_enabled      = var.synapse_managed_virtual_network_enabled
  public_network_access_enabled        = var.synapse_public_network_access_enabled
  sql_administrator_login              = var.synapse_sql_admin_login
  sql_administrator_login_password     = var.synapse_sql_admin_password

  identity {
    type = "SystemAssigned"
  }

  tags = azurerm_resource_group.synapse_lab.tags
}

resource "azurerm_synapse_firewall_rule" "current_client" {
  name                 = var.synapse_workspace_firewall_rule_name
  synapse_workspace_id = azurerm_synapse_workspace.synapse_lab.id
  start_ip_address     = var.synapse_workspace_firewall_start_ip_address
  end_ip_address       = var.synapse_workspace_firewall_end_ip_address
}

resource "azurerm_synapse_spark_pool" "synapse_lab" {
  name                 = var.synapse_spark_pool_name
  synapse_workspace_id = azurerm_synapse_workspace.synapse_lab.id
  node_size_family     = var.synapse_spark_node_size_family
  node_size            = var.synapse_spark_node_size
  cache_size           = var.synapse_spark_cache_size
  spark_version        = "3.4"

  auto_scale {
    min_node_count = var.synapse_spark_autoscale_min_node_count
    max_node_count = var.synapse_spark_autoscale_max_node_count
  }

  auto_pause {
    delay_in_minutes = var.synapse_spark_autopause_delay_in_minutes
  }

  tags = azurerm_resource_group.synapse_lab.tags
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

output "synapse_workspace_name" {
  value = azurerm_synapse_workspace.synapse_lab.name
}

output "synapse_workspace_connectivity_endpoints" {
  value = azurerm_synapse_workspace.synapse_lab.connectivity_endpoints
}

output "synapse_workspace_firewall_rule_name" {
  value = azurerm_synapse_firewall_rule.current_client.name
}

output "synapse_spark_pool_name" {
  value = azurerm_synapse_spark_pool.synapse_lab.name
}
