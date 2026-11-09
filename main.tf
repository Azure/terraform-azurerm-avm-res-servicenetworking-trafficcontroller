# AVM Interfaces module for locks, role assignments, diagnostic settings, and private endpoints
module "avm_interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.10.0"

  location                                  = var.location
  diagnostic_settings_v2                    = var.diagnostic_settings
  enable_telemetry                          = var.enable_telemetry
  lock                                      = var.lock
  private_endpoints                         = var.private_endpoints
  private_endpoints_manage_dns_zone_group   = var.private_endpoints_manage_dns_zone_group
  private_endpoints_scope                   = azapi_resource.this.id
  role_assignment_definition_lookup_enabled = true
  role_assignment_definition_scope          = "/subscriptions/${data.azapi_client_config.this.subscription_id}"
  role_assignments                          = var.role_assignments
}

resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = var.parent_id
  type      = "Microsoft.ServiceNetworking/trafficControllers@2025-01-01"
  body = {
    properties = {}
  }
  response_export_values    = ["properties.configurationEndpoints"]
  retry                     = var.retry
  schema_validation_enabled = true
  tags                      = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts != null ? { this = var.timeouts } : {}

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  lifecycle {
    ignore_changes = [
      body.properties.securityPolicyConfigurations
    ]
  }
}

data "azapi_client_config" "this" {}

resource "azapi_resource" "frontend" {
  for_each = var.frontends

  location  = var.location
  name      = each.value.name
  parent_id = azapi_resource.this.id
  # publicNetworkAccess and association are only available from API version 2026-03-01. Frontends that do not set
  # `public_network_access` keep using 2025-01-01 so existing deployments are unchanged.
  type = each.value.public_network_access == null ? "Microsoft.ServiceNetworking/trafficControllers/frontends@2025-01-01" : "Microsoft.ServiceNetworking/trafficControllers/frontends@2026-03-01"
  body = {
    properties = merge(
      each.value.public_network_access == null ? {} : { publicNetworkAccess = lower(each.value.public_network_access) },
      each.value.association_key == null ? {} : { association = { id = azapi_resource.association[each.value.association_key].id } }
    )
  }
  response_export_values = ["properties.fqdn"]
  retry                  = var.retry
  # The AzAPI embedded schema does not include ServiceNetworking API version 2026-03-01 yet.
  schema_validation_enabled = each.value.public_network_access == null
  tags                      = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts != null ? { this = var.timeouts } : {}

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

resource "azapi_resource" "association" {
  for_each = var.associations

  location  = var.location
  name      = each.value.name
  parent_id = azapi_resource.this.id
  type      = "Microsoft.ServiceNetworking/trafficControllers/associations@2025-01-01"
  body = {
    properties = {
      associationType = "subnets"
      subnet = {
        id = each.value.subnet_resource_id
      }
    }
  }
  response_export_values    = ["properties.subnet"]
  retry                     = var.retry
  schema_validation_enabled = true
  tags                      = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts != null ? { this = var.timeouts } : {}

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

resource "azapi_resource" "security_policy" {
  for_each = var.security_policies

  location  = var.location
  name      = each.value.name
  parent_id = azapi_resource.this.id
  type      = "Microsoft.ServiceNetworking/trafficControllers/securityPolicies@2025-01-01"
  body = {
    properties = {
      wafPolicy = {
        id = each.value.waf_policy_resource_id
      }
    }
  }
  response_export_values    = []
  retry                     = var.retry
  schema_validation_enabled = true
  tags                      = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts != null ? { this = var.timeouts } : {}

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  depends_on = [azapi_resource.frontend, azapi_resource.association]
}

# Lock
resource "azapi_resource" "lock" {
  count = var.lock != null ? 1 : 0

  name                   = module.avm_interfaces.lock_azapi.name
  parent_id              = azapi_resource.this.id
  type                   = module.avm_interfaces.lock_azapi.type
  body                   = module.avm_interfaces.lock_azapi.body
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts != null ? { this = var.timeouts } : {}

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  depends_on = [
    azapi_resource.diagnostic_setting,
    azapi_resource.role_assignment
  ]
}

# Role Assignments
resource "azapi_resource" "role_assignment" {
  for_each = module.avm_interfaces.role_assignments_azapi

  name                   = each.value.name
  parent_id              = azapi_resource.this.id
  type                   = each.value.type
  body                   = each.value.body
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts != null ? { this = var.timeouts } : {}

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

# Diagnostic Settings
resource "azapi_resource" "diagnostic_setting" {
  for_each = module.avm_interfaces.diagnostic_settings_azapi_v2

  name                   = each.value.name
  parent_id              = azapi_resource.this.id
  type                   = each.value.type
  body                   = each.value.body
  ignore_null_property   = true
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts != null ? { this = var.timeouts } : {}

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

# Private Endpoints
resource "azapi_resource" "private_endpoint" {
  for_each = module.avm_interfaces.private_endpoints_azapi

  location               = coalesce(var.private_endpoints[each.key].location, azapi_resource.this.location)
  name                   = each.value.name
  parent_id              = coalesce(var.private_endpoints[each.key].resource_group_name, azapi_resource.this.parent_id)
  type                   = each.value.type
  body                   = each.value.body
  response_export_values = []
  retry                  = var.retry
  tags                   = each.value.tags

  dynamic "timeouts" {
    for_each = var.timeouts != null ? { this = var.timeouts } : {}

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  lifecycle {
    precondition {
      condition     = var.private_endpoints[each.key].subresource_name != null
      error_message = "`private_endpoints[\"${each.key}\"].subresource_name` is required and must be the name of the private frontend."
    }
  }
  # The private link sub resource is a frontend, which must exist before the private endpoint connects to it.
  depends_on = [azapi_resource.frontend, azapi_resource.association]
}

resource "azapi_resource" "private_endpoint_dns_zone_group" {
  for_each = module.avm_interfaces.private_dns_zone_groups_azapi

  name                   = each.value.name
  parent_id              = azapi_resource.private_endpoint[each.key].id
  type                   = each.value.type
  body                   = each.value.body
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts != null ? { this = var.timeouts } : {}

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

resource "azapi_resource" "private_endpoint_lock" {
  for_each = module.avm_interfaces.lock_private_endpoint_azapi

  name                   = each.value.name
  parent_id              = azapi_resource.private_endpoint[each.value.pe_key].id
  type                   = each.value.type
  body                   = each.value.body
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts != null ? { this = var.timeouts } : {}

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  depends_on = [
    azapi_resource.private_endpoint_dns_zone_group,
    azapi_resource.private_endpoint_role_assignment
  ]
}

resource "azapi_resource" "private_endpoint_role_assignment" {
  for_each = module.avm_interfaces.role_assignments_private_endpoint_azapi

  name                   = each.value.name
  parent_id              = azapi_resource.private_endpoint[each.value.pe_key].id
  type                   = each.value.type
  body                   = each.value.body
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts != null ? { this = var.timeouts } : {}

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}
