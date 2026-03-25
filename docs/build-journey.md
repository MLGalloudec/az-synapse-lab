# Synapse Lab Build Journey

This document captures the order we built the lab in, why each step mattered, and the errors we hit along the way.

The goal was not to build the full platform in one jump. The goal was to understand the dependency chain by adding one layer at a time and keeping everything easy to create and destroy with Terraform.

## Step 1: Start With A Resource Group

We first reduced the repo down to the smallest useful Terraform deployment:

- one Azure resource group
- a helper script to run `terraform init`, `terraform apply`, and `terraform destroy`

Why:

- it gave us a clean starting point
- it proved we could create and destroy infrastructure repeatedly
- it established the lab naming pattern

Terraform shape at this stage:

- `azurerm_resource_group`

Key learning:

- even the simplest lab benefits from being reproducible
- the resource group becomes the anchor for everything else

## Error: Resource Group Name Blocked By Azure Policy

When we first tried to create the resource group, Azure rejected it with a policy error:

```text
Error: creating "Resource Group ...": unexpected status 403 (403 Forbidden) with error: RequestDisallowedByPolicy
Resource 'rg-synapse-lab-uksouth' was disallowed by policy.
Reasons: 'Access Denied: The resource naming convention has not been adhered to.'
```

What it meant:

- Terraform was working
- Azure Policy in the subscription was enforcing a naming convention
- the chosen resource group name did not match that convention

What we did:

- adjusted the resource group name to match the allowed pattern

Key learning:

- policy failures are platform governance issues, not Terraform syntax issues
- subscription-level policy can change what names are acceptable

## Step 2: Add Storage For Synapse

Next we added the storage layer required by Synapse:

- one storage account
- ADLS Gen2 enabled with hierarchical namespace
- one filesystem named `synapse`

Terraform shape added:

- `random_string` for a globally unique storage account name
- `azurerm_storage_account`
- `azurerm_storage_data_lake_gen2_filesystem`

Why:

- a Synapse workspace depends on a Data Lake Gen2 filesystem
- this gave us the next dependency in the chain before introducing Synapse itself

Dependency chain at this stage:

- resource group
- storage account
- filesystem

Key learning:

- Synapse does not start with compute
- it starts with storage

## Step 3: Introduce Workspace Variables

Before creating the workspace itself, we introduced the input variables it would need:

- workspace name
- managed resource group name
- SQL admin login
- SQL admin password
- managed virtual network toggle
- public network access toggle

We also moved local values into Terraform variable files:

- added `terraform.tfvars.example`
- ignored `terraform.tfvars` in `.gitignore`

Why:

- the workspace introduces real configuration choices
- separating variables first made the next Terraform step easier to understand

Key learning:

- define inputs before adding the next resource
- use `terraform.tfvars` for local developer configuration rather than a generic `.env`

## Step 4: Add The Synapse Workspace

Next we created the Synapse workspace itself.

Terraform shape added:

- `azurerm_synapse_workspace`

It was wired to:

- the existing resource group
- the existing ADLS Gen2 filesystem
- the SQL admin credentials
- the managed resource group name

Why:

- this is the first actual Synapse control-plane resource
- it turns the storage foundation into a Synapse environment

Dependency chain at this stage:

- resource group
- storage account
- filesystem
- Synapse workspace

Key learning:

- the workspace is the top-level Synapse management boundary
- it is not the compute itself

## What A Synapse Workspace Is

The mental model we landed on was:

- storage account and filesystem: where data lives
- Synapse workspace: the control plane and management boundary
- Spark pool: the compute used to run notebooks

A Synapse workspace ties together:

- the default data lake
- Synapse Studio
- SQL endpoints
- Spark pools
- pipelines and integration features
- security and access settings

## Step 5: Enable Managed Virtual Network

We decided to turn on the Synapse managed virtual network by default.

Why:

- private connectivity is likely later
- this is a creation-time choice for the workspace
- it is better to make that choice early than rebuild later

Key learning:

- some architecture decisions are cheap later
- managed virtual network is not one of them

## Step 6: Add The Spark Pool

Once the workspace existed, we added a minimal Spark pool for notebooks.

Terraform shape added:

- `azurerm_synapse_spark_pool`

Initial configuration choices:

- memory-optimized family
- `Small` node size
- autoscale enabled
- auto-pause after 15 minutes

Why:

- this added the actual notebook compute layer
- it completed the core path from infrastructure to runnable notebooks

Dependency chain at this stage:

- resource group
- storage account
- filesystem
- Synapse workspace
- Spark pool

Key learning:

- the Spark pool depends on the workspace
- the workspace depends on the filesystem

## Error: Invalid Terraform Type `integer`

When we first added the Spark pool variables, Terraform failed during initialization:

```text
Error: Invalid type specification

on main.tf line 74, in variable "synapse_spark_cache_size":
  type = integer

The keyword "integer" is not a valid type specification.
```

The same error repeated for:

- `synapse_spark_cache_size`
- `synapse_spark_autoscale_min_node_count`
- `synapse_spark_autoscale_max_node_count`
- `synapse_spark_autopause_delay_in_minutes`

What it meant:

- the Terraform language does not support `integer` as a type keyword
- it expects `number`

What we did:

- changed those variable types from `integer` to `number`

Key learning:

- some failures happen before provider initialization
- Terraform validates configuration syntax before it downloads providers

## Step 7: Smoke Test The Platform

Before hardening everything, we chose to validate the happy path first.

The smoke test order was:

1. apply the infrastructure
2. open Synapse Studio
3. attach a notebook to the Spark pool
4. run a tiny Spark command
5. run a write/read test to ADLS Gen2

The simplest compute-only smoke test was:

```python
spark.range(10).show()
```

The storage smoke test was:

```python
from pyspark.sql import Row

rows = [Row(id=1, value="alpha"), Row(id=2, value="beta")]
df = spark.createDataFrame(rows)

storage_account = "<your-storage-account-name>"
path = f"abfss://synapse@{storage_account}.dfs.core.windows.net/smoke-test/output"

df.write.mode("overwrite").parquet(path)

result = spark.read.parquet(path)
result.show()
print("row_count =", result.count())
```

Why we chose this before hardening:

- it validates the platform end to end
- it gives a clean baseline before adding more security complexity

## Error: Client IP Not Authorized To Use Synapse Studio / Notebook Session

When we opened Synapse Studio and tried to start a notebook session, we hit:

```text
We cannot reach server to enable some notebook functionalites (export as Python/HTML/LaTeX).
Diagnostic info: [ClientIpAddressNotAuthorized] Client Ip address : 178.255.71.207

We are unable to start a notebook session.
Diagnostic information: fetch_kernel_specs ... [ClientIpAddressNotAuthorized]
Client Ip address : 178.255.71.207
```

What it meant:

- the workspace public endpoint was reachable
- but the workspace firewall was blocking the current client IP

What we did:

- added a Synapse workspace firewall rule to Terraform
- parameterized the start and end IP address

Terraform shape added:

- `azurerm_synapse_firewall_rule`

Key learning:

- workspace public access and workspace firewall rules are separate concerns
- Studio access can fail even when the infrastructure itself exists correctly

## Error: Forbidden To Use The Storage Account

After fixing the workspace firewall, we got a new storage access error during the notebook test:

```text
forbidden to use the storage account
```

What it meant:

- the notebook runtime could now reach the workspace
- but the identity being used did not have the required storage permissions

This was a classic “network fixed, RBAC still missing” moment.

What we did:

- granted the Synapse workspace managed identity the `Storage Blob Data Contributor` role on the storage account

Terraform shape added:

- `azurerm_role_assignment`

Role assignment used:

- scope: the storage account
- role: `Storage Blob Data Contributor`
- principal: the Synapse workspace system-assigned managed identity

Key learning:

- access to ADLS Gen2 is a separate authorization layer
- creating the workspace and filesystem is not enough by itself

## Error: Interactive Notebook Still Hit Storage 403

Even after granting the workspace managed identity access, we still hit a storage authorization error in the notebook:

```text
Py4JJavaError: An error occurred while calling o4333.parquet.
: java.nio.file.AccessDeniedException: Operation failed:
"This request is not authorized to perform this operation using this permission.",
403, HEAD,
https://stsynlabb6degny7.dfs.core.windows.net/synapse/smoke-test/output?upn=false&action=getStatus&timeout=90
```

What it meant:

- network access was no longer the blocker
- the notebook session could reach the storage endpoint
- but the identity being used for the interactive Spark session still lacked the required storage permissions

This exposed an important distinction:

- service-side Synapse operations often use the workspace managed identity
- interactive notebook operations in Synapse Studio often use the signed-in Microsoft Entra user context

What we did:

- kept the `Storage Blob Data Contributor` assignment for the workspace managed identity
- also granted `Storage Blob Data Contributor` to the current signed-in user

Terraform shape added:

- `data "azurerm_client_config" "current"`
- `azurerm_role_assignment` for the current user object ID

Key learning:

- “Synapse has access” and “my notebook session has access” are not always the same thing
- interactive notebook access can require user RBAC in addition to workspace identity RBAC
- when debugging cloud platforms, a second 403 after fixing the first often means you have moved to the next security layer rather than failed to fix the previous one

## Step 8: Manage Firewall And RBAC In Code

At this point we decided both network access and storage access should be declarative:

- workspace firewall rule managed in Terraform
- storage RBAC managed in Terraform

Why:

- no manual portal drift
- reproducible lab setup
- easy destroy and recreate cycle

## Step 9: Move Human Access From Per-User RBAC To A Lab Group

Once the smoke test worked, we refined the model for teaching and repeatability.

Originally, interactive notebook access had been fixed by assigning storage RBAC directly to the current signed-in user. That worked, but it was not the best long-term teaching model because it tied the lab to one person.

We replaced that with:

- an Entra ID security group created by Terraform
- membership for the current signed-in user
- storage RBAC assigned to the group instead of directly to the user

Terraform shape added:

- `azuread` provider
- `azuread_group`
- `azuread_group_member`

Terraform shape changed:

- removed direct per-user storage role assignment
- replaced it with group-based storage role assignment

Why:

- the lab now teaches a cleaner access pattern
- the access model is reusable for multiple people
- the group is owned by the lab and is removed during `terraform destroy`

Key learning:

- direct user RBAC is useful for debugging
- group-based RBAC is usually the better steady-state teaching model
- Entra objects can also be part of a disposable lab if Terraform manages them

## Error: New Provider Needed For Group-Based RBAC

After adding the Entra group resources, Terraform validation reported:

```text
Error: Missing required provider

This configuration requires provider
registry.terraform.io/hashicorp/azuread, but that provider isn't available.
You may be able to install it automatically by running:
  terraform init
```

What it meant:

- the configuration was now valid in shape
- but the local Terraform working directory had not yet downloaded the `azuread` provider

What we did:

- re-ran `terraform init` before the next apply

Key learning:

- adding a new provider changes the initialization requirements
- `terraform validate` can fail simply because the provider plugin has not been installed yet

Dependency chain now:

- resource group
- storage account
- ADLS Gen2 filesystem
- Synapse workspace
- storage RBAC for the workspace managed identity
- Entra ID lab group
- storage RBAC for the lab user group
- Synapse workspace firewall rule
- Synapse Spark pool

## Where The Lab Stands Now

The current platform can now support:

- Synapse Studio access
- Spark notebook execution
- writing to and reading from the default ADLS Gen2 filesystem

It is still intentionally minimal. It does not yet cover:

- broader user or group RBAC
- private endpoints
- linked services
- pipelines
- dedicated SQL pools
- richer lake layout or sample data

## Teaching Sequence Summary

If you were teaching this lab, the build story is:

1. Create a resource group that can be created and destroyed cleanly.
2. Add the storage account and ADLS Gen2 filesystem that Synapse depends on.
3. Introduce workspace variables before adding the workspace resource.
4. Create the Synapse workspace and explain what it is.
5. Decide early whether managed virtual network should be enabled.
6. Add the Spark pool as the compute layer for notebooks.
7. Run a smoke test before hardening everything.
8. Fix public endpoint access with a Synapse workspace firewall rule.
9. Fix storage authorization with RBAC for the workspace managed identity.
10. Fix interactive notebook access with user-side storage RBAC.
11. Replace per-user RBAC with a destroyable Entra group for lab users.
12. Re-run the smoke test and confirm the end-to-end path works.

## Main Lessons

- build cloud platforms in dependency order
- validate the happy path before tightening every control
- policy, networking, and RBAC failures are different classes of problem
- Synapse is not just “a Spark cluster”; it is a workspace that coordinates storage, security, and compute
- declarative firewall and RBAC rules make the lab teachable and repeatable
