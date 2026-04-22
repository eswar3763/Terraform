# Azure Key Vault Module - Variables

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "keyvault_name" {
  description = "Key Vault name"
  type        = string
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

variable "sku_name" {
  description = "Key Vault SKU name"
  type        = string
  default     = "standard"
}

variable "enabled_for_disk_encryption" {
  description = "Enable disk encryption"
  type        = bool
  default     = true
}

variable "enabled_for_template_deployment" {
  description = "Enable for template deployment"
  type        = bool
  default     = true
}
