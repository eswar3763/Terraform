output "storage_account_id" {
  description = "The ID of the storage account"
  value       = azurerm_storage_account.storage.id
}

output "storage_account_name" {
  description = "The name of the storage account"
  value       = azurerm_storage_account.storage.name
}

output "storage_account_primary_blob_endpoint" {
  description = "The primary blob endpoint URL"
  value       = azurerm_storage_account.storage.primary_blob_endpoint
}

output "storage_account_primary_connection_string" {
  description = "The primary connection string (for Function Apps, apps)"
  value       = azurerm_storage_account.storage.primary_connection_string
  sensitive   = true
}

output "storage_account_access_key" {
  description = "The primary access key"
  value       = azurerm_storage_account.storage.primary_access_key
  sensitive   = true
}

output "queue_name" {
  description = "The name of the storage queue"
  value       = try(azurerm_storage_queue.function_queue[0].name, "")
}

output "blob_container_name" {
  description = "The name of the blob container"
  value       = try(azurerm_storage_container.blob_container[0].name, "")
}

output "table_name" {
  description = "The name of the storage table"
  value       = try(azurerm_storage_table.state_table[0].name, "")
}
