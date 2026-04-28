# Complete Maven Project Structure - Summary

## Overview

A complete production-ready Maven-based Spring Boot microservices architecture has been created with three fully functional services, comprehensive configurations, and deployment scripts.

## Directory Structure Created

```
examples/maven-services/
│
├── user-service/
│   ├── pom.xml                                          # Maven configuration
│   └── src/
│       ├── main/
│       │   ├── java/com/example/userservice/
│       │   │   ├── UserServiceApplication.java          # Main application class
│       │   │   ├── controller/
│       │   │   │   └── UserController.java              # REST endpoints (CRUD + health)
│       │   │   ├── service/
│       │   │   │   └── UserService.java                 # Business logic
│       │   │   ├── repository/
│       │   │   │   └── UserRepository.java              # Database access (JPA)
│       │   │   └── entity/
│       │   │       └── User.java                        # Entity model
│       │   └── resources/
│       │       └── application.properties               # Configuration (DB, logging, metrics)
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
│       │   │   │   └── OrderController.java             # REST endpoints
│       │   │   ├── service/
│       │   │   │   └── OrderService.java                # REST client calls to User & Payment services
│       │   │   ├── repository/
│       │   │   │   └── OrderRepository.java
│       │   │   └── entity/
│       │   │       └── Order.java
│       │   └── resources/
│       │       └── application.properties               # Service URLs for inter-service calls
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
│       │   │   │   └── PaymentController.java           # REST endpoints + process endpoint
│       │   │   ├── service/
│       │   │   │   └── PaymentService.java              # Payment processing logic
│       │   │   ├── repository/
│       │   │   │   └── PaymentRepository.java
│       │   │   └── entity/
│       │   │       └── Payment.java
│       │   └── resources/
│       │       └── application.properties               # API_KEY configuration
│       └── test/
│           └── java/com/example/paymentservice/
│               └── PaymentServiceApplicationTests.java
│
├── docker-compose.yml                                   # Full local development stack
├── build.sh                                             # Build all services
├── start-local.sh                                       # Run all services locally
├── README.md                                            # Complete documentation
└── QUICK_REFERENCE.md                                   # Quick command reference
```

## What's Included

### 1. Three Complete Spring Boot Microservices

**User Service (Port 8081)**
- `UserController`: CRUD operations + health check
- `UserService`: Business logic with data access
- `UserRepository`: JPA interface for database queries
- `User`: Entity with validation annotations
- Endpoints: GET/POST/PUT/DELETE users, search by username/email

**Order Service (Port 8082)**
- `OrderController`: CRUD + order processing endpoints
- `OrderService`: Inter-service REST calls to User & Payment services using WebClient
- `OrderRepository`: Queries by userId and status
- `Order`: Entity with relational data
- Endpoints: Create order, process order (calls Payment Service), manage orders

**Payment Service (Port 8083)**
- `PaymentController`: Payment CRUD + process/refund endpoints
- `PaymentService`: Payment processing with validation and transaction generation
- `PaymentRepository`: Queries by orderId, status, transactionId
- `Payment`: Entity with payment tracking fields
- Endpoints: Create payment, process payment, refund payment, track status

### 2. Maven Configuration (pom.xml)

Each service includes:
- Spring Boot 2.7.10 (latest stable)
- Spring Data JPA (ORM)
- MySQL Connector 8.0.33
- Spring Boot Actuator (health checks, metrics)
- Micrometer Prometheus (metrics collection)
- Lombok (reduces boilerplate)
- Spring WebFlux (REST client for inter-service calls)
- JUnit testing framework

### 3. Database Configuration

Each service configured with:
- MySQL 8.0 connection (Flexible Server compatible)
- HikariCP connection pooling (10 max, 5 min)
- Hibernate auto-schema creation (update mode)
- UTF8MB4 character set support
- JPA/Hibernate best practices

### 4. Application Properties

Each service has `application.properties` with:
- Server port configuration (8081, 8082, 8083)
- MySQL database credentials
- JPA/Hibernate settings (batch size, formatting)
- Actuator endpoints (health, metrics, prometheus)
- Logging configuration (per-service DEBUG level)
- Service-to-service URLs for inter-service communication

### 5. Inter-Service Communication

**Order Service → User Service**
```java
// Verify user exists before creating order
webClientBuilder.build()
    .get()
    .uri(userServiceUrl + "/api/users/" + userId + "/exists")
    .retrieve()
    .bodyToMono(Boolean.class)
    .block();
```

**Order Service → Payment Service**
```java
// Call payment service to process payment
webClientBuilder.build()
    .post()
    .uri(paymentServiceUrl + "/api/payments/process")
    .bodyValue(paymentRequest)
    .retrieve()
    .bodyToMono(Map.class)
    .block();
```

### 6. Docker Integration

- **docker-compose.yml**: Complete stack with MySQL + 3 services
- **Dockerfile.springboot**: Multi-stage build (Maven builder + JDK runtime)
- Services are interconnected via network bridge
- Health checks for automatic restart
- Volume for MySQL data persistence

### 7. Automation Scripts

**build.sh**
- Validates Maven and Docker installation
- Builds all three services with `mvn clean package`
- Optionally builds Docker images
- Generates build summary

**start-local.sh**
- Checks MySQL (starts Docker container if needed)
- Starts all three services with `mvn spring-boot:run`
- Provides quick test commands
- Instructions for stopping services

### 8. Documentation

**README.md** (Comprehensive)
- Project overview and architecture
- Prerequisites and installation
- Service endpoints documentation
- API examples with curl commands
- Docker and docker-compose setup
- Testing procedures
- Troubleshooting guide
- Production deployment references

**QUICK_REFERENCE.md**
- Command cheat sheet
- Quick start options (3 methods)
- Common Maven commands
- Service endpoint table
- Example API calls
- Environment variables reference
- Troubleshooting checklist

## Key Features

✅ **Production-Ready**
- Validation (bean validation on entities)
- Exception handling (try-catch with proper error responses)
- Logging (SLF4J with configurable levels)
- Health checks (Spring Boot Actuator)
- Metrics (Prometheus export)

✅ **Scalable**
- Stateless services (no session affinity needed)
- Database connection pooling
- Configurable ports for multiple instances
- Environment-based configuration

✅ **Secure**
- Non-root database user (azureuser)
- Password management via environment variables
- API key support (Payment Service)
- Input validation on all endpoints

✅ **Observable**
- Actuator health endpoints
- Prometheus metrics exposure
- Structured logging
- Database query logging (optional)

✅ **Maintainable**
- Clean code structure (entity/repo/service/controller layers)
- Lombok for reduced boilerplate
- Comprehensive error handling
- Extensive documentation

## Quick Start Commands

### Option 1: Docker Compose (Easiest)
```bash
cd examples/maven-services
docker-compose up --build
```

### Option 2: Maven Build
```bash
./build.sh
cd user-service && mvn spring-boot:run
cd order-service && mvn spring-boot:run  # new terminal
cd payment-service && mvn spring-boot:run # new terminal
```

### Option 3: Script-Based
```bash
chmod +x build.sh start-local.sh
./build.sh
./start-local.sh
```

## Testing

### Create User
```bash
curl -X POST http://localhost:8081/api/users \
  -H "Content-Type: application/json" \
  -d '{"username":"john","email":"john@example.com","password":"pass123","firstName":"John","lastName":"Doe"}'
```

### Create Order
```bash
curl -X POST http://localhost:8082/api/orders \
  -H "Content-Type: application/json" \
  -d '{"userId":1,"amount":99.99,"currency":"USD"}'
```

### Process Order (triggers Payment Service)
```bash
curl -X POST http://localhost:8082/api/orders/1/process
```

### Check Health
```bash
curl http://localhost:8081/actuator/health
curl http://localhost:8082/actuator/health
curl http://localhost:8083/actuator/health
```

## Technology Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Framework | Spring Boot | 2.7.10 |
| Language | Java | 16 |
| Build Tool | Maven | 3.6+ |
| Database | MySQL | 8.0.33 |
| ORM | Spring Data JPA | 2.7.10 |
| REST Client | Spring WebFlux | 2.7.10 |
| Metrics | Micrometer Prometheus | 1.9.x |
| Container | Docker | Latest |
| Orchestration | Docker Compose | 3.8 |

## Next Steps

1. **Local Development**: Run services with docker-compose or Maven
2. **Testing**: Use provided curl examples to test endpoints
3. **Docker Images**: Build and push to Azure Container Registry
4. **Kubernetes**: Deploy to AKS using manifests in examples/3-tier-architecture/
5. **Production**: Follow DEPLOYMENT.md for Terraform + AKS deployment

## Files Created

- 9 Java source files (entities, repositories, services, controllers)
- 3 pom.xml files (Maven configs for each service)
- 3 application.properties (service configurations)
- 1 docker-compose.yml (complete local stack)
- 2 shell scripts (build.sh, start-local.sh)
- 3 documentation files (README.md, QUICK_REFERENCE.md, SUMMARY.md)

**Total: 21 files**

## Integration with Terraform

These services are ready to be:
- Containerized and pushed to Azure Container Registry
- Deployed to AKS cluster via Kubernetes manifests
- Configured with environment variables from Terraform outputs
- Integrated with MySQL database created by Terraform
- Connected to App Service and Function Apps for hybrid deployment

See [DEPLOYMENT.md](../../DEPLOYMENT.md) for complete deployment instructions.
