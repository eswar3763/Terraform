# Application Gateway Module - Layer 7 Load Balancer
# Provides advanced routing, WAF, SSL/TLS termination, and path-based routing

resource "azurerm_application_gateway" "appgw" {
  name                = var.app_gateway_name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku {
    name     = var.sku_name
    tier     = var.sku_tier
    capacity = var.capacity
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = var.appgw_subnet_id
  }

  # Frontend IP Configuration
  frontend_ip_configuration {
    name                 = "frontend-ip-public"
    public_ip_address_id = azurerm_public_ip.appgw_public_ip.id
  }

  frontend_ip_configuration {
    name                          = "frontend-ip-private"
    private_ip_address_allocation = "Static"
    private_ip_address            = var.appgw_private_ip_address
    subnet_id                     = var.appgw_subnet_id
  }

  # Frontend Ports
  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_port {
    name = "https-port"
    port = 443
  }

  # HTTP Settings - Backend Communication
  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
    pick_host_name_from_backend_address = true

    connection_draining {
      enabled           = true
      drain_timeout_sec = 20
    }
  }

  # HTTPS Settings - TLS Termination
  backend_http_settings {
    name                  = "https-settings"
    cookie_based_affinity = "Disabled"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 20
    pick_host_name_from_backend_address = true

    connection_draining {
      enabled           = true
      drain_timeout_sec = 20
    }
  }

  # Backend Address Pools - Kubernetes Ingress Controller
  backend_address_pool {
    name = "aks-backend-pool"
    # IP addresses will be added dynamically by AGIC
  }

  # HTTP Listeners
  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip-public"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
    host_names                     = var.host_names
  }

  # HTTPS Listener with SSL Certificate
  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "frontend-ip-public"
    frontend_port_name             = "https-port"
    protocol                       = "Https"
    ssl_certificate_name           = "appgw-cert"
    host_names                     = var.host_names
    require_sni                    = true
  }

  # Request Routing Rules - HTTP to HTTPS Redirect
  request_routing_rule {
    name                       = "http-redirect-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    redirect_configuration_name = "redirect-config"
    priority                   = 1
  }

  # Request Routing Rules - HTTPS to Backend
  request_routing_rule {
    name                       = "https-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "https-listener"
    backend_address_pool_name  = "aks-backend-pool"
    backend_http_settings_name = "http-settings"
    priority                   = 2
  }

  # Path-based Rules for Multi-Service Routing
  dynamic "url_path_map" {
    for_each = var.path_based_routing ? [1] : []
    content {
      name                               = "path-routing"
      default_backend_address_pool_name  = "aks-backend-pool"
      default_backend_http_settings_name = "http-settings"

      path_rule {
        name                       = "api-rule"
        paths                      = ["/api/*"]
        backend_address_pool_name  = "aks-backend-pool"
        backend_http_settings_name = "http-settings"
      }

      path_rule {
        name                       = "health-rule"
        paths                      = ["/actuator/health", "/health"]
        backend_address_pool_name  = "aks-backend-pool"
        backend_http_settings_name = "http-settings"
      }
    }
  }

  # Redirect Configuration
  redirect_configuration {
    name               = "redirect-config"
    redirect_type      = "Permanent"
    target_listener_name = "https-listener"
    include_path       = true
    include_query_string = true
  }

  # SSL Certificate (from Key Vault)
  ssl_certificate {
    name                = "appgw-cert"
    data                = var.certificate_data != "" ? base64decode(var.certificate_data) : null
    password            = var.certificate_password
    key_vault_secret_id = var.certificate_secret_id != "" ? var.certificate_secret_id : null
  }

  # Health Probe for Backend
  probe {
    name                                      = "health-probe"
    protocol                                  = "Http"
    path                                      = "/actuator/health"
    host                                      = "localhost"
    interval                                  = 30
    timeout                                   = 10
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
    match {
      status_code = ["200-399"]
    }
  }

  # WAF (Web Application Firewall) - Optional
  dynamic "waf_configuration" {
    for_each = var.enable_waf ? [1] : []
    content {
      enabled          = true
      firewall_mode    = var.waf_mode  # "Detection" or "Prevention"
      rule_set_type    = "OWASP"
      rule_set_version = "3.2"

      disabled_rule_group {
        rule_group_name = "crs_41_sql_injection_attacks"
        rules           = []  # Disable specific rules if needed
      }
    }
  }

  # Tags
  tags = {
    Environment = var.environment
    Module      = "application-gateway"
  }

  depends_on = [azurerm_public_ip.appgw_public_ip]
}

# Public IP for Application Gateway
resource "azurerm_public_ip" "appgw_public_ip" {
  name                = "${var.app_gateway_name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = var.environment
    Module      = "application-gateway"
  }
}

# Managed Identity for AGIC (Application Gateway Ingress Controller)
resource "azurerm_user_assigned_identity" "agic_identity" {
  resource_group_name = var.resource_group_name
  location            = var.location
  name                = "${var.app_gateway_name}-agic-identity"

  tags = {
    Environment = var.environment
    Module      = "application-gateway"
  }
}

# Role Assignment for AGIC to manage Application Gateway
resource "azurerm_role_assignment" "agic_gateway_role" {
  scope              = azurerm_application_gateway.appgw.id
  role_definition_name = "Contributor"
  principal_id       = azurerm_user_assigned_identity.agic_identity.principal_id
}

# Role Assignment for AGIC to access resource group
resource "azurerm_role_assignment" "agic_resource_group_role" {
  scope              = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  role_definition_name = "Reader"
  principal_id       = azurerm_user_assigned_identity.agic_identity.principal_id
}

# Get current context for subscription ID
data "azurerm_client_config" "current" {}

# Optional: Application Insights for monitoring
resource "azurerm_application_insights" "appgw_insights" {
  count = var.enable_monitoring ? 1 : 0

  name                = "${var.app_gateway_name}-insights"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"

  tags = {
    Environment = var.environment
    Module      = "application-gateway"
  }
}

# Diagnostic Settings for Application Gateway
resource "azurerm_monitor_diagnostic_setting" "appgw_diagnostics" {
  count = var.enable_monitoring ? 1 : 0

  name                       = "${var.app_gateway_name}-diagnostics"
  target_resource_id         = azurerm_application_gateway.appgw.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
