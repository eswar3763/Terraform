variable "server_name" {
  description = "Name of the MySQL Flexible Server"
  type        = string
}

variable "location" {
  description = "Azure region for the MySQL server"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "admin_username" {
  description = "Administrator username"
  type        = string
  default     = "azureuser"
  sensitive   = true
}

variable "admin_password" {
  description = "Administrator password (must be 8-128 characters, contain uppercase, lowercase, digit, special char)"
  type        = string
  sensitive   = true
}

variable "sku_name" {
  description = "SKU name for the MySQL server (e.g., B_Standard_B1s, B_Standard_B2s, GP_Standard_D2s_v3)"
  type        = string
  default     = "B_Standard_B1s"
}

variable "storage_gb" {
  description = "Storage size in GB (20-16384)"
  type        = number
  default     = 20
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "geo_redundant_backup_enabled" {
  description = "Enable geo-redundant backups"
  type        = bool
  default     = false
}

variable "mysql_version" {
  description = "MySQL version (5.7 or 8.0)"
  type        = string
  default     = "8.0"
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "appdb"
}

variable "charset" {
  description = "Database character set"
  type        = string
  default     = "utf8mb4"
}

variable "collation" {
  description = "Database collation"
  type        = string
  default     = "utf8mb4_unicode_ci"
}

variable "aks_subnet_address_prefix" {
  description = "AKS subnet address prefix for firewall rule (leave empty to skip)"
  type        = string
  default     = ""
}
