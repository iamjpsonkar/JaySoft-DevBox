#!/bin/zsh

# Stop all running Docker containers
echo -e "\033[34mStopping all services...\033[0m"  # Blue for informational message
docker-compose down --volumes --remove-orphans

# Final message
echo -e "\033[32mAll services have been stopped and Kafka topics have been removed.\033[0m"  # Green for success
