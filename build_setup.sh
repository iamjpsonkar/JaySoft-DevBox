#!/bin/bash

# Color codes for output
RED="\033[31m"
GREEN="\033[32m"
BLUE="\033[34m"
CYAN="\033[36m"
NC="\033[0m" # No Color

# Load environment variables
echo -e "${CYAN}\nLoading environment variables...${NC}"
if [[ -f .env ]]; then
    source .env
    echo -e "${GREEN}\tEnvironment variables loaded successfully.${NC}\n"
else
    echo -e "${RED}\tError: .env file not found!${NC}\n"
    exit 1
fi

# Ensure Zookeeper is enabled if Kafka is enabled
if [ "${BUILD_KAFKA-0}" -eq 1 ]; then
    BUILD_ZOOKEEPER=1
    export BUILD_ZOOKEEPER=1
    echo -e "${BLUE}\tKafka is enabled. Ensuring Zookeeper is also enabled.${NC}\n"
else
    BUILD_ZOOKEEPER=0
    export BUILD_ZOOKEEPER=0
fi

# Function to check if Docker is running
check_docker() {
    echo -e "${CYAN}\nChecking Docker status...${NC}"
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}\tError: Docker is not running. Please start Docker first.${NC}\n"
        exit 1
    else
        echo -e "${GREEN}\tDocker is running.${NC}\n"
    fi
}

# Function to check if a service is up
check_service_up() {
    local service_name=$1
    local port=$2
    echo -e "${CYAN}\nChecking if $service_name is up on port $port...${NC}"

    if docker inspect -f '{{.State.Running}}' $service_name 2>/dev/null | grep -q 'true'; then
        echo -e "${GREEN}\t$service_name is running on port $port.${NC}\n"
    else
        echo -e "${RED}\tError: $service_name is not running on port $port. Check logs for details.${NC}\n"
        exit 1
    fi
}

# Function to pull Docker images
pull_images() {
    echo -e "${BLUE}\nPulling necessary Docker images...${NC}"
    local services=("ZOOKEEPER" "KAFKA" "MYSQL" "REDIS" "POSTGRES" "AKHQ" "GRAFANA")

    for service in "${services[@]}"; do
        local build_var="BUILD_${service}"
        local service_name=$(echo "$service" | tr '[:upper:]' '[:lower:]')

        if [ "${!build_var-0}" -eq 1 ]; then
            echo -e "${CYAN}\tPulling image for $service_name...${NC}"
            docker-compose pull "$service_name"
            echo -e "${GREEN}\tImage for $service_name pulled successfully.${NC}\n"
        fi
    done
    echo -e "${GREEN}\nAll Docker images pulled successfully.${NC}\n"
}

# Function to start Docker services
start_services() {
    echo -e "${BLUE}\nStarting selected services...${NC}"
    local services_to_start=()

    for service in zookeeper kafka mysql redis postgres akhq grafana; do
        local build_var="BUILD_${service^^}"
        if [ "${!build_var-0}" -eq 1 ]; then
            services_to_start+=("$service")
        fi
    done

    if [ ${#services_to_start[@]} -gt 0 ]; then
        docker-compose up --build -d "${services_to_start[@]}"
        echo -e "${GREEN}\tSelected services started in detached mode.${NC}\n"
    else
        echo -e "${CYAN}\tNo services enabled to start.${NC}\n"
    fi
}

# Function to verify services
verify_services() {
    echo -e "${BLUE}\nWaiting for services to initialize...${NC}"
    sleep 5

    declare -A services_ports=(
        ["zookeeper"]=${ZOOKEEPER_PORT:-2181}
        ["kafka"]=${KAFKA_EXTERNAL_PORT:-9092}
        ["mysql"]=${MYSQL_EXTERNAL_PORT:-3306}
        ["redis"]=${REDIS_EXTERNAL_PORT:-6379}
        ["postgres"]=${POSTGRES_EXTERNAL_PORT:-5432}
        ["akhq"]=${AKHQ_EXTERNAL_PORT:-8080}
        ["grafana"]=${GRAFANA_EXTERNAL_PORT:-3000}
    )

    for service in "${!services_ports[@]}"; do
        local build_var="BUILD_${service^^}"

        if [ "${!build_var-0}" -eq 1 ]; then
            check_service_up "$service" "${services_ports[$service]}"
            case $service in
                mysql) echo -e "${GREEN}\tMySQL: mysql://localhost:${services_ports[$service]}${NC}\n";;
                redis) echo -e "${GREEN}\tRedis: redis://localhost:${services_ports[$service]}${NC}\n";;
                postgres) echo -e "${GREEN}\tPostgreSQL: postgres://localhost:${services_ports[$service]}${NC}\n";;
                akhq) echo -e "${GREEN}\tAKHQ Kafka UI: http://localhost:${services_ports[$service]}${NC}\n";;
                grafana) echo -e "${GREEN}\tGrafana UI: http://localhost:${services_ports[$service]}${NC}\n";;
                zookeeper) echo -e "${GREEN}\tZookeeper: localhost:${services_ports[$service]}${NC}\n";;
                kafka) echo -e "${GREEN}\tKafka: localhost:${services_ports[$service]}${NC}\n";;
            esac
        fi
    done
    echo -e "${GREEN}\nAll services are running and accessible.${NC}\n"
}

# Main execution flow
echo -e "${CYAN}\n--- Starting Docker Environment Setup ---${NC}"
check_docker
pull_images
start_services
verify_services
echo -e "${GREEN}\n--- Docker Environment Setup Complete ---${NC}\n"
