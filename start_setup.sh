#!/bin/zsh

# Start all containers in the docker-compose setup
echo -e "\033[34mStarting all stopped containers...\033[0m"  # Blue for informational message
docker-compose start

if [ $? -eq 0 ]; then
    echo -e "\033[32mAll containers have been started successfully.\033[0m"  # Green for success
else
    echo -e "\033[31mError: Failed to start the containers. Please check Docker logs for details.\033[0m"  # Red for error
    exit 1
fi
