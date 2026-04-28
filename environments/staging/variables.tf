variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "client_id" {
  description = "Azure Client ID (Service Principal)"
  type        = string
}

variable "client_secret" {
  description = "Azure Client Secret (Service Principal)"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-3tier-app-staging"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

# Network Variables
variable "vnet_name" {
  description = "Virtual Network name"
  type        = string
  default     = "vnet-staging"
}

variable "vnet_address_space" {
  description = "Virtual Network address space"
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "subnet_name" {
  description = "Subnet name"
  type        = string
  default     = "subnet-staging"
}

variable "subnet_address_prefix" {
  description = "Subnet address prefix"
  type        = string
  default     = "10.1.1.0/24"
}

# Key Vault Variables
variable "keyvault_name" {
  description = "Key Vault name (must be globally unique)"
  type        = string
  default     = "kv3tierapp-staging"
}

# ACR Variables
variable "acr_name" {
  description = "Azure Container Registry name"
  type        = string
  default     = "acr3tierappstaging"
}

# AKS Variables
variable "aks_cluster_name" {
  description = "AKS Cluster name"
  type        = string
  default     = "aks-3tier-staging"
}

variable "aks_dns_prefix" {
  description = "DNS prefix for AKS cluster"
  type        = string
  default     = "aks3tierstaging"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.27"
}

# MySQL Variables
variable "mysql_server_name" {
  description = "MySQL Server name"
  type        = string
  default     = "mysql-3tier-staging"
}

variable "mysql_database_name" {
  description = "MySQL Database name"
  type        = string
  default     = "appdb"
}

variable "mysql_admin_username" {
  description = "MySQL admin username"
  type        = string
  default     = "azureuser"
}

variable "mysql_admin_password" {
  description = "MySQL admin password (min 8 chars, include uppercase, lowercase, digit, special)"
  type        = string
  sensitive   = true
}

# Storage Account Variables
variable "storage_account_name" {
  description = "Storage Account name (globally unique, lowercase alphanumeric only)"
  type        = string
  default     = "st3tierappstaging"
}

# Function App Variables
variable "function_app_name" {
  description = "Function App name"
  type        = string
  default     = "func-3tier-staging"
}

# App Service Variables
variable "app_service_plan_name" {
  description = "App Service Plan name"
  type        = string
  default     = "asp-3tier-staging"
}

variable "app_service_name" {
  description = "App Service name"
  type        = string
  default     = "app-3tier-staging"
}

# Monitoring Variables
variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID (optional)"
  type        = string
  default     = ""
}

# Application Gateway Variables
variable "app_gateway_name" {
  description = "Application Gateway name"
  type        = string
  default     = "appgw-3tier-staging"
}

variable "app_gateway_sku_name" {
  description = "Application Gateway SKU name"
  type        = string
  default     = "Standard_v2"
}

variable "app_gateway_sku_tier" {
  description = "Application Gateway SKU tier"
  type        = string
  default     = "Standard_v2"
}

variable "app_gateway_capacity" {
  description = "Application Gateway capacity"
  type        = number
  default     = 2
}

variable "appgw_private_ip_address" {
  description = "Private IP address for Application Gateway"
  type        = string
  default     = "10.1.2.5"
}

variable "app_gateway_host_names" {
  description = "Host names for Application Gateway"
  type        = list(string)
  default     = ["myapp.com", "www.myapp.com"]
}

variable "app_gateway_path_based_routing" {
  description = "Enable path-based routing on Application Gateway"
  type        = bool
  default     = true
}

variable "certificate_secret_id" {
  description = "Key Vault secret ID for SSL certificate"
  type        = string
  default     = ""
}

variable "enable_waf" {
  description = "Enable Web Application Firewall"
  type        = bool
  default     = true
}

variable "waf_mode" {
  description = "WAF mode: Detection or Prevention"
  type        = string
  default     = "Detection"
}

# Load Balancer Variables
variable "load_balancer_name" {
  description = "Load Balancer name"
  type        = string
  default     = "lb-3tier-staging"
}

variable "load_balancer_sku" {
  description = "Load Balancer SKU"
  type        = string
  default     = "Standard"
}
