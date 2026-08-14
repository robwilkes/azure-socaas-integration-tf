# terraform-azurerm-socaas-integration

This module provisions the Azure-side resources required to connect a SOC/SIEM provider to Microsoft Entra ID and Azure Event Hubs for log streaming and capture.

It creates:

- A storage account with network restrictions, soft delete, and a blob container used as the Event Hub Capture destination.
- An Event Hubs namespace and one or more Event Hubs with Capture enabled to the storage account.
- Listen-only SAS authorization rules for each Event Hub, and an optional namespace-level Send+Listen rule.
- An Entra ID application registration and enterprise application, with configurable API permissions and optional client secret.
- RBAC assignments so the SIEM service principal can read from the Event Hub namespace and write to the storage container.
- An optional tenant-level Entra ID diagnostic setting that streams logs to the Event Hub.

## What this module is for

Use this module when you need to stand up the Azure resources that support a SIEM/SOC integration workflow:

- collect Azure sign-in, audit, and related security logs,
- deliver them to Event Hubs,
- archive them to storage with Event Hub Capture,
- and expose the identifiers and keys required by the provider.

## Prerequisites

Before using this module, ensure that:

- you have an existing Azure resource group,
- your Terraform identity has permission to create the resources listed above,
- the storage account name is globally unique,
- you have the provider egress IPs or CIDR ranges that should be allowed through the network rules.

For Entra ID-related resources, the deploying principal may need elevated permissions depending on the options you enable.

## Usage

```hcl
module "socaas_integration" {
  source = "git::https://github.com/robwilkes/azure-socaas-integration-tf.git?ref=v0.1.0"

  resource_group_name     = "rg-socaas-aue-001"
  storage_account_name    = "stsocaasaue001"
  eventhub_namespace_name = "evhns-socaas-aue-001"
  app_registration_name   = "Integration-SOCaaS-AzureLogs-Prod"

  allowed_ip_addresses = ["1.1.1.1", "2.2.2.2"]
}
```

A complete root module example is available in the examples/basic directory.

## Key inputs

The module exposes a number of inputs for naming, networking, capture, Entra permissions, and optional secrets. The most commonly used ones are:

| Input                           | Description                                                               |
| ------------------------------- | ------------------------------------------------------------------------- |
| resource_group_name             | Existing resource group to deploy into.                                   |
| storage_account_name            | Globally unique storage account name.                                     |
| allowed_ip_addresses            | Public IPs/CIDRs allowed through the storage and Event Hub network rules. |
| eventhub_namespace_name         | Name of the Event Hubs namespace.                                         |
| eventhub_count                  | Number of Event Hubs to create.                                           |
| app_registration_name           | Display name for the Entra application registration.                      |
| api_permissions                 | API permissions requested by the application.                             |
| create_client_secret            | Creates a client secret and exposes it as a sensitive output.             |
| enable_entra_diagnostic_setting | Creates an Entra ID diagnostic setting that sends logs to the Event Hub.  |

## Outputs

The module returns values that are typically shared with the SOC/SIEM provider:

- application_client_id
- directory_tenant_id
- service_principal_object_id
- eventhub_namespace_name
- eventhub_names
- storage_account_name
- capture_container_name
- eventhub_listen_keys
- namespace_send_listen_key
- client_secret (when enabled)

## Deployment permissions

Deploying this module requires the appropriate Azure RBAC and Microsoft Entra permissions:

- Azure RBAC: `Owner` or `Contributor` plus `User Access Administrator` or `Role Based Access Control Administrator` on the target resource group so the module can create role assignments.
- Microsoft Entra ID: permission to create applications and service principals, such as `Application Administrator`.
- If you enable `grant_admin_consent`, the deploying principal must have a privileged role such as `Global Administrator` or `Privileged Role Administrator`.
- If you enable `enable_entra_diagnostic_setting`, the deploying principal also needs permission to manage Entra diagnostic settings, and the tenant must support the log categories you select.

## Post-deployment checklist

After Terraform applies the configuration, complete the remaining integration steps:

1. Review the outputs and share the identifiers and credentials required by the provider, including the tenant ID, client ID, and the Event Hubs details.
2. If you enabled `create_client_secret`, retrieve the secret with `terraform output -raw client_secret`.
3. If you did not enable `enable_entra_diagnostic_setting`, configure the Entra diagnostic setting in the portal or through your preferred automation workflow.
4. If admin consent was not granted during deployment, complete it in the Microsoft Entra admin center for the requested permissions.

## Security considerations

Some features create sensitive material in Terraform state. Use caution when enabling them:

- namespace_send_listen_rule_name creates a namespace-level SAS rule and stores its secret material in state.
- create_client_secret creates a client secret and exposes it as a sensitive output.
- eventhub_listen_keys are always created and returned as sensitive outputs.

If your state backend is not tightly controlled, consider creating these credentials manually instead.

## Modules and implementation notes

This module uses AVM modules for the core Azure resources where available, and native Terraform resources for the remaining pieces that are not covered by the AVM modules, including Entra ID objects and SAS authorization rules.

The default configuration is designed to provide a sensible baseline for SIEM integration scenarios, including:

- Standard Event Hubs namespace SKU for Capture support,
- RAGRS storage redundancy,
- a capture container created automatically,
- and a default set of Entra permissions that can be adjusted as needed.
