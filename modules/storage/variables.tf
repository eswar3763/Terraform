variable "storage_account_name" {
  description = "Name of the storage account (must be 3-24 lowercase alphanumeric)"
  type        = string
}

variable "location" {
  description = "Azure region for the storage account"
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

variable "account_tier" {
  description = "Storage account tier (Standard or Premium)"
  type        = string
  default     = "Standard"
}

variable "account_replication_type" {
  description = "Replication type (LRS, GRS, RAGRS, ZRS)"
  type        = string
  default     = "LRS"
}

variable "access_tier" {
  description = "Access tier (Hot or Cool)"
  type        = string
  default     = "Hot"
}

variable "create_queue" {
  description = "Whether to create a storage queue"
  type        = bool
  default     = true
}

variable "queue_name" {
  description = "Name of the storage queue"
  type        = string
  default     = "function-queue"
}

variable "create_blob_container" {
  description = "Whether to create a blob container"
  type        = bool
  default     = true
}

variable "blob_container_name" {
  description = "Name of the blob container"
  type        = string
  default     = "app-blobs"
}

variable "create_table" {
  description = "Whether to create a storage table"
  type        = bool
  default     = false
}

variable "table_name" {
  description = "Name of the storage table"
  type        = string
  default     = "appstate"
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for diagnostic logs"
  type        = string
  default     = ""
}
