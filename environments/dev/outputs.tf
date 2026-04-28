# Dev Environment - Outputs

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
  description = "ACR Login Server (use this for docker push/pull)"
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
  description = "Kubernetes Config (for kubectl config use-context)"
  value       = module.aks.kube_config_raw
  sensitive   = true
}

# MySQL Outputs
output "mysql_server_fqdn" {
  description = "MySQL Server FQDN (use this in connection strings)"
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
  description = "JDBC URL for Spring Boot applications"
  value       = module.mysql.jdbc_url
}

# Storage Account Outputs
output "storage_account_name" {
  description = "Storage Account Name"
  value       = module.storage.storage_account_name
}

output "storage_account_primary_blob_endpoint" {
  description = "Storage Account Blob Endpoint"
  value       = module.storage.storage_account_primary_blob_endpoint
}

output "storage_connection_string" {
  description = "Storage Account Connection String (for Function Apps)"
  value       = module.storage.storage_account_primary_connection_string
  sensitive   = true
}

output "storage_queue_name" {
  description = "Storage Queue Name"
  value       = module.storage.queue_name
}

output "storage_blob_container_name" {
  description = "Blob Container Name"
  value       = module.storage.blob_container_name
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

# Connection Strings Summary
output "connection_strings_summary" {
  description = "Summary of connection strings for application configuration"
  value = {
    mysql_jdbc_url = module.mysql.jdbc_url
    mysql_host     = module.mysql.server_fqdn
    mysql_user     = module.mysql.admin_username
    acr_server     = module.acr.registry_login_server
    storage_connection_string = "See storage_connection_string output"
    aks_api_endpoint = module.aks.fqdn
  }
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
  description = "Public IP Address of Application Gateway (use this for your domain)"
  value       = module.application_gateway.public_ip_address
}

output "application_gateway_public_ip_id" {
  description = "Public IP ID of Application Gateway"
  value       = module.application_gateway.public_ip_id
}

output "agic_client_id" {
  description = "Client ID of AGIC Managed Identity (for Kubernetes)"
  value       = module.application_gateway.agic_identity_id
}

output "agic_principal_id" {
  description = "Principal ID of AGIC Managed Identity"
  value       = module.application_gateway.agic_identity_principal_id
}

output "agic_identity_resource_id" {
  description = "Resource ID of AGIC Managed Identity"
  value       = module.application_gateway.agic_identity_resource_id
}

# Load Balancer Outputs
output "load_balancer_id" {
  description = "Load Balancer ID"
  value       = module.load_balancer.load_balancer_id
}

output "load_balancer_name" {
  description = "Load Balancer Name"
  value       = module.load_balancer.load_balancer_name
}

output "load_balancer_public_ip" {
  description = "Public IP Address of Load Balancer (for backup/failover)"
  value       = module.load_balancer.public_ip_address
}

output "load_balancer_backend_pool_id" {
  description = "Backend Address Pool ID"
  value       = module.load_balancer.backend_address_pool_id
}

# Domain Configuration Summary
output "domain_configuration_summary" {
  description = "Summary for domain configuration"
  value = {
    domain_name        = "myapp.com"
    app_gateway_ip     = module.application_gateway.public_ip_address
    load_balancer_ip   = module.load_balancer.public_ip_address
    dns_a_record       = "myapp.com → ${module.application_gateway.public_ip_address}"
    dns_www_record     = "www.myapp.com → ${module.application_gateway.public_ip_address}"
  }
}
