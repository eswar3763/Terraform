# Maven Services - Quick Reference

## File Structure

```
maven-services/
├── user-service/          # User management service (port 8081)
├── order-service/         # Order management service (port 8082)
├── payment-service/       # Payment processing service (port 8083)
├── Dockerfile.springboot  # Maven multi-stage Dockerfile
├── docker-compose.yml     # Docker Compose for local development
├── build.sh              # Build script for all services
├── start-local.sh        # Start all services locally
└── README.md             # Full documentation
```

## Quick Start

### Option 1: Docker Compose (Easiest)

```bash
cd examples/maven-services
docker-compose up --build
```

Services will be available at:
- User Service: http://localhost:8081
- Order Service: http://localhost:8082
- Payment Service: http://localhost:8083

### Option 2: Maven Local Build

```bash
# Build all services
cd user-service && mvn clean install && cd ..
cd order-service && mvn clean install && cd ..
cd payment-service && mvn clean install && cd ..

# Start services (each in separate terminal)
cd user-service && mvn spring-boot:run
cd order-service && mvn spring-boot:run
cd payment-service && mvn spring-boot:run
```

### Option 3: Using Build Script

```bash
chmod +x build.sh
./build.sh
```

## Common Maven Commands

### Build & Package

```bash
mvn clean install           # Clean and build
mvn clean package           # Create JAR without running tests
mvn clean package -DskipTests  # Skip tests for faster build
mvn clean install -U        # Update dependencies
```

### Run Services

```bash
mvn spring-boot:run        # Run application
mvn spring-boot:run -Dspring-boot.run.arguments="--debug"  # Debug mode
```

### Testing

```bash
mvn test                    # Run all tests
mvn test -Dtest=UserControllerTest  # Run specific test
mvn test -DskipTests=true   # Skip tests
```

### Build Docker Image

```bash
docker build -t user-service:1.0 -f ../Dockerfile.springboot .
docker push acr.azurecr.io/user-service:1.0
```

## Service Endpoints

### User Service (8081)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/users` | Get all users |
| POST | `/api/users` | Create user |
| GET | `/api/users/{id}` | Get user by ID |
| GET | `/api/users/username/{username}` | Get user by username |
| GET | `/api/users/email/{email}` | Get user by email |
| PUT | `/api/users/{id}` | Update user |
| DELETE | `/api/users/{id}` | Delete user |
| GET | `/actuator/health` | Health check |

### Order Service (8082)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/orders` | Get all orders |
| POST | `/api/orders` | Create order |
| GET | `/api/orders/{id}` | Get order by ID |
| GET | `/api/orders/user/{userId}` | Get user's orders |
| GET | `/api/orders/status/{status}` | Get orders by status |
| PUT | `/api/orders/{id}` | Update order |
| POST | `/api/orders/{id}/process` | Process order |
| DELETE | `/api/orders/{id}` | Delete order |
| GET | `/actuator/health` | Health check |

### Payment Service (8083)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/payments` | Get all payments |
| POST | `/api/payments` | Create payment |
| GET | `/api/payments/{id}` | Get payment by ID |
| GET | `/api/payments/order/{orderId}` | Get payment by order |
| POST | `/api/payments/{id}/process` | Process payment |
| POST | `/api/payments/process` | Create and process payment |
| POST | `/api/payments/{id}/refund` | Refund payment |
| DELETE | `/api/payments/{id}` | Delete payment |
| GET | `/actuator/health` | Health check |

## Example API Calls

### Create User

```bash
curl -X POST http://localhost:8081/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe",
    "email": "john@example.com",
    "password": "securePass123",
    "firstName": "John",
    "lastName": "Doe"
  }'
```

### Create Order

```bash
curl -X POST http://localhost:8082/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "amount": 99.99,
    "currency": "USD",
    "description": "Test order"
  }'
```

### Process Order (calls Payment Service)

```bash
curl -X POST http://localhost:8082/api/orders/1/process
```

### Process Payment

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

### Get All Orders for User

```bash
curl http://localhost:8082/api/orders/user/1
```

### Check Service Health

```bash
curl http://localhost:8081/actuator/health
curl http://localhost:8082/actuator/health
curl http://localhost:8083/actuator/health
```

## Environment Variables

```bash
# Database Configuration
MYSQL_HOST=localhost           # MySQL hostname
MYSQL_USER=azureuser          # MySQL username
MYSQL_PASSWORD=password123    # MySQL password

# Service URLs (for inter-service communication)
USER_SERVICE_URL=http://user-service:8081
PAYMENT_SERVICE_URL=http://payment-service:8083

# API Keys
API_KEY=your-secret-api-key
```

## Configuration Files

Each service has `src/main/resources/application.properties`:

```properties
# Server Port
server.port=8081

# Database
spring.datasource.url=jdbc:mysql://localhost:3306/appdb
spring.datasource.username=azureuser
spring.datasource.password=password123

# Actuator (health & metrics)
management.endpoints.web.exposure.include=health,metrics,prometheus

# Logging
logging.level.root=INFO
logging.level.com.example.userservice=DEBUG
```

## Troubleshooting

### MySQL Connection Failed
```bash
# Check MySQL is running
docker ps | grep mysql

# Check MySQL credentials
mysql -h localhost -u azureuser -ppassword123 appdb

# View logs
docker logs mysql-dev
```

### Port Already in Use
```bash
# Kill process on port 8081
lsof -i :8081
kill -9 <PID>

# Or change port in application.properties
server.port=8085
```

### Build Failed
```bash
# Clear Maven cache
mvn clean
rm -rf ~/.m2/repository

# Update dependencies
mvn dependency:resolve
```

### Docker Build Issues
```bash
# Check Dockerfile location
ls -la ../Dockerfile.springboot

# Build with verbose output
docker build --progress=plain -t user-service:1.0 .
```

## Project Dependencies

- Spring Boot 2.7.10
- Spring Data JPA
- MySQL Connector 8.0.33
- Lombok (reduces boilerplate)
- Spring Boot Actuator (metrics)
- Micrometer Prometheus (metrics export)
- Spring WebFlux (REST client)

## Performance Tips

1. **Database**: Use connection pooling (HikariCP default)
2. **JVM**: Set heap size: `JAVA_OPTS="-Xmx512m"`
3. **Docker**: Multi-stage build reduces image size
4. **Metrics**: Monitor with `/actuator/prometheus`

## Deployment

For Kubernetes deployment, refer to [DEPLOYMENT.md](../DEPLOYMENT.md)

## Support & Documentation

- Spring Boot: https://spring.io/projects/spring-boot
- Maven: https://maven.apache.org/
- Docker: https://docs.docker.com/
- MySQL: https://dev.mysql.com/doc/
