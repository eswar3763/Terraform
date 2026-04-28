# Staging Environment - Outputs

# Resource Group
output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.env_rg.name
}

# Network Outputs
output "vnet_id" {
  description = "Virtual Network ID"
  value       = module.network.vnet_id
}

output "subnet_id" {
  description = "Subnet ID"
  value       = module.network.subnet_id
}

# Key Vault Outputs
output "keyvault_id" {
  description = "Key Vault ID"
  value       = module.keyvault.keyvault_id
}

output "keyvault_uri" {
  description = "Key Vault URI"
  value       = module.keyvault.keyvault_uri
}

# ACR Outputs
output "acr_registry_id" {
  description = "Azure Container Registry ID"
  value       = module.acr.registry_id
}

output "acr_login_server" {
  description = "ACR Login Server"
  value       = module.acr.registry_login_server
}

output "acr_admin_username" {
  description = "ACR Admin Username"
  value       = module.acr.registry_admin_username
}

output "acr_admin_password" {
  description = "ACR Admin Password"
  value       = module.acr.registry_admin_password
  sensitive   = true
}

# AKS Outputs
output "aks_cluster_id" {
  description = "AKS Cluster ID"
  value       = module.aks.cluster_id
}

output "aks_cluster_name" {
  description = "AKS Cluster Name"
  value       = module.aks.cluster_name
}

output "aks_fqdn" {
  description = "AKS Cluster FQDN"
  value       = module.aks.fqdn
}

output "aks_kube_config" {
  description = "Kubernetes Config"
  value       = module.aks.kube_config_raw
  sensitive   = true
}

# MySQL Outputs
output "mysql_server_fqdn" {
  description = "MySQL Server FQDN"
  value       = module.mysql.server_fqdn
}

output "mysql_database_name" {
  description = "MySQL Database Name"
  value       = module.mysql.database_name
}

output "mysql_admin_username" {
  description = "MySQL Admin Username"
  value       = module.mysql.admin_username
}

output "mysql_jdbc_url" {
  description = "JDBC URL for Spring Boot"
  value       = module.mysql.jdbc_url
}

# Storage Account Outputs
output "storage_account_name" {
  description = "Storage Account Name"
  value       = module.storage.storage_account_name
}

output "storage_connection_string" {
  description = "Storage Connection String"
  value       = module.storage.storage_account_primary_connection_string
  sensitive   = true
}

output "storage_queue_name" {
  description = "Storage Queue Name"
  value       = module.storage.queue_name
}

# Function App Outputs
output "function_app_name" {
  description = "Function App Name"
  value       = module.function_app.function_app_name
}

output "function_app_url" {
  description = "Function App URL"
  value       = module.function_app.function_app_url
}

# App Service Outputs
output "app_service_name" {
  description = "App Service Name"
  value       = module.app_service.app_service_name
}

output "app_service_url" {
  description = "App Service URL"
  value       = module.app_service.app_service_url
}

# Application Gateway Outputs
output "application_gateway_id" {
  description = "Application Gateway ID"
  value       = module.application_gateway.application_gateway_id
}

output "application_gateway_name" {
  description = "Application Gateway Name"
  value       = module.application_gateway.application_gateway_name
}

output "application_gateway_public_ip" {
  description = "Public IP Address of Application Gateway (for DNS records)"
  value       = module.application_gateway.public_ip_address
}

output "agic_client_id" {
  description = "Client ID of AGIC Managed Identity"
  value       = module.application_gateway.agic_identity_id
}

output "agic_principal_id" {
  description = "Principal ID of AGIC Managed Identity"
  value       = module.application_gateway.agic_identity_principal_id
}

# Load Balancer Outputs
output "load_balancer_id" {
  description = "Load Balancer ID"
  value       = module.load_balancer.load_balancer_id
}

output "load_balancer_public_ip" {
  description = "Public IP Address of Load Balancer"
  value       = module.load_balancer.public_ip_address
}

# Domain Configuration Summary
output "domain_configuration_summary" {
  description = "Summary for domain configuration"
  value = {
    domain_name        = "myapp.com"
    app_gateway_ip     = module.application_gateway.public_ip_address
    load_balancer_ip   = module.load_balancer.public_ip_address
    dns_a_record       = "myapp.com → ${module.application_gateway.public_ip_address}"
  }
}
