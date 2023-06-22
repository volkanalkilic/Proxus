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

read user_choice

if [ "$user_choice" != "${user_choice#[Yy]}" ]; then
  echo -e "${GREEN}Continuing with the script...${NC}"
else
  echo -e "${RED}Exiting without making any changes.${NC}"
  exit 0
fi

# Prompt user for configuration variables with default values
read -p "Please enter the POSTGRES_USER (default: proxus): " POSTGRES_USER
POSTGRES_USER=${POSTGRES_USER:-proxus}

read -p "Please enter the POSTGRES_PASSWORD (default: proxus): " POSTGRES_PASSWORD
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-proxus}

read -p "Please enter the ASPNETCORE_ENVIRONMENT (Development, Staging, Production, default: Development): " ASPNETCORE_ENVIRONMENT
ASPNETCORE_ENVIRONMENT=${ASPNETCORE_ENVIRONMENT:-Development}

# Identify the OS
OS=$(uname | tr '[:upper:]' '[:lower:]')

# Install package manager based on the OS type
case $OS in
'darwin')
  # Check if Homebrew is installed, if not install it.
  if ! command -v brew &>/dev/null; then
    echo -e "${YELLOW}Homebrew is not installed. Attempting to install...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    echo -e "${GREEN}Homebrew is already installed.${NC}"
  fi
  ;;
'msys' | 'cygwin' | 'win32')
  # Check if Chocolatey is installed, if not install it.
  if ! command -v choco &>/dev/null; then
    echo -e "${YELLOW}Chocolatey is not installed. Attempting to install...${NC}"
    /bin/bash -c "$(curl -fsSL https://chocolatey.org/install.ps1)"
  else
    echo -e "${GREEN}Chocolatey is already installed.${NC}"
  fi
  ;;
esac

# Install Docker and Docker Compose if not already installed
if ! command -v docker &>/dev/null; then
  echo -e "${YELLOW}Docker is not installed. Attempting to install...${NC}"
  case $OS in
  'darwin') brew install docker ;;
  'msys' | 'cygwin' | 'win32') choco install docker ;;
  esac
else
  echo -e "${GREEN}Docker is already installed.${NC}"
fi

if ! command -v docker-compose &>/dev/null; then
  echo -e "${YELLOW}Docker Compose is not installed. Attempting to install...${NC}"
  case $OS in
  'darwin') brew install docker-compose ;;
  'msys' | 'cygwin' | 'win32') choco install docker-compose ;;
  esac
else
  echo -e "${GREEN}Docker Compose is already installed.${NC}"
fi

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
      - ALLOW_EMPTY_PASSWORD=yes
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
case $OS in
'darwin') open "http://$IP_ADDRESS:8080" ;;
'linux') xdg-open "http://$IP_ADDRESS:8080" ;;
'msys' | 'cygwin' | 'win32') start "http://$IP_ADDRESS:8080" ;;
*) echo "Unsupported operating system. Please manually open the following URL in your browser: http://$IP_ADDRESS:8080" ;;
esac

echo -e "${GREEN}Done! You should now see your application running in your default browser.${NC}"
