variable "plan_name" {
  description = "Name of the App Service Plan"
  type        = string
}

variable "app_name" {
  description = "Name of the App Service (must be globally unique)"
  type        = string
}

variable "location" {
  description = "Azure region for the App Service"
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

variable "sku_name" {
  description = "SKU tier for App Service Plan (F1=Free, B1=Basic, S1=Standard, P1v2=Premium)"
  type        = string
  default     = "B1"
}

variable "docker_image_name" {
  description = "Docker image name (e.g., myapp:latest)"
  type        = string
}

variable "docker_registry_url" {
  description = "Docker registry URL (e.g., https://myacr.azurecr.io)"
  type        = string
}

variable "docker_registry_username" {
  description = "Docker registry username"
  type        = string
  sensitive   = true
}

variable "docker_registry_password" {
  description = "Docker registry password"
  type        = string
  sensitive   = true
}

variable "app_command_line" {
  description = "App command line or startup script"
  type        = string
  default     = ""
}

variable "app_settings" {
  description = "Additional application settings (environment variables)"
  type        = map(string)
  default     = {}
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for diagnostic logs"
  type        = string
  default     = ""
}
