terraform {
  required_version = "~> 1.9"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.4"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

## Section to provide a random Azure region for the resource group
# This allows us to randomize the region for the resource group.
module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.11.0"
}

# This allows us to randomize the region for the resource group.
resource "random_integer" "region_index" {
  max = length(local.regions) - 1
  min = 0
}

locals {
  # Application Gateway for Containers is available in limited regions
  regions = [
    for r in module.regions.regions : r
    if contains(["eastus", "westus2", "northeurope", "westeurope", "australiaeast", "centralus", "southcentralus", "westus", "eastus2", "uksouth", "northcentralus", "japaneast", "canadacentral"], r.name)
  ]
  selected_region = local.regions[random_integer.region_index.result].name
}
## End of section to provide a random Azure region for the resource group

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.3"
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = local.selected_region
  name     = module.naming.resource_group.name_unique
}

# This is the module call
module "test" {
  source = "../../"

  # source             = "Azure/avm-res-servicenetworking-trafficcontroller/azurerm"
  # version            = "..."
  location            = azurerm_resource_group.this.location
  name                = module.naming.application_gateway.name_unique
  resource_group_name = azurerm_resource_group.this.name
  associations = {
    default = {
      name               = "association-default"
      subnet_resource_id = azapi_resource.subnet.id
    }
  }
  enable_telemetry = var.enable_telemetry # see variables.tf
  frontends = {
    default = {
      name = "frontend-default"
    }
  }
}

# Networking resources required for the association
resource "azapi_resource" "vnet" {
  location  = azurerm_resource_group.this.location
  name      = module.naming.virtual_network.name_unique
  parent_id = azurerm_resource_group.this.id
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  body = {
    properties = {
      addressSpace = {
        addressPrefixes = ["10.0.0.0/16"]
      }
    }
  }
}

resource "azapi_resource" "subnet" {
  name      = "subnet-agc"
  parent_id = azapi_resource.vnet.id
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  body = {
    properties = {
      addressPrefix = "10.0.1.0/24"
      delegations = [{
        name = "delegation"
        properties = {
          serviceName = "Microsoft.ServiceNetworking/trafficControllers"
        }
      }]
    }
  }
}
