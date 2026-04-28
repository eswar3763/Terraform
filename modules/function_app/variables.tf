variable "function_app_name" {
  description = "Name of the Function App (must be globally unique)"
  type        = string
}

variable "location" {
  description = "Azure region for the Function App"
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

variable "plan_type" {
  description = "Hosting plan type (consumption or app_service)"
  type        = string
  default     = "consumption"

  validation {
    condition     = contains(["consumption", "app_service"], var.plan_type)
    error_message = "Plan type must be either 'consumption' or 'app_service'."
  }
}

variable "plan_name" {
  description = "Name of the App Service Plan (only used if plan_type is app_service)"
  type        = string
  default     = ""
}

variable "plan_sku_name" {
  description = "SKU for App Service Plan (only used if plan_type is app_service, e.g., B1, S1, P1v2)"
  type        = string
  default     = "B1"
}

variable "runtime" {
  description = "Function App runtime (node, python, java, dotnet, etc.)"
  type        = string
  default     = "node"
}

variable "runtime_version" {
  description = "Runtime version (e.g., 16, 18 for Node.js, 3.9 for Python)"
  type        = string
  default     = "18"
}

variable "storage_account_name" {
  description = "Name of the storage account for function runtime"
  type        = string
}

variable "storage_account_access_key" {
  description = "Access key for the storage account"
  type        = string
  sensitive   = true
}

variable "storage_account_connection_string" {
  description = "Connection string for the storage account"
  type        = string
  sensitive   = true
}

variable "app_settings" {
  description = "Additional application settings (environment variables)"
  type        = map(string)
  default     = {}
}

variable "app_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  type        = string
  default     = ""
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for diagnostic logs"
  type        = string
  default     = ""
}
