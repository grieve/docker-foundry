#!/bin/bash

function confirm {
    read -r -p "$1 [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            printf "\n"
            true
            ;;
        *)
            printf "\n"
            false
            ;;
    esac
}

function confirm_flipped {
    read -r -p "$1 [Y/n] " response
    case "$response" in
        [nN][oO]|[nN])
            printf "\n"
            false
            ;;
        *)
            printf "\n"
            true
            ;;
    esac
}

function logo {
    # print in blue
    printf "\e[1;34m"
    printf "\n\
████████▄   ▄██████▄   ▄████████    ▄█   ▄█▄    ▄████████    ▄████████         \n\
███   ▀███ ███    ███ ███    ███   ███ ▄███▀   ███    ███   ███    ███         \n\
███    ███ ███    ███ ███    █▀    ███▐██▀     ███    █▀    ███    ███         \n\
███    ███ ███    ███ ███         ▄█████▀     ▄███▄▄▄      ▄███▄▄▄▄██▀         \n\
███    ███ ███    ███ ███        ▀▀█████▄    ▀▀███▀▀▀     ▀▀███▀▀▀▀▀           \n\
███    ███ ███    ███ ███    █▄    ███▐██▄     ███    █▄  ▀███████████         \n\
███   ▄███ ███    ███ ███    ███   ███ ▀███▄   ███    ███   ███    ███         \n\
████████▀   ▀██████▀  ████████▀    ███   ▀█▀   ██████████   ███    ███         \n\
                                   ▀                        ███    ████        \n"
    printf "\e[0m"
    printf "\e[1;33m"
    printf "\
   ▄████████  ▄██████▄  ███    █▄  ███▄▄▄▄   ████████▄     ▄████████ ▄██   ▄   \n\
  ███    ███ ███    ███ ███    ███ ███▀▀▀██▄ ███   ▀███   ███    ███ ███   ██▄ \n\
  ███    █▀  ███    ███ ███    ███ ███   ███ ███    ███   ███    ███ ███▄▄▄███ \n\
 ▄███▄▄▄     ███    ███ ███    ███ ███   ███ ███    ███  ▄███▄▄▄▄██▀ ▀▀▀▀▀▀███ \n\
▀▀███▀▀▀     ███    ███ ███    ███ ███   ███ ███    ███ ▀▀███▀▀▀▀▀   ▄██   ███ \n\
  ███        ███    ███ ███    ███ ███   ███ ███    ███ ▀███████████ ███   ███ \n\
  ███        ███    ███ ███    ███ ███   ███ ███   ▄███   ███    ███ ███   ███ \n\
  ███         ▀██████▀  ████████▀   ▀█   █▀  ████████▀    ███    ███  ▀█████▀  \n\
                                                          ███    ███           \n"
    printf "\e[0m\n"
}


function clear_screen {
    printf "\033c"
    logo
}

function log {
    printf "\e[0m$1\e[0m\n"
}

function info {
    printf "\e[1;34m$1\e[0m\n"
}

function warning {
    printf "\e[1;33m$1\e[0m\n"
}

function error {
    printf "\e[1;31m$1\e[0m\n"
}

function success {
    printf "\e[1;32m$1\e[0m\n"
}

function intro {
    log "Welcome to the Foundry VTT Docker image builder.\nThis script will walk through all the steps to build a docker image for Foundry VTT and create a compose configuration to get you up and running.\n"
    error "It is dangerous to run scripts from the internet without understanding what they do. Please ensure you trust the source of this script, or read through it before running it.\n"

    if ! confirm_flipped "Do you wish to continue?"; then
        warning "Exiting..."
        exit 1
    fi
}

function verify_docker_installed {
    if ! command -v docker &> /dev/null
    then
        error "Docker could not be found. Please install Docker and try again."
        exit 1
    fi
}

function verify_docker_running {
    if ! docker info &> /dev/null
    then
        error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
}

function check_if_foundry_zip_already_present {
    foundry_zip_file=$(find . -iname "foundryvtt*.zip" -print -quit)
    if [ -z "$foundry_zip_file" ]; then
        return 1
    else
        warning "Foundry VTT zip file ($foundry_zip_file) already present."
        if confirm "Do you wish to download it again?"; then
            rm  "$foundry_zip_file"
            return 1
        fi
        return 0
    fi
}

function get_foundry_zip_url {
    printf "Now we need to get a download URL for the latest version of Foundry VTT.\n"
    printf "To do this please:\n"
    printf "\t1. Go to https://foundryvtt.com/ and sign in.\n"
    printf "\t2. Click your account name in the top right.\n"
    printf "\t3. Click 'Purchased Licenses'.\n"
    printf "\t4. Select Operating System: Node.js.\n"
    printf "\t5. Click 'Timed URL'.\n"
    printf "\n"

    echo "Paste the URL here:"
    read -p "> " -r foundry_url
}

function download_foundry_zip {
    echo "Downloading Foundry VTT..."
    foundry_zip_file=$(echo "$foundry_url" | sed -n 's/.*\/\([Ff][Oo][Uu][Nn][Dd][Rr][Yy][^\/]*\.zip\).*/\1/p')
    curl -# -L "$foundry_url" --output "$foundry_zip_file"
}

function get_image_tags {
    foundry_version=$(echo "$foundry_zip_file" | sed -n 's/^.*-\([0-9]\+\.[0-9]\+\)\.zip/\1/p')
    info "Foundry VTT version: $foundry_version"

    # if we have no version, tag it as latest
    if [ -z "$foundry_version" ]; then
        foundry_version="latest"
    fi
    foundry_image_tag="foundryvtt:${foundry_version}"
}

function write_dockerfile {
    # Write the dockerfile to disk
    cat > Dockerfile << EOF
FROM node:24-alpine

RUN deluser node && \
    mkdir /opt/foundryvtt && \
    adduser --disabled-password foundry -u 1000 && \
    chown -R foundry:foundry /opt/foundryvtt && \
    chmod -R g+s /opt/foundryvtt 

RUN apk add --no-cache libressl-dev

COPY ${foundry_zip_file} /tmp/${foundry_zip_file}
RUN unzip /tmp/${foundry_zip_file} -d /opt/foundry && rm /tmp/${foundry_zip_file}

WORKDIR /opt/foundry

USER foundry

EXPOSE 30000

ENTRYPOINT ["node", "main.js", "--dataPath=/mnt/data", "--port=30000"]
EOF
}

function build_docker_image {
    echo "Building Docker image..."
    docker build -t "$foundry_image_tag" .
    if [ "$foundry_version" != "latest" ]; then
        docker tag "$foundry_image_tag" foundryvtt:latest
    fi
}

function request_data_directory {
    # request the user enters their directory
    # default to $HOME/foundryvtt
    warning "Where would you like to store your Foundry VTT data?"
    error "This is where your worlds, modules, and other data will be stored."
    log "If you are unsure, just press enter to use the default ($HOME/foundryvtt)."
    read -p "> " -r data_directory
    if [ -z "$data_directory" ]; then
        data_directory="$HOME/foundryvtt"
    fi
}

function write_docker_compose_file {
    # check if the file exists
    if [ -f docker-compose.yaml ]; then
        error "docker-compose.yaml already exists."
        if confirm "Do you wish to overwrite it?"; then
            rm docker-compose.yaml
        else
            return 0
        fi
    fi

    log "Creating docker-compose.yaml..."
    cat > docker-compose.yaml << EOF
version: "3.8"
services:
    foundryvtt:
        image: ${foundry_image_tag}
        container_name: foundryvtt
        restart: unless-stopped
        ports:
        - "30000:30000"
        volumes:
        - ${data_directory}:/mnt/data
EOF
    printf "\n---\n"
    cat docker-compose.yaml
    printf "\n---\n"
    success "docker-compose.yaml created successfully."
}

function stop_and_remove_any_running_containers {
    running_container=$(docker ps -a | grep foundryvtt)
    if [ -n "$running_container" ]; then
        error "Foundry VTT container already exists."
        if confirm "Do you wish to stop and remove it?"; then
            docker stop foundryvtt > /dev/null
            docker rm foundryvtt > /dev/null
            running_container=""
        fi
    fi
}

function start_foundry {
    log "We are now ready to start Foundry VTT."
    if confirm_flipped "Do you wish to start Foundry VTT now?"; then
        info "Starting Foundry VTT..."
        docker compose up -d
        sleep 5
        status=$(docker inspect -f {{.State.Status}} foundryvtt)
        if [ "$status" != "running" ]; then
            error "Foundry VTT failed to start."
            docker logs foundryvtt
            exit 1
        fi
        success "Foundry VTT started successfully."
        running_container=$(docker ps -a | grep foundryvtt)
    fi
}

function display_instructions {
    printf "\n"
    if [ -n "$running_container" ]; then
        success "Foundry VTT is currently running.\n"
    else
        error "Foundry VTT is not currently running.\n"
    fi
    log "You can access it at:\n"
    info "\thttp://localhost:30000\n\n"
    log "To stop Foundry VTT, run:\n"
    info "\tdocker compose down\n\n"
    log "To start Foundry VTT again, run:\n"
    info "\tdocker compose up -d\n\n"
}

function cleanup {
    rm -f Dockerfile
    if confirm "Do you wish to remove the Foundry VTT zip file?"; then
        rm "$foundry_zip_file"
    fi
}

# INTRO & PREREQS
clear_screen
intro
verify_docker_installed
verify_docker_running

# FOUNDRY DOWNLOAD
clear_screen
if ! check_if_foundry_zip_already_present; then
    get_foundry_zip_url
    download_foundry_zip
fi
get_image_tags
info "Ready to build Docker image: $foundry_image_tag"
sleep 5

# BUILD DOCKER IMAGE
clear_screen
write_dockerfile
build_docker_image
success "Docker image built successfully."
sleep 5

# CREATE COMPOSE FILE
clear_screen
request_data_directory
info "Using data directory: $data_directory"
mkdir -p "$data_directory"
write_docker_compose_file
sleep 5

# START UP
clear_screen
stop_and_remove_any_running_containers
if [ -z "$running_container" ]; then
    start_foundry
fi
sleep 5

# CLEANUP & OUTRO
clear_screen
display_instructions
cleanup
