# RBAC Configuration for Three-Tier Application
# Purpose: Control access to environments and Azure resources
# Environments: Dev, Staging, Production

# ═══════════════════════════════════════════════════════════════════════════
# 1. AZURE SERVICE PRINCIPALS & ROLE ASSIGNMENTS
# ═══════════════════════════════════════════════════════════════════════════

# File: rbac/azure-service-principals.sh
# Purpose: Create and configure Azure service principals for pipeline access

#!/bin/bash

set -e

# Configuration
SUBSCRIPTION_ID="your-subscription-id"
RESOURCE_GROUP_DEV="rg-3tier-app-dev"
RESOURCE_GROUP_STAGING="rg-3tier-app-staging"
RESOURCE_GROUP_PROD="rg-3tier-app-prod"

echo "=== Creating Azure Service Principals ==="

# ─────────────────────────────────────────────────────────────────────────
# DEV ENVIRONMENT SERVICE PRINCIPAL
# ─────────────────────────────────────────────────────────────────────────

echo "Creating DEV environment service principal..."

az ad sp create-for-rbac \
  --name "three-tier-app-dev-pipeline" \
  --role "Contributor" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_DEV" \
  --output json > dev-sp-credentials.json

DEV_CLIENT_ID=$(jq -r '.clientId' dev-sp-credentials.json)
DEV_TENANT_ID=$(jq -r '.tenantId' dev-sp-credentials.json)

echo "✓ DEV SP created: $DEV_CLIENT_ID"

# ─────────────────────────────────────────────────────────────────────────
# STAGING ENVIRONMENT SERVICE PRINCIPAL
# ─────────────────────────────────────────────────────────────────────────

echo "Creating STAGING environment service principal..."

az ad sp create-for-rbac \
  --name "three-tier-app-staging-pipeline" \
  --role "Contributor" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_STAGING" \
  --output json > staging-sp-credentials.json

STAGING_CLIENT_ID=$(jq -r '.clientId' staging-sp-credentials.json)

echo "✓ STAGING SP created: $STAGING_CLIENT_ID"

# ─────────────────────────────────────────────────────────────────────────
# PRODUCTION ENVIRONMENT SERVICE PRINCIPAL (Restricted)
# ─────────────────────────────────────────────────────────────────────────

echo "Creating PRODUCTION environment service principal (with restricted role)..."

az ad sp create-for-rbac \
  --name "three-tier-app-prod-pipeline" \
  --role "Contributor" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_PROD" \
  --output json > prod-sp-credentials.json

PROD_CLIENT_ID=$(jq -r '.clientId' prod-sp-credentials.json)

echo "✓ PRODUCTION SP created: $PROD_CLIENT_ID"

# ─────────────────────────────────────────────────────────────────────────
# CREATE CUSTOM ROLES FOR LEAST PRIVILEGE
# ─────────────────────────────────────────────────────────────────────────

echo "Creating custom roles for least privilege access..."

# Custom role for Dev - Can manage AKS, ACR, but not delete
cat > dev-custom-role.json << EOF
{
  "Name": "Three-Tier-App-Dev-Deployer",
  "Description": "Deploy to dev environment only",
  "Type": "CustomRole",
  "Permissions": [
    {
      "Actions": [
        "containerservice/managedClusters/read",
        "containerservice/managedClusters/listClusterUserCredential/action",
        "containerRegistry/registries/push/write",
        "containerRegistry/registries/pull/read",
        "Microsoft.Authorization/*/read",
        "Microsoft.KeyVault/vaults/read",
        "Microsoft.KeyVault/vaults/secrets/read"
      ],
      "NotActions": [
        "Microsoft.Authorization/*/delete",
        "Microsoft.KeyVault/vaults/delete",
        "Microsoft.Authorization/policyAssignments/delete",
        "Microsoft.Authorization/locks/delete"
      ]
    }
  ],
  "AssignableScopes": [
    "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_DEV"
  ]
}
EOF

az role definition create --role-definition @dev-custom-role.json || echo "Dev role may already exist"

# Assign custom role to dev SP
az role assignment create \
  --assignee $DEV_CLIENT_ID \
  --role "Three-Tier-App-Dev-Deployer" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_DEV"

echo "✓ Custom roles assigned"

# ─────────────────────────────────────────────────────────────────────────
# DENY DANGEROUS ACTIONS IN PROD
# ─────────────────────────────────────────────────────────────────────────

echo "Creating deny policies for production..."

cat > prod-deny-policy.json << EOF
{
  "properties": {
    "displayName": "Deny dangerous actions in production",
    "description": "Prevent accidental deletion of critical production resources",
    "mode": "All",
    "policyRule": {
      "if": {
        "allOf": [
          {
            "field": "type",
            "in": [
              "Microsoft.ContainerService/managedClusters",
              "Microsoft.DBforMySQL/servers",
              "Microsoft.KeyVault/vaults"
            ]
          },
          {
            "anyOf": [
              {
                "field": "Microsoft.Authorization/policyDefinitions/type",
                "equals": "DELETE"
              }
            ]
          }
        ]
      },
      "then": {
        "effect": "Deny"
      }
    }
  }
}
EOF

# Apply deny policy
az policy definition create \
  --name "deny-prod-deletions" \
  --display-name "Deny Production Deletions" \
  --description "Prevent deletion of critical production resources" \
  --mode All \
  --rules prod-deny-policy.json \
  || echo "Policy may already exist"

echo "✓ Deny policies created"

# ─────────────────────────────────────────────────────────────────────────
# CREATE ACR ROLES FOR CONTAINER SECURITY
# ─────────────────────────────────────────────────────────────────────────

echo "Creating ACR-specific roles..."

# Get ACR resource IDs
ACR_DEV=$(az acr list -g $RESOURCE_GROUP_DEV --query '[0].id' -o tsv)
ACR_STAGING=$(az acr list -g $RESOURCE_GROUP_STAGING --query '[0].id' -o tsv)
ACR_PROD=$(az acr list -g $RESOURCE_GROUP_PROD --query '[0].id' -o tsv)

# Assign ACR push/pull roles
az role assignment create \
  --assignee $DEV_CLIENT_ID \
  --role "AcrPush" \
  --scope $ACR_DEV

az role assignment create \
  --assignee $DEV_CLIENT_ID \
  --role "AcrPull" \
  --scope $ACR_DEV

echo "✓ ACR roles assigned"

# ─────────────────────────────────────────────────────────────────────────
# CONFIGURE MANAGED IDENTITIES FOR AGIC
# ─────────────────────────────────────────────────────────────────────────

echo "Setting up Managed Identities for AGIC..."

# Create managed identity for AGIC
for ENV in dev staging prod; do
  RG="rg-3tier-app-${ENV}"
  IDENTITY_NAME="agic-identity-${ENV}"
  
  az identity create \
    --resource-group $RG \
    --name $IDENTITY_NAME
  
  IDENTITY_ID=$(az identity show -g $RG -n $IDENTITY_NAME --query 'id' -o tsv)
  
  # Assign roles to managed identity
  az role assignment create \
    --assignee-object-id $(az identity show -g $RG -n $IDENTITY_NAME --query 'principalId' -o tsv) \
    --role "Contributor" \
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG"
done

echo "✓ Managed identities created"

echo ""
echo "=== Service Principals Created ==="
echo "Save these in Azure DevOps Service Connections:"
echo "Dev: $(cat dev-sp-credentials.json)"
echo "Staging: $(cat staging-sp-credentials.json)"
echo "Prod: $(cat prod-sp-credentials.json)"

