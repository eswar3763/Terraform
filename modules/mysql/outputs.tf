output "server_id" {
  description = "The ID of the MySQL Flexible Server"
  value       = azurerm_mysql_flexible_server.mysql.id
}

output "server_name" {
  description = "The name of the MySQL Flexible Server"
  value       = azurerm_mysql_flexible_server.mysql.name
}

output "server_fqdn" {
  description = "The FQDN of the MySQL server (for connection strings)"
  value       = azurerm_mysql_flexible_server.mysql.fqdn
}

output "database_name" {
  description = "The name of the created database"
  value       = azurerm_mysql_flexible_database.database.name
}

output "admin_username" {
  description = "Administrator username"
  value       = azurerm_mysql_flexible_server.mysql.administrator_login
}

output "connection_string" {
  description = "JDBC connection string for Spring Boot (mysql://<user>:<password>@<fqdn>:3306/<db>)"
  value       = "mysql://${var.admin_username}:*****@${azurerm_mysql_flexible_server.mysql.fqdn}:3306/${azurerm_mysql_flexible_database.database.name}"
  sensitive   = true
}

output "jdbc_url" {
  description = "JDBC URL for Spring Boot (jdbc:mysql://...)"
  value       = "jdbc:mysql://${azurerm_mysql_flexible_server.mysql.fqdn}:3306/${azurerm_mysql_flexible_database.database.name}?useSSL=true&requireSSL=true"
}
