output "agc_frontend_fqdn" {
  description = "The FQDN of the AG4C frontend. Use this to create a DNS CNAME record."
  value       = module.agc.frontends["web"].fqdn
}

output "agc_resource_id" {
  description = "The resource ID of the Application Gateway for Containers."
  value       = module.agc.resource_id
}

output "aks_cluster_name" {
  description = "The name of the AKS cluster."
  value       = module.aks.name
}

output "resource_group_name" {
  description = "The name of the resource group."
  value       = azapi_resource.rg.name
}

output "uami_client_id" {
  description = "The client ID of the ALB Controller managed identity. Use this when configuring federated credentials."
  value       = azapi_resource.uami_alb.output.properties.clientId
}
