mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ServiceNetworking/trafficControllers/agc-test"
      name = "agc-test"
      output = {
        properties = {
          configurationEndpoints = ["test.trafficcontroller.azure.net"]
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

mock_provider "azurerm" {}
mock_provider "modtm" {}
mock_provider "random" {}

variables {
  location            = "eastus"
  name                = "agc-test"
  resource_group_name = "rg-test"
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
    condition     = can(modtm_telemetry.telemetry)
    error_message = "Telemetry resource should be created when enable_telemetry is true (default)."
  }
}

run "apply_telemetry_disabled" {
  command = apply

  variables {
    enable_telemetry = false
  }

  assert {
    condition     = length(modtm_telemetry.telemetry) == 0
    error_message = "Telemetry resource should not be created when enable_telemetry is false."
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
}

run "name_validation_invalid_start" {
  command = plan

  variables {
    name = "-invalid"
  }

  expect_failures = [
    var.name
  ]
}

run "name_validation_invalid_end" {
  command = plan

  variables {
    name = "invalid-"
  }

  expect_failures = [
    var.name
  ]
}
