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
