# Azure Synapse Lab

This repo now covers the current foundation of the Synapse lab with Terraform:

- the resource group
- the storage account configured for ADLS Gen2
- the filesystem the Synapse workspace will later use as its default data lake
- the Synapse workspace itself

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

- `main.tf`: Terraform configuration for the resource group, storage account, ADLS Gen2 filesystem, and Synapse workspace
- `scripts/rg.sh`: Helper script for Terraform create/destroy operations

## Synapse Workspace Variables

The Terraform uses these workspace inputs:

- `synapse_workspace_name`
- `synapse_managed_resource_group_name`
- `synapse_sql_admin_login`
- `synapse_sql_admin_password`
- `synapse_managed_virtual_network_enabled`
- `synapse_public_network_access_enabled`

For local development, copy the example variables file and set your own values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Then edit `terraform.tfvars` and set a strong value for `synapse_sql_admin_password`.

The lab defaults to `synapse_managed_virtual_network_enabled = true` so the workspace is ready for managed private endpoints and tighter network isolation later.

## Dependency Order

The resources are now built in this order:

- resource group
- storage account
- ADLS Gen2 filesystem
- Synapse workspace

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
