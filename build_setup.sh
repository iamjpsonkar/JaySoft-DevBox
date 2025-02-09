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

replace_env_vars() {
    local script_path="$1"
    
    if [[ ! -f "$script_path" ]]; then
        echo "File not found: $script_path"
        return 1
    fi

    # Extract all variables in the format ${VAR_NAME}
    local vars=$(grep -oP '\$\{\K[A-Za-z0-9_]+(?=\})' "$script_path" | sort -u)

    # Create a temporary file to store the updated content
    local temp_file=$(mktemp)

    # Read the original file and replace variables with their environment values
    cp "$script_path" "$temp_file"
    for var in $vars; do
        value=${!var}
        if [[ -n "$value" ]]; then
        sed -i "s/\\\${$var}/$value/g" "$temp_file"
        fi
    done

    # Overwrite the original file with the updated content
    mv "$temp_file" "$script_path"

    echo "Environment variables replaced successfully in $script_path"
}

if [ "${BUILD_PROMETHEUS-0}" -eq 1 ]; then
    replace_env_vars ${PROMETHEUS_YML}
    echo -e "${BLUE}\tUpdated ${PROMETHEUS_YML}${NC}\n"
fi

if [ "${BUILD_GRAFANA-0}" -eq 1 ]; then
    replace_env_vars ${GRAFANA_YML}
    echo -e "${BLUE}\tUpdated ${GRAFANA_YML}${NC}\n"
fi


generate_my_cnf() {
    # Default values if not set
    local MYSQL_USER="${MYSQL_USER-root}"
    local MYSQL_PASS="${MYSQL_PASS-password}"
    local MYSQL_HOST="${MYSQL_HOST-mysql}"
    local MYSQL_PORT="${MYSQL_PORT-3306}"
    local CNF_PATH="${1-./mysql_exporter/.my.cnf}"

    # Create the directory if it doesn't exist
    mkdir -p "$(dirname "$CNF_PATH")"

    # Generate the .my.cnf file
cat > "$CNF_PATH" <<EOF
[client]
user=${MYSQL_USER}
password=${MYSQL_PASS}
host=${MYSQL_HOST}
port=${MYSQL_PORT}
EOF

    # Set secure permissions
    chmod 600 "$CNF_PATH"

    echo "✅ .my.cnf generated at $CNF_PATH"
}

generate_my_cnf

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
    local services=("MONITOR" "ZOOKEEPER" "KAFKA" "MYSQL" "REDIS" "POSTGRES" "KAFDROP" "AKHQ" "PROMETHEUS" "GRAFANA" "KAFKA_EXPORTER" "REDIS_EXPORTER" "MYSQL_EXPORTER" "POSTGRES_EXPORTER")

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

    for service in monitor zookeeper kafka mysql redis postgres kafdrop akhq prometheus grafana kafka_exporter redis_exporter mysql_exporter postgres_exporter; do
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
        ["zookeeper"]=${ZOOKEEPER_PORT-2181}
        ["kafka"]=${KAFKA_EXTERNAL_PORT-19092}
        ["mysql"]=${MYSQL_EXTERNAL_PORT-13306}
        ["redis"]=${REDIS_EXTERNAL_PORT-16379}
        ["postgres"]=${POSTGRES_EXTERNAL_PORT-15432}
        ["akhq"]=${AKHQ_EXTERNAL_PORT-18080}
        ["kafdrop"]=${KAFDROP_EXTERNAL_PORT-19000}
        ["grafana"]=${GRAFANA_EXTERNAL_PORT-13000}
        ["kafka_exporter"]=${KAFKA_EXPORTER_PORT-9308}
        ["redis_exporter"]=${REDIS_EXPORTER_PORT-9121}
        ["mysql_exporter"]=${MYSQL_EXPORTER_PORT-9104}
        ["postgres_exporter"]=${POSTGRES_EXPORTER_PORT-9187}
        ["prometheus"]=${PROMETHEUS_EXTERNAL_PORT-19090}
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
                kafdrop) echo -e "${GREEN}\tKAFDROP Kafka UI: http://localhost:${services_ports[$service]}${NC}\n";;
                grafana) echo -e "${GREEN}\tGrafana UI: http://localhost:${services_ports[$service]}${NC}\n";;
                zookeeper) echo -e "${GREEN}\tZookeeper: localhost:${services_ports[$service]}${NC}\n";;
                kafka) echo -e "${GREEN}\tKafka: localhost:${services_ports[$service]}${NC}\n";;
                kafka) echo -e "${GREEN}\tKafka Exporter: localhost:${services_ports[$service]}${NC}\n";;
                kafka) echo -e "${GREEN}\tMYSQL Exporter: localhost:${services_ports[$service]}${NC}\n";;
                kafka) echo -e "${GREEN}\tREDIS Exporter: localhost:${services_ports[$service]}${NC}\n";;
                kafka) echo -e "${GREEN}\tPOSTGRES Exporter: localhost:${services_ports[$service]}${NC}\n";;
                kafka) echo -e "${GREEN}\tPROMETHEUS Exporter: localhost:${services_ports[$service]}${NC}\n";;
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

# git checkout the updated yml file
git checkout prometheus.yml
git checkout grafana/provisioning/datasources/datasources.yml