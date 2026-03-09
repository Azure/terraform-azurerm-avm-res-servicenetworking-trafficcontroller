output "associations" {
  description = "The associations created on the Application Gateway for Containers."
  value = {
    for k, v in azapi_resource.association : k => {
      name               = v.name
      resource_id        = v.id
      subnet_resource_id = v.output.properties.subnet.id
    }
  }
}

output "configuration_endpoints" {
  description = "The configuration endpoints of the Application Gateway for Containers."
  value       = azapi_resource.this.output.properties.configurationEndpoints
}

output "frontends" {
  description = "The frontends created on the Application Gateway for Containers."
  value = {
    for k, v in azapi_resource.frontend : k => {
      name        = v.name
      resource_id = v.id
      fqdn        = v.output.properties.fqdn
    }
  }
}

output "name" {
  description = "The name of the Application Gateway for Containers (Traffic Controller)."
  value       = azapi_resource.this.name
}

output "resource" {
  description = "The Application Gateway for Containers (Traffic Controller) resource."
  value       = azapi_resource.this
}

output "resource_id" {
  description = "The resource ID of the Application Gateway for Containers (Traffic Controller)."
  value       = azapi_resource.this.id
}

output "security_policies" {
  description = "The security policies created on the Application Gateway for Containers."
  value = {
    for k, v in azapi_resource.security_policy : k => {
      name        = v.name
      resource_id = v.id
    }
  }
}
