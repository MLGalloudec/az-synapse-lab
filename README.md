# Azure Synapse Lab

This repo now covers the current foundation of the Synapse lab with Terraform:

- the resource group
- the storage account configured for ADLS Gen2
- the filesystem the Synapse workspace will later use as its default data lake
- the Synapse workspace itself
- the Synapse Spark pool for notebook execution

## What This Creates

- Resource group: `rg-synapse-lab-uks`
- Location: `UK South`
- Tags: `workload=synapse-lab`, `environment=lab`
- Storage account: `stsynlab<random-suffix>`
- ADLS Gen2 enabled: `true`
- Filesystem: `synapse`
- Synapse workspace: from `synapse_workspace_name`
- Synapse managed resource group: from `synapse_managed_resource_group_name`
- Synapse managed virtual network: `true` by default
- Synapse workspace firewall rule: current client IP
- Spark pool: from `synapse_spark_pool_name`
- Spark pool size: `Small` memory-optimized nodes
- Spark pool auto-pause: `15` minutes

The resource group name is fixed and descriptive for the lab. The storage account name includes a random suffix because Azure storage account names must be globally unique.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) installed
- Azure CLI installed (`az`)
- Logged into Azure:

```bash
az login
```

If you use multiple subscriptions, set the target subscription:

```bash
az account set --subscription "<subscription-id-or-name>"
```

## Files

- `main.tf`: Terraform configuration for the resource group, storage account, ADLS Gen2 filesystem, Synapse workspace, and Spark pool
- `scripts/rg.sh`: Helper script for Terraform create/destroy operations

## Synapse Workspace Variables

The Terraform uses these workspace inputs:

- `synapse_workspace_name`
- `synapse_managed_resource_group_name`
- `synapse_sql_admin_login`
- `synapse_sql_admin_password`
- `synapse_managed_virtual_network_enabled`
- `synapse_public_network_access_enabled`
- `synapse_workspace_firewall_rule_name`
- `synapse_workspace_firewall_start_ip_address`
- `synapse_workspace_firewall_end_ip_address`
- `synapse_spark_pool_name`
- `synapse_spark_node_size_family`
- `synapse_spark_node_size`
- `synapse_spark_cache_size`
- `synapse_spark_autoscale_min_node_count`
- `synapse_spark_autoscale_max_node_count`
- `synapse_spark_autopause_delay_in_minutes`

For local development, copy the example variables file and set your own values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Then edit `terraform.tfvars` and set a strong value for `synapse_sql_admin_password`.

The lab defaults to `synapse_managed_virtual_network_enabled = true` so the workspace is ready for managed private endpoints and tighter network isolation later.
The lab also expects a Synapse workspace firewall rule for your client IP if you are accessing Synapse Studio over the public endpoint.

## Dependency Order

The resources are now built in this order:

- resource group
- storage account
- ADLS Gen2 filesystem
- Synapse workspace
- Synapse workspace firewall rule
- Synapse Spark pool

## Usage

Create or update the lab infrastructure:

```bash
./scripts/rg.sh create
```

Destroy the lab infrastructure:

```bash
./scripts/rg.sh destroy
```

## Direct Terraform Commands

Create/update:

```bash
terraform init
terraform apply
```

Destroy:

```bash
terraform init
terraform destroy
```
