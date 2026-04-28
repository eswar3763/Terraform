# Azure Load Balancer Module - Layer 4 Load Balancer
# Provides basic network load balancing for TCP/UDP traffic

resource "azurerm_lb" "lb" {
  name                = var.load_balancer_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku

  frontend_ip_configuration {
    name                 = "frontend-ip-public"
    public_ip_address_id = azurerm_public_ip.lb_public_ip.id
  }

  # Private IP Configuration (optional, for internal load balancing)
  dynamic "frontend_ip_configuration" {
    for_each = var.enable_private_ip ? [1] : []
    content {
      name                          = "frontend-ip-private"
      subnet_id                     = var.subnet_id
      private_ip_address_allocation = "Static"
      private_ip_address            = var.private_ip_address
    }
  }

  tags = {
    Environment = var.environment
    Module      = "load-balancer"
  }
}

# Public IP for Load Balancer
resource "azurerm_public_ip" "lb_public_ip" {
  name                = "${var.load_balancer_name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = var.sku == "Standard" ? "Standard" : "Basic"

  tags = {
    Environment = var.environment
    Module      = "load-balancer"
  }
}

# Backend Address Pool
resource "azurerm_lb_backend_address_pool" "backend_pool" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "backend-pool"
}

# Health Probe
resource "azurerm_lb_probe" "health_probe" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "health-probe"
  protocol        = var.probe_protocol
  port            = var.probe_port
  request_path    = var.probe_protocol == "Http" ? "/actuator/health" : null
  interval_in_seconds = 15
  number_of_probes = 2
}

# Load Balancing Rules
resource "azurerm_lb_rule" "lb_rule" {
  for_each = var.load_balancing_rules

  loadbalancer_id                = azurerm_lb.lb.id
  name                           = each.key
  protocol                       = each.value.protocol
  frontend_port                  = each.value.frontend_port
  backend_port                   = each.value.backend_port
  frontend_ip_configuration_name = "frontend-ip-public"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.backend_pool.id]
  probe_id                       = azurerm_lb_probe.health_probe.id
  enable_floating_ip             = each.value.enable_floating_ip
  idle_timeout_in_minutes        = each.value.idle_timeout_in_minutes
  load_distribution              = each.value.load_distribution
}

# Outbound Rule (for NAT)
resource "azurerm_lb_outbound_rule" "outbound" {
  count = var.enable_outbound_rule ? 1 : 0

  loadbalancer_id         = azurerm_lb.lb.id
  name                    = "outbound-rule"
  protocol                = "All"
  frontend_ip_configuration_names = ["frontend-ip-public"]
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend_pool.id
}

# NAT Rule for SSH Access (optional)
resource "azurerm_lb_nat_rule" "ssh_nat" {
  count = var.enable_ssh_nat ? 1 : 0

  loadbalancer_id            = azurerm_lb.lb.id
  name                       = "ssh-nat-rule"
  protocol                   = "Tcp"
  frontend_port              = 22
  backend_port               = 22
  frontend_ip_configuration_name = "frontend-ip-public"
}

# Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "lb_diagnostics" {
  count = var.enable_monitoring ? 1 : 0

  name                       = "${var.load_balancer_name}-diagnostics"
  target_resource_id         = azurerm_lb.lb.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "LoadBalancerAlertEvent"
  }

  enabled_log {
    category = "LoadBalancerProbeHealthStatus"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
