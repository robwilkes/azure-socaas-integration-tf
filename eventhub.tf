module "eventhub_namespace" {
  # source  = "Azure/avm-res-eventhub-namespace/azurerm"
  # version = "0.1.0"
  source = "git::https://github.com/robwilkes/terraform-azurerm-avm-res-eventhub-namespace.git?ref=fixes"

  name                = var.eventhub_namespace_name
  resource_group_name = var.resource_group_name
  location            = local.location
  tags                = var.tags

  sku                      = var.eventhub_namespace_sku
  capacity                 = var.eventhub_namespace_capacity
  auto_inflate_enabled     = true
  maximum_throughput_units = var.eventhub_namespace_maximum_throughput_units

  # SAS auth must remain enabled for the shared access keys the SIEM consumes
  # (disableLocalAuth: false in the Bicep).
  local_authentication_enabled  = true
  public_network_access_enabled = true

  network_rulesets = {
    default_action                 = "Deny"
    public_network_access_enabled  = true
    trusted_service_access_enabled = true
    ip_rule = [
      for ip in var.allowed_ip_addresses : {
        action  = "Allow"
        ip_mask = ip
      }
    ]
  }

  event_hubs = {
    for name in local.eventhub_names : name => {
      namespace_name      = var.eventhub_namespace_name
      resource_group_name = var.resource_group_name
      partition_count     = var.eventhub_partition_count
      message_retention   = var.eventhub_message_retention_days
      status              = "Active"

      capture_description = {
        enabled             = true
        encoding            = "Avro"
        interval_in_seconds = var.eventhub_capture_interval_in_seconds
        size_limit_in_bytes = var.eventhub_capture_size_limit_in_bytes
        destination = {
          name                = "EventHubArchive.AzureBlockBlob"
          archive_name_format = "{Namespace}/{EventHub}/{PartitionId}/{Year}/{Month}/{Day}/{Hour}/{Minute}/{Second}"
          blob_container_name = var.capture_container_name
          storage_account_id  = module.storage_account.resource_id
        }
      }
    }
  }

  # Azure Event Hubs Data Receiver for the SIEM service principal at namespace
  # scope. NOTE: the source Bicep passed TWO role definition IDs (Reader +
  # Event Hubs Data Receiver) into a single subscriptionResourceId() call, which
  # produces a malformed role definition ID - this is the corrected intent.
  role_assignments = {
    siem_eventhub_data_receiver = {
      role_definition_id_or_name = "Azure Event Hubs Data Receiver"
      principal_id               = azuread_service_principal.siem.object_id
      principal_type             = "ServicePrincipal"
      description                = "SOC/SIEM provider - consume Event Hub streams"
    }
  }

  enable_telemetry = var.enable_telemetry
}

#------------------------------------------------------------------------------
# SAS authorization rules
#
# The AVM Event Hub Namespace module (v0.1.0) does not model authorization
# rules, so these are native azurerm resources alongside it. The default
# RootManageSharedAccessKey and the $Default consumer group are created by the
# platform automatically and are intentionally not declared here (the Bicep
# re-declared both redundantly).
#------------------------------------------------------------------------------

# Listen-only rule on each hub - the key the SIEM actually consumes with.
resource "azurerm_eventhub_authorization_rule" "siem_listen" {
  for_each = toset(local.eventhub_names)

  name                = var.eventhub_listen_rule_name
  eventhub_name       = each.value
  namespace_name      = var.eventhub_namespace_name
  resource_group_name = var.resource_group_name

  listen = true
  send   = false
  manage = false

  depends_on = [module.eventhub_namespace]
}

# Optional namespace-level Send+Listen rule (SIEM instructions, step 3).
resource "azurerm_eventhub_namespace_authorization_rule" "send_listen" {
  count = var.namespace_send_listen_rule_name != null ? 1 : 0

  name                = var.namespace_send_listen_rule_name
  namespace_name      = var.eventhub_namespace_name
  resource_group_name = var.resource_group_name

  listen = true
  send   = true
  manage = false

  depends_on = [module.eventhub_namespace]
}
