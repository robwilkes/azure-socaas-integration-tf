terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.37, < 5.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.0, < 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  # The AVM storage module authenticates data-plane-adjacent operations with
  # Entra ID; recommended when shared key access is locked down.
  storage_use_azuread = true
}

provider "azuread" {}

resource "azurerm_resource_group" "socaas" {
  name     = "rg-socaas-aue-001"
  location = "australiaeast"
}

module "socaas_integration" {
  # Pin to a release tag once published, e.g. ?ref=v0.1.0
  source = "git::https://github.com/robwilkes/azure-socaas-integration-tf.git?ref=v0.1.0"

  resource_group_name = azurerm_resource_group.socaas.name

  storage_account_name    = "stsocaasaue001"
  eventhub_namespace_name = "evhns-socaas-aue-001"
  eventhub_base_name      = "evh-socaas-aue-"
  eventhub_count          = 1

  app_registration_name = "Integration-SOCaaS-AzureLogs-Prod"

  allowed_ip_addresses = [
    "1.1.1.1",
    "2.2.2.2",
  ]

  tags = {
    ExampleTag = "ValueHere"
  }

  # Opt-in extras - all default to off/manual:
  # namespace_send_listen_rule_name = "SocaasSendListen"
  # create_client_secret            = true
  # grant_admin_consent             = true
  # enable_entra_diagnostic_setting = true
}

output "siem_handover" {
  sensitive = true
  value = {
    app_registration = {
      client_id     = module.socaas_integration.application_client_id
      client_secret = module.socaas_integration.client_secret
      tenant_id     = module.socaas_integration.directory_tenant_id
    }

    event_hub = {
      namespace_name = module.socaas_integration.eventhub_namespace_name
      hubs_names     = module.socaas_integration.eventhub_names

      # Optional: only populated when namespace_send_listen_rule_name is set.
      namespace_send_listen_key = module.socaas_integration.namespace_send_listen_key

      # Per-hub listen keys are always created by the module.
      eventhub_listen_keys = module.socaas_integration.eventhub_listen_keys
    }

    storage_account = {
      name = module.socaas_integration.storage_account_name
    }
  }
}
