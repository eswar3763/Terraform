# Azure Function App - Main Configuration

resource "azurerm_service_plan" "function_plan" {
  count               = var.plan_type == "consumption" ? 0 : 1
  name                = var.plan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.plan_sku_name

  tags = {
    Environment = var.environment
    Module      = "function_app"
  }
}

resource "azurerm_function_app" "function_app" {
  name                       = var.function_app_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  app_service_plan_id        = var.plan_type == "consumption" ? null : azurerm_service_plan.function_plan[0].id
  storage_account_name       = var.storage_account_name
  storage_account_access_key = var.storage_account_access_key
  os_type                    = "linux"
  runtime_version            = var.runtime_version

  version = "~4"

  app_settings = merge(
    {
      "FUNCTIONS_WORKER_RUNTIME"      = var.runtime
      "APPINSIGHTS_INSTRUMENTATIONKEY" = var.app_insights_instrumentation_key != "" ? var.app_insights_instrumentation_key : ""
      "AzureWebJobsStorage"           = var.storage_account_connection_string
      "WEBSITE_RUN_FROM_PACKAGE"      = "1"
      "SCM_COMMAND_IDLE_TIMEOUT"      = "10"
    },
    var.app_settings
  )

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = var.environment
    Module      = "function_app"
  }

  depends_on = [azurerm_service_plan.function_plan]
}

# Authentication settings for Function App
resource "azurerm_function_app_host_keys" "host_keys" {
  function_app_id = azurerm_function_app.function_app.id

  depends_on = [azurerm_function_app.function_app]
}

# Diagnostic settings for Function App
resource "azurerm_monitor_diagnostic_setting" "function_app_logs" {
  count              = var.log_analytics_workspace_id != "" ? 1 : 0
  name               = "${var.function_app_name}-logs"
  target_resource_id = azurerm_function_app.function_app.id
  
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "FunctionAppLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
