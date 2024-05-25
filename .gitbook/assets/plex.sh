#!/usr/bin/env bash
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "Welcome to the Plex setup script !"
echo "This script will install the latest version of Plex Media Server and other services."

# Verify if docker and docker compose (not docker-compose) are installed, if not install them
if ! command -v docker > /dev/null; then
    # echo "Docker is not installed. Installing Docker ..."
    # sudo usermod -aG docker $USER
    # curl -fsSL https://get.docker.com | sh
    echo "Docker is not installed. Please install Docker and run the script again."
fi
if ! command -v docker compose > /dev/null; then
    echo "Docker Compose is not installed. Installing Docker Compose ..."
    echo "Please install Docker Compose and run the script again."
fi

echo -e "${GREEN}\nUpdating system and installing dependencies (rclone, curl, whiptail)...\n${NC}"
sudo apt update
sudo apt full-upgrade -y
sudo apt install -y curl rclone whiptail
sudo apt autoremove
sudo apt clean

echo -e "${BLUE}\nPlease set up your remote for source files (WebDav ...)\n${NC}"
rclone config

# Check if rclone configuration was successful
if rclone listremotes > /dev/null 2>&1; then

    # Mount the remote
    rclone mount my-remote:links /home/plex/data/rclone --dir-cache-time 10s --allow-other

    # Define the checkable options
    CHECKABLE_OPTIONS=(
        "Plex Debrid" "Description for Plex Debrid" OFF
        "Jackett" "Description for Jackett" OFF
        "Flaresolverr" "Description for Flaresolverr" OFF
        "Overseerr" "Description for Overseerr" OFF
        "Tautulli" "Description for Tautulli" OFF
    )

    # Show the checklist dialog for checkable options
    CHOICES=$(whiptail --title "Select Options" --checklist \
    "Choose options using space and navigate with arrow keys" 15 50 5 \
    "${CHECKABLE_OPTIONS[@]}" 3>&1 1>&2 2>&3)

    # Check exit status
    if [ $? -ne 0 ]; then
        echo "User canceled."
        exit 1
    fi

    # Initialize an array to store the selected options
    SELECTED_OPTIONS=()

    # Process the selected checkable options
    for CHOICE in $CHOICES; do
        case $CHOICE in
            "\"Plex Debrid\"")
                echo "Option 1 selected: Plex Debrid"
                SELECTED_OPTIONS+=( "plex_debrid" )
                ;;
            "\"Jackett\"")
                echo "Option 2 selected: Jackett"
                SELECTED_OPTIONS+=( "jackett" )
                ;;
            "\"Flaresolverr\"")
                echo "Option 3 selected: Flaresolverr"
                SELECTED_OPTIONS+=( "flaresolverr" )
                ;;
            "\"Overseerr\"")
                echo "Option 4 selected: Overseerr"
                SELECTED_OPTIONS+=( "overseerr" )
                ;;
            "\"Tautulli\"")
                echo "Option 5 selected: Tautulli"
                SELECTED_OPTIONS+=( "tautulli" )
                ;;
        esac
    done

    # Continue with additional commands
    echo "You have selected the options: ${SELECTED_OPTIONS[*]}. Proceeding with the next steps."

    # Construct the docker-compose command based on the selected options
    DOCKER_COMPOSE_COMMAND="curl -L https://raw.githubusercontent.com/Crackvignoule/Wiki/main/.gitbook/assets/docker-compose.yml -o - | docker compose -f - up -d"
    for OPTION in "${SELECTED_OPTIONS[@]}"; do
        DOCKER_COMPOSE_COMMAND+=" $OPTION"
    done

    # Execute the docker-compose command
    eval "$DOCKER_COMPOSE_COMMAND"

    echo "Everything placed under /home/plex/"
    exit 0

else
    echo "rclone configuration failed or no remotes configured. Exiting."
    exit 1
fi