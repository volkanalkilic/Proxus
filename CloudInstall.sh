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

echo "This script is designed to install the Proxus IIoT Platform. 
It will perform the following operations:

1. Identify the operating system.
2. Check if the necessary package managers (Homebrew for MacOS, Chocolatey for Windows) are installed. If not, it will attempt to install them.
3. Check if Docker and Docker Compose are installed. If not, it will attempt to install them.
4. Create Proxus Docker Compose file.
5. Start Docker Compose setup.


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

# Prompt user for password options
echo -e "${YELLOW}Password Options:${NC}"
echo -e "1. Enter passwords manually"
echo -e "2. Generate random passwords"
echo -e "3. Use default passwords"

read -r password_option

case $password_option in
    1) RANDOM_PASSWORD_OPTION='N';;
    2) RANDOM_PASSWORD_OPTION='Y';;
    3) RANDOM_PASSWORD_OPTION='N';;
    *) echo -e "${RED}Invalid option. Exiting.${NC}"; exit 1;;
esac

# Prompt user for configuration variables
POSTGRES_USER=$(prompt_or_generate_password "Please enter the POSTGRES_USER" "proxus" "$RANDOM_PASSWORD_OPTION")
POSTGRES_PASSWORD=$(prompt_or_generate_password "Please enter the POSTGRES_PASSWORD" "proxus" "$RANDOM_PASSWORD_OPTION")
ASPNETCORE_ENVIRONMENT=$(prompt_or_generate_password "Please enter the ASPNETCORE_ENVIRONMENT" "Development" "$RANDOM_PASSWORD_OPTION")
REDIS_PASSWORD=$(prompt_or_generate_password "Please enter the REDIS_PASSWORD" "proxus" "$RANDOM_PASSWORD_OPTION")


# Function to install Docker on Windows
install_docker_windows() {
    # Generate PowerShell script
    cat > install_docker.ps1 <<EOF
# Check if running as administrator
\$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-NOT \$IsAdmin) {
    Write-Output "Please run this script as an Administrator!"
    exit 1
}

# Check if Docker is installed
if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
    # Install Chocolatey if not already installed
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }

    # Install Docker
    choco install docker-engine -y
    choco install docker-compose -y
} else {
    Write-Output "Docker is already installed."
}
EOF

    # Run the PowerShell script
    powershell -ExecutionPolicy Bypass -File ./install_docker.ps1
}

# Determine the operating system
OS="$(uname)"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Attempting to install..."
    # Install Docker
    case "$OS" in
        "Linux")
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io
            ;;
        "Darwin")
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
            brew cask install docker
            ;;
        "MINGW"*|"CYGWIN"*|"MSYS"*)
            install_docker_windows
            ;;
        *)
            echo "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
else
    echo "Docker is already installed."
fi

# Create docker-compose.yml file
cat <<EOF >docker-compose.yml
version: '3.8'
name: proxus
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
      - POSTGRES_DB=Proxus
      - POSTGRES_USER=POSTGRES_USER
      - POSTGRES_PASSWORD=POSTGRES_PASSWORD
  
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
    command: [ "./Proxus.Blazor.Server",
         "--GatewayID=1",  
         "--GrpcInterfaceBinding=Localhost", 
         "RedisConnection=redis:6379, password=$REDIS_PASSWORD", 
         "ClusterProvider=Redis",
         "ConnectionString=Server=localhost;Port=5442;User ID=$POSTGRES_USER;Password=$POSTGRES_PASSWORD;Database=Proxus;"]
  
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
    volumes:
      - type: volume
        source: config
        target: /app/config
        read_only: false
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - CONSUL_HTTP_ADDR=consul:8500
      - AdvertisedHost=proxus-server
    command: [ "./Proxus.Server", 
         "--GatewayID=1",  
         "--GrpcInterfaceBinding=Localhost", 
         "RedisConnection=redis:6379, password=$REDIS_PASSWORD", 
         "ClusterProvider=Redis",
         "ConnectionString=Server=localhost;Port=5442;User ID=$POSTGRES_USER;Password=$POSTGRES_PASSWORD;Database=Proxus;"]
  
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
    command: [ "./Proxus.WebApi",
             "ConnectionString=Server=localhost;Port=5442;User ID=$POSTGRES_USER;Password=$POSTGRES_PASSWORD;Database=Proxus;"]
      
networks:
  proxus:
    driver: bridge

volumes:
  proxus-db-volume:
  config:

EOF

# Run Docker Compose
docker compose up -d

# Get machine's IP address
IP_ADDRESS="localhost"

# Open browser
case $(uname | tr '[:upper:]' '[:lower:]') in
    'darwin') open "http://$IP_ADDRESS:8080" ;;
    'linux') xdg-open "http://$IP_ADDRESS:8080" ;;
    'msys' | 'cygwin' | 'win32') start "http://$IP_ADDRESS:8080" ;;
    *) echo "Unsupported operating system. Please manually open the following URL in your browser: http://$IP_ADDRESS:8080" ;;
esac

# Save passwords to a text file
PASSWORDS_FILE="$(pwd)/passwords.txt"
echo "POSTGRES_USER: $POSTGRES_USER" >"$PASSWORDS_FILE"
echo "POSTGRES_PASSWORD: $POSTGRES_PASSWORD" >>"$PASSWORDS_FILE"
echo "ASPNETCORE_ENVIRONMENT: $ASPNETCORE_ENVIRONMENT" >>"$PASSWORDS_FILE"
echo "REDIS_PASSWORD: $REDIS_PASSWORD" >>"$PASSWORDS_FILE"

echo -e "${GREEN}Done! You should now see your application running in your default browser.${NC}"
echo "Password details have been saved to: $PASSWORDS_FILE"
