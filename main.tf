# AVM Interfaces module for locks, role assignments, diagnostic settings, and managed identities
module "avm_interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.6.0"

  diagnostic_settings_v2                    = var.diagnostic_settings
  enable_telemetry                          = var.enable_telemetry
  lock                                      = var.lock
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
  create_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers              = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values    = ["properties.configurationEndpoints"]
  retry                     = var.retry
  schema_validation_enabled = true
  tags                      = var.tags
  update_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

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
  type      = "Microsoft.ServiceNetworking/trafficControllers/frontends@2025-01-01"
  body = {
    properties = {}
  }
  create_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers              = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values    = ["properties.fqdn"]
  retry                     = var.retry
  schema_validation_enabled = true
  tags                      = var.tags
  update_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

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
  create_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers              = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values    = ["properties.subnet"]
  retry                     = var.retry
  schema_validation_enabled = true
  tags                      = var.tags
  update_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  dynamic "timeouts" {
    for_each = var.timeouts != null ? { this = var.timeouts } : {}

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  depends_on = [azapi_resource.frontend]
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
  create_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers              = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values    = []
  retry                     = var.retry
  schema_validation_enabled = true
  tags                      = var.tags
  update_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

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
  create_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values = []
  retry                  = var.retry
  update_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

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
  create_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values = []
  retry                  = var.retry
  update_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

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
  create_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  ignore_null_property   = true
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values = []
  retry                  = var.retry
  update_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

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
