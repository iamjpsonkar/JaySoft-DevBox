#!/bin/bash

# Load environment variables from the .env file
if [[ -f .env ]]; then
    source .env
else
    echo -e "\033[31m.env file not found!\033[0m"  # Red color for error
    exit 1
fi

# Function to check if a service is up
check_service_up() {
    local service_name=$1
    local port=$2
    echo ""
    echo -e "\033[36mChecking if $service_name is up on port $port...\033[0m"  # Cyan for checking status

    # Cross-platform service check using 'docker inspect'
    if docker inspect -f '{{.State.Running}}' $service_name 2>/dev/null | grep -q 'true'; then
        echo -e "\033[32m$service_name is up!\033[0m"  # Green for success
        echo ""
        return 0
    else
        echo -e "\033[31mError: $service_name did not start on port $port. Please check the logs.\033[0m"  # Red for error
        return 1
    fi
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "\033[31mDocker is not running. Please start Docker first.\033[0m"  # Red for error
    exit 1
fi

# Determine the platform
DEV_PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
if [[ "$DEV_PLATFORM" == "linux" ]]; then
    DEV_PLATFORM="$DEV_PLATFORM/amd64" # Default to amd64 for Linux
elif [[ "$DEV_PLATFORM" == "darwin" ]]; then
    DEV_PLATFORM="$DEV_PLATFORM/amd64" # Default to amd64 for macOS
fi

# Pull the necessary images
echo -e "\033[34mPulling necessary Docker images...\033[0m"  # Blue for informational message
docker-compose pull
echo -e "\033[32mDocker images pulled successfully.\033[0m"  # Green for success

# Start all services
echo -e "\033[34mStarting all services...\033[0m"  # Blue for informational message
docker-compose up --build -d
echo -e "\033[32mServices started in detached mode.\033[0m"  # Green for success

# Wait for services to be ready
echo -e "\033[34mWaiting for services to be ready...\033[0m"  # Blue for informational message
sleep 5
echo -e "\033[32mServices should now be up and running.\033[0m"  # Green for success

# Final message
echo -e "\033[34mServices which are running and accessible at the following URLs:\033[0m"  # Blue for informational message
echo ""

# Check if services are up
if [ "$BUILD_KAFKA" -eq 1 ]; then
    check_service_up "zookeeper" "$ZOOKEEPER_PORT" || exit 1
    check_service_up "kafka" "$KAFKA_EXTERNAL_PORT" || exit 1
fi

if [ "$BUILD_MYSQL" -eq 1 ]; then
    check_service_up "mysql" "$MYSQL_EXTERNAL_PORT" || exit 1
    echo -e "\033[32mMySQL: mysql://localhost:$MYSQL_EXTERNAL_PORT\033[0m"  # Green for success
    echo ""
fi

if [ "$BUILD_REDIS" -eq 1 ]; then
    check_service_up "redis" "$REDIS_EXTERNAL_PORT" || exit 1
    echo -e "\033[32mRedis: redis://localhost:$REDIS_EXTERNAL_PORT\033[0m"  # Green for success
    echo ""
fi

if [ "$BUILD_KAFKA_UI_AKHQ" -eq 1 ]; then
    check_service_up "akhq" "$AKHQ_EXTERNAL_PORT" || exit 1
    echo -e "\033[32mAKHQ Kafka UI: http://localhost:$AKHQ_EXTERNAL_PORT\033[0m"  # Green for success
    echo ""
fi

if [ "$BUILD_POSTGRES" -eq 1 ]; then
    check_service_up "postgres" "$POSTGRES_EXTERNAL_PORT" || exit 1
    echo -e "\033[32mPostgreSQL: postgres://localhost:$POSTGRES_EXTERNAL_PORT\033[0m"  # Green for success
    echo ""
fi