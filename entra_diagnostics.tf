#------------------------------------------------------------------------------
# Entra ID (tenant-level) diagnostic settings -> first Event Hub
#
# Streams AAD logs to the Event Hub using the namespace's built-in
# RootManageSharedAccessKey rule. Off by default because it requires elevated
# Entra permissions and license-dependent log categories; enable via
# var.enable_entra_diagnostic_setting or configure manually in the portal.
#------------------------------------------------------------------------------

data "azurerm_eventhub_namespace" "this" {
  count = var.enable_entra_diagnostic_setting ? 1 : 0

  name                = var.eventhub_namespace_name
  resource_group_name = var.resource_group_name

  depends_on = [module.eventhub_namespace]
}

resource "azurerm_monitor_aad_diagnostic_setting" "this" {
  count = var.enable_entra_diagnostic_setting ? 1 : 0

  name                           = var.entra_diagnostic_setting_name
  eventhub_name                  = local.eventhub_names[0]
  eventhub_authorization_rule_id = "${data.azurerm_eventhub_namespace.this[0].id}/authorizationRules/RootManageSharedAccessKey"

  dynamic "enabled_log" {
    for_each = toset(var.entra_diagnostic_log_categories)
    content {
      category = enabled_log.value
    }
  }

  depends_on = [module.eventhub_namespace]
}
