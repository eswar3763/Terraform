# Azure Key Vault Module - Main Configuration

resource "azurerm_key_vault" "kv" {
  name                = var.keyvault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = var.sku_name

  enabled_for_disk_encryption       = var.enabled_for_disk_encryption
  enabled_for_template_deployment   = var.enabled_for_template_deployment
  enable_rbac_authorization          = true
  purge_protection_enabled           = true
  soft_delete_retention_days         = 7

  tags = {
    Environment = var.environment
    Module      = "keyvault"
  }
}
