# Terraform Azure Infrastructure

This repository contains Terraform configurations for managing Azure cloud infrastructure across multiple environments using reusable modules.

## Folder Structure

```
terraform/
├── modules/
│   ├── network/              # Virtual Network and Subnets
│   ├── aks/                  # Azure Kubernetes Service
│   ├── acr/                  # Azure Container Registry
│   └── keyvault/             # Azure Key Vault
│
├── environments/
│   ├── dev/                  # Development environment
│   │   ├── main.tf
│   │   ├── backend.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   │
│   ├── staging/              # Staging environment
│   │   ├── main.tf
│   │   ├── backend.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   │
│   └── prod/                 # Production environment
│       ├── main.tf
│       ├── backend.tf
│       ├── variables.tf
│       └── terraform.tfvars
│
├── global/
│   ├── providers.tf          # Azure Provider configuration
│   └── versions.tf           # Terraform version and provider requirements
│
├── secrets/                  # Sensitive files (git-ignored)
├── shared/                   # Shared configurations and scripts
├── .gitignore
└── README.md
```

## Getting Started

1. Install Terraform (version >= 1.0)
2. Configure Azure CLI: `az login`
3. Copy the example variables file and add your credentials:
   ```bash
   cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
   # Edit the file with your actual Azure credentials
   ```
4. Navigate to the desired environment: `cd environments/dev`
5. Initialize: `terraform init`
6. Plan: `terraform plan`
7. Apply: `terraform apply`

## Environments

- **Dev**: Development environment for testing and development
- **Staging**: Staging environment for pre-production validation
- **Prod**: Production environment for live workloads

## Available Modules

### Network Module
Manages Azure Virtual Networks and Subnets
- **Location**: `modules/network/`
- **Resources**: VNet, Subnets

### AKS Module
Manages Azure Kubernetes Service clusters
- **Location**: `modules/aks/`
- **Resources**: Kubernetes cluster with system-assigned identity

### ACR Module
Manages Azure Container Registry
- **Location**: `modules/acr/`
- **Resources**: Container registry with configurable SKU

### KeyVault Module
Manages Azure Key Vault for secrets management
- **Location**: `modules/keyvault/`
- **Resources**: Key Vault with RBAC and purge protection

## Secrets Management

Sensitive variables and credentials should be stored in the `secrets/` folder. Use `-var-file` flag to load them:

```bash
terraform plan -var-file=../secrets/dev-secrets.tfvars
```

## Variables

Update the `terraform.tfvars` files in each environment with your Azure subscription details and other required variables.

```bash
terraform plan -var-file=../secrets/dev-secrets.tfvars
```

Update the `terraform.tfvars` files in each environment with your Azure subscription details and other required variables.