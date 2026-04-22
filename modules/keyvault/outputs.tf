# Azure Key Vault Module - Outputs

output "keyvault_id" {
  description = "Key Vault ID"
  value       = azurerm_key_vault.kv.id
}

output "keyvault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.kv.name
}

output "keyvault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.kv.vault_uri
}
