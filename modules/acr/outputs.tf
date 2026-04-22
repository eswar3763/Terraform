# Azure Container Registry Module - Outputs

output "registry_id" {
  description = "Container Registry ID"
  value       = azurerm_container_registry.acr.id
}

output "registry_name" {
  description = "Container Registry name"
  value       = azurerm_container_registry.acr.name
}

output "login_server" {
  description = "Container Registry login server"
  value       = azurerm_container_registry.acr.login_server
}
