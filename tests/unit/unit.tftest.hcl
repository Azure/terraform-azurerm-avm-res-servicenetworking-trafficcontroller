mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ServiceNetworking/trafficControllers/agc-test"
      name = "agc-test"
      output = {
        properties = {
          configurationEndpoints = ["test.trafficcontroller.azure.net"]
          fqdn                   = "test-frontend.fqdn.trafficcontroller.azure.net"
          subnet = {
            id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/subnet-test"
          }
        }
      }
    }
  }

  mock_data "azapi_client_config" {
    defaults = {
      subscription_id          = "00000000-0000-0000-0000-000000000000"
      tenant_id                = "00000000-0000-0000-0000-000000000001"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "random" {}

variables {
  location  = "eastus"
  name      = "agc-test"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
}

run "apply_default" {
  command = apply

  assert {
    condition     = azapi_resource.this.name == "agc-test"
    error_message = "Traffic Controller name should be 'agc-test'."
  }

  assert {
    condition     = azapi_resource.this.location == "eastus"
    error_message = "Traffic Controller location should be 'eastus'."
  }

  assert {
    condition     = output.name == "agc-test"
    error_message = "Name output should be 'agc-test'."
  }

  assert {
    condition     = output.resource_id != ""
    error_message = "Resource ID output should not be empty."
  }

  assert {
    condition     = can(azapi_resource.telemetry)
    error_message = "Telemetry resource should be created when enable_telemetry is true (default)."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "apply_telemetry_disabled" {
  command = apply

  variables {
    enable_telemetry = false
  }

  assert {
    condition     = length(azapi_resource.telemetry) == 0
    error_message = "Telemetry resource should not be created when enable_telemetry is false."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "apply_with_frontend" {
  command = apply

  variables {
    frontends = {
      fe1 = {
        name = "frontend-test"
      }
    }
  }

  assert {
    condition     = length(azapi_resource.frontend) == 1
    error_message = "One frontend should be created."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "frontend_default_keeps_current_api_version" {
  command = apply

  variables {
    frontends = {
      fe1 = {
        name = "frontend-test"
      }
    }
  }

  assert {
    condition     = azapi_resource.frontend["fe1"].type == "Microsoft.ServiceNetworking/trafficControllers/frontends@2025-01-01"
    error_message = "Frontends without public_network_access should keep API version 2025-01-01."
  }

  assert {
    condition     = length(azapi_resource.frontend["fe1"].body.properties) == 0
    error_message = "Frontends without public_network_access should not send any properties."
  }

  assert {
    condition     = azapi_resource.frontend["fe1"].schema_validation_enabled == true
    error_message = "Schema validation should stay enabled for frontends using API version 2025-01-01."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "frontend_public_network_access_enabled" {
  command = apply

  variables {
    frontends = {
      fe1 = {
        name                  = "frontend-test"
        public_network_access = "Enabled"
      }
    }
  }

  assert {
    condition     = azapi_resource.frontend["fe1"].type == "Microsoft.ServiceNetworking/trafficControllers/frontends@2026-03-01"
    error_message = "Frontends with public_network_access should use API version 2026-03-01."
  }

  assert {
    condition     = azapi_resource.frontend["fe1"].body.properties.publicNetworkAccess == "enabled"
    error_message = "publicNetworkAccess should be sent as the lower case value enabled."
  }

  assert {
    condition     = !can(azapi_resource.frontend["fe1"].body.properties.association)
    error_message = "A public frontend must not reference an association."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "frontend_public_network_access_disabled" {
  command = apply

  variables {
    associations = {
      assoc1 = {
        name               = "assoc-test"
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/subnet-test"
      }
    }
    frontends = {
      fe1 = {
        name                  = "frontend-private"
        public_network_access = "Disabled"
        association_key       = "assoc1"
      }
      fe2 = {
        name = "frontend-public"
      }
    }
  }

  assert {
    condition     = azapi_resource.frontend["fe1"].type == "Microsoft.ServiceNetworking/trafficControllers/frontends@2026-03-01"
    error_message = "A private frontend should use API version 2026-03-01."
  }

  assert {
    condition     = azapi_resource.frontend["fe1"].body.properties.publicNetworkAccess == "disabled"
    error_message = "publicNetworkAccess should be sent as the lower case value disabled."
  }

  assert {
    condition     = azapi_resource.frontend["fe1"].body.properties.association.id == azapi_resource.association["assoc1"].id
    error_message = "The private frontend should reference the association selected by association_key."
  }

  assert {
    condition     = azapi_resource.frontend["fe1"].schema_validation_enabled == false
    error_message = "Schema validation should be disabled for API version 2026-03-01, which is not in the AzAPI embedded schema."
  }

  assert {
    condition     = azapi_resource.frontend["fe2"].type == "Microsoft.ServiceNetworking/trafficControllers/frontends@2025-01-01" && length(azapi_resource.frontend["fe2"].body.properties) == 0
    error_message = "A frontend without public_network_access in the same map should be unchanged."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "frontend_private_requires_association_key" {
  command = plan

  variables {
    frontends = {
      fe1 = {
        name                  = "frontend-private"
        public_network_access = "Disabled"
      }
    }
  }

  expect_failures = [
    var.frontends
  ]
  providers = {
    azapi  = azapi
    random = random
  }
}

run "frontend_public_rejects_association_key" {
  command = plan

  variables {
    associations = {
      assoc1 = {
        name               = "assoc-test"
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/subnet-test"
      }
    }
    frontends = {
      fe1 = {
        name                  = "frontend-public"
        public_network_access = "Enabled"
        association_key       = "assoc1"
      }
    }
  }

  expect_failures = [
    var.frontends
  ]
  providers = {
    azapi  = azapi
    random = random
  }
}

run "frontend_association_key_must_exist" {
  command = plan

  variables {
    frontends = {
      fe1 = {
        name                  = "frontend-private"
        public_network_access = "Disabled"
        association_key       = "missing"
      }
    }
  }

  expect_failures = [
    var.frontends
  ]
  providers = {
    azapi  = azapi
    random = random
  }
}

run "frontend_public_network_access_invalid" {
  command = plan

  variables {
    frontends = {
      fe1 = {
        name                  = "frontend-test"
        public_network_access = "Maybe"
      }
    }
  }

  expect_failures = [
    var.frontends
  ]
  providers = {
    azapi  = azapi
    random = random
  }
}
run "apply_with_association" {
  command = apply

  variables {
    associations = {
      assoc1 = {
        name               = "assoc-test"
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/subnet-test"
      }
    }
  }

  assert {
    condition     = length(azapi_resource.association) == 1
    error_message = "One association should be created."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "apply_with_security_policy" {
  command = apply

  variables {
    security_policies = {
      waf1 = {
        name                   = "waf-test"
        waf_policy_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies/waf-policy-test"
      }
    }
  }

  assert {
    condition     = length(azapi_resource.security_policy) == 1
    error_message = "One security policy should be created."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "name_validation_valid" {
  command = apply

  variables {
    name = "my-agc.test_01"
  }

  assert {
    condition     = azapi_resource.this.name == "my-agc.test_01"
    error_message = "Traffic Controller should accept valid name with hyphens, dots, and underscores."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "name_validation_invalid_start" {
  command = plan

  variables {
    name = "-invalid"
  }

  expect_failures = [
    var.name
  ]
  providers = {
    azapi  = azapi
    random = random
  }
}

run "name_validation_invalid_end" {
  command = plan

  variables {
    name = "invalid-"
  }

  expect_failures = [
    var.name
  ]
  providers = {
    azapi  = azapi
    random = random
  }
}
