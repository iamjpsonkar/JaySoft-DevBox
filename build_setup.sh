#!/bin/bash

# Color codes for output
RED="\033[31m"
GREEN="\033[32m"
BLUE="\033[34m"
CYAN="\033[36m"
NC="\033[0m" # No Color


# Define services
services="monitor mysql mysql_exporter redis redis_exporter postgres postgres_exporter zookeeper kafka kafka_exporter prometheus grafana kafka_ui"


# Load environment variables
echo -e "${CYAN}\nLoading environment variables...${NC}"
if [ -f .env ]; then
    . .env
    echo -e "${GREEN}    Environment variables loaded successfully.${NC}\n"
else
    echo -e "${RED}    Error: .env file not found!${NC}\n"
    exit 1
fi

# Ensure Zookeeper is enabled if Kafka is enabled
if [ "${BUILD_KAFKA-0}" -eq 1 ]; then
    export BUILD_ZOOKEEPER=1
    echo -e "${BLUE}    Kafka is enabled. Ensuring Zookeeper is also enabled.${NC}\n"
else
    export BUILD_ZOOKEEPER=0
    export BUILD_KAFKA_UI=0
    export BUILD_KAFKA_EXPORTER=0
fi

if [ "${BUILD_REDIS-0}" -eq 0 ]; then
    export BUILD_REDIS_EXPORTER=0
fi

if [ "${BUILD_MYSQL-0}" -eq 0 ]; then
    export BUILD_MYSQL_EXPORTER=0
fi

if [ "${BUILD_POSTGRES-0}" -eq 0 ]; then
    export BUILD_POSTGRES_EXPORTER=0
fi

replace_env_vars() {
    script_path="$1"

    if [ ! -f "$script_path" ]; then
        echo -e "${RED}File not found: $script_path${NC}"
        return 1
    fi

    vars=$(grep -o '\${[A-Za-z0-9_]\+}' "$script_path" | sed 's/[${}]//g' | sort -u)
    temp_file=$(mktemp)
    cp "$script_path" "$temp_file"

    for var in $vars; do
        eval "value=\${$var}"
        [ -n "$value" ] && sed "s|\${$var}|$value|g" "$temp_file" > "${temp_file}.tmp" && mv "${temp_file}.tmp" "$temp_file"
    done

    mv "$temp_file" "$script_path"
    echo -e "✅ Environment variables replaced in $script_path"
}

# [ "${BUILD_PROMETHEUS-0}" -eq 1 ] && replace_env_vars "$PROMETHEUS_YML"
# [ "${BUILD_GRAFANA-0}" -eq 1 ] && replace_env_vars "$GRAFANA_YML"

generate_my_cnf() {
    dir="${1-./mysql_exporter}"
    mkdir -p "$dir"
    cat > "$dir/.my.cnf" <<EOF
[client]
user=${MYSQL_USER-root}
password=${MYSQL_PASS-password}
host=${MYSQL_HOST-mysql}
port=${MYSQL_PORT-3306}
EOF
    chmod 600 "$dir/.my.cnf"
    echo -e "✅ .my.cnf generated"
}

generate_my_cnf

check_docker() {
    echo -e "${CYAN}\nChecking Docker status...${NC}"
    if docker info >/dev/null 2>&1; then
        echo -e "${GREEN}    Docker is running.${NC}\n"
    else
        echo -e "${RED}    Error: Docker is not running.${NC}"
        exit 1
    fi
}

check_service_up() {
    service="$1"
    port="$2"
    if docker inspect -f '{{.State.Running}}' "$service" 2>/dev/null | grep -q 'true'; then
        echo -e "${GREEN}    $service is running on port $port.${NC}\n"
    else
        echo -e "${RED}    Error: $service is not running on port $port.${NC}"
        exit 1
    fi
}

pull_images() {
    echo -e "${BLUE}\nPulling Docker images...${NC}"
    for service in $services; do
        upper_service=$(echo -e "$service" | tr '[:lower:]' '[:upper:]')
        eval "build_flag=\${BUILD_${upper_service}-0}"
        if [ "$build_flag" -eq 1 ]; then
            echo -e "${CYAN}    Pulling image for $service...${NC}"
            docker-compose pull "$service"
        fi
    done
    echo -e "${GREEN}✅ All Docker images pulled.${NC}\n"
}

start_services() {
    echo -e "${BLUE}\nStarting services...${NC}"
    services_to_start=""
    for service in $services; do
        upper_service=$(echo -e "$service" | tr '[:lower:]' '[:upper:]')
        eval "build_flag=\${BUILD_${upper_service}-0}"
        if [ "$build_flag" -eq 1 ]; then
            services_to_start="$services_to_start $service"
        fi
    done
    if [ -n "$services_to_start" ]; then
        docker-compose up --build -d $services_to_start --pull never
        echo -e "${GREEN}✅ Services started.${NC}\n"
    else
        echo -e "${CYAN}ℹ️ No services enabled to start.${NC}"
    fi
}

verify_services() {
    echo -e "${BLUE}\nWaiting for services to initialize...${NC}"
    sleep 5

    declare -A services_ports=(
        ["mysql"]=${MYSQL_EXTERNAL_PORT-13306}
        ["mysql_exporter"]=${MYSQL_EXPORTER_PORT-9104}
        ["redis"]=${REDIS_EXTERNAL_PORT-16379}
        ["redis_exporter"]=${REDIS_EXPORTER_PORT-9121}
        ["postgres"]=${POSTGRES_EXTERNAL_PORT-15432}
        ["postgres_exporter"]=${POSTGRES_EXPORTER_PORT-9187}
        ["zookeeper"]=${ZOOKEEPER_PORT-2181}
        ["kafka"]=${KAFKA_EXTERNAL_PORT-19092}
        ["kafka_exporter"]=${KAFKA_EXPORTER_PORT-9308}
        ["prometheus"]=${PROMETHEUS_EXTERNAL_PORT-19090}
        ["grafana"]=${GRAFANA_EXTERNAL_PORT-13000}
        ["kafka_ui"]=${KAFKA_UI_EXTERNAL_PORT-18080}
    )

    for service in "${!services_ports[@]}"; do
        local build_var="BUILD_${service^^}"

        if [ "${!build_var-0}" -eq 1 ]; then
            check_service_up "$service" "${services_ports[$service]}"
            case $service in
                mysql) echo -e "✅ ${GREEN}\tMySQL: mysql://localhost:${services_ports[$service]}${NC}\n";;
                mysql_exporter) echo -e "✅ ${GREEN}\tMYSQL Exporter: http://localhost:${services_ports[$service]}${NC}\n";;
                redis) echo -e "✅ ${GREEN}\tRedis: redis://localhost:${services_ports[$service]}${NC}\n";;
                redis_exporter) echo -e "✅ ${GREEN}\tREDIS Exporter: http://localhost:${services_ports[$service]}${NC}\n";;
                postgres) echo -e "✅ ${GREEN}\tPostgreSQL: postgres://localhost:${services_ports[$service]}${NC}\n";;
                postgres_exporter) echo -e "✅ ${GREEN}\tPOSTGRES Exporter: http://localhost:${services_ports[$service]}${NC}\n";;
                zookeeper) echo -e "✅ ${GREEN}\tZookeeper: localhost:${services_ports[$service]}${NC}\n";;
                kafka) echo -e "✅ ${GREEN}\tKafka: localhost:${services_ports[$service]}${NC}\n";;
                kafka_exporter) echo -e "✅ ${GREEN}\tKafka Exporter: localhost:${services_ports[$service]}${NC}\n";;
                prometheus) echo -e "✅ ${GREEN}\tPROMETHEUS Exporter: http://localhost:${services_ports[$service]}${NC}\n";;
                grafana) echo -e "✅ ${GREEN}\tGrafana UI: http://localhost:${services_ports[$service]}${NC}\n";;
                kafka_ui) echo -e "✅ ${GREEN}\tKafka UI: http://localhost:${services_ports[$service]}${NC}\n";;
            esac
        fi
    done
    echo -e "${GREEN}✅ All services are up and running.${NC}\n"
}

# Main Execution
check_docker
pull_images
start_services
verify_services

echo -e "${GREEN}🎉 Docker Environment Setup Complete!${NC}\n"
