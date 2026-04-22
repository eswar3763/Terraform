provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

# Add your resources here
# Example: resource "azurerm_resource_group" "example" {
#   name     = "example-rg"
#   location = "East US"
# }