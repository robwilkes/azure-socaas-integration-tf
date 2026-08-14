#------------------------------------------------------------------------------
# App registration + service principal (Enterprise Application)
#
# There is no AVM module for Entra ID objects (AVM covers ARM resources via
# azurerm/azapi), so the azuread provider is used directly.
#------------------------------------------------------------------------------

# Resolve the service principals of the resource APIs (Graph, O365 Management
# APIs, ...) so permission *names* can be translated to IDs - avoids hardcoding
# permission GUIDs.
data "azuread_service_principal" "resource_apis" {
  for_each  = var.api_permissions
  client_id = each.key
}

resource "azuread_application" "siem" {
  display_name = var.app_registration_name

  dynamic "required_resource_access" {
    for_each = var.api_permissions

    content {
      resource_app_id = required_resource_access.key

      dynamic "resource_access" {
        for_each = required_resource_access.value.application_roles
        content {
          id   = data.azuread_service_principal.resource_apis[required_resource_access.key].app_role_ids[resource_access.value]
          type = "Role"
        }
      }

      dynamic "resource_access" {
        for_each = required_resource_access.value.delegated_scopes
        content {
          id   = data.azuread_service_principal.resource_apis[required_resource_access.key].oauth2_permission_scope_ids[resource_access.value]
          type = "Scope"
        }
      }
    }
  }
}

resource "azuread_service_principal" "siem" {
  client_id = azuread_application.siem.client_id
}

# Optional: grant admin consent for the application roles requested above.
resource "azuread_app_role_assignment" "consent" {
  for_each = var.grant_admin_consent ? merge([
    for api_client_id, perms in var.api_permissions : {
      for role in perms.application_roles :
      "${api_client_id}/${role}" => {
        api_client_id = api_client_id
        role          = role
      }
    }
  ]...) : {}

  principal_object_id = azuread_service_principal.siem.object_id
  resource_object_id  = data.azuread_service_principal.resource_apis[each.value.api_client_id].object_id
  app_role_id         = data.azuread_service_principal.resource_apis[each.value.api_client_id].app_role_ids[each.value.role]
}

# Optional: client secret. Lands in Terraform state - see variable description.
resource "azuread_application_password" "siem" {
  count = var.create_client_secret ? 1 : 0

  application_id    = azuread_application.siem.id
  display_name      = "socaas-siem"
  end_date_relative = var.client_secret_end_date_relative
}
