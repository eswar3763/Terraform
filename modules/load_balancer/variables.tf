# Load Balancer Module - Variables

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

variable "load_balancer_name" {
  description = "Name of the Load Balancer"
  type        = string
}

variable "sku" {
  description = "SKU of the Load Balancer (Basic or Standard)"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard"], var.sku)
    error_message = "SKU must be 'Basic' or 'Standard'."
  }
}

variable "subnet_id" {
  description = "ID of the subnet (for private IP configuration)"
  type        = string
  default     = ""
}

variable "enable_private_ip" {
  description = "Enable private IP frontend"
  type        = bool
  default     = false
}

variable "private_ip_address" {
  description = "Private IP address for the load balancer (must be in subnet range)"
  type        = string
  default     = ""
}

variable "probe_protocol" {
  description = "Protocol for health probe (Tcp, Http, Https)"
  type        = string
  default     = "Http"

  validation {
    condition     = contains(["Tcp", "Http", "Https"], var.probe_protocol)
    error_message = "Probe protocol must be 'Tcp', 'Http', or 'Https'."
  }
}

variable "probe_port" {
  description = "Port for health probe"
  type        = number
  default     = 80
}

variable "load_balancing_rules" {
  description = "Map of load balancing rules"
  type = map(object({
    protocol               = string
    frontend_port          = number
    backend_port           = number
    enable_floating_ip     = bool
    idle_timeout_in_minutes = number
    load_distribution      = string
  }))
  default = {
    http = {
      protocol               = "Tcp"
      frontend_port          = 80
      backend_port           = 80
      enable_floating_ip     = false
      idle_timeout_in_minutes = 4
      load_distribution      = "SourceIPProtocol"
    }
    https = {
      protocol               = "Tcp"
      frontend_port          = 443
      backend_port           = 443
      enable_floating_ip     = false
      idle_timeout_in_minutes = 4
      load_distribution      = "SourceIPProtocol"
    }
  }
}

variable "enable_outbound_rule" {
  description = "Enable outbound rule for NAT"
  type        = bool
  default     = true
}

variable "enable_ssh_nat" {
  description = "Enable SSH NAT rule"
  type        = bool
  default     = false
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
