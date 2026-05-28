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

provider "azapi" {}

provider "azurerm" {
  features {}
}

## Region selection — AG4C is available in limited regions
module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.11.0"
}

resource "random_integer" "region_index" {
  max = length(local.regions) - 1
  min = 0
}

locals {
  regions = [
    for r in module.regions.regions : r
    if contains(["eastus", "eastus2", "westus2", "centralus", "southcentralus", "northeurope", "westeurope", "uksouth", "canadacentral"], r.name)
  ]
  selected_region = local.regions[random_integer.region_index.result].name
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.3"
}

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------
resource "azapi_resource" "rg" {
  location = local.selected_region
  name     = module.naming.resource_group.name_unique
  type     = "Microsoft.Resources/resourceGroups@2024-03-01"
}

# -----------------------------------------------------------------------------
# Networking — VNet with 3 subnets
# -----------------------------------------------------------------------------
resource "azapi_resource" "vnet" {
  location  = local.selected_region
  name      = module.naming.virtual_network.name_unique
  parent_id = azapi_resource.rg.id
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  body = {
    properties = {
      addressSpace = {
        addressPrefixes = ["10.0.0.0/16"]
      }
    }
  }
}

# AKS node subnet
resource "azapi_resource" "subnet_aks" {
  name      = "subnet-aks"
  parent_id = azapi_resource.vnet.id
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  body = {
    properties = {
      addressPrefix = "10.0.1.0/24"
    }
  }
}

# AG4C association subnet — delegated to Microsoft.ServiceNetworking/trafficControllers
resource "azapi_resource" "subnet_agc" {
  name      = "subnet-agc"
  parent_id = azapi_resource.vnet.id
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  body = {
    properties = {
      addressPrefix = "10.0.2.0/24"
      delegations = [{
        name = "agc-delegation"
        properties = {
          serviceName = "Microsoft.ServiceNetworking/trafficControllers"
        }
      }]
    }
  }
  # The Application Gateway for Containers association keeps the subnet briefly
  # "in use" after it is deleted; retry the subnet deletion until it is released.
  retry = {
    error_message_regex  = ["InUseSubnetCannotBeDeleted"]
    interval_seconds     = 30
    max_interval_seconds = 120
  }

  depends_on = [azapi_resource.subnet_aks]
}

# API Server VNet Integration subnet — delegated to Microsoft.ContainerService/managedClusters
resource "azapi_resource" "subnet_apiserver" {
  name      = "subnet-apiserver"
  parent_id = azapi_resource.vnet.id
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-05-01"
  body = {
    properties = {
      addressPrefix = "10.0.3.0/28"
      delegations = [{
        name = "aks-delegation"
        properties = {
          serviceName = "Microsoft.ContainerService/managedClusters"
        }
      }]
    }
  }

  depends_on = [azapi_resource.subnet_agc]
}

# -----------------------------------------------------------------------------
# User-Assigned Managed Identity — for ALB Controller
# -----------------------------------------------------------------------------
resource "azapi_resource" "uami_alb" {
  location  = local.selected_region
  name      = "id-alb-controller"
  parent_id = azapi_resource.rg.id
  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
}

# User-Assigned Managed Identity — for AKS cluster control plane (required for VNet integration)
resource "azapi_resource" "uami_aks" {
  location  = local.selected_region
  name      = "id-aks-cluster"
  parent_id = azapi_resource.rg.id
  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
}

resource "random_uuid" "role_agc_config_manager" {}
resource "random_uuid" "role_network_contributor" {}
resource "random_uuid" "role_aks_network_contributor" {}

# Role: AppGw for Containers Configuration Manager on the Resource Group
resource "azapi_resource" "role_agc_config_manager" {
  name      = random_uuid.role_agc_config_manager.result
  parent_id = azapi_resource.rg.id
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  body = {
    properties = {
      principalId      = azapi_resource.uami_alb.output.properties.principalId
      principalType    = "ServicePrincipal"
      roleDefinitionId = "/subscriptions/${data.azapi_client_config.this.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/fbc52c3f-28ad-4303-a892-8a056630b8f1"
    }
  }
  response_export_values = []
}

# Role: Network Contributor on the AG4C subnet
resource "azapi_resource" "role_network_contributor" {
  name      = random_uuid.role_network_contributor.result
  parent_id = azapi_resource.subnet_agc.id
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  body = {
    properties = {
      principalId      = azapi_resource.uami_alb.output.properties.principalId
      principalType    = "ServicePrincipal"
      roleDefinitionId = "/subscriptions/${data.azapi_client_config.this.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7"
    }
  }
  response_export_values = []
}

data "azapi_client_config" "this" {}

# Role: Network Contributor on the VNet for the AKS identity
resource "azapi_resource" "role_aks_network_contributor" {
  name      = random_uuid.role_aks_network_contributor.result
  parent_id = azapi_resource.vnet.id
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  body = {
    properties = {
      principalId      = azapi_resource.uami_aks.output.properties.principalId
      principalType    = "ServicePrincipal"
      roleDefinitionId = "/subscriptions/${data.azapi_client_config.this.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7"
    }
  }
  response_export_values = []
}

# -----------------------------------------------------------------------------
# AKS Cluster — via AVM module
# -----------------------------------------------------------------------------
module "aks" {
  source  = "Azure/avm-res-containerservice-managedcluster/azurerm"
  version = "0.5.4"

  location  = local.selected_region
  name      = module.naming.kubernetes_cluster.name_unique
  parent_id = azapi_resource.rg.id
  # Private cluster with API server VNet integration
  api_server_access_profile = {
    enable_private_cluster  = true
    enable_vnet_integration = true
    subnet_id               = azapi_resource.subnet_apiserver.id
  }
  # Default node pool
  default_agent_pool = {
    vm_size             = "Standard_D4ds_v5"
    os_sku              = "AzureLinux"
    vnet_subnet_id      = azapi_resource.subnet_aks.id
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 3
    count_of            = 1
  }
  enable_telemetry = var.enable_telemetry
  # User-assigned identity required for VNet integration
  managed_identities = {
    system_assigned            = false
    user_assigned_resource_ids = [azapi_resource.uami_aks.id]
  }
  # Standard tier provides a financially-backed SLA (WAF reliability)
  sku = {
    name = "Base"
    tier = "Standard"
  }
  # Network configuration — Azure CNI
  network_profile = {
    network_plugin = "azure"
    service_cidr   = "172.16.0.0/16"
    dns_service_ip = "172.16.0.10"
  }
  # Required for ALB Controller workload identity
  oidc_issuer_profile = {
    enabled = true
  }
  security_profile = {
    workload_identity = {
      enabled = true
    }
  }

  depends_on = [azapi_resource.role_aks_network_contributor]
}

# -----------------------------------------------------------------------------
# Application Gateway for Containers — via this module
# -----------------------------------------------------------------------------
# WAF Policy for Application Gateway for Containers
# -----------------------------------------------------------------------------
resource "azapi_resource" "waf_policy" {
  location  = local.selected_region
  name      = "waf-agc-${module.naming.application_gateway.name_unique}"
  parent_id = azapi_resource.rg.id
  type      = "Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2024-05-01"
  body = {
    properties = {
      policySettings = {
        state                  = "Enabled"
        mode                   = "Prevention"
        requestBodyCheck       = true
        maxRequestBodySizeInKb = 128
        fileUploadLimitInMb    = 100
      }
      managedRules = {
        managedRuleSets = [{
          ruleSetType    = "Microsoft_DefaultRuleSet"
          ruleSetVersion = "2.1"
        }]
      }
    }
  }
}

# -----------------------------------------------------------------------------
module "agc" {
  source = "../../"

  location  = local.selected_region
  name      = "agc-${module.naming.application_gateway.name_unique}"
  parent_id = azapi_resource.rg.id
  associations = {
    main = {
      name               = "association-main"
      subnet_resource_id = azapi_resource.subnet_agc.id
    }
  }
  enable_telemetry = var.enable_telemetry
  frontends = {
    web = {
      name = "frontend-web"
    }
  }
  security_policies = {
    waf = {
      name                   = "secpol-waf"
      waf_policy_resource_id = azapi_resource.waf_policy.id
    }
  }

  depends_on = [
    azapi_resource.role_agc_config_manager,
    azapi_resource.role_network_contributor,
    module.aks
  ]
}
