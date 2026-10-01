data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  location = coalesce(var.location, data.azurerm_resource_group.this.location)

  # Numbered hubs: 1-based index zero-padded to 3 digits: evh-socaas-aue-001, -002, ...
  numbered_eventhub_names = [for i in range(var.eventhub_count) : format("%s%03d", var.eventhub_base_name, i + 1)]

  # All hubs: the numbered ones plus any explicitly named extras.
  eventhub_names = concat(local.numbered_eventhub_names, var.eventhub_additional_names)
}
