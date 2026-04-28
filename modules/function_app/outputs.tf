output "function_app_id" {
  description = "The ID of the Function App"
  value       = azurerm_function_app.function_app.id
}

output "function_app_name" {
  description = "The name of the Function App"
  value       = azurerm_function_app.function_app.name
}

output "function_app_default_hostname" {
  description = "The default hostname of the Function App"
  value       = azurerm_function_app.function_app.default_hostname
}

output "function_app_url" {
  description = "The default URL of the Function App"
  value       = "https://${azurerm_function_app.function_app.default_hostname}"
}

output "function_app_principal_id" {
  description = "The principal ID of the system-assigned managed identity"
  value       = azurerm_function_app.function_app.identity[0].principal_id
}

output "host_keys" {
  description = "Default host keys for the Function App"
  value       = azurerm_function_app_host_keys.host_keys.default_function_key
  sensitive   = true
}
