# Terraform Azure Infrastructure

This repository contains Terraform configurations for managing Azure cloud infrastructure across Dev and Prod environments.

## Folder Structure

- `environments/dev/`: Terraform configuration for the Development environment
- `environments/prod/`: Terraform configuration for the Production environment
- `environments/uat/`: Terraform configuration for the User Acceptance Testing environment
- `global/`: Global configurations and shared settings
- `modules/`: Reusable Terraform modules
- `secrets/`: Sensitive configuration files (not committed to Git)
- `shared/`: Shared configurations and scripts
- `versions.tf`: Terraform version and provider requirements

## Getting Started

1. Install Terraform (version >= 1.0)
2. Configure Azure CLI: `az login`
3. Navigate to the desired environment: `cd environments/dev`
4. Initialize: `terraform init`
5. Plan: `terraform plan`
6. Apply: `terraform apply`

## Environments

- **Dev**: Development environment for testing and development
- **Prod**: Production environment for live workloads
- **UAT**: User Acceptance Testing environment for pre-production validation

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