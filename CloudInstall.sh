#!/bin/bash

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


Do you wish to continue? (y/n)"

read user_choice

if [ "$user_choice" != "${user_choice#[Yy]}" ] ;then
    echo "Continuing with the script..."
else
    echo "Exiting without making any changes."
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
            echo "Homebrew is not installed. Attempting to install..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        else
            echo "Homebrew is already installed."
        fi
        ;;
    'msys' | 'cygwin' | 'win32')
        # Check if Chocolatey is installed, if not install it.
        if ! command -v choco &> /dev/null
        then
            echo "Chocolatey is not installed. Attempting to install..."
            /bin/bash -c "$(curl -fsSL https://chocolatey.org/install.ps1)"
        else
            echo "Chocolatey is already installed."
        fi
        ;;
esac

# Check if Docker is installed
if ! command -v docker &> /dev/null
then
    echo "Docker is not installed. Attempting to install..."
    
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
            echo "Unsupported operating system. Please install Docker manually."
            exit 1
            ;;
    esac

    echo "Docker installation complete."
else
    echo "Docker is already installed."
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null
then
    echo "Docker Compose is not installed. Attempting to install..."

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
            echo "Unsupported operating system. Please install Docker Compose manually."
            exit 1
            ;;
    esac

    echo "Docker Compose installation complete."
else
    echo "Docker Compose is already installed."
fi

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
