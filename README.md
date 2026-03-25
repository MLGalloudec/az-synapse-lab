# Azure Synapse Lab

This repo now covers the first two infrastructure steps for a Synapse lab with Terraform:

- the resource group
- the storage account configured for ADLS Gen2
- the filesystem the Synapse workspace will later use as its default data lake

## What This Creates

- Resource group: `rg-synapse-lab-uksouth`
- Location: `UK South`
- Tags: `workload=synapse-lab`, `environment=lab`
- Storage account: `stsynlab<random-suffix>`
- ADLS Gen2 enabled: `true`
- Filesystem: `synapse`

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

- `main.tf`: Terraform configuration for the resource group, storage account, and ADLS Gen2 filesystem
- `scripts/rg.sh`: Helper script for Terraform create/destroy operations

## Usage

Create the resource group:

```bash
./scripts/rg.sh create
```

Destroy the resource group:

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
