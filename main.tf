data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  location = coalesce(var.location, data.azurerm_resource_group.this.location)

  # 1-based, zero-padded-to-3-digits hub names: evh-socaas-aue-001, -002, ...
  eventhub_names = [for i in range(var.eventhub_count) : format("%s%03d", var.eventhub_base_name, i + 1)]
}
