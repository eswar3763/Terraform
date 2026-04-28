# Storage Account - Main Configuration

resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name
  location                 = var.location
  resource_group_name      = var.resource_group_name
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
  access_tier              = var.access_tier
  https_traffic_only_enabled = true
  min_tls_version          = "TLS1_2"

  tags = {
    Environment = var.environment
    Module      = "storage"
  }
}

# Storage queue for async processing
resource "azurerm_storage_queue" "function_queue" {
  count                = var.create_queue ? 1 : 0
  name                 = var.queue_name
  storage_account_name = azurerm_storage_account.storage.name
}

# Storage container for blob storage (images, documents)
resource "azurerm_storage_container" "blob_container" {
  count                 = var.create_blob_container ? 1 : 0
  name                  = var.blob_container_name
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

# Storage table for state management
resource "azurerm_storage_table" "state_table" {
  count                = var.create_table ? 1 : 0
  name                 = var.table_name
  storage_account_name = azurerm_storage_account.storage.name
}

# Diagnostic settings for storage account
resource "azurerm_monitor_diagnostic_setting" "storage_logs" {
  count              = var.log_analytics_workspace_id != "" ? 1 : 0
  name               = "${var.storage_account_name}-logs"
  target_resource_id = "${azurerm_storage_account.storage.id}/queueServices/default"
  
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
    enabled  = true
  }
}
