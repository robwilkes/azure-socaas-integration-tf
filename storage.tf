module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.7.3"

  name      = var.storage_account_name
  parent_id = data.azurerm_resource_group.this.id
  location  = local.location
  tags      = var.tags

  account_kind     = "StorageV2"
  account_sku_name = var.storage_account_sku_name
  access_tier      = "Hot"

  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  allow_nested_items_to_be_public   = false
  shared_access_key_enabled         = true
  default_to_oauth_authentication   = false
  public_network_access_enabled     = true
  cross_tenant_replication_enabled  = false
  allowed_copy_scope                = "AAD"
  large_file_share_enabled          = true
  infrastructure_encryption_enabled = false

  routing = {
    choice                      = "MicrosoftRouting"
    publish_microsoft_endpoints = true
    publish_internet_endpoints  = false
  }

  network_rules = {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = var.allowed_ip_addresses
  }

  blob_properties = {
    delete_retention_policy = {
      enabled                = true
      days                   = var.storage_soft_delete_retention_days
      allow_permanent_delete = false
    }
    container_delete_retention_policy = {
      enabled = true
      days    = var.storage_soft_delete_retention_days
    }
  }

  # Capture destination container. The original Bicep referenced this container
  # in the capture config but never created it, which breaks Capture on a fresh
  # deployment - it is created here deliberately.
  containers = {
    capture = {
      name          = var.capture_container_name
      public_access = "None"
    }
  }

  # Storage Blob Data Contributor for the SIEM service principal, scoped to the
  # storage account (matches the Bicep role assignment).
  role_assignments = {
    siem_blob_data_contributor = {
      role_definition_id_or_name = "Storage Blob Data Contributor"
      principal_id               = azuread_service_principal.siem.object_id
      principal_type             = "ServicePrincipal"
      description                = "SOC/SIEM provider - read captured Event Hub archives"
    }
  }

  enable_telemetry = var.enable_telemetry
}
