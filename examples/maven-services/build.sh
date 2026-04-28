#!/bin/bash

# Maven Build Script for All Microservices
# This script builds Docker images for all three services and pushes them to ACR

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ACR_SERVER="${ACR_SERVER:-acr.azurecr.io}"
IMAGE_TAG="${IMAGE_TAG:-1.0.0}"
DOCKER_REGISTRY_USER="${DOCKER_REGISTRY_USER:-}"
DOCKER_REGISTRY_PASSWORD="${DOCKER_REGISTRY_PASSWORD:-}"

echo -e "${YELLOW}======================================${NC}"
echo -e "${YELLOW}Maven Microservices Build Script${NC}"
echo -e "${YELLOW}======================================${NC}"

# Function to print messages
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Check prerequisites
print_info "Checking prerequisites..."

if ! command -v mvn &> /dev/null; then
    print_error "Maven is not installed. Please install Maven 3.6.0 or higher."
    exit 1
fi
print_status "Maven found: $(mvn -v | head -1)"

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker."
    exit 1
fi
print_status "Docker found: $(docker --version)"

if ! command -v git &> /dev/null; then
    print_error "Git is not installed. Please install Git."
    exit 1
fi
print_status "Git found: $(git --version | head -1)"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

print_info "Building services from: $SCRIPT_DIR"

# Build each service
SERVICES=("user-service" "order-service" "payment-service")
BUILD_SUCCESS=0
BUILD_FAILED=0

for service in "${SERVICES[@]}"; do
    echo ""
    print_info "Building $service..."
    
    if [ ! -d "$SCRIPT_DIR/$service" ]; then
        print_error "$service directory not found"
        BUILD_FAILED=$((BUILD_FAILED + 1))
        continue
    fi
    
    cd "$SCRIPT_DIR/$service"
    
    # Clean and build
    if mvn clean package -DskipTests > /tmp/$service-build.log 2>&1; then
        print_status "$service built successfully"
        BUILD_SUCCESS=$((BUILD_SUCCESS + 1))
    else
        print_error "$service build failed. See /tmp/$service-build.log for details"
        BUILD_FAILED=$((BUILD_FAILED + 1))
        cat /tmp/$service-build.log | tail -20
        continue
    fi
    
    # Build Docker image (optional)
    if [ "${BUILD_DOCKER:-false}" = "true" ]; then
        print_info "Building Docker image for $service..."
        
        DOCKERFILE_PATH="$SCRIPT_DIR/../Dockerfile.springboot"
        if [ ! -f "$DOCKERFILE_PATH" ]; then
            print_error "Dockerfile.springboot not found at $DOCKERFILE_PATH"
            continue
        fi
        
        IMAGE_NAME="$ACR_SERVER/$service:$IMAGE_TAG"
        
        if docker build -t "$IMAGE_NAME" -f "$DOCKERFILE_PATH" . > /tmp/$service-docker.log 2>&1; then
            print_status "Docker image built: $IMAGE_NAME"
            
            # Push to ACR (optional)
            if [ ! -z "$DOCKER_REGISTRY_USER" ] && [ ! -z "$DOCKER_REGISTRY_PASSWORD" ]; then
                print_info "Logging in to $ACR_SERVER..."
                echo "$DOCKER_REGISTRY_PASSWORD" | docker login -u "$DOCKER_REGISTRY_USER" --password-stdin "$ACR_SERVER"
                
                print_info "Pushing Docker image $IMAGE_NAME..."
                if docker push "$IMAGE_NAME" > /tmp/$service-push.log 2>&1; then
                    print_status "Image pushed successfully"
                else
                    print_error "Image push failed. See /tmp/$service-push.log for details"
                fi
            fi
        else
            print_error "Docker build failed for $service. See /tmp/$service-docker.log for details"
        fi
    fi
done

echo ""
print_info "Build Summary:"
print_status "Successful: $BUILD_SUCCESS"
if [ $BUILD_FAILED -gt 0 ]; then
    print_error "Failed: $BUILD_FAILED"
else
    print_status "Failed: 0"
fi

if [ $BUILD_FAILED -eq 0 ]; then
    echo ""
    print_status "All services built successfully!"
    echo ""
    print_info "Next steps:"
    echo "  1. Start services locally:  mvn spring-boot:run (in each service directory)"
    echo "  2. Run integration tests:   mvn test"
    echo "  3. Deploy to AKS:           See DEPLOYMENT.md for instructions"
else
    exit 1
fi
