#!/bin/zsh

# Stop all running containers in the docker-compose setup
echo -e "\033[34mStopping all containers without deleting them...\033[0m"  # Blue for informational message
docker-compose stop

if [ $? -eq 0 ]; then
    echo -e "\033[32mAll containers have been stopped successfully.\033[0m"  # Green for success
else
    echo -e "\033[31mError: Failed to stop the containers. Please check Docker logs for details.\033[0m"  # Red for error
    exit 1
fi
