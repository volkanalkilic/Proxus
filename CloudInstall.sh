#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}
██████╗ ██████╗  ██████╗ ██╗  ██╗██╗   ██╗███████╗
██╔══██╗██╔══██╗██╔═══██╗╚██╗██╔╝██║   ██║██╔════╝
██████╔╝██████╔╝██║   ██║ ╚███╔╝ ██║   ██║███████╗
██╔═══╝ ██╔══██╗██║   ██║ ██╔██╗ ██║   ██║╚════██║
██║     ██║  ██║╚██████╔╝██╔╝ ██╗╚██████╔╝███████║
╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
                                                  
${NC}
"

echo -e "${YELLOW}This script is designed for Proxus IIoT Platform. 
It will perform the following operations:

1. Identify the operating system.
2. Check if the necessary package managers (Homebrew for MacOS, Chocolatey for Windows) are installed. If not, it will attempt to install them.
3. Check if Docker and Docker Compose are installed. If not, it will attempt to install them.
4. Create a basic Docker Compose file.
5. Start Docker Compose setup.

WARNING: This script will make changes to your system in order to install the necessary software. 
Please ensure you have a backup of your data before proceeding.

Do you wish to continue? (y/n)${NC}"

read user_choice

if [ "$user_choice" != "${user_choice#[Yy]}" ] ;then
    echo -e "${GREEN}Continuing with the script...${NC}"
else
    echo -e "${RED}Exiting without making any changes.${NC}"
    exit 0
fi

# Identify the OS
OS=$(uname|tr '[:upper:]' '[:lower:]')

# Install package manager based on the OS type
case $OS in
    'darwin')
        # Check if Homebrew is installed, if not install it.
        if ! command -v brew &> /dev/null
        then
            echo -e "${YELLOW}Homebrew is not installed. Attempting to install...${NC}"
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        else
            echo -e "${GREEN}Homebrew is already installed.${NC}"
        fi
        ;;
    'msys' | 'cygwin' | 'win32')
        # Check if Chocolatey is installed, if not install it.
        if ! command -v choco &> /dev/null
        then
            echo -e "${YELLOW}Chocolatey is not installed. Attempting to install...${NC}"
            /bin/bash -c "$(curl -fsSL https://chocolatey.org/install.ps1)"
        else
            echo -e "${GREEN}Chocolatey is already installed.${NC}"
        fi
        ;;
esac

# Progress bar
echo -ne "${GREEN}###                               (15%)\r${NC}"
sleep 1

# Check if Docker is installed
if ! command -v docker &> /dev/null
then
    echo -e "${YELLOW}Docker is not installed. Attempting to install...${NC}"
    
    # Docker installation based on the OS type
    case $OS in
        'linux')
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            ;;
        'darwin')
            brew install --cask docker
            ;;
        'msys' | 'cygwin' | 'win32')
            choco install docker-desktop
            ;;
        *)
            echo -e "${RED}Unsupported operating system. Please install Docker manually.${NC}"
            exit 1
            ;;
    esac

    echo -e "${GREEN}Docker installation complete.${NC}"
else
    echo -e "${GREEN}Docker is already installed.${NC}"
fi

# Progress bar
echo -ne "${GREEN}#####                             (33%)\r${NC}"
sleep 1

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null
then
    echo -e "${YELLOW}Docker Compose is not installed. Attempting to install...${NC}"

    case $OS in
        'linux')
            sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
            ;;
        'darwin')
            brew install docker-compose
            ;;
        'msys' | 'cygwin' | 'win32')
            choco install docker-compose
            ;;
        *)
            echo -e "${RED}Unsupported operating system. Please install Docker Compose manually.${NC}"
            exit 1
            ;;
    esac

    echo -e "${GREEN}Docker Compose installation complete.${NC}"
else
    echo -e "${GREEN}Docker Compose is already installed.${NC}"
fi

# Progress bar
echo -ne "${GREEN}#############                     (66%)\r${NC}"
sleep 1

# Create a basic docker-compose.yml file
cat << EOF > docker-compose.yml
version: '3'
services:
  proxus:
    image: your-image
    ports:
      - '8080:8080'
EOF

# Run Docker Compose
docker-compose up -d

# Progress bar
echo -ne "${GREEN}#######################           (100%)\r${NC}"
echo -ne '\n'
