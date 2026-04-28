# Network Module
# This module creates Azure Virtual Network resources

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

variable "vnet_name" {
  description = "Virtual Network name"
  type        = string
}

variable "vnet_address_space" {
  description = "Virtual Network address space"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_name" {
  description = "Subnet name"
  type        = string
}

variable "subnet_address_prefix" {
  description = "Subnet address prefix"
  type        = string
  default     = "10.0.1.0/24"
}

variable "appgw_subnet_name" {
  description = "Application Gateway subnet name"
  type        = string
  default     = "appgw-subnet"
}

variable "appgw_subnet_address_prefix" {
  description = "Application Gateway subnet address prefix"
  type        = string
  default     = "10.0.2.0/24"
}

variable "create_lb_subnet" {
  description = "Create Load Balancer subnet"
  type        = bool
  default     = false
}

variable "lb_subnet_name" {
  description = "Load Balancer subnet name"
  type        = string
  default     = "lb-subnet"
}

variable "lb_subnet_address_prefix" {
  description = "Load Balancer subnet address prefix"
  type        = string
  default     = "10.0.3.0/24"
}
