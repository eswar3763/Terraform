#!/bin/bash

# ArgoCD Installation Script
# This script installs ArgoCD in the AKS cluster and configures it for the 3-tier application

set -e

echo "=================================================="
echo "ArgoCD Installation and Setup"
echo "=================================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Verify prerequisites
echo -e "\n${YELLOW}Step 1: Verifying prerequisites${NC}"
echo "Checking kubectl..."
kubectl version --client

echo "Checking Helm..."
helm version

echo "Checking cluster connection..."
kubectl cluster-info

# Step 2: Create ArgoCD namespace
echo -e "\n${YELLOW}Step 2: Creating ArgoCD namespace${NC}"
kubectl create namespace argocd || echo "Namespace 'argocd' already exists"

# Step 3: Install ArgoCD
echo -e "\n${YELLOW}Step 3: Installing ArgoCD${NC}"
echo "Installing stable version of ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Step 4: Wait for ArgoCD pods to be ready
echo -e "\n${YELLOW}Step 4: Waiting for ArgoCD pods to be ready${NC}"
echo "This may take 2-3 minutes..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/part-of=argocd \
  -n argocd \
  --timeout=300s

echo -e "${GREEN}ArgoCD pods are ready${NC}"

# Step 5: Verify installation
echo -e "\n${YELLOW}Step 5: Verifying ArgoCD installation${NC}"
echo "ArgoCD services:"
kubectl get svc -n argocd
echo ""
echo "ArgoCD pods:"
kubectl get pods -n argocd

# Step 6: Get initial admin password
echo -e "\n${YELLOW}Step 6: Retrieving initial admin password${NC}"
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo -e "${GREEN}Initial Admin Password: ${ADMIN_PASSWORD}${NC}"
echo "Username: admin"
echo "Store this password securely! Change it after first login."

# Step 7: Create AppProject
echo -e "\n${YELLOW}Step 7: Creating AppProject for RBAC${NC}"
kubectl apply -f argocd/projects/three-tier-app.yaml

# Step 8: Create Git repository secret
echo -e "\n${YELLOW}Step 8: Setting up Git repository access${NC}"
echo "Choose authentication method:"
echo "1) HTTPS with Personal Access Token"
echo "2) SSH with private key"
read -p "Enter choice (1 or 2): " auth_choice

if [ "$auth_choice" = "1" ]; then
    read -p "Enter GitHub username: " github_user
    read -sp "Enter GitHub Personal Access Token: " github_token
    echo ""
    
    # Create HTTPS secret
    kubectl create secret generic github-terraform-repo \
      --from-literal=type=git \
      --from-literal=url=https://github.com/eswar3763/Terraform.git \
      --from-literal=password="$github_token" \
      --from-literal=username="$github_user" \
      --from-literal=insecure=false \
      --from-literal=enableLFS=true \
      -n argocd \
      --dry-run=client -o yaml | kubectl label -f - \
      argocd.argoproj.io/secret-type=repository --dry-run=client -o yaml | kubectl apply -f -
    
    echo -e "${GREEN}HTTPS repository secret created${NC}"
    
elif [ "$auth_choice" = "2" ]; then
    read -p "Enter path to SSH private key: " ssh_key_path
    
    if [ ! -f "$ssh_key_path" ]; then
        echo -e "${RED}Error: SSH key not found at $ssh_key_path${NC}"
        exit 1
    fi
    
    # Create SSH secret
    kubectl create secret generic github-terraform-repo-ssh \
      --from-literal=type=git \
      --from-literal=url=git@github.com:eswar3763/Terraform.git \
      --from-file=sshPrivateKey="$ssh_key_path" \
      -n argocd \
      --dry-run=client -o yaml | kubectl label -f - \
      argocd.argoproj.io/secret-type=repository --dry-run=client -o yaml | kubectl apply -f -
    
    echo -e "${GREEN}SSH repository secret created${NC}"
else
    echo -e "${RED}Invalid choice${NC}"
    exit 1
fi

# Step 9: Apply ArgoCD Applications
echo -e "\n${YELLOW}Step 9: Creating ArgoCD Applications${NC}"
kubectl apply -f argocd/applications/user-service.yaml
kubectl apply -f argocd/applications/order-service.yaml
kubectl apply -f argocd/applications/payment-service.yaml

echo -e "${GREEN}Applications created${NC}"

# Step 10: Verify applications
echo -e "\n${YELLOW}Step 10: Verifying applications${NC}"
echo "Waiting for applications to be created..."
sleep 5

kubectl get applications -n argocd

# Step 11: Expose ArgoCD UI
echo -e "\n${YELLOW}Step 11: Exposing ArgoCD UI${NC}"
echo "Exposing ArgoCD server service..."

# Option 1: Port forward (temporary)
echo -e "\n${GREEN}Option 1: Port Forward (for testing)${NC}"
echo "Run in a new terminal:"
echo "  kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "Then access: https://localhost:8080"

# Option 2: LoadBalancer (permanent)
echo -e "\n${GREEN}Option 2: LoadBalancer (for production)${NC}"
read -p "Expose ArgoCD via LoadBalancer? (y/n): " expose_lb

if [ "$expose_lb" = "y" ]; then
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
    echo "Waiting for external IP..."
    sleep 10
    EXTERNAL_IP=$(kubectl get svc -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ ! -z "$EXTERNAL_IP" ]; then
        echo -e "${GREEN}ArgoCD is now accessible at: https://$EXTERNAL_IP${NC}"
    else
        echo "External IP not yet assigned. Check later with:"
        echo "  kubectl get svc -n argocd argocd-server"
    fi
fi

# Step 12: Summary
echo -e "\n${GREEN}=================================================="
echo "ArgoCD Installation Complete!"
echo "==================================================${NC}"
echo ""
echo "Next steps:"
echo "1. Access ArgoCD UI:"
echo "   - Login with username: admin"
echo "   - Password: $ADMIN_PASSWORD"
echo ""
echo "2. Change admin password:"
echo "   - Use the 'Change Password' option in settings"
echo "   - Or use ArgoCD CLI:"
echo "     argocd login <argocd-server> --username admin --password $ADMIN_PASSWORD"
echo "     argocd account update-password --current-password $ADMIN_PASSWORD --new-password <new-password>"
echo ""
echo "3. Connect Git repository:"
echo "   - Already configured via secret"
echo "   - Verify in Settings → Repositories"
echo ""
echo "4. Monitor applications:"
echo "   - kubectl get applications -n argocd"
echo "   - kubectl describe app user-service -n argocd"
echo ""
echo "5. View application status:"
echo "   - argocd app list"
echo "   - argocd app get user-service"
echo "   - argocd app get order-service"
echo "   - argocd app get payment-service"
echo ""
echo "6. Sync applications:"
echo "   - Manual: argocd app sync <app-name>"
echo "   - Auto-sync is enabled (changes in Git auto-sync)"
echo ""
echo "Documentation: https://github.com/eswar3763/Terraform/blob/main/HELM_ARGOCD_COMPLETE_SETUP_GUIDE.md"
