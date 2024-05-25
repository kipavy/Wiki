#!/usr/bin/env bash

echo "Welcome ! Set up your remote for source files (WebDav ...)"
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