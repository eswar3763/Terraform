# Global Configurations

This folder contains global Terraform configurations that apply across all environments.

## Files

- `versions.tf`: Moved to root directory for Terraform to recognize it. Contains required Terraform version and provider configurations.

## Usage

Global settings are automatically loaded by Terraform when running commands in any environment directory.