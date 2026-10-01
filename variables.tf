#------------------------------------------------------------------------------
# General
#------------------------------------------------------------------------------

variable "resource_group_name" {
  type        = string
  description = "Name of an existing resource group to deploy into."
}

variable "location" {
  type        = string
  default     = null
  description = "Azure region. Defaults to the resource group's location when null."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to all resources created by this module."
}

variable "allowed_ip_addresses" {
  type        = list(string)
  description = "Public IPv4 addresses / CIDR ranges permitted through the Storage Account and Event Hub Namespace network rules (i.e. the SOC/SIEM provider's egress IPs)."

  validation {
    condition     = length(var.allowed_ip_addresses) > 0
    error_message = "At least one allowed IP address must be supplied, otherwise the SIEM provider cannot reach the resources."
  }
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = "Enables Microsoft's AVM telemetry inside the child AVM modules. See https://aka.ms/avm/telemetryinfo."
}

#------------------------------------------------------------------------------
# Storage Account (Event Hub Capture destination)
#------------------------------------------------------------------------------

variable "storage_account_name" {
  type        = string
  description = "Globally unique Storage Account name, e.g. 'stsocaasaue001'."
}

variable "storage_account_sku_name" {
  type        = string
  default     = "Standard_RAGRS"
  description = "Storage Account SKU. Defaults to Standard_RAGRS to match the validated Bicep deployment (note: the SIEM provider's written instructions say LRS; override here if you want to follow them instead)."
}

variable "storage_soft_delete_retention_days" {
  type        = number
  default     = 7
  description = "Soft-delete retention (days) for both blobs and containers."
}

variable "capture_container_name" {
  type        = string
  default     = "blb-socaas-001"
  description = "Blob container that Event Hub Capture archives into. Created by this module (the original Bicep referenced it but never created it)."
}

#------------------------------------------------------------------------------
# Event Hub Namespace / Event Hubs
#------------------------------------------------------------------------------

variable "eventhub_namespace_name" {
  type        = string
  description = "Event Hub Namespace name, e.g. 'evhns-socaas-aue-001'."
}

variable "eventhub_namespace_sku" {
  type        = string
  default     = "Standard"
  description = "Event Hub Namespace SKU. Standard (per the validated deployment) is required for Capture and auto-inflate; the SIEM instructions' 'Basic' tier does not support Capture."
}

variable "eventhub_namespace_capacity" {
  type        = number
  default     = 2
  description = "Baseline throughput units for the namespace."
}

variable "eventhub_namespace_maximum_throughput_units" {
  type        = number
  default     = 6
  description = "Maximum throughput units when auto-inflate is enabled."
}

variable "eventhub_count" {
  type        = number
  default     = 1
  description = "Number of Event Hubs to create under the namespace."
}

variable "eventhub_base_name" {
  type        = string
  default     = "evh-socaas-aue-"
  description = "Base name for Event Hubs; a 1-based index zero-padded to 3 digits is appended (evh-socaas-aue-001, ...)."
}

variable "eventhub_partition_count" {
  type        = number
  default     = 4
  description = "Partitions per Event Hub."
}

variable "eventhub_message_retention_days" {
  type        = number
  default     = 1
  description = "Message retention in days per Event Hub."
}

variable "eventhub_capture_interval_in_seconds" {
  type        = number
  default     = 300
  description = "Capture window interval in seconds."
}

variable "eventhub_capture_size_limit_in_bytes" {
  type        = number
  default     = 314572800
  description = "Capture window size limit in bytes."
}

variable "eventhub_listen_rule_name" {
  type        = string
  default     = "EventHubAccessKey"
  description = "Name of the Listen-only SAS authorization rule created on each Event Hub for the SIEM provider."
}

variable "namespace_send_listen_rule_name" {
  type        = string
  default     = null
  description = "Optional. When set, creates a namespace-level SAS authorization rule with Send + Listen rights (per the SIEM instructions, step 3). Leave null to skip and create the key manually instead — the key material otherwise ends up in Terraform state, so ensure your state backend is appropriately secured."
}

#------------------------------------------------------------------------------
# Entra ID app registration / service principal
#------------------------------------------------------------------------------

variable "app_registration_name" {
  type        = string
  default     = "Integration-SOCaaS-AzureLogs-Prod"
  description = "Display name (and unique name) of the Entra ID application registration used by the SIEM provider."
}

variable "api_permissions" {
  type = map(object({
    application_roles = optional(list(string), [])
    delegated_scopes  = optional(list(string), [])
  }))
  default = {
    # Microsoft Graph
    "00000003-0000-0000-c000-000000000000" = {
      delegated_scopes  = ["User.Read"]
      application_roles = ["SecurityIncident.Read.All", "SecurityIncident.ReadWrite.All"]
    }
    # Office 365 Management APIs
    "c5393580-f805-4401-95e8-94b7a6ef2fc2" = {
      application_roles = ["ActivityFeed.Read", "ActivityFeed.ReadDlp", "ServiceHealth.Read"]
    }
    # Microsoft Defender for Endpoint (WindowsDefenderATP)
    "fc780465-2017-40d4-a0c5-307022471b92" = {
      application_roles = ["Alert.Read.All"]
    }
  }
  description = <<-DESC
    API permissions to request on the app registration, keyed by the *client ID* of the
    resource API. Permission names are resolved to IDs at plan time from the tenant's
    service principals, so a typo or a permission that does not exist on that API will
    fail the plan rather than deploy silently-wrong GUIDs.

    NOTE: the SIEM instructions list SecurityIncident.Read.All / SecurityIncident.ReadWrite.All /
    Incident.Read.All under "O365 Management APIs", but those permissions do not exist on that
    API. SecurityIncident.* live on Microsoft Graph (defaulted here). Incident.Read.All exists
    on the Microsoft 365 Defender / Threat Protection API, while Alert.Read.All is on the
    Microsoft Defender for Endpoint (WindowsDefenderATP) API. Confirm with your provider
    which endpoint they actually call, then adjust this map if required.
  DESC
}

variable "grant_admin_consent" {
  type        = bool
  default     = false
  description = "When true, Terraform grants admin consent for the requested *application* roles via azuread_app_role_assignment. The deploying principal needs privileged Entra roles (e.g. Privileged Role Administrator / Global Administrator). Delegated scopes are not consented by this module."
}

variable "create_client_secret" {
  type        = bool
  default     = false
  description = "When true, creates a client secret on the app registration and exposes it as a sensitive output. The secret is stored in Terraform state — only enable if your state backend is secured; otherwise create the credential manually in the portal."
}

variable "client_secret_end_date_relative" {
  type        = string
  default     = "8760h" # 1 year
  description = "Validity period for the client secret, relative to creation (Go duration format)."
}

#------------------------------------------------------------------------------
# Entra ID (AAD) diagnostic settings -> Event Hub
#------------------------------------------------------------------------------

variable "enable_entra_diagnostic_setting" {
  type        = bool
  default     = false
  description = "When true, creates the tenant-level Entra ID diagnostic setting streaming logs to the first Event Hub (SIEM instructions, step 6). The deploying principal needs Entra permissions to manage AAD diagnostic settings (e.g. Global Administrator / Security Administrator) and the tenant needs Entra ID P1/P2 for most log categories. Leave false to configure manually in the portal."
}

variable "entra_diagnostic_setting_name" {
  type        = string
  default     = "socaas-siem"
  description = "Name of the Entra ID diagnostic setting."
}

variable "entra_diagnostic_log_categories" {
  type = list(string)
  default = [
    "AuditLogs",
    "SignInLogs",
    "NonInteractiveUserSignInLogs",
    "ServicePrincipalSignInLogs",
    "ManagedIdentitySignInLogs",
    "ProvisioningLogs",
    "ADFSSignInLogs",
    "RiskyUsers",
    "UserRiskEvents",
    "RiskyServicePrincipals",
    "ServicePrincipalRiskEvents",
  ]
  description = "Entra ID log categories to stream ('all log related sources, metrics are not necessary'). Trim this list to what your tenant's licensing actually supports — unlicensed categories cause deployment errors."
}
