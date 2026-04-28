# Azure Key Vault Module - Main Configuration

resource "azurerm_key_vault" "kv" {
  name                = var.keyvault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = var.sku_name

  enabled_for_disk_encryption       = var.enabled_for_disk_encryption
  enabled_for_template_deployment   = var.enabled_for_template_deployment
  enable_rbac_authorization         = true
  purge_protection_enabled          = true
  soft_delete_retention_days        = 7

  tags = {
    Environment = var.environment
    Module      = "keyvault"
  }
}

# RBAC Role Assignments for identities that need access to Key Vault

# App Service identity - read secrets
resource "azurerm_role_assignment" "app_service_secrets" {
  count              = var.app_service_principal_id != "" ? 1 : 0
  scope              = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id       = var.app_service_principal_id
}

# Function App identity - read secrets
resource "azurerm_role_assignment" "function_app_secrets" {
  count              = var.function_app_principal_id != "" ? 1 : 0
  scope              = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id       = var.function_app_principal_id
}

# AKS kubelet identity - read secrets (for external-secrets operator)
resource "azurerm_role_assignment" "aks_kubelet_secrets" {
  count              = var.aks_kubelet_principal_id != "" ? 1 : 0
  scope              = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id       = var.aks_kubelet_principal_id
}
