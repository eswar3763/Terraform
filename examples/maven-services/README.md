# Maven Microservices - Complete Project Structure

This directory contains three complete Maven-based Spring Boot microservices for the 3-tier architecture:

1. **User Service** (Port 8081) - User management and authentication
2. **Order Service** (Port 8082) - Order management and processing
3. **Payment Service** (Port 8083) - Payment processing and transactions

## Project Structure

```
maven-services/
├── user-service/
│   ├── pom.xml
│   └── src/
│       ├── main/
│       │   ├── java/com/example/userservice/
│       │   │   ├── UserServiceApplication.java
│       │   │   ├── controller/
│       │   │   │   └── UserController.java
│       │   │   ├── service/
│       │   │   │   └── UserService.java
│       │   │   ├── repository/
│       │   │   │   └── UserRepository.java
│       │   │   └── entity/
│       │   │       └── User.java
│       │   └── resources/
│       │       └── application.properties
│       └── test/
│           └── java/com/example/userservice/
│               └── UserServiceApplicationTests.java
│
├── order-service/
│   ├── pom.xml
│   └── src/
│       ├── main/
│       │   ├── java/com/example/orderservice/
│       │   │   ├── OrderServiceApplication.java
│       │   │   ├── controller/
│       │   │   │   └── OrderController.java
│       │   │   ├── service/
│       │   │   │   └── OrderService.java (with inter-service REST calls)
│       │   │   ├── repository/
│       │   │   │   └── OrderRepository.java
│       │   │   └── entity/
│       │   │       └── Order.java
│       │   └── resources/
│       │       └── application.properties
│       └── test/
│           └── java/com/example/orderservice/
│               └── OrderServiceApplicationTests.java
│
├── payment-service/
│   ├── pom.xml
│   └── src/
│       ├── main/
│       │   ├── java/com/example/paymentservice/
│       │   │   ├── PaymentServiceApplication.java
│       │   │   ├── controller/
│       │   │   │   └── PaymentController.java
│       │   │   ├── service/
│       │   │   │   └── PaymentService.java (with payment processing)
│       │   │   ├── repository/
│       │   │   │   └── PaymentRepository.java
│       │   │   └── entity/
│       │   │       └── Payment.java
│       │   └── resources/
│       │       └── application.properties
│       └── test/
│           └── java/com/example/paymentservice/
│               └── PaymentServiceApplicationTests.java
│
└── README.md (this file)
```

## Prerequisites

- Java 16 or higher
- Maven 3.6.0 or higher
- MySQL 8.0+ (local or remote)
- Docker & Docker Desktop (optional, for containerization)

## Installation & Setup

### 1. Build All Services

```bash
# Navigate to each service directory
cd user-service
mvn clean install

cd ../order-service
mvn clean install

cd ../payment-service
mvn clean install
```

### 2. Configure MySQL Database

```bash
# Connect to MySQL
mysql -h localhost -u azureuser -p

# Create database
CREATE DATABASE appdb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EXIT;
```

### 3. Update Environment Variables

Create `.env` or set environment variables:

```bash
export MYSQL_HOST=localhost
export MYSQL_USER=azureuser
export MYSQL_PASSWORD=YourPassword
export USER_SERVICE_URL=http://localhost:8081
export PAYMENT_SERVICE_URL=http://localhost:8083
export API_KEY=your-secret-api-key
```

## Running Services Locally

### Start User Service

```bash
cd user-service
mvn spring-boot:run
# Service runs on http://localhost:8081
```

### Start Order Service (in another terminal)

```bash
cd order-service
mvn spring-boot:run
# Service runs on http://localhost:8082
```

### Start Payment Service (in another terminal)

```bash
cd payment-service
mvn spring-boot:run
# Service runs on http://localhost:8083
```

## Service Endpoints

### User Service (Port 8081)

```
GET  /api/users                    - Get all users
POST /api/users                    - Create new user
GET  /api/users/{id}               - Get user by ID
GET  /api/users/username/{username} - Get user by username
GET  /api/users/email/{email}      - Get user by email
PUT  /api/users/{id}               - Update user
DELETE /api/users/{id}             - Delete user
GET  /api/users/{id}/exists        - Check if user exists
GET  /actuator/health              - Health check
GET  /actuator/prometheus          - Prometheus metrics
```

### Order Service (Port 8082)

```
GET  /api/orders                   - Get all orders
POST /api/orders                   - Create new order
GET  /api/orders/{id}              - Get order by ID
GET  /api/orders/user/{userId}     - Get orders by user
GET  /api/orders/status/{status}   - Get orders by status
PUT  /api/orders/{id}              - Update order
POST /api/orders/{id}/process      - Process order
DELETE /api/orders/{id}            - Delete order
GET  /actuator/health              - Health check
GET  /actuator/prometheus          - Prometheus metrics
```

### Payment Service (Port 8083)

```
GET  /api/payments                 - Get all payments
POST /api/payments                 - Create new payment
GET  /api/payments/{id}            - Get payment by ID
GET  /api/payments/order/{orderId} - Get payment by order
POST /api/payments/{id}/process    - Process payment
POST /api/payments/process         - Create and process payment
POST /api/payments/{id}/refund     - Refund payment
PUT  /api/payments/{id}            - Update payment
DELETE /api/payments/{id}          - Delete payment
GET  /actuator/health              - Health check
GET  /actuator/prometheus          - Prometheus metrics
```

## Testing the Services

### 1. Create a User

```bash
curl -X POST http://localhost:8081/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe",
    "email": "john@example.com",
    "password": "securePassword123",
    "firstName": "John",
    "lastName": "Doe"
  }'
```

### 2. Create an Order

```bash
curl -X POST http://localhost:8082/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "amount": 99.99,
    "currency": "USD",
    "description": "Sample order"
  }'
```

### 3. Process an Order

```bash
curl -X POST http://localhost:8082/api/orders/1/process
```

### 4. Create and Process a Payment

```bash
curl -X POST http://localhost:8083/api/payments/process \
  -H "Content-Type: application/json" \
  -d '{
    "orderId": 1,
    "amount": 99.99,
    "currency": "USD",
    "paymentMethod": "credit_card"
  }'
```

## Building Docker Images

### Build Individual Images

```bash
# User Service
cd user-service
docker build -t acr.azurecr.io/user-service:1.0.0 -f ../Dockerfile.springboot .
docker push acr.azurecr.io/user-service:1.0.0

# Order Service
cd ../order-service
docker build -t acr.azurecr.io/order-service:1.0.0 -f ../Dockerfile.springboot .
docker push acr.azurecr.io/order-service:1.0.0

# Payment Service
cd ../payment-service
docker build -t acr.azurecr.io/payment-service:1.0.0 -f ../Dockerfile.springboot .
docker push acr.azurecr.io/payment-service:1.0.0
```

### Using docker-compose (Optional)

Create a `docker-compose.yml` in the parent directory:

```yaml
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: appdb
      MYSQL_USER: azureuser
      MYSQL_PASSWORD: password123
    ports:
      - "3306:3306"

  user-service:
    build:
      context: user-service
      dockerfile: ../Dockerfile.springboot
    ports:
      - "8081:8081"
    environment:
      MYSQL_HOST: mysql
      MYSQL_USER: azureuser
      MYSQL_PASSWORD: password123
    depends_on:
      - mysql

  order-service:
    build:
      context: order-service
      dockerfile: ../Dockerfile.springboot
    ports:
      - "8082:8082"
    environment:
      MYSQL_HOST: mysql
      MYSQL_USER: azureuser
      MYSQL_PASSWORD: password123
      USER_SERVICE_URL: http://user-service:8081
      PAYMENT_SERVICE_URL: http://payment-service:8083
    depends_on:
      - mysql

  payment-service:
    build:
      context: payment-service
      dockerfile: ../Dockerfile.springboot
    ports:
      - "8083:8083"
    environment:
      MYSQL_HOST: mysql
      MYSQL_USER: azureuser
      MYSQL_PASSWORD: password123
      API_KEY: your-secret-api-key
    depends_on:
      - mysql
```

Run with: `docker-compose up`

## Database Schema

The services will automatically create tables on startup (Hibernate `ddl-auto=update`):

- **users** - User information (User Service)
- **orders** - Order records (Order Service)
- **payments** - Payment records (Payment Service)

## Configuration Files

Each service has an `application.properties` file for configuration:

- `src/main/resources/application.properties`

Key configuration options:

```properties
server.port=8081                                # Service port
spring.datasource.url=jdbc:mysql://...         # MySQL connection
spring.jpa.hibernate.ddl-auto=update           # Auto-create tables
management.endpoints.web.exposure.include=health,metrics,prometheus
```

## Logging

Logs are configured in `application.properties`:

```properties
logging.level.root=INFO
logging.level.com.example.userservice=DEBUG
```

## Dependencies

All services use these common dependencies:

- Spring Boot 2.7.10
- Spring Data JPA
- MySQL Connector/J 8.0.33
- Lombok (reduces boilerplate)
- Spring Boot Actuator (health checks, metrics)
- Micrometer Prometheus (metrics collection)
- Spring WebFlux (REST client for inter-service calls)

## Development Tips

1. **Running Tests:**
   ```bash
   mvn test
   ```

2. **Clean Build:**
   ```bash
   mvn clean install
   ```

3. **Skip Tests:**
   ```bash
   mvn clean install -DskipTests
   ```

4. **Build JAR:**
   ```bash
   mvn clean package
   ```

5. **Debug Mode:**
   ```bash
   mvn spring-boot:run -Dspring-boot.run.arguments="--debug"
   ```

## Troubleshooting

### Connection to MySQL Failed
- Verify MySQL is running: `mysql -u root -p`
- Check credentials in `application.properties`
- Ensure database exists: `CREATE DATABASE appdb;`

### Port Already in Use
- Change port in `application.properties`: `server.port=8085`
- Or kill process: `lsof -i :8081`

### Maven Build Fails
- Clear cache: `mvn clean`
- Update Maven: `mvn -version`
- Download dependencies: `mvn dependency:resolve`

## Production Deployment

For Kubernetes deployment, see [DEPLOYMENT.md](../DEPLOYMENT.md) in the parent directory.

## License

MIT License - See LICENSE file

## Support

For issues or questions, refer to:
- Spring Boot Documentation: https://spring.io/projects/spring-boot
- Maven Documentation: https://maven.apache.org/
- Terraform Deployment Guide: `../DEPLOYMENT.md`
