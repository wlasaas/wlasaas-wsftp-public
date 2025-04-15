#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${GREEN}[+] $1${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}[!] $1${NC}"
}

# Function to check if command was successful
check_status() {
    if [ $? -eq 0 ]; then
        print_status "$1"
    else
        print_error "$2"
        exit 1
    fi
}

# Check if script is running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root (use sudo)"
    exit 1
fi

# 1. System Update and Dependencies
print_status "Updating system packages..."
dnf update -y
check_status "System updated successfully" "Failed to update system"

print_status "Installing basic dependencies..."
dnf install -y yum-utils device-mapper-persistent-data lvm2 curl
check_status "Dependencies installed successfully" "Failed to install dependencies"

# 2. Docker Installation
print_status "Installing Docker..."
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf install -y docker-ce docker-ce-cli containerd.io
systemctl enable --now docker
check_status "Docker installed and started successfully" "Failed to install Docker"

# 3. Docker Compose Installation
print_status "Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
check_status "Docker Compose installed successfully" "Failed to install Docker Compose"

# 4. Git Installation
print_status "Installing Git..."
dnf install -y git
check_status "Git installed successfully" "Failed to install Git"

# 5. AWS CLI Installation
print_status "Installing AWS CLI..."
dnf install -y awscli
check_status "AWS CLI installed successfully" "Failed to install AWS CLI"

# 6. AWS Configuration
print_status "Configuring AWS CLI..."
echo -e "${YELLOW}Please enter your AWS credentials:${NC}"
read -p "AWS Access Key ID: " aws_access_key
read -p "AWS Secret Access Key: " aws_secret_key

# Configure AWS CLI
aws configure set aws_access_key_id "$aws_access_key"
aws configure set aws_secret_access_key "$aws_secret_key"
aws configure set region "sa-east-1"
aws configure set output "json"
check_status "AWS CLI configured successfully" "Failed to configure AWS CLI"

# 7. ECR Login and Image Pull
print_status "Logging into AWS ECR and pulling image..."
aws ecr get-login-password --region sa-east-1 | docker login --username AWS --password-stdin 091448068257.dkr.ecr.sa-east-1.amazonaws.com
docker pull 091448068257.dkr.ecr.sa-east-1.amazonaws.com/wlasaas/wsftp:latest
docker tag 091448068257.dkr.ecr.sa-east-1.amazonaws.com/wlasaas/wsftp:latest wlasaas/wsftp-wla:latest
check_status "Docker image pulled and tagged successfully" "Failed to pull Docker image"

# 8. Clone WSFTP Repository
print_status "Cloning WSFTP repository..."
git clone https://github.com/wlasaas/wlasaas-wsftp-public.git wlasaas-wsftp
cd wlasaas-wsftp
check_status "Repository cloned successfully" "Failed to clone repository"

# 9. Fix Permissions and Start Service
print_status "Setting up permissions and starting service..."
mkdir -p docker/db
touch -p docker/data
chmod -R 777 docker
docker-compose up -d
check_status "Service started successfully" "Failed to start service"

# Final Instructions
echo -e "\n${GREEN}=== Installation Complete ===${NC}"
echo -e "${YELLOW}You can now access:${NC}"
echo -e "- Web Panel: http://YOUR_SERVER_IP:PORT"
echo -e "- SFTP: sftp://YOUR_SERVER_IP:PORT"
echo -e "\n${YELLOW}Don't forget to:${NC}"
echo -e "2. Configure your firewall rules"
echo -e "3. Check the service status using 'docker-compose ps'" 