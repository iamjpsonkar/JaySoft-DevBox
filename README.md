# JaySoft-DevBox: Your Local Development Playground

JaySoft-DevBox is a local development environment that helps you set up and manage various services using Docker. It provides an easy way to run databases like MySQL, PostgreSQL, and caching tools like Redis, along with monitoring tools like Prometheus and Grafana.

## Current Features

- **Pre-configured Services:** Includes MySQL, PostgreSQL, Redis, Kafka, and monitoring tools.
- **Automated Setup:** Uses Docker Compose to start all required services.
- **Service Management Scripts:** Scripts to build, start, stop, delete, and rebuild the environment.
- **Monitoring Support:** Prometheus and Grafana for real-time service monitoring.
- **CI/CD Ready:** Can be integrated with continuous deployment pipelines.

## How to Run the Project

### Prerequisites
- **Docker** and **Docker Compose** installed on your system.
- `.env` file with required configurations.

### Steps to Run:
1. **Clone the Repository**
   ```sh
   git clone <repository-url>
   cd <project-folder>
   ```

2. **Build and Start Services**
   ```sh
   bash build_setup.sh
   ```
   - This script loads environment variables, pulls necessary Docker images, and starts the required services.

3. **Verify Running Services**
   ```sh
   docker ps
   ```
   - This command will show all running containers.

4. **Pause Services**
   ```sh
   bash pause_setup.sh
   ```

5. **Start Services**
   ```sh
   bash start_setup.sh
   ```

6. **Delete Services Completely**
   ```sh
   bash delete_setup.sh
   ```

7. **Rebuild the setup**
   ```sh
   bash rebuild_setup.sh
   ```

## How the `.env` File Controls Everything

The `.env` file is responsible for enabling/disabling services, setting external/internal ports, defining database credentials, and specifying Docker image versions. Below is a breakdown of key configurations:

### Service Enablement
```ini
BUILD_MONITOR=1
BUILD_ZOOKEEPER=1
BUILD_MYSQL=1
BUILD_REDIS=1
BUILD_KAFKA=1
BUILD_KAFKA_UI=1
BUILD_POSTGRES=1
BUILD_GRAFANA=1
BUILD_PROMETHEUS=1
BUILD_KAFKA_EXPORTER=1
BUILD_MYSQL_EXPORTER=1
BUILD_POSTGRES_EXPORTER=1
BUILD_REDIS_EXPORTER=1
```
These values determine which services will be started.

### External Ports (Adjustable)
```ini
ZOOKEEPER_EXTERNAL_PORT=2181
KAFKA_EXTERNAL_PORT=19092
MYSQL_EXTERNAL_PORT=13306
REDIS_EXTERNAL_PORT=16379
KAFKA_UI_EXTERNAL_PORT=18080
POSTGRES_EXTERNAL_PORT=15432
PROMETHEUS_EXTERNAL_PORT=9090
GRAFANA_EXTERNAL_PORT=3000
```
You can modify these ports to prevent conflicts with other running applications.

### Internal Ports (Do Not Edit)
```ini
ZOOKEEPER_PORT=2181
KAFKA_PORT=9092
MYSQL_PORT=3306
REDIS_PORT=6379
POSTGRES_PORT=5432
```
These are fixed ports used by Docker internally.

### Database Credentials
```ini
MYSQL_USER=root
MYSQL_PASS=root
POSTGRES_USER=postgres
POSTGRES_PASS=postgres
```
Modify these credentials if needed.

### Image Versions and Platforms
```ini
MONITOR_IMAGE="alpine:3.21"
ZOOKEEPER_IMAGE="confluentinc/cp-zookeeper:7.3.0"
KAFKA_IMAGE="confluentinc/cp-kafka:7.3.0"
MYSQL_IMAGE="mysql:8.0.31"
REDIS_IMAGE="redis:7.0-alpine"
POSTGRES_IMAGE="postgres:15-alpine"
GRAFANA_IMAGE="grafana/grafana:10.2.0"
PROMETHEUS_IMAGE="prom/prometheus:v2.47.0"
```
These values control the versions of the services being used.

## Contribution

We welcome contributions! Feel free to report issues or suggest improvements.

## Upcoming Features

- **Graphical User Interface:** A web-based UI to manage services easily.
- **Resource Manager:** Track and optimize resource usage.
- **Simplified One-Click Installation:** A single command to install everything.
- **Extended Service Support:** Add more frameworks and programming languages.
- **Advanced Monitoring:** Tools like Sentry and New Relic for better debugging.

## License

JaySoft-DevBox is open-source software licensed under the MIT License.

---
**Let's make local development easier! 🚀**

