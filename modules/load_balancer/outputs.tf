# Load Balancer Module - Outputs

output "load_balancer_id" {
  description = "ID of the Load Balancer"
  value       = azurerm_lb.lb.id
}

output "load_balancer_name" {
  description = "Name of the Load Balancer"
  value       = azurerm_lb.lb.name
}

output "public_ip_address" {
  description = "Public IP address of the Load Balancer"
  value       = azurerm_public_ip.lb_public_ip.ip_address
}

output "public_ip_id" {
  description = "ID of the public IP address"
  value       = azurerm_public_ip.lb_public_ip.id
}

output "backend_address_pool_id" {
  description = "ID of the backend address pool"
  value       = azurerm_lb_backend_address_pool.backend_pool.id
}

output "health_probe_id" {
  description = "ID of the health probe"
  value       = azurerm_lb_probe.health_probe.id
}

output "frontend_ip_configuration_id" {
  description = "ID of the frontend IP configuration"
  value       = azurerm_lb.lb.frontend_ip_configuration[0].id
}

output "frontend_ip_configuration_name" {
  description = "Name of the frontend IP configuration"
  value       = azurerm_lb.lb.frontend_ip_configuration[0].name
}

output "load_balancing_rules" {
  description = "Load balancing rules configuration"
  value = {
    for k, v in azurerm_lb_rule.lb_rule : k => {
      id   = v.id
      name = v.name
    }
  }
}
