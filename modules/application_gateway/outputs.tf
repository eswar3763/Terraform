# Application Gateway Module - Outputs

output "application_gateway_id" {
  description = "ID of the Application Gateway"
  value       = azurerm_application_gateway.appgw.id
}

output "application_gateway_name" {
  description = "Name of the Application Gateway"
  value       = azurerm_application_gateway.appgw.name
}

output "public_ip_address" {
  description = "Public IP address of the Application Gateway"
  value       = azurerm_public_ip.appgw_public_ip.ip_address
}

output "public_ip_id" {
  description = "ID of the public IP address"
  value       = azurerm_public_ip.appgw_public_ip.id
}

output "frontend_ip_configuration_ids" {
  description = "IDs of frontend IP configurations"
  value = {
    public  = azurerm_application_gateway.appgw.frontend_ip_configuration[0].id
    private = azurerm_application_gateway.appgw.frontend_ip_configuration[1].id
  }
}

output "agic_identity_id" {
  description = "Client ID of the AGIC managed identity"
  value       = azurerm_user_assigned_identity.agic_identity.client_id
}

output "agic_identity_principal_id" {
  description = "Principal ID of the AGIC managed identity"
  value       = azurerm_user_assigned_identity.agic_identity.principal_id
}

output "agic_identity_resource_id" {
  description = "Resource ID of the AGIC managed identity"
  value       = azurerm_user_assigned_identity.agic_identity.id
}

output "backend_address_pool_id" {
  description = "ID of the backend address pool"
  value       = azurerm_application_gateway.appgw.backend_address_pool[0].id
}

output "application_insights_id" {
  description = "ID of Application Insights"
  value       = var.enable_monitoring ? azurerm_application_insights.appgw_insights[0].id : ""
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights"
  value       = var.enable_monitoring ? azurerm_application_insights.appgw_insights[0].instrumentation_key : ""
  sensitive   = true
}
