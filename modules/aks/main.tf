# AKS Module - Main Configuration

resource "azurerm_kubernetes_cluster" "aks" {
  name                       = var.cluster_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  dns_prefix                 = var.dns_prefix
  kubernetes_version         = var.kubernetes_version
  role_based_access_control_enabled = true
  api_server_authorized_ip_ranges   = var.api_server_authorized_ips

  default_node_pool {
    name                = "default"
    node_count          = var.node_count
    vm_size             = var.vm_size
    availability_zones  = var.availability_zones
    enable_auto_scaling = var.enable_auto_scaling
    min_count           = var.min_node_count
    max_count           = var.max_node_count
    vnet_subnet_id      = var.subnet_id
    
    node_labels = {
      "workload" = "system"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
    docker_bridge_cidr = var.docker_bridge_cidr
    load_balancer_sku = "standard"
  }

  addon_profile {
    oms_agent {
      enabled            = var.enable_monitoring
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }

    ingress_application_gateway {
      enabled = false  # We'll use NGINX ingress controller instead
    }
  }

  tags = {
    Environment = var.environment
    Module      = "aks"
  }
}

# AKS Kubelet Identity - for managing node permissions
data "azurerm_user_assigned_identity" "aks_kubelet" {
  name                = "${azurerm_kubernetes_cluster.aks.name}-agentpool"
  resource_group_name = "MC_${var.resource_group_name}_${var.cluster_name}_${var.location}"

  depends_on = [azurerm_kubernetes_cluster.aks]
}

# Role assignment: AKS nodes can pull from ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  count              = var.acr_id != "" ? 1 : 0
  scope              = var.acr_id
  role_definition_name = "AcrPull"
  principal_id       = data.azurerm_user_assigned_identity.aks_kubelet.principal_id

  depends_on = [azurerm_kubernetes_cluster.aks]
}

# Diagnostic settings for AKS
resource "azurerm_monitor_diagnostic_setting" "aks_logs" {
  count              = var.log_analytics_workspace_id != "" ? 1 : 0
  name               = "${var.cluster_name}-logs"
  target_resource_id = azurerm_kubernetes_cluster.aks.id
  
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-audit"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-scheduler"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
