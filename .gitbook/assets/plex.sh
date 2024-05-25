#!/usr/bin/env bash
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# TODO : Use systemd to manage auto start of the rclone mount (no more need service for udpate as watchtower is used)

update_and_install_dependencies() {
    echo -e "${GREEN}\nUpdating system and installing dependencies (rclone, curl, whiptail)...\n${NC}"
    sudo apt update
    sudo apt full-upgrade -y
    sudo apt install -y curl rclone whiptail
    sudo apt autoremove
    sudo apt clean
}

check_docker_installation() {
    if ! command -v docker > /dev/null; then
        # echo "Docker is not installed. Installing Docker ..."
        # sudo usermod -aG docker $USER
        # curl -fsSL https://get.docker.com | sh
        echo "Docker is not installed. Please install Docker and run the script again."
    fi
    if ! command -v docker compose > /dev/null; then
        echo "Docker Compose is not installed. Please install Docker Compose and run the script again. See https://docs.docker.com/engine/install/"
    fi
}

configure_and_mount_rclone() {
    echo -e "${BLUE}\nPlease set up your "plex" remote for source files, when done just quit config with q\n${NC}"
    echo -e "${RED}Name your remote: plex otherwise the script will fail${NC}"
    rclone config
    echo -e "${GREEN}\nMounting rclone remote to /home/plex/data/rclone ...\n${NC}"
    if rclone listremotes > /dev/null 2>&1; then
        rclone mount plex:links /home/plex/data/rclone --dir-cache-time 10s --allow-other
    else
        echo "rclone configuration failed or no remotes configured. Exiting."
        exit 1
    fi
}

display_and_process_checklist() {
    # Define the checkable options
    CHECKABLE_OPTIONS=(
        "Watchtower" "Auto update containers" ON
        "Plex Debrid" "Used to treat users requests" ON
        "Jackett" "Scrapper" ON
        "Flaresolverr" "May be used by Jackett to Bypass Captcha" ON
        "Overseerr" "Provides cool Web UI for user requests" OFF
        "Tautulli" "Management Dashboard for Plex" OFF
    )

    # Show the checklist dialog for checkable options
    CHOICES=$(whiptail --title "Select Options" --checklist \
    "Choose options using space and navigate with arrow keys" 15 65 5 \
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
            "\"Watchtower\"")
                echo "Option 1 selected: Watchtower"
                SELECTED_OPTIONS+=( "watchtower" )
                ;;
            "\"Plex Debrid\"")
                echo "Option 2 selected: Plex Debrid"
                SELECTED_OPTIONS+=( "plex_debrid" )
                ;;
            "\"Jackett\"")
                echo "Option 3 selected: Jackett"
                SELECTED_OPTIONS+=( "jackett" )
                ;;
            "\"Flaresolverr\"")
                echo "Option 4 selected: Flaresolverr"
                SELECTED_OPTIONS+=( "flaresolverr" )
                ;;
            "\"Overseerr\"")
                echo "Option 5 selected: Overseerr"
                SELECTED_OPTIONS+=( "overseerr" )
                ;;
            "\"Tautulli\"")
                echo "Option 6 selected: Tautulli"
                SELECTED_OPTIONS+=( "tautulli" )
                ;;
        esac
    done

    echo "You have selected the options: ${SELECTED_OPTIONS[*]}. Proceeding with the next steps."
}

construct_and_execute_docker_compose() {
    # Construct the docker-compose command based on the selected options
    DOCKER_COMPOSE_COMMAND="curl -L https://raw.githubusercontent.com/Crackvignoule/Wiki/main/.gitbook/assets/docker-compose.yml -o - | docker compose -f - up -d"
    for OPTION in "${SELECTED_OPTIONS[@]}"; do
        DOCKER_COMPOSE_COMMAND+=" $OPTION"
    done

    # Execute the docker-compose command
    eval "$DOCKER_COMPOSE_COMMAND"

    echo "Everything placed under /home/plex/"
    exit 0
}


echo "Welcome to the Plex setup script !"
echo "This script will install the latest version of Plex Media Server and other services."

check_docker_installation
update_and_install_dependencies
configure_and_mount_rclone
display_and_process_checklist
construct_and_execute_docker_compose