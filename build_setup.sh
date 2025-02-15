#!/bin/bash

# Color codes for output
RED="\033[31m"
GREEN="\033[32m"
BLUE="\033[34m"
CYAN="\033[36m"
NC="\033[0m" # No Color

# Load environment variables
echo -e "${CYAN}\nLoading environment variables...${NC}"
if [ -f .env ]; then
    set -a
    . .env
    set +a
    echo -e "${GREEN}✅ Environment variables loaded successfully.${NC}\n"
else
    echo -e "${RED}❌ Error: .env file not found!${NC}\n"
    exit 1
fi

# Ensure required dependencies
if [ "${BUILD_KAFKA-0}" -eq 1 ]; then
    export BUILD_ZOOKEEPER=1
    echo -e "${BLUE}ℹ️ Kafka is enabled. Enabling Zookeeper as well.${NC}\n"
else
    export BUILD_ZOOKEEPER=0
    export BUILD_KAFKA_UI=0
    export BUILD_KAFKA_EXPORTER=0
fi

[ "${BUILD_REDIS-0}" -eq 0 ] && export BUILD_REDIS_EXPORTER=0
[ "${BUILD_MYSQL-0}" -eq 0 ] && export BUILD_MYSQL_EXPORTER=0
[ "${BUILD_POSTGRES-0}" -eq 0 ] && export BUILD_POSTGRES_EXPORTER=0

# Function to check Docker status
check_docker() {
    echo -e "${CYAN}\nChecking Docker status...${NC}"
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not running!${NC}"
        exit 1
    fi
    if ! docker-compose version >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker Compose is not installed!${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Docker is running.${NC}\n"
}

# Function to check if a service is running
check_service_up() {
    local service="$1"
    local port="$2"
    for i in {1..10}; do
        if docker inspect -f '{{.State.Running}}' "$service" 2>/dev/null | grep -q 'true'; then
            echo -e "${GREEN}✅ $service is running on port $port.${NC}"
            return 0
        fi
        echo -e "${BLUE}⌛ Waiting for $service to start...${NC}"
        sleep 3
    done
    echo -e "${RED}❌ $service failed to start on port $port.${NC}"
}

# Pull necessary images
pull_images() {
    echo -e "${BLUE}\nPulling Docker images...${NC}"
    for service in monitor mysql mysql_exporter redis redis_exporter postgres postgres_exporter \
        zookeeper kafka kafka_exporter prometheus grafana kafka_ui; do
        upper_service=$(echo "$service" | tr '[:lower:]' '[:upper:]')
        eval "build_flag=\${BUILD_${upper_service}-0}"
        if [ "$build_flag" -eq 1 ]; then
            echo -e "${CYAN}🔄 Pulling $service image...${NC}"
            docker-compose pull "$service"
        fi
    done
    echo -e "${GREEN}✅ All required images pulled.${NC}\n"
}

# Start enabled services
start_services() {
    echo -e "${BLUE}\nStarting services...${NC}"
    local services_to_start=""
    for service in monitor mysql mysql_exporter redis redis_exporter postgres postgres_exporter \
        zookeeper kafka kafka_exporter prometheus grafana kafka_ui; do
        upper_service=$(echo "$service" | tr '[:lower:]' '[:upper:]')
        eval "build_flag=\${BUILD_${upper_service}-0}"
        if [ "$build_flag" -eq 1 ]; then
            services_to_start+=" $service"
        fi
    done
    if [ -n "$services_to_start" ]; then
        docker-compose up --build -d $services_to_start --pull never
        echo -e "${GREEN}✅ Services started.${NC}\n"
    else
        echo -e "${CYAN}ℹ️ No enabled services to start.${NC}"
    fi
}

# Verify services are up
verify_services() {
    echo -e "${BLUE}\nVerifying services are running...${NC}"
    declare -A service_ports=(
        ["mysql"]=${MYSQL_EXTERNAL_PORT-3306}
        ["redis"]=${REDIS_EXTERNAL_PORT-6379}
        ["postgres"]=${POSTGRES_EXTERNAL_PORT-5432}
        ["zookeeper"]=${ZOOKEEPER_EXTERNAL_PORT-2181}
        ["kafka"]=${KAFKA_EXTERNAL_PORT-9092}
        ["kafka_ui"]=${KAFKA_UI_EXTERNAL_PORT-9092}
        ["prometheus"]=${PROMETHEUS_EXTERNAL_PORT-9090}
        ["grafana"]=${GRAFANA_EXTERNAL_PORT-3000}
    )
    for service in "${!service_ports[@]}"; do
        build_var="BUILD_${service^^}"
        if [ "${!build_var-0}" -eq 1 ]; then
            check_service_up "$service" "${service_ports[$service]}"
            case $service in
                mysql) echo -e "✅ ${GREEN}\tMySQL: mysql://localhost:${service_ports[$service]}${NC}\n";;
                redis) echo -e "✅ ${GREEN}\tRedis: redis://localhost:${service_ports[$service]}${NC}\n";;
                postgres) echo -e "✅ ${GREEN}\tPostgreSQL: postgres://localhost:${service_ports[$service]}${NC}\n";;
                zookeeper) echo -e "✅ ${GREEN}\tZookeeper: localhost:${service_ports[$service]}${NC}\n";;
                kafka) echo -e "✅ ${GREEN}\tKafka: localhost:${service_ports[$service]}${NC}\n";;
                kafka_ui) echo -e "✅ ${GREEN}\tKafka: http://localhost:${service_ports[$service]}${NC}\n";;
                prometheus) echo -e "✅ ${GREEN}\tPrometheus: http://localhost:${service_ports[$service]}${NC}\n";;
                grafana) echo -e "✅ ${GREEN}\tGrafana UI: http://localhost:${service_ports[$service]}${NC}\n";;
            esac
        fi
    done
    echo -e "${GREEN}✅ All services are running.${NC}\n"
}

# Main Execution
check_docker
bash conf_generator.sh
pull_images
start_services
verify_services

echo -e "${GREEN}🎉 Docker environment setup complete!${NC}\n"
