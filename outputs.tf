#------------------------------------------------------------------------------
# Identifiers the SIEM provider needs (per their instructions)
#------------------------------------------------------------------------------

output "application_client_id" {
  value       = azuread_application.siem.client_id
  description = "Application (client) ID of the SIEM app registration."
}

output "directory_tenant_id" {
  value       = azuread_service_principal.siem.application_tenant_id
  description = "Directory (tenant) ID."
}

output "service_principal_object_id" {
  value       = azuread_service_principal.siem.object_id
  description = "Object ID of the Enterprise Application (service principal)."
}

output "client_secret" {
  value       = var.create_client_secret ? azuread_application_password.siem[0].value : null
  sensitive   = true
  description = "Client secret for the app registration (null unless create_client_secret = true). Retrieve with 'terraform output -raw client_secret'."
}

#------------------------------------------------------------------------------
# Event Hub
#------------------------------------------------------------------------------

output "eventhub_namespace_id" {
  value       = module.eventhub_namespace.resource_id
  description = "Resource ID of the Event Hub Namespace."
}

output "eventhub_namespace_name" {
  value       = var.eventhub_namespace_name
  description = "Name of the Event Hub Namespace."
}

output "eventhub_names" {
  value       = local.eventhub_names
  description = "Names of the Event Hubs created."
}

output "eventhub_listen_keys" {
  value = {
    for name, rule in azurerm_eventhub_authorization_rule.siem_listen :
    name => {
      primary_connection_string = rule.primary_connection_string
      primary_key               = rule.primary_key
    }
  }
  sensitive   = true
  description = "Per-hub Listen-only SAS credentials (rule name from var.eventhub_listen_rule_name)."
}

output "namespace_send_listen_key" {
  value = var.namespace_send_listen_rule_name != null ? {
    primary_connection_string = azurerm_eventhub_namespace_authorization_rule.send_listen[0].primary_connection_string
    primary_key               = azurerm_eventhub_namespace_authorization_rule.send_listen[0].primary_key
  } : null
  sensitive   = true
  description = "Namespace-level Send+Listen SAS credentials (null unless namespace_send_listen_rule_name is set)."
}

#------------------------------------------------------------------------------
# Storage
#------------------------------------------------------------------------------

output "storage_account_id" {
  value       = module.storage_account.resource_id
  description = "Resource ID of the capture Storage Account."
}

output "storage_account_name" {
  value       = var.storage_account_name
  description = "Name of the capture Storage Account."
}

output "capture_container_name" {
  value       = var.capture_container_name
  description = "Blob container receiving Event Hub Capture archives."
}
