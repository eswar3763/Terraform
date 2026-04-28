# AKS Module - Outputs

output "cluster_id" {
  description = "AKS Cluster ID"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "cluster_name" {
  description = "AKS Cluster name"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "kube_config" {
  description = "Kubernetes config"
  value       = azurerm_kubernetes_cluster.aks.kube_config
  sensitive   = true
}

output "kube_config_raw" {
  description = "Raw Kubernetes config (sensitive)"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "fqdn" {
  description = "FQDN of the Kubernetes cluster"
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "aks_identity_principal_id" {
  description = "Principal ID of the AKS cluster identity (for RBAC assignments)"
  value       = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

output "kubelet_identity" {
  description = "Kubelet managed identity for pulling from ACR"
  value       = data.azurerm_user_assigned_identity.aks_kubelet.principal_id
}

output "node_resource_group_name" {
  description = "The name of the resource group created by AKS for cluster resources"
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}
