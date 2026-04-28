# App Service Plan and App Service - Main Configuration

resource "azurerm_service_plan" "app_service_plan" {
  name                = var.plan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.sku_name

  tags = {
    Environment = var.environment
    Module      = "app_service"
  }
}

resource "azurerm_linux_web_app" "app_service" {
  name                = var.app_name
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.app_service_plan.id

  site_config {
    application_stack {
      docker_image_name           = var.docker_image_name
      docker_registry_url         = var.docker_registry_url
      docker_registry_username    = var.docker_registry_username
      docker_registry_password    = var.docker_registry_password
    }
    
    always_on = var.sku_name != "F1" ? true : false
    
    app_command_line = var.app_command_line
  }

  app_settings = merge(
    {
      "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
      "DOCKER_REGISTRY_SERVER_URL"          = var.docker_registry_url
      "DOCKER_REGISTRY_SERVER_USERNAME"     = var.docker_registry_username
      "DOCKER_REGISTRY_SERVER_PASSWORD"     = var.docker_registry_password
      "DOCKER_ENABLE_CI"                    = "true"
    },
    var.app_settings
  )

  identity {
    type = "SystemAssigned"
  }

  logs {
    detailed_error_messages = true
    failed_request_tracing  = true
  }

  tags = {
    Environment = var.environment
    Module      = "app_service"
  }

  depends_on = [azurerm_service_plan.app_service_plan]
}

# Diagnostic settings for logging
resource "azurerm_monitor_diagnostic_setting" "app_service_logs" {
  name               = "${var.app_name}-logs"
  target_resource_id = azurerm_linux_web_app.app_service.id
  
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }

  enabled_log {
    category = "AppServiceConsoleLogs"
  }

  enabled_log {
    category = "AppServiceApplicationLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
