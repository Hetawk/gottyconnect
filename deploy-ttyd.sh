#!/bin/bash

###############################################################################
# ttyd Deployment Script with Automatic SSL
# 
# This script automates the complete deployment of ttyd with:
# - Installation check and automatic installation if needed
# - Automatic SSL certificate generation via Let's Encrypt
# - Nginx reverse proxy configuration
# - Systemd service setup for auto-start
# - Comprehensive logging
# - Full environment variable support
#
# Usage: sudo ./deploy-ttyd.sh
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

###############################################################################
# Load Configuration from .env file
###############################################################################
load_env() {
    if [ -f "$SCRIPT_DIR/.env" ]; then
        echo -e "${GREEN}✓ Loading configuration from .env file${NC}"
        export $(cat "$SCRIPT_DIR/.env" | grep -v '^#' | grep -v '^$' | xargs)
        
        # Set SERVICE_NAME default if not provided
        SERVICE_NAME="${SERVICE_NAME:-ttydconnect}"
        
        # Auto-configure paths based on SERVICE_NAME if not explicitly set
        LOG_DIR="${LOG_DIR:-/var/log/${SERVICE_NAME}}"
        SERVICE_FILE="${SERVICE_FILE:-/etc/systemd/system/${SERVICE_NAME}.service}"
        NGINX_CONFIG="${NGINX_CONFIG:-/etc/nginx/sites-available/${SERVICE_NAME}}"
        TTYD_INSTALL_DIR="${TTYD_INSTALL_DIR:-/usr/local/bin}"
        
        # Generate TTYDCONNECT_AUTH_TOKEN if not provided
        if [ -z "$TTYDCONNECT_AUTH_TOKEN" ]; then
            TTYDCONNECT_AUTH_TOKEN=$(openssl rand -hex 32)
            echo -e "${YELLOW}⚠ Generated new TTYDCONNECT_AUTH_TOKEN${NC}"
            # Save it back to .env file
            if grep -q "^TTYDCONNECT_AUTH_TOKEN=" "$SCRIPT_DIR/.env"; then
                sed -i "s/^TTYDCONNECT_AUTH_TOKEN=.*/TTYDCONNECT_AUTH_TOKEN=${TTYDCONNECT_AUTH_TOKEN}/" "$SCRIPT_DIR/.env"
            else
                echo "TTYDCONNECT_AUTH_TOKEN=${TTYDCONNECT_AUTH_TOKEN}" >> "$SCRIPT_DIR/.env"
            fi
            echo -e "${GREEN}✓ TTYDCONNECT_AUTH_TOKEN saved to .env file${NC}"
        fi
        
        echo -e "${BLUE}Service Name: ${SERVICE_NAME}${NC}"
    else
        echo -e "${RED}✗ Error: .env file not found!${NC}"
        echo -e "${YELLOW}Please copy .env.example to .env and configure it:${NC}"
        echo -e "  cp .env.example .env"
        echo -e "  nano .env"
        exit 1
    fi
}

###############################################################################
# Validate Configuration
###############################################################################
validate_config() {
    echo -e "${BLUE}Validating configuration...${NC}"
    
    local errors=0
    
    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}✗ DOMAIN is not set${NC}"
        errors=$((errors + 1))
    fi
    
    if [ -z "$TTYD_USERNAME" ]; then
        echo -e "${RED}✗ TTYD_USERNAME is not set${NC}"
        errors=$((errors + 1))
    fi
    
    if [ -z "$TTYD_PASSWORD" ] || [ "$TTYD_PASSWORD" == "your_secure_password_here" ]; then
        echo -e "${RED}✗ TTYD_PASSWORD is not set or using default${NC}"
        errors=$((errors + 1))
    fi
    
    if [ -z "$SSL_EMAIL" ] || [ "$SSL_EMAIL" == "your-email@example.com" ]; then
        echo -e "${RED}✗ SSL_EMAIL is not set or using default${NC}"
        errors=$((errors + 1))
    fi
    
    if [ $errors -gt 0 ]; then
        echo -e "${RED}✗ Configuration validation failed with $errors error(s)${NC}"
        echo -e "${YELLOW}Please update your .env file and try again${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Configuration validated${NC}"
}

###############################################################################
# Setup Logging
###############################################################################
setup_logging() {
    # Update paths if they changed from temp
    LOG_DIR="${LOG_DIR:-/var/log/${SERVICE_NAME}}"
    mkdir -p "$LOG_DIR"
    
    # Update log file paths with correct SERVICE_NAME
    INSTALL_LOG="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
    SERVICE_LOG="$LOG_DIR/${SERVICE_NAME}-service.log"
    
    # Create log file
    touch "$INSTALL_LOG"
    
    # Log function is already defined in main(), just update the log
    log "=== Logging Configured ==="
    log "Domain: $DOMAIN"
    log "Service Name: $SERVICE_NAME"
    log "Port: ${TTYD_PORT:-7681}"
    log "Log Directory: $LOG_DIR"
    
    echo -e "${GREEN}✓ Logging setup complete${NC}"
    echo -e "${BLUE}Installation log: $INSTALL_LOG${NC}"
}

###############################################################################
# Check if running as root
###############################################################################
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}✗ This script must be run as root (use sudo)${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Root privileges confirmed${NC}"
}

###############################################################################
# Detect OS and Package Manager
###############################################################################
detect_os() {
    log "Detecting operating system..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        log "Detected OS: $OS $VERSION"
    else
        log "Cannot detect OS"
        echo -e "${RED}✗ Unsupported operating system${NC}"
        exit 1
    fi
    
    # Determine package manager
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt-get"
        PKG_UPDATE="apt-get update"
        PKG_INSTALL="apt-get install -y"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        PKG_UPDATE="yum check-update"
        PKG_INSTALL="yum install -y"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        PKG_UPDATE="dnf check-update"
        PKG_INSTALL="dnf install -y"
    else
        log "No supported package manager found"
        echo -e "${RED}✗ Unsupported package manager${NC}"
        exit 1
    fi
    
    log "Package manager: $PKG_MANAGER"
    echo -e "${GREEN}✓ OS detection complete${NC}"
}

###############################################################################
# Update System
###############################################################################
update_system() {
    echo -e "${BLUE}Updating system packages...${NC}"
    log "Updating system packages"
    
    $PKG_UPDATE >> "$INSTALL_LOG" 2>&1 || true
    
    echo -e "${GREEN}✓ System updated${NC}"
    log "System update complete"
}

###############################################################################
# Install Dependencies
###############################################################################
install_dependencies() {
    echo -e "${BLUE}Installing dependencies...${NC}"
    log "Installing required dependencies"
    
    local deps="nginx certbot python3-certbot-nginx wget curl"
    
    for dep in $deps; do
        if ! command -v $dep &> /dev/null && ! dpkg -l | grep -q "^ii  $dep"; then
            log "Installing $dep..."
            $PKG_INSTALL $dep >> "$INSTALL_LOG" 2>&1
        else
            log "$dep already installed"
        fi
    done
    
    echo -e "${GREEN}✓ Dependencies installed${NC}"
}

###############################################################################
# Check and Install ttyd
###############################################################################
install_ttyd() {
    echo -e "${BLUE}Checking ttyd installation...${NC}"
    
    TTYD_INSTALL_DIR="${TTYD_INSTALL_DIR:-/usr/local/bin}"
    
    if command -v ttyd &> /dev/null; then
        TTYD_VERSION=$(ttyd --version 2>&1 | head -n1 || echo "unknown")
        echo -e "${GREEN}✓ ttyd is already installed${NC}"
        log "ttyd found: $TTYD_VERSION"
        return 0
    fi
    
    echo -e "${YELLOW}ttyd not found. Installing...${NC}"
    log "Installing ttyd"
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            TTYD_ARCH="x86_64"
            ;;
        aarch64|arm64)
            TTYD_ARCH="aarch64"
            ;;
        armv7l)
            TTYD_ARCH="armhf"
            ;;
        *)
            log "Unsupported architecture: $ARCH"
            echo -e "${RED}✗ Unsupported architecture: $ARCH${NC}"
            exit 1
            ;;
    esac
    
    log "Detected architecture: $TTYD_ARCH"
    
    # Download latest ttyd
    TTYD_VERSION="1.7.7"
    TTYD_URL="https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${TTYD_ARCH}"
    
    log "Downloading ttyd from $TTYD_URL"
    
    if wget -O "${TTYD_INSTALL_DIR}/ttyd" "$TTYD_URL" >> "$INSTALL_LOG" 2>&1; then
        chmod +x "${TTYD_INSTALL_DIR}/ttyd"
        log "ttyd installed successfully to ${TTYD_INSTALL_DIR}/ttyd"
        echo -e "${GREEN}✓ ttyd installed successfully${NC}"
    else
        log "Failed to download ttyd"
        echo -e "${RED}✗ Failed to download ttyd${NC}"
        exit 1
    fi
}

###############################################################################
# Configure Firewall
###############################################################################
configure_firewall() {
    echo -e "${BLUE}Configuring firewall...${NC}"
    log "Configuring firewall rules"
    
    # Check if ufw is available
    if command -v ufw &> /dev/null; then
        ufw allow 'Nginx Full' >> "$INSTALL_LOG" 2>&1 || true
        ufw allow 22/tcp >> "$INSTALL_LOG" 2>&1 || true
        log "UFW rules added"
    fi
    
    # Check if firewalld is available
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-service=http >> "$INSTALL_LOG" 2>&1 || true
        firewall-cmd --permanent --add-service=https >> "$INSTALL_LOG" 2>&1 || true
        firewall-cmd --reload >> "$INSTALL_LOG" 2>&1 || true
        log "Firewalld rules added"
    fi
    
    echo -e "${GREEN}✓ Firewall configured${NC}"
}

###############################################################################
# Create Systemd Service
###############################################################################
create_systemd_service() {
    echo -e "${BLUE}Creating systemd service...${NC}"
    log "Creating systemd service for ${SERVICE_NAME}"
    
    TTYD_PORT="${TTYD_PORT:-7681}"
    ENABLE_AUTH="${ENABLE_AUTH:-false}"
    
    # Build the complete ExecStart command
    if [ "$ENABLE_AUTH" = "true" ]; then
        EXEC_START="/usr/local/bin/ttyd --port ${TTYD_PORT} --credential ${TTYD_USERNAME}:${TTYD_PASSWORD} --interface 127.0.0.1 --writable bash"
        log "Authentication enabled for ttyd"
    else
        EXEC_START="/usr/local/bin/ttyd --port ${TTYD_PORT} --interface 127.0.0.1 --writable bash"
        log "Authentication disabled - ttyd will be accessible without password prompt"
    fi
    
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=ttyd - Share your terminal over the web
Documentation=https://github.com/tsl0922/ttyd
After=network.target

[Service]
Type=simple
User=root
ExecStart=${EXEC_START}
Restart=always
RestartSec=10
StandardOutput=append:${SERVICE_LOG}
StandardError=append:${SERVICE_LOG}

# Security settings
NoNewPrivileges=false
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    log "Systemd service file created: $SERVICE_FILE"
    
    # Reload systemd
    systemctl daemon-reload
    log "Systemd daemon reloaded"
    
    # Enable service to start on boot
    systemctl enable $(basename "$SERVICE_FILE") >> "$INSTALL_LOG" 2>&1
    log "${SERVICE_NAME} service enabled for auto-start"
    
    echo -e "${GREEN}✓ Systemd service created and enabled${NC}"
}

###############################################################################
# Configure Nginx
###############################################################################
configure_nginx() {
    echo -e "${BLUE}Configuring Nginx...${NC}"
    log "Configuring Nginx reverse proxy"
    
    TTYD_PORT="${TTYD_PORT:-7681}"
    
    # Create Nginx config (without SSL first, for certbot)
    cat > "$NGINX_CONFIG" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    
    # Let's Encrypt challenge location
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Redirect to HTTPS (will be added after SSL setup)
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS configuration will be added by certbot
EOF

    log "Nginx configuration created: $NGINX_CONFIG"
    
    # Enable site
    if [ -d /etc/nginx/sites-enabled ]; then
        ln -sf "$NGINX_CONFIG" "/etc/nginx/sites-enabled/$(basename $NGINX_CONFIG)"
        log "Nginx site enabled"
    fi
    
    # Test Nginx configuration
    if nginx -t >> "$INSTALL_LOG" 2>&1; then
        log "Nginx configuration test passed"
        
        # Kill any rogue nginx processes not managed by systemd
        if pgrep -x nginx > /dev/null && ! systemctl is-active --quiet nginx; then
            log "Found nginx processes not managed by systemd, cleaning up..."
            pkill -9 nginx >> "$INSTALL_LOG" 2>&1 || true
            sleep 1
        fi
        
        # Now start or reload nginx properly
        if systemctl is-active --quiet nginx; then
            systemctl reload nginx >> "$INSTALL_LOG" 2>&1
            log "Nginx reloaded"
        else
            systemctl start nginx >> "$INSTALL_LOG" 2>&1
            systemctl enable nginx >> "$INSTALL_LOG" 2>&1
            log "Nginx started and enabled"
        fi
        
        echo -e "${GREEN}✓ Nginx configured${NC}"
    else
        log "Nginx configuration test failed"
        echo -e "${RED}✗ Nginx configuration error${NC}"
        exit 1
    fi
}

###############################################################################
# Setup SSL with Let's Encrypt
###############################################################################
setup_ssl() {
    echo -e "${BLUE}Setting up SSL certificate with Let's Encrypt...${NC}"
    log "Starting SSL certificate generation"
    
    # Check if certificate already exists
    if [ -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
        echo -e "${YELLOW}SSL certificate already exists for ${DOMAIN}${NC}"
        log "SSL certificate already exists, checking if renewal needed"
        certbot renew --dry-run >> "$INSTALL_LOG" 2>&1 || true
    else
        echo -e "${BLUE}Obtaining new SSL certificate...${NC}"
        log "Obtaining SSL certificate from Let's Encrypt"
        
        # Stop nginx temporarily if needed
        systemctl stop nginx >> "$INSTALL_LOG" 2>&1 || true
        
        # Obtain certificate
        if certbot certonly --standalone \
            --non-interactive \
            --agree-tos \
            --email "$SSL_EMAIL" \
            -d "$DOMAIN" >> "$INSTALL_LOG" 2>&1; then
            
            log "SSL certificate obtained successfully"
            echo -e "${GREEN}✓ SSL certificate obtained${NC}"
        else
            log "Failed to obtain SSL certificate"
            echo -e "${RED}✗ Failed to obtain SSL certificate${NC}"
            echo -e "${YELLOW}Please check:${NC}"
            echo -e "  1. Domain DNS is pointing to this server"
            echo -e "  2. Port 80 and 443 are accessible"
            echo -e "  3. Email address is valid"
            systemctl start nginx >> "$INSTALL_LOG" 2>&1 || true
            exit 1
        fi
    fi
    
    # Update Nginx config with SSL
    TTYD_PORT="${TTYD_PORT:-7681}"
    
    cat > "$NGINX_CONFIG" <<EOF
# HTTP - Redirect to HTTPS
server {
    listen 80;
    server_name ${DOMAIN};
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS - ttyd Reverse Proxy with Token Authentication
server {
    listen 443 ssl http2;
    server_name ${DOMAIN};
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Access and Error Logs
    access_log ${LOG_DIR}/nginx-access.log;
    error_log ${LOG_DIR}/nginx-error.log;
    
    # ttyd WebSocket Proxy with Token Authentication
    location / {
        # Validate TTYDCONNECT_AUTH_TOKEN header
        set \$auth_token_valid 0;
        
        if (\$http_x_auth_token = "${TTYDCONNECT_AUTH_TOKEN}") {
            set \$auth_token_valid 1;
        }
        
        # Reject if token is invalid
        if (\$auth_token_valid = 0) {
            return 401 "Unauthorized: Invalid or missing X-Auth-Token header";
        }
        
        proxy_pass http://127.0.0.1:${TTYD_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket specific settings
        proxy_read_timeout 86400;
        proxy_buffering off;
    }
}
EOF

    log "Nginx configuration updated with SSL"
    
    # Test and reload Nginx
    if nginx -t >> "$INSTALL_LOG" 2>&1; then
        systemctl start nginx >> "$INSTALL_LOG" 2>&1
        systemctl reload nginx >> "$INSTALL_LOG" 2>&1
        log "Nginx reloaded with SSL configuration"
        echo -e "${GREEN}✓ SSL configured and Nginx reloaded${NC}"
    else
        log "Nginx configuration test failed after SSL setup"
        echo -e "${RED}✗ Nginx configuration error${NC}"
        exit 1
    fi
    
    # Setup auto-renewal
    log "Setting up SSL certificate auto-renewal"
    (crontab -l 2>/dev/null | grep -v 'certbot renew'; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
    log "SSL auto-renewal configured"
}

###############################################################################
# Start Services
###############################################################################
start_services() {
    echo -e "${BLUE}Starting services...${NC}"
    log "Starting ${SERVICE_NAME} and nginx services"
    
    SERVICE_NAME_FILE=$(basename "$SERVICE_FILE")
    
    # Start ttyd
    systemctl restart "$SERVICE_NAME_FILE" >> "$INSTALL_LOG" 2>&1
    sleep 2
    
    if systemctl is-active --quiet "$SERVICE_NAME_FILE"; then
        log "${SERVICE_NAME} service started successfully"
        echo -e "${GREEN}✓ ${SERVICE_NAME} service started${NC}"
    else
        log "${SERVICE_NAME} service failed to start"
        echo -e "${RED}✗ Failed to start ${SERVICE_NAME} service${NC}"
        echo -e "${YELLOW}Check logs: journalctl -u $SERVICE_NAME_FILE -n 50${NC}"
        exit 1
    fi
    
    # Ensure nginx is running
    systemctl restart nginx >> "$INSTALL_LOG" 2>&1
    if systemctl is-active --quiet nginx; then
        log "nginx service running"
        echo -e "${GREEN}✓ nginx service running${NC}"
    else
        log "nginx service failed to start"
        echo -e "${RED}✗ Failed to start nginx service${NC}"
        exit 1
    fi
}

###############################################################################
# Verify Installation
###############################################################################
verify_installation() {
    echo -e "${BLUE}Verifying installation...${NC}"
    log "Running verification checks"
    
    local errors=0
    
    # Check ttyd binary
    if command -v ttyd &> /dev/null; then
        echo -e "${GREEN}✓ ttyd binary found${NC}"
        log "ttyd binary: $(which ttyd)"
    else
        echo -e "${RED}✗ ttyd binary not found${NC}"
        errors=$((errors + 1))
    fi
    
    # Check ttyd service
    if systemctl is-active --quiet "${SERVICE_NAME}.service"; then
        echo -e "${GREEN}✓ ${SERVICE_NAME} service is running${NC}"
        log "${SERVICE_NAME} service status: active"
    else
        echo -e "${RED}✗ ${SERVICE_NAME} service is not running${NC}"
        errors=$((errors + 1))
    fi
    
    # Check nginx service
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✓ nginx service is running${NC}"
        log "nginx service status: active"
    else
        echo -e "${RED}✗ nginx service is not running${NC}"
        errors=$((errors + 1))
    fi
    
    # Check SSL certificate
    if [ -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
        echo -e "${GREEN}✓ SSL certificate exists${NC}"
        log "SSL certificate found for ${DOMAIN}"
    else
        echo -e "${YELLOW}⚠ SSL certificate not found${NC}"
        log "SSL certificate not found"
    fi
    
    # Check if ttyd port is listening
    if netstat -tuln 2>/dev/null | grep -q ":${TTYD_PORT:-7681}" || ss -tuln 2>/dev/null | grep -q ":${TTYD_PORT:-7681}"; then
        echo -e "${GREEN}✓ ttyd is listening on port ${TTYD_PORT:-7681}${NC}"
        log "ttyd listening on port ${TTYD_PORT:-7681}"
    else
        echo -e "${YELLOW}⚠ ttyd port not detected (may be binding to localhost only)${NC}"
    fi
    
    if [ $errors -gt 0 ]; then
        log "Verification completed with $errors error(s)"
        return 1
    else
        log "All verification checks passed"
        return 0
    fi
}

###############################################################################
# Print Summary
###############################################################################
print_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          ttyd Deployment Completed Successfully!          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🔐 AUTHENTICATION TOKEN (IMPORTANT!)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  TTYDCONNECT_AUTH_TOKEN=${GREEN}${TTYDCONNECT_AUTH_TOKEN}${NC}"
    echo -e ""
    echo -e "${CYAN}  ⚠️  Keep this token SECRET! It grants full access to your terminal.${NC}"
    echo -e "${CYAN}  ℹ️  All clients must send this in 'X-Auth-Token' header${NC}"
    echo -e "${CYAN}  ℹ️  Token is saved in: ${SCRIPT_DIR}/.env${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🌐 Connection Details${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${CYAN}Domain:${NC}      ${GREEN}https://${DOMAIN}${NC}"
    echo -e "  ${CYAN}WebSocket:${NC}   ${GREEN}wss://${DOMAIN}${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📊 Service Status${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${CYAN}${SERVICE_NAME}:${NC} ${GREEN}$(systemctl is-active ${SERVICE_NAME}.service)${NC}"
    echo -e "  ${CYAN}nginx:${NC}       ${GREEN}$(systemctl is-active nginx)${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📝 Log Files${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Deployment:   ${YELLOW}${INSTALL_LOG}${NC}"
    echo -e "  Service:      ${YELLOW}${SERVICE_LOG}${NC}"
    echo -e "  Nginx Access: ${YELLOW}${LOG_DIR}/nginx-access.log${NC}"
    echo -e "  Nginx Error:  ${YELLOW}${LOG_DIR}/nginx-error.log${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}⚙️  Management Commands${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    SERVICE_NAME_FILE=$(basename "$SERVICE_FILE")
    echo -e "  Check status:  ${YELLOW}sudo systemctl status $SERVICE_NAME_FILE${NC}"
    echo -e "  View logs:     ${YELLOW}sudo journalctl -u $SERVICE_NAME_FILE -f${NC}"
    echo -e "  Restart:       ${YELLOW}sudo systemctl restart $SERVICE_NAME_FILE${NC}"
    echo -e "  Stop:          ${YELLOW}sudo systemctl stop $SERVICE_NAME_FILE${NC}"
    echo -e "  Renew SSL:     ${YELLOW}sudo certbot renew${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🔧 Environment Variables for Your Apps${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${CYAN}TTYD_URL=${GREEN}https://${DOMAIN}${NC}"
    echo -e "  ${CYAN}TTYDCONNECT_AUTH_TOKEN=${GREEN}${TTYDCONNECT_AUTH_TOKEN}${NC}"
    echo ""
    echo -e "${GREEN}✓ Auto-start is enabled - service will start on boot${NC}"
    echo -e "${GREEN}✓ SSL auto-renewal is configured${NC}"
    echo -e "${GREEN}✓ Token-based authentication is active${NC}"
    echo -e "${GREEN}✓ Your terminal is now accessible at: https://${DOMAIN}${NC}"
    echo ""
    
    log "=== Deployment Summary Printed ==="
    log "Deployment completed successfully"
}

###############################################################################
# Main Execution
###############################################################################
main() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         ttyd Automatic Deployment Script v2.0             ║"
    echo "║    Complete Setup with SSL, Auto-Start & Logging          ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Check root privileges
    check_root
    
    # Setup logging FIRST (before any log() calls)
    # Create initial log directory
    LOG_DIR_TEMP="/var/log/ttydconnect"
    mkdir -p "$LOG_DIR_TEMP"
    INSTALL_LOG="$LOG_DIR_TEMP/install-$(date +%Y%m%d-%H%M%S).log"
    SERVICE_LOG="$LOG_DIR_TEMP/ttydconnect-service.log"
    touch "$INSTALL_LOG"
    
    # Define log function early
    log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$INSTALL_LOG"
    }
    
    log "=== ttyd Deployment Started ==="
    
    # Load and validate configuration
    load_env
    validate_config
    
    # Now properly setup logging with correct paths
    setup_logging
    
    # Detect OS
    detect_os
    
    # Update system
    update_system
    
    # Install dependencies
    install_dependencies
    
    # Install ttyd
    install_ttyd
    
    # Configure firewall
    configure_firewall
    
    # Create systemd service
    create_systemd_service
    
    # Configure Nginx (without SSL first)
    configure_nginx
    
    # Setup SSL with Let's Encrypt
    setup_ssl
    
    # Start all services
    start_services
    
    # Verify installation
    verify_installation
    
    # Print summary
    print_summary
    
    log "=== ttyd Deployment Completed Successfully ==="
}

# Run main function
main "$@"
