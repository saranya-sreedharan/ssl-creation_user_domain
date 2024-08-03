#!/bin/bash

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to display error messages
error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Function to display success messages
success() {
    echo -e "${GREEN}$1${NC}"
}

# Function to display warning messages
warning() {
    echo -e "${YELLOW}Warning: $1${NC}"
}

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    error "This script must be run as root"
fi

# Gather input from the user
read -p "Enter the Domain name: " domain_name
read -p "Enter the location where you want to perform operations: " location
read -p "Enter the email address to generate SSL certificate: " email

# Validate domain name and email
# Add your validation logic here

# Create location if it doesn't exist
mkdir -p "$location" || error "Failed to create directory: $location"
cd "$location" || error "Failed to change directory to: $location"

# Update package information
echo -e "${YELLOW}Updating packages...${NC}"
sudo apt update || error "Failed to update packages"

# Install Docker if not installed
if ! command -v docker &>/dev/null; then
    echo -e "${YELLOW}Installing Docker...${NC}"
    sudo apt install -y docker.io || error "Failed to install Docker"
fi

# Install Certbot and its Nginx plugin
echo -e "${YELLOW}Installing Certbot and its Nginx plugin...${NC}"
sudo apt install -y certbot python3-certbot-nginx || error "Failed to install Certbot"

# Generate SSL certificate
echo -e "${YELLOW}Generating SSL certificate for $domain_name...${NC}"
sudo certbot certonly --nginx --email "$email" --agree-tos --eff-email -d "$domain_name" || error "Failed to generate SSL certificate"

# Install Nginx if not installed
if ! command -v nginx &>/dev/null; then
    echo -e "${YELLOW}Installing Nginx...${NC}"
    sudo apt install -y nginx || error "Failed to install Nginx"
fi

# Create Nginx configuration
echo -e "${YELLOW}Creating Nginx configuration file...${NC}"
cat <<EOL | sudo tee "/etc/nginx/sites-available/$domain_name.conf" >/dev/null
server {
    listen 443 ssl;
    server_name www.$domain_name $domain_name;

    ssl_certificate /etc/letsencrypt/live/$domain_name/fullchain.pem; 
    ssl_certificate_key /etc/letsencrypt/live/$domain_name/privkey.pem; 

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
EOL

# Enable the site by creating a symbolic link
sudo ln -sf "/etc/nginx/sites-available/$domain_name.conf" "/etc/nginx/sites-enabled/$domain_name.conf"

# Check Nginx configuration
echo -e "${YELLOW}Checking Nginx configuration...${NC}"
if sudo nginx -t; then
    success "Nginx configuration is correct"
else
    warning "Nginx configuration error"
fi

# Restart Nginx to apply changes
echo -e "${YELLOW}Restarting Nginx...${NC}"
sudo systemctl restart nginx || warning "Failed to restart Nginx"

success "SSL certificate for $domain_name has been generated and configured in Nginx successfully"