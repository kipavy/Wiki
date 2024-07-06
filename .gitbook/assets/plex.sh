#!/usr/bin/env bash
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# TODO : real testing
# TODO : Warn about port forwarding
# TODO : Add more choices and robustness (for example, ask if user wants to run docker install script, unlock plex pass features for free...)

update_and_install_dependencies() {
    echo -e "${GREEN}\nUpdating system and installing dependencies (rclone, curl, whiptail)...\n${NC}"
    sudo apt update
    sudo apt full-upgrade -y
    sudo apt install -y curl rclone whiptail python3-venv
    sudo apt autoremove
    sudo apt clean
}

check_docker_installation() {
    if ! command -v docker > /dev/null; then
        # echo "Docker is not installed. Installing Docker ..."
        # sudo usermod -aG docker $USER
        # curl -fsSL https://get.docker.com | sh
        echo "Docker is not installed. Please install Docker and run the script again. See https://docs.docker.com/engine/install/"
        exit 1
    fi
    if ! command -v docker compose > /dev/null; then
        echo "Docker Compose is not installed. Please install Docker Compose and run the script again. See https://docs.docker.com/engine/install/"
        exit 1
    fi
}

configure_and_mount_rclone() {
    echo -e "${BLUE}\nPlease set up your \"plex\" remote for source files. When done, just quit config with q.\n${NC}"
    echo -e "${RED}Name your remote: plex, otherwise the script will fail.${NC}"

    while true; do
        rclone config
        echo -e "${GREEN}\nChecking if \"plex\" remote is configured...\n${NC}"
        if rclone listremotes | grep -q "^plex:"; then
            echo -e "${GREEN}\n\"plex\" remote is configured successfully.\n${NC}"
            break
        else
            echo -e "${RED}\n\"plex\" remote is not configured. Please try again.\n${NC}"
        fi
    done

    echo -e "${GREEN}\nMounting rclone remote to /home/plex/plexmediaserver/data/rclone ...\n${NC}"
    mkdir -p /home/plex/plexmediaserver/data/rclone
    rclone mount plex:links /home/plex/plexmediaserver/data/rclone --dir-cache-time 10s --allow-other &

    # Ask user if they want to create the systemd service
    if whiptail --title "Create Systemd Service" --yesno "Do you want to create a systemd service to mount the plex remote at boot?" 10 60; then
        echo -e "${GREEN}\nCreating systemd service for rclone mount...\n${NC}"
        # Create the systemd service file
        cat <<EOF | sudo tee /etc/systemd/system/plex_rclone.service >/dev/null
[Unit]
Description=RClone Mount Service for Plex
After=network-online.target

[Service]
Type=simple
ExecStart=rclone mount plex:links /home/plex/plexmediaserver/data/rclone --dir-cache-time 10s --allow-other
Restart=always

[Install]
WantedBy=default.target
EOF

        # Reload systemd to pick up the new service file
        sudo systemctl daemon-reload

        # Enable and start the service
        sudo systemctl enable --now plex_rclone.service

        echo -e "${GREEN}\nRClone mount systemd service 'plex_rclone' created and started successfully.\n${NC}"
    else
        echo -e "${RED}\nSkipping creation of systemd service for rclone mount.\n${NC}"
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
        "Debrid Client Proxy" "Web UI Alldebrid Proxy" OFF
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
    eval "CHOICES=($CHOICES)"
    for CHOICE in "${CHOICES[@]}"; do
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
            "\"Debrid Client Proxy\"")
                echo "Option 7 selected: Debrid Client Proxy"
                SELECTED_OPTIONS+=( "debridclientproxy" )
                ;;
        esac
    done

    echo "You have selected the options: ${SELECTED_OPTIONS[*]}. Proceeding with the next steps."
}

construct_and_execute_docker_compose() {
    # Construct the docker-compose command based on the selected options
    DOCKER_COMPOSE_COMMAND="curl -L https://raw.githubusercontent.com/Crackvignoule/Wiki/main/.gitbook/assets/docker-compose.yml -o - | docker compose -f - up -d plex"
    for OPTION in "${SELECTED_OPTIONS[@]}"; do
        DOCKER_COMPOSE_COMMAND+=" $OPTION"
    done

    # Execute the docker-compose command
    eval "$DOCKER_COMPOSE_COMMAND"
}

unlock_plex_pass_free() {
    echo -e "${GREEN}\nUnlocking Plex Pass features for free (you're saving 100$)...\n${NC}"
    # I couldnt use apt install because some patchelf versions are too recent for glib used in plex docker
    # Installing patchelf in temp venv
    python3 -m venv /tmp/pythonplex
    source /tmp/pythonplex/bin/activate
    pip install patchelf
    PATCH_ELF_PATH=$(which patchelf)
    sudo sh -c "PATH=$PATCH_ELF_PATH:$PATH; $(curl -sSL https://gitgud.io/yuv420p10le/plexmediaserver_crack/-/raw/master/scripts/crack_docker.sh)"
    deactivate
    rm -rf /tmp/pythonplex
}

finish_config() {
    echo "Everything placed under /home/plex/"
    if [[ " ${SELECTED_OPTIONS[*]} " == *"plex_debrid"* ]]; then
        echo -e "${BLUE}\nAlmost done, Entering plex_debrid configuration...\n${NC}"
        docker attach plex_debrid
    fi
    echo -e "${GREEN}\nLast step, Open Plex Web UI to start configuration by opening http://localhost:32400/web or http://<ipaddress>:32400/web \n${NC}"
    exit 0
}


echo "Welcome to the Plex setup script !"
echo "This script has been made for Debian/Ubuntu/etc. It will install the latest version of Plex Media Server and other services."

check_docker_installation
update_and_install_dependencies
# configure_and_mount_rclone
display_and_process_checklist
construct_and_execute_docker_compose
unlock_plex_pass_free
finish_config