# AKS Module - Variables

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

variable "cluster_name" {
  description = "AKS Cluster name"
  type        = string
}

variable "dns_prefix" {
  description = "DNS prefix for AKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.27"
}

variable "node_count" {
  description = "Initial number of nodes in the default node pool"
  type        = number
  default     = 3
}

variable "vm_size" {
  description = "Virtual machine size for AKS nodes"
  type        = string
  default     = "Standard_B2s"
}

variable "subnet_id" {
  description = "Subnet ID for AKS cluster networking"
  type        = string
  default     = ""
}

variable "availability_zones" {
  description = "Availability zones for node pool (for HA in prod)"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for node pool"
  type        = bool
  default     = true
}

variable "min_node_count" {
  description = "Minimum number of nodes for auto-scaling"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes for auto-scaling"
  type        = number
  default     = 5
}

variable "service_cidr" {
  description = "CIDR block for Kubernetes service objects"
  type        = string
  default     = "10.1.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address within service_cidr for DNS"
  type        = string
  default     = "10.1.0.10"
}

variable "docker_bridge_cidr" {
  description = "CIDR block for Docker bridge"
  type        = string
  default     = "172.17.0.1/16"
}

variable "api_server_authorized_ips" {
  description = "Authorized IP ranges for API server access (whitelist)"
  type        = list(string)
  default     = []
}

variable "enable_monitoring" {
  description = "Enable Azure Monitor for AKS"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for monitoring"
  type        = string
  default     = ""
}

variable "acr_id" {
  description = "Azure Container Registry ID for ACR pull permissions"
  type        = string
  default     = ""
}
