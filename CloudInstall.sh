#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "
██████╗ ██████╗  ██████╗ ██╗  ██╗██╗   ██╗███████╗
██╔══██╗██╔══██╗██╔═══██╗╚██╗██╔╝██║   ██║██╔════╝
██████╔╝██████╔╝██║   ██║ ╚███╔╝ ██║   ██║███████╗
██╔═══╝ ██╔══██╗██║   ██║ ██╔██╗ ██║   ██║╚════██║
██║     ██║  ██║╚██████╔╝██╔╝ ██╗╚██████╔╝███████║
╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
                                                  
"

echo "This script is designed for Proxus IIoT Platform. 
It will perform the following operations:

1. Identify the operating system.
2. Check if the necessary package managers (Homebrew for MacOS, Chocolatey for Windows) are installed. If not, it will attempt to install them.
3. Check if Docker and Docker Compose are installed. If not, it will attempt to install them.
4. Create a basic Docker Compose file.
5. Start Docker Compose setup.

WARNING: This script will make changes to your system in order to install the necessary software. 
Please ensure you have a backup of your data before proceeding.

Do you wish to continue? (y/n)"

read -r user_choice

if [[ $user_choice =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Continuing with the script...${NC}"
else
    echo -e "${RED}Exiting without making any changes.${NC}"
    exit 0
fi

# Function to generate a random password
generate_random_password() {
    local length=$1
    LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w "$length" | head -n 1
}

# Function to prompt for password or generate randomly
prompt_or_generate_password() {
    local prompt=$1
    local default=$2
    local random=$3
    local password

    if [[ $random =~ ^[Yy]$ ]]; then
        password=$(generate_random_password 16)
    else
        read -p "$prompt (default: $default): " password
        password=${password:-$default}
    fi

    echo "$password"
}

# Prompt user for configuration variables
POSTGRES_USER=$(prompt_or_generate_password "Please enter the POSTGRES_USER" "proxus" "$RANDOM_PASSWORD_OPTION")
POSTGRES_PASSWORD=$(prompt_or_generate_password "Please enter the POSTGRES_PASSWORD" "proxus" "$RANDOM_PASSWORD_OPTION")
ASPNETCORE_ENVIRONMENT=$(prompt_or_generate_password "Please enter the ASPNETCORE_ENVIRONMENT" "Development" "$RANDOM_PASSWORD_OPTION")
REDIS_PASSWORD=$(prompt_or_generate_password "Please enter the REDIS_PASSWORD" "proxus" "$RANDOM_PASSWORD_OPTION")

# Create docker-compose.yml file
cat <<EOF >docker-compose.yml
version: '3.8'
services:

  redis:
    image: 'bitnami/redis:latest'
    container_name: redis
    restart: always
    ports:
      - "6379:6379"
    environment:
      - REDIS_PASSWORD=$REDIS_PASSWORD
      - ALLOW_EMPTY_PASSWORD=no
    networks:
      - proxus
  
  timescaledb:
    restart: always
    container_name: timescaledb
    image: timescale/timescaledb:latest-pg14
    command: postgres -c shared_preload_libraries=timescaledb -p 5442
    volumes:
      - type: volume
        source: proxus-db-volume
        target: /var/lib/postgresql/data
        read_only: false
    networks:
      - proxus
    ports:
      - "5442:5442"
    environment:
      # - PGDATA=/var/lib/postgresql/data/timescaledb
      - POSTGRES_DB=proxus
      - POSTGRES_USER=proxus
      - POSTGRES_PASSWORD=proxus
  
  proxus-ui:
    restart: always
    depends_on:
      - redis
      - proxus-server
    container_name: proxus-ui
    image: proxusplatform/proxus-ui:latest
    labels:
      kompose.serviceaccount-name: "Proxus"
    networks:
      - proxus
    ports:
      - "8080:8080"
    volumes:
      - type: volume
        source: config
        target: /app/config
        read_only: false
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ASPNETCORE_URLS=http://+:8080
      # - ASPNETCORE_HTTPS_PORT=443
      - CONSUL_HTTP_ADDR=consul:8500
      - AdvertisedHost=proxus-ui
    command: [ "./Proxus.Blazor.Server",  "--GatewayID=1",  "--GrpcInterfaceBinding=Localhost", "RedisConnection=redis:6379", "ClusterProvider=Redis"]
  
  proxus-server:
    restart: always
    depends_on:
      - redis
    container_name: proxus-server
    image: proxusplatform/proxus-server:latest
    user: "0"
    networks:
      - proxus
    ports:
      - "1883:1883"
    labels:
      kompose.serviceaccount-name: "Proxus"
    volumes:
      - type: volume
        source: config
        target: /app/config
        read_only: false
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - CONSUL_HTTP_ADDR=consul:8500
      - AdvertisedHost=proxus-server
    command: [ "./Proxus.Server", "--GatewayID=1",  "--GrpcInterfaceBinding=Localhost", "RedisConnection=redis:6379",  "ClusterProvider=Redis"]
  
  proxus-api:
    restart: always
    container_name: proxus-api
    image: proxusplatform/proxus-api:latest
    networks:
      - proxus
    ports:
      - "8082:8082"
    volumes:
      - type: volume
        source: config
        target: /app/config
        read_only: false
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ASPNETCORE_URLS=http://+:8081
networks:
  proxus:
    driver: bridge

volumes:
  proxus-db-volume:
  config:

EOF

# Run Docker Compose
docker-compose up -d

# Get machine's IP address
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Open browser
case $(uname | tr '[:upper:]' '[:lower:]') in
    'darwin') open "http://$IP_ADDRESS:8080" ;;
    'linux') xdg-open "http://$IP_ADDRESS:8080" ;;
    'msys' | 'cygwin' | 'win32') start "http://$IP_ADDRESS:8080" ;;
    *) echo "Unsupported operating system. Please manually open the following URL in your browser: http://$IP_ADDRESS:8080" ;;
esac

# Save passwords to a text file
echo "POSTGRES_USER: $POSTGRES_USER" >passwords.txt
echo "POSTGRES_PASSWORD: $POSTGRES_PASSWORD" >>passwords.txt
echo "ASPNETCORE_ENVIRONMENT: $ASPNETCORE_ENVIRONMENT" >>passwords.txt
echo "REDIS_PASSWORD: $REDIS_PASSWORD" >>passwords.txt

echo -e "${GREEN}Done! You should now see your application running in your default browser.${NC}"
echo "Password details have been saved to passwords.txt file."
echo "Please check the passwords.txt file for the generated passwords."

