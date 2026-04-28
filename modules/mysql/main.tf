# Azure Database for MySQL - Main Configuration

resource "azurerm_mysql_flexible_server" "mysql" {
  name                   = var.server_name
  location               = var.location
  resource_group_name    = var.resource_group_name
  administrator_login    = var.admin_username
  administrator_password = var.admin_password
  sku_name               = var.sku_name
  storage_gb             = var.storage_gb
  backup_retention_days  = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup_enabled
  version                = var.mysql_version

  tags = {
    Environment = var.environment
    Module      = "mysql"
  }
}

resource "azurerm_mysql_flexible_database" "database" {
  name                = var.database_name
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.mysql.name
  charset             = var.charset
  collation           = var.collation
}

# Firewall rule for Azure services
resource "azurerm_mysql_flexible_server_firewall_rule" "azure_services" {
  name                = "AllowAzureServices"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.mysql.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

# Firewall rule for AKS subnet (if provided)
resource "azurerm_mysql_flexible_server_firewall_rule" "aks_subnet" {
  count               = var.aks_subnet_address_prefix != "" ? 1 : 0
  name                = "AllowAKSSubnet"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.mysql.name
  start_ip_address    = var.aks_subnet_address_prefix
  end_ip_address      = var.aks_subnet_address_prefix
}

# Database parameter group for character set
resource "azurerm_mysql_flexible_server_configuration" "charset" {
  name                = "character_set_server"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.mysql.name
  value               = "utf8mb4"
}
