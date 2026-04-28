# Application Gateway Module - Variables

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "app_gateway_name" {
  description = "Name of the Application Gateway"
  type        = string
}

variable "sku_name" {
  description = "Name of the Application Gateway SKU"
  type        = string
  default     = "Standard_v2"
}

variable "sku_tier" {
  description = "Tier of the Application Gateway SKU"
  type        = string
  default     = "Standard_v2"
}

variable "capacity" {
  description = "Minimum capacity of the Application Gateway"
  type        = number
  default     = 1
}

variable "appgw_subnet_id" {
  description = "ID of the subnet for Application Gateway"
  type        = string
}

variable "appgw_private_ip_address" {
  description = "Private IP address for Application Gateway (must be in subnet range)"
  type        = string
}

variable "host_names" {
  description = "List of host names for the Application Gateway"
  type        = list(string)
  default     = []
}

variable "certificate_data" {
  description = "Base64-encoded PFX certificate data (optional - use if certificate_secret_id not provided)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "certificate_password" {
  description = "Password for the PFX certificate (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "certificate_secret_id" {
  description = "Key Vault secret ID containing the certificate (recommended - use this instead of certificate_data)"
  type        = string
  default     = ""
}

variable "path_based_routing" {
  description = "Enable path-based routing rules"
  type        = bool
  default     = true
}

variable "enable_waf" {
  description = "Enable Web Application Firewall"
  type        = bool
  default     = false
}

variable "waf_mode" {
  description = "WAF mode: 'Detection' or 'Prevention'"
  type        = string
  default     = "Detection"

  validation {
    condition     = contains(["Detection", "Prevention"], var.waf_mode)
    error_message = "WAF mode must be 'Detection' or 'Prevention'."
  }
}

variable "enable_monitoring" {
  description = "Enable monitoring and diagnostics"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "ID of Log Analytics workspace for diagnostics"
  type        = string
  default     = ""
}
