#!/bin/bash

# Quick Start Guide for Maven Services
# This script starts all services locally for development and testing

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Maven Services - Local Development${NC}"
echo -e "${YELLOW}========================================${NC}"

# Check if MySQL is running
echo -e "${YELLOW}Checking MySQL...${NC}"
if ! mysql -u azureuser -ppassword -e "SELECT 1" &> /dev/null; then
    echo -e "${YELLOW}MySQL is not running. Starting MySQL Docker container...${NC}"
    docker run -d \
      --name mysql-dev \
      -e MYSQL_ROOT_PASSWORD=rootpassword \
      -e MYSQL_DATABASE=appdb \
      -e MYSQL_USER=azureuser \
      -e MYSQL_PASSWORD=password \
      -p 3306:3306 \
      mysql:8.0
    
    echo "Waiting for MySQL to be ready..."
    sleep 10
fi

# Set environment variables
export MYSQL_HOST=localhost
export MYSQL_USER=azureuser
export MYSQL_PASSWORD=password
export USER_SERVICE_URL=http://localhost:8081
export PAYMENT_SERVICE_URL=http://localhost:8083
export API_KEY=dev-api-key-123

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Function to start a service
start_service() {
    local service=$1
    local port=$2
    
    echo ""
    echo -e "${GREEN}Starting $service on port $port...${NC}"
    cd "$SCRIPT_DIR/$service"
    mvn spring-boot:run &
    
    # Wait for service to be ready
    echo "Waiting for $service to start..."
    sleep 15
    
    if curl -s http://localhost:$port/actuator/health | grep -q "UP"; then
        echo -e "${GREEN}✓ $service is running${NC}"
    else
        echo -e "${YELLOW}⚠ $service may still be starting...${NC}"
    fi
}

# Start all services
echo ""
echo -e "${YELLOW}Starting all microservices...${NC}"

start_service "user-service" 8081
start_service "order-service" 8082
start_service "payment-service" 8083

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All services are running!${NC}"
echo -e "${GREEN}========================================${NC}"

echo ""
echo "User Service:    http://localhost:8081"
echo "Order Service:   http://localhost:8082"
echo "Payment Service: http://localhost:8083"

echo ""
echo -e "${YELLOW}Quick Test Commands:${NC}"
echo ""

echo "1. Create a user:"
echo "curl -X POST http://localhost:8081/api/users \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"username\":\"test\",\"email\":\"test@example.com\",\"password\":\"pass123\",\"firstName\":\"Test\",\"lastName\":\"User\"}'"

echo ""
echo "2. Get all users:"
echo "curl http://localhost:8081/api/users"

echo ""
echo "3. Create an order:"
echo "curl -X POST http://localhost:8082/api/orders \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"userId\":1,\"amount\":99.99,\"currency\":\"USD\",\"description\":\"Test order\"}'"

echo ""
echo "4. Process an order:"
echo "curl -X POST http://localhost:8082/api/orders/1/process"

echo ""
echo "5. Check health:"
echo "curl http://localhost:8081/actuator/health"
echo "curl http://localhost:8082/actuator/health"
echo "curl http://localhost:8083/actuator/health"

echo ""
echo -e "${YELLOW}Note: Press Ctrl+C in each terminal to stop the services${NC}"
echo -e "${YELLOW}To stop all services: pkill -f 'spring-boot:run'${NC}"

# Wait for interrupt
wait
