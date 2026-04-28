# Network Module - Outputs

output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  description = "Virtual Network name"
  value       = azurerm_virtual_network.vnet.name
}

output "subnet_id" {
  description = "Subnet ID"
  value       = azurerm_subnet.subnet.id
}

output "subnet_name" {
  description = "Subnet name"
  value       = azurerm_subnet.subnet.name
}

output "appgw_subnet_id" {
  description = "Application Gateway subnet ID"
  value       = azurerm_subnet.appgw_subnet.id
}

output "appgw_subnet_name" {
  description = "Application Gateway subnet name"
  value       = azurerm_subnet.appgw_subnet.name
}

output "lb_subnet_id" {
  description = "Load Balancer subnet ID"
  value       = var.create_lb_subnet ? azurerm_subnet.lb_subnet[0].id : null
}

output "lb_subnet_name" {
  description = "Load Balancer subnet name"
  value       = var.create_lb_subnet ? azurerm_subnet.lb_subnet[0].name : null
}
