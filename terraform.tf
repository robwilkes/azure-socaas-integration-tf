terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    # AVM storage module >= 0.7.x requires azurerm >= 4.37 (AzAPI-based rewrite).
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
