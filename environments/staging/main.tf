# Staging Environment - Main Configuration

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

# Add your resources here or call modules
# Example:
# module "network" {
#   source = "../../modules/network"
#   
#   resource_group_name = azurerm_resource_group.env_rg.name
#   location            = azurerm_resource_group.env_rg.location
#   environment         = var.environment
# }
