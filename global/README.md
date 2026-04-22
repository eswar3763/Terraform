# Global Configurations

This folder contains global Terraform configurations that apply across all environments.

## Files

### versions.tf
Contains:
- Required Terraform version (>= 1.0)
- Azure provider version specification (~> 3.0)

### providers.tf
Contains:
- Azure provider configuration
- Authentication setup using Service Principal credentials
- Feature flag configurations

## Usage

Global settings are automatically loaded by Terraform when running commands in any environment directory. The provider configuration uses variables from each environment's `variables.tf` and `terraform.tfvars` files.