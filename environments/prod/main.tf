# Prod Environment - Main Configuration
# HA production setup: 3+ nodes across AZs, P1v2 App Service, Memory-optimized MySQL

# Create Resource Group
resource "azurerm_resource_group" "env_rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = var.environment
    Project     = "Terraform-Azure"
    CreatedBy   = "Terraform"
  }
}

# Network Module
module "network" {
  source = "../../modules/network"

  resource_group_name     = azurerm_resource_group.env_rg.name
  location                = azurerm_resource_group.env_rg.location
  environment             = var.environment
  vnet_name               = var.vnet_name
  vnet_address_space      = var.vnet_address_space
  subnet_name             = var.subnet_name
  subnet_address_prefix   = var.subnet_address_prefix
  appgw_subnet_name       = "appgw-subnet"
  appgw_subnet_address_prefix = "10.2.2.0/24"
  create_lb_subnet        = false
}

# Key Vault Module
module "keyvault" {
  source = "../../modules/keyvault"

  resource_group_name  = azurerm_resource_group.env_rg.name
  location             = azurerm_resource_group.env_rg.location
  environment          = var.environment
  keyvault_name        = var.keyvault_name
  tenant_id            = var.tenant_id
  sku_name             = "premium"  # Premium for production
}

# ACR Module
module "acr" {
  source = "../../modules/acr"

  resource_group_name = azurerm_resource_group.env_rg.name
  location            = azurerm_resource_group.env_rg.location
  environment         = var.environment
  registry_name       = var.acr_name
  sku                 = "Premium"  # Premium for production
  admin_enabled       = true
}

# AKS Module - HA Configuration
module "aks" {
  source = "../../modules/aks"

  resource_group_name  = azurerm_resource_group.env_rg.name
  location             = azurerm_resource_group.env_rg.location
  environment          = var.environment
  cluster_name         = var.aks_cluster_name
  dns_prefix           = var.aks_dns_prefix
  kubernetes_version   = var.kubernetes_version
  node_count           = 3  # 3 nodes minimum for HA
  vm_size              = "Standard_D2s_v3"  # Higher-spec VMs for production
  subnet_id            = module.network.subnet_id
  availability_zones   = ["1", "2", "3"]  # Spread across zones
  enable_auto_scaling  = true
  min_node_count       = 3
  max_node_count       = 10  # Allow scaling up to 10
  log_analytics_workspace_id = var.log_analytics_workspace_id
  acr_id               = module.acr.registry_id
  api_server_authorized_ips = var.api_server_authorized_ips
}

# MySQL Module - HA Configuration
module "mysql" {
  source = "../../modules/mysql"

  resource_group_name = azurerm_resource_group.env_rg.name
  location            = azurerm_resource_group.env_rg.location
  environment         = var.environment
  server_name         = var.mysql_server_name
  database_name       = var.mysql_database_name
  admin_username      = var.mysql_admin_username
  admin_password      = var.mysql_admin_password
  sku_name            = "MO_Standard_E4s_v3"  # Memory-optimized for production
  storage_gb          = 256  # 256GB for production workloads
  backup_retention_days = 30  # 30-day retention for production
  geo_redundant_backup_enabled = true  # Geo-redundant backups for DR
  mysql_version       = "8.0"
  aks_subnet_address_prefix = var.subnet_address_prefix
}

# Storage Account Module - HA Configuration
module "storage" {
  source = "../../modules/storage"

  resource_group_name  = azurerm_resource_group.env_rg.name
  location             = azurerm_resource_group.env_rg.location
  environment          = var.environment
  storage_account_name = var.storage_account_name
  account_tier         = "Standard"
  account_replication_type = "RAGRS"  # Read-access geo-redundant storage
  create_queue         = true
  queue_name           = "function-queue"
  create_blob_container = true
  blob_container_name  = "app-blobs"
  log_analytics_workspace_id = var.log_analytics_workspace_id
}

# Function App Module - Premium Plan for Production
module "function_app" {
  source = "../../modules/function_app"

  resource_group_name           = azurerm_resource_group.env_rg.name
  location                      = azurerm_resource_group.env_rg.location
  environment                   = var.environment
  function_app_name             = var.function_app_name
  plan_type                     = "app_service"  # Premium plan for production
  plan_name                     = var.function_plan_name
  plan_sku_name                 = "P1v2"  # Premium plan
  runtime                       = "node"
  runtime_version               = "18"
  storage_account_name          = module.storage.storage_account_name
  storage_account_access_key    = module.storage.storage_account_access_key
  storage_account_connection_string = module.storage.storage_account_primary_connection_string
  app_settings = {
    "MYSQL_HOST"     = module.mysql.server_fqdn
    "MYSQL_DATABASE" = module.mysql.database_name
    "MYSQL_USER"     = var.mysql_admin_username
    "ENVIRONMENT"    = "production"
  }
  log_analytics_workspace_id = var.log_analytics_workspace_id

  depends_on = [module.storage]
}

# App Service Module - Premium for Production
module "app_service" {
  source = "../../modules/app_service"

  resource_group_name      = azurerm_resource_group.env_rg.name
  location                 = azurerm_resource_group.env_rg.location
  environment              = var.environment
  plan_name                = var.app_service_plan_name
  app_name                 = var.app_service_name
  sku_name                 = "P1v2"  # Premium tier for production
  docker_image_name        = "nginx:latest"
  docker_registry_url      = module.acr.registry_login_server
  docker_registry_username = module.acr.registry_admin_username
  docker_registry_password = module.acr.registry_admin_password
  app_settings = {
    "MYSQL_HOST"     = module.mysql.server_fqdn
    "MYSQL_DATABASE" = module.mysql.database_name
    "MYSQL_USER"     = var.mysql_admin_username
    "ENVIRONMENT"    = "production"
  }
  log_analytics_workspace_id = var.log_analytics_workspace_id

  depends_on = [module.acr, module.mysql]
}

# Update Key Vault with access policies
resource "azurerm_role_assignment" "function_app_kv_access" {
  scope              = module.keyvault.keyvault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id       = module.function_app.function_app_principal_id
}

resource "azurerm_role_assignment" "app_service_kv_access" {
  scope              = module.keyvault.keyvault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id       = module.app_service.app_service_principal_id
}

# Application Gateway Module - HA Configuration
module "application_gateway" {
  source = "../../modules/application_gateway"

  resource_group_name    = azurerm_resource_group.env_rg.name
  location               = azurerm_resource_group.env_rg.location
  environment            = var.environment
  app_gateway_name       = var.app_gateway_name
  sku_name               = var.app_gateway_sku_name
  sku_tier               = var.app_gateway_sku_tier
  capacity               = var.app_gateway_capacity
  appgw_subnet_id        = module.network.appgw_subnet_id
  appgw_private_ip_address = var.appgw_private_ip_address
  host_names             = var.app_gateway_host_names
  certificate_secret_id  = var.certificate_secret_id
  path_based_routing     = var.app_gateway_path_based_routing
  enable_waf             = var.enable_waf
  waf_mode               = var.waf_mode
  enable_monitoring      = true
  log_analytics_workspace_id = var.log_analytics_workspace_id

  depends_on = [module.network]
}

# Load Balancer Module - HA Configuration
module "load_balancer" {
  source = "../../modules/load_balancer"

  resource_group_name    = azurerm_resource_group.env_rg.name
  location               = azurerm_resource_group.env_rg.location
  environment            = var.environment
  load_balancer_name     = var.load_balancer_name
  sku                    = var.load_balancer_sku
  enable_monitoring      = true
  log_analytics_workspace_id = var.log_analytics_workspace_id
}