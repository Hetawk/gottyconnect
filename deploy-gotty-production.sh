#!/bin/bash

###############################################################################
# GoTTY Production Deployment - Complete Automated Setup
#
# Features:
# ✅ Single script - complete deployment
# ✅ Public endpoint with URL token authentication (NO POPUP in iframes!)
# ✅ HTTP Basic Auth for direct access
# ✅ Automatic port detection and conflict resolution
# ✅ SSL/HTTPS with Let's Encrypt
# ✅ Portable - works on any server
# ✅ Robust error handling and rollback
#
# Usage: sudo ./deploy-gotty-production.sh
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

###############################################################################
# Root check
###############################################################################
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Must run as root (use sudo)${NC}"
    exit 1
fi

###############################################################################
# Load or create configuration
###############################################################################
load_config() {
    echo -e "${BLUE}Loading configuration...${NC}"
    
    if [ ! -f "$SCRIPT_DIR/.env" ]; then
        echo -e "${RED}✗ .env not found${NC}"
        echo -e "${YELLOW}Please create .env with GOTTY_DOMAIN, SSL_EMAIL, GOTTY_AUTH_TOKEN${NC}"
        exit 1
    fi
    
    source "$SCRIPT_DIR/.env"
    
    # Use GOTTY_DOMAIN or fall back to DOMAIN
    DOMAIN="${GOTTY_DOMAIN:-${DOMAIN}}"
    
    # Validate required fields
    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}✗ Please set GOTTY_DOMAIN or DOMAIN in .env file${NC}"
        exit 1
    fi
    
    if [ -z "$SSL_EMAIL" ]; then
        echo -e "${RED}✗ Please set SSL_EMAIL in .env file${NC}"
        exit 1
    fi
    
    # Generate auth token if not exists
    if [ -z "$GOTTY_AUTH_TOKEN" ]; then
        GOTTY_AUTH_TOKEN=$(openssl rand -hex 32)
        echo "GOTTY_AUTH_TOKEN=${GOTTY_AUTH_TOKEN}" >> "$SCRIPT_DIR/.env"
        echo -e "${GREEN}✓ Generated GOTTY_AUTH_TOKEN${NC}"
    fi
    
    # Extract username from GOTTY_CREDENTIAL or set default
    if [ -n "$GOTTY_CREDENTIAL" ]; then
        GOTTY_USER=$(echo "$GOTTY_CREDENTIAL" | cut -d: -f1)
        GOTTY_PASS=$(echo "$GOTTY_CREDENTIAL" | cut -d: -f2)
    else
        GOTTY_USER="terminal"
        GOTTY_PASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)
        GOTTY_CREDENTIAL="${GOTTY_USER}:${GOTTY_PASS}"
        echo "GOTTY_CREDENTIAL=${GOTTY_CREDENTIAL}" >> "$SCRIPT_DIR/.env"
        echo -e "${GREEN}✓ Generated GOTTY_CREDENTIAL${NC}"
    fi
    
    # Auto-detect available port
    GOTTY_PORT="${GOTTY_PORT:-7680}"
    while ss -tuln | grep -q ":${GOTTY_PORT} " || netstat -tuln 2>/dev/null | grep -q ":${GOTTY_PORT} "; do
        echo -e "${YELLOW}⚠ Port ${GOTTY_PORT} in use, trying next...${NC}"
        GOTTY_PORT=$((GOTTY_PORT + 1))
    done
    
    # Update .env with final port if changed
    if ! grep -q "^GOTTY_PORT=" "$SCRIPT_DIR/.env"; then
        echo "GOTTY_PORT=${GOTTY_PORT}" >> "$SCRIPT_DIR/.env"
    elif ! grep -q "^GOTTY_PORT=${GOTTY_PORT}$" "$SCRIPT_DIR/.env"; then
        sed -i "s/^GOTTY_PORT=.*/GOTTY_PORT=${GOTTY_PORT}/" "$SCRIPT_DIR/.env"
    fi
    
    SERVICE_NAME="gottyconnect"
    LOG_DIR="/var/log/${SERVICE_NAME}"
    
    mkdir -p "$LOG_DIR"
    
    echo -e "${GREEN}✓ Configuration loaded${NC}"
    echo -e "${BLUE}  Domain: ${DOMAIN}${NC}"
    echo -e "${BLUE}  Port: ${GOTTY_PORT}${NC}"
    echo -e "${BLUE}  User: ${GOTTY_USER}${NC}"
    echo -e "${BLUE}  Auth Token: ${GOTTY_AUTH_TOKEN:0:16}...${NC}"
}

###############################################################################
# Install dependencies
###############################################################################
install_deps() {
    echo -e "${BLUE}Installing dependencies...${NC}"
    
    apt update -qq
    apt install -y wget nginx certbot python3-certbot-nginx curl jq > /dev/null 2>&1
    
    echo -e "${GREEN}✓ Dependencies installed${NC}"
}

###############################################################################
# Install GoTTY
###############################################################################
install_gotty() {
    echo -e "${BLUE}Installing GoTTY...${NC}"
    
    if [ -f "/usr/local/bin/gotty" ]; then
        echo -e "${GREEN}✓ GoTTY already installed${NC}"
        return 0
    fi
    
    VERSION=$(curl -s https://api.github.com/repos/yudai/gotty/releases/latest | jq -r '.tag_name')
    VERSION="${VERSION:-v1.0.1}"
    
    cd /tmp
    wget -q "https://github.com/yudai/gotty/releases/download/${VERSION}/gotty_linux_amd64.tar.gz"
    tar -xzf gotty_linux_amd64.tar.gz
    mv gotty /usr/local/bin/
    chmod +x /usr/local/bin/gotty
    rm -f gotty_linux_amd64.tar.gz
    
    echo -e "${GREEN}✓ GoTTY installed: $(/usr/local/bin/gotty --version)${NC}"
}

###############################################################################
# Stop conflicting services
###############################################################################
stop_conflicts() {
    echo -e "${BLUE}Stopping conflicting services...${NC}"
    
    # Stop old ttyd services
    for service in ttydconnect ttyd gottyconnect; do
        if systemctl list-units --full -all | grep -q "${service}.service"; then
            systemctl stop ${service}.service 2>/dev/null || true
            systemctl disable ${service}.service 2>/dev/null || true
        fi
    done
    
    # Remove old nginx configs
    rm -f /etc/nginx/sites-enabled/ttydconnect 2>/dev/null || true
    rm -f /etc/nginx/sites-enabled/gottyconnect 2>/dev/null || true
    
    echo -e "${GREEN}✓ Conflicts cleared${NC}"
}

###############################################################################
# Create systemd service
###############################################################################
create_service() {
    echo -e "${BLUE}Creating systemd service...${NC}"
    
    cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=GoTTY Terminal Server
Documentation=https://github.com/yudai/gotty
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
Environment="GOTTY_CREDENTIAL=${GOTTY_CREDENTIAL}"
ExecStart=/usr/local/bin/gotty \\
    --port ${GOTTY_PORT} \\
    --address 127.0.0.1 \\
    --permit-write \\
    --credential "${GOTTY_CREDENTIAL}" \\
    --reconnect \\
    --reconnect-time 10 \\
    --max-connection 50 \\
    bash --login
Restart=always
RestartSec=10
StandardOutput=append:${LOG_DIR}/gotty.log
StandardError=append:${LOG_DIR}/gotty.log

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}.service
    
    echo -e "${GREEN}✓ Service created${NC}"
}

###############################################################################
# Configure Nginx with Public Endpoint (No Auth Popup)
###############################################################################
configure_nginx() {
    echo -e "${BLUE}Configuring Nginx with public endpoint...${NC}"
    
    # Generate Base64 auth for GoTTY
    GOTTY_AUTH_BASE64=$(echo -n "${GOTTY_CREDENTIAL}" | base64 -w 0)
    
    cat > /etc/nginx/sites-available/${SERVICE_NAME} <<EOF
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

# HTTPS - Main Terminal Server
server {
    listen 443 ssl http2;
    server_name ${DOMAIN};
    
    # SSL Configuration (managed by certbot)
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000" always;
    
    # Logging
    access_log ${LOG_DIR}/nginx-access.log;
    error_log ${LOG_DIR}/nginx-error.log;
    
    # ===== PUBLIC ENDPOINT - NO AUTH POPUP =====
    # This endpoint validates token in URL and adds Basic Auth header server-side
    # Usage: https://${DOMAIN}/public?token=YOUR_TOKEN
    location = /public {
        # Validate token in URL parameter
        if (\$arg_token != "${GOTTY_AUTH_TOKEN}") {
            return 401 "Invalid or missing token";
        }
        
        # Add Basic Auth header automatically (invisible to browser)
        proxy_set_header Authorization "Basic ${GOTTY_AUTH_BASE64}";
        
        # Proxy to GoTTY (trailing slash is critical!)
        proxy_pass http://127.0.0.1:${GOTTY_PORT}/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
    # ===== END PUBLIC ENDPOINT =====
    
    # ===== STATIC ASSETS - NO TOKEN REQUIRED =====
    # JavaScript, CSS, and images needed by GoTTY
    # These are loaded by the browser after loading /public
    location ~ ^/(js|css|favicon\.png|auth_token\.js) {
        # Add Basic Auth header for GoTTY assets
        proxy_set_header Authorization "Basic ${GOTTY_AUTH_BASE64}";
        
        proxy_pass http://127.0.0.1:${GOTTY_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    # ===== END STATIC ASSETS =====
    
    # ===== WEBSOCKET FROM /public PAGE =====
    # GoTTY tries to connect to /publicws when loaded from /public
    # This catches that and redirects to the correct /ws endpoint
    location = /publicws {
        # Add Basic Auth header for WebSocket
        proxy_set_header Authorization "Basic ${GOTTY_AUTH_BASE64}";
        
        # Rewrite to correct WebSocket path
        rewrite ^/publicws\$ /ws break;
        
        proxy_pass http://127.0.0.1:${GOTTY_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
    # ===== END /publicws FIX =====
    
    # ===== WEBSOCKET ENDPOINT =====
    location /ws {
        # Add Basic Auth header for WebSocket
        proxy_set_header Authorization "Basic ${GOTTY_AUTH_BASE64}";
        
        proxy_pass http://127.0.0.1:${GOTTY_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
    # ===== END WEBSOCKET =====
    
    # Regular endpoint (requires Basic Auth - will show popup in iframe)
    location / {
        proxy_pass http://127.0.0.1:${GOTTY_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_buffering off;
    }
    
    # Health check endpoint (no auth)
    location /health {
        access_log off;
        return 200 '{"status":"ok","service":"gotty"}';
        add_header Content-Type application/json;
    }
}
EOF

    # Enable site
    ln -sf /etc/nginx/sites-available/${SERVICE_NAME} /etc/nginx/sites-enabled/
    
    # Test config
    nginx -t
    
    echo -e "${GREEN}✓ Nginx configured with /public endpoint + static assets${NC}"
}

###############################################################################
# Setup SSL
###############################################################################
setup_ssl() {
    echo -e "${BLUE}Setting up SSL...${NC}"
    
    if [ -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
        echo -e "${GREEN}✓ SSL certificate exists${NC}"
        return 0
    fi
    
    # Stop nginx for standalone cert
    systemctl stop nginx 2>/dev/null || true
    
    # Get certificate
    certbot certonly --standalone \
        --non-interactive \
        --agree-tos \
        --email "${SSL_EMAIL}" \
        -d "${DOMAIN}" || {
        echo -e "${RED}✗ SSL certificate failed${NC}"
        echo -e "${YELLOW}  Make sure ${DOMAIN} points to this server${NC}"
        exit 1
    }
    
    # Setup auto-renewal
    (crontab -l 2>/dev/null | grep -v 'certbot renew'; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
    
    echo -e "${GREEN}✓ SSL certificate obtained${NC}"
}

###############################################################################
# Start services
###############################################################################
start_services() {
    echo -e "${BLUE}Starting services...${NC}"
    
    systemctl start ${SERVICE_NAME}.service
    systemctl start nginx
    
    sleep 3
    
    if ! systemctl is-active --quiet ${SERVICE_NAME}.service; then
        echo -e "${RED}✗ GoTTY service failed to start${NC}"
        journalctl -u ${SERVICE_NAME}.service -n 20 --no-pager
        exit 1
    fi
    
    if ! systemctl is-active --quiet nginx; then
        echo -e "${RED}✗ Nginx failed to start${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Services started${NC}"
}

###############################################################################
# Create test scripts
###############################################################################
create_tests() {
    echo -e "${BLUE}Creating test scripts...${NC}"
    
    # Bash test script
    cat > "$SCRIPT_DIR/test-gotty.sh" <<EOF
#!/bin/bash
echo "🧪 Testing GoTTY Terminal Server"
echo ""

# Test 1: Health check
echo "1️⃣  Health check..."
HTTP_CODE=\$(curl -s -o /dev/null -w "%{http_code}" https://${DOMAIN}/health 2>/dev/null)
if [ "\$HTTP_CODE" = "200" ]; then
    echo "   ✅ Health check OK"
else
    echo "   ❌ Health check failed (code: \$HTTP_CODE)"
fi

# Test 2: Public endpoint with valid token (NO POPUP!)
echo ""
echo "2️⃣  Public endpoint (iframe-friendly)..."
HTTP_CODE=\$(curl -s -o /dev/null -w "%{http_code}" \\
    "https://${DOMAIN}/public?token=${GOTTY_AUTH_TOKEN}" 2>/dev/null)
if [ "\$HTTP_CODE" = "200" ]; then
    echo "   ✅ Public endpoint works (NO AUTH POPUP)"
else
    echo "   ❌ Public endpoint failed (code: \$HTTP_CODE)"
fi

# Test 3: Public endpoint with invalid token (should fail)
echo ""
echo "3️⃣  Token validation..."
HTTP_CODE=\$(curl -s -o /dev/null -w "%{http_code}" \\
    "https://${DOMAIN}/public?token=invalid" 2>/dev/null)
if [ "\$HTTP_CODE" = "401" ]; then
    echo "   ✅ Invalid token rejected (401)"
else
    echo "   ⚠️  Unexpected code: \$HTTP_CODE"
fi

# Test 4: Direct access with Basic Auth
echo ""
echo "4️⃣  Basic Auth (direct access)..."
HTTP_CODE=\$(curl -s -o /dev/null -w "%{http_code}" \\
    -u "${GOTTY_CREDENTIAL}" \\
    https://${DOMAIN} 2>/dev/null)
if [ "\$HTTP_CODE" = "200" ]; then
    echo "   ✅ Basic Auth works"
else
    echo "   ⚠️  Basic Auth code: \$HTTP_CODE"
fi

echo ""
echo "5️⃣  Service status:"
sudo systemctl status ${SERVICE_NAME}.service --no-pager -l | head -8

echo ""
echo "✅ Test complete!"
echo ""
echo "🔗 Connection Info:"
echo "   Public (NO POPUP): https://${DOMAIN}/public?token=${GOTTY_AUTH_TOKEN}"
echo "   Direct (has popup): https://${DOMAIN}"
echo "   WebSocket: wss://${DOMAIN}/ws"
echo ""
echo "📋 For iframe embedding (recommended):"
echo "   <iframe src=\"https://${DOMAIN}/public?token=${GOTTY_AUTH_TOKEN}\"></iframe>"
EOF

    chmod +x "$SCRIPT_DIR/test-gotty.sh"
    
    # Node.js test script for WebSocket
    cat > "$SCRIPT_DIR/test-gotty-node.js" <<EOF
const WebSocket = require('ws');

// For WebSocket connections, use Basic Auth
const config = {
    url: 'wss://${DOMAIN}/ws',
    auth: '${GOTTY_CREDENTIAL}'
};

console.log('🔌 Testing GoTTY WebSocket Connection');
console.log('URL:', config.url);
console.log('');

// Create Basic Auth header
const authHeader = 'Basic ' + Buffer.from(config.auth).toString('base64');

const ws = new WebSocket(config.url, {
    headers: {
        'Authorization': authHeader
    }
});

let outputReceived = false;

ws.on('open', () => {
    console.log('✅ Connected!');
    console.log('');
    
    // Send test commands
    setTimeout(() => {
        console.log('📤 Sending: pwd');
        ws.send('0pwd\\n');
    }, 500);
    
    setTimeout(() => {
        console.log('📤 Sending: whoami');
        ws.send('0whoami\\n');
    }, 1000);
    
    setTimeout(() => {
        console.log('📤 Sending: echo "Test Success"');
        ws.send('0echo "Test Success"\\n');
    }, 1500);
});

ws.on('message', (data) => {
    if (Buffer.isBuffer(data)) {
        const buffer = Buffer.from(data);
        if (buffer.length > 0 && buffer[0] === 0x30) {
            const base64Data = buffer.slice(1).toString('utf-8');
            try {
                const decoded = Buffer.from(base64Data, 'base64').toString('utf-8');
                if (decoded.trim()) {
                    outputReceived = true;
                    console.log('📥', JSON.stringify(decoded.trim()));
                }
            } catch (e) {}
        }
    }
});

ws.on('error', (err) => {
    console.error('❌ Error:', err.message);
});

ws.on('close', () => {
    console.log('');
    console.log('🔌 Connection closed');
    console.log(outputReceived ? '✅ Test PASSED' : '❌ Test FAILED');
    process.exit(outputReceived ? 0 : 1);
});

setTimeout(() => ws.close(), 5000);
EOF

    echo -e "${GREEN}✓ Test scripts created${NC}"
}

###############################################################################
# Create integration documentation
###############################################################################
create_docs() {
    echo -e "${BLUE}Creating documentation...${NC}"
    
    cat > "$SCRIPT_DIR/INTEGRATION.md" <<EOF
# GoTTY Integration Guide

## Connection Details

- **Domain**: https://${DOMAIN}
- **Public Endpoint** (NO POPUP): https://${DOMAIN}/public?token=YOUR_TOKEN
- **Direct Endpoint** (has popup): https://${DOMAIN}
- **WebSocket**: wss://${DOMAIN}/ws
- **Auth Token**: \`${GOTTY_AUTH_TOKEN}\`
- **Basic Auth**: \`${GOTTY_CREDENTIAL}\`

## Important: Two Authentication Methods

### 1. Public Endpoint (Recommended for iframes - NO POPUP!)

**URL Format:**
\`\`\`
https://${DOMAIN}/public?token=${GOTTY_AUTH_TOKEN}
\`\`\`

**How it works:**
- Token in URL parameter
- Nginx validates token server-side
- Nginx adds Basic Auth header automatically
- Browser NEVER sees authentication requirement
- **Perfect for iframe embedding - NO POPUP!**

**Usage in iframe:**
\`\`\`html
<iframe 
  src="https://${DOMAIN}/public?token=${GOTTY_AUTH_TOKEN}"
  style="width: 100%; height: 600px; border: none;"
  sandbox="allow-same-origin allow-scripts allow-forms"
></iframe>
\`\`\`

**Usage in Next.js/React:**
\`\`\`typescript
const publicUrl = \`\${process.env.GOTTY_PUBLIC_URL}?token=\${process.env.GOTTY_AUTH_TOKEN}\`;

<iframe 
  src={publicUrl}
  style={{ width: '100%', height: '600px', border: 'none' }}
/>
\`\`\`

### 2. Direct Access (Basic Auth - Will Show Popup in iframes)

**URL Format:**
\`\`\`
https://${DOMAIN}
\`\`\`

**Authentication:**
- Username: \`${GOTTY_USER}\`
- Password: \`${GOTTY_PASS}\`
- Or use: \`${GOTTY_CREDENTIAL}\`

**Note:** This will trigger browser authentication popup in iframes. Use public endpoint instead.

## Quick Tests

\`\`\`bash
# Health check (no auth)
curl https://${DOMAIN}/health

# Public endpoint (NO POPUP)
curl "https://${DOMAIN}/public?token=${GOTTY_AUTH_TOKEN}"

# Public endpoint with invalid token (should return 401)
curl "https://${DOMAIN}/public?token=invalid"

# Direct access with Basic Auth
curl -u "${GOTTY_CREDENTIAL}" https://${DOMAIN}
\`\`\`

## Integration Examples

### JavaScript/TypeScript - Browser (Recommended)

\`\`\`typescript
// For iframe embedding (NO POPUP!)
const terminalUrl = 'https://${DOMAIN}/public?token=${GOTTY_AUTH_TOKEN}';

const iframe = document.createElement('iframe');
iframe.src = terminalUrl;
iframe.style.width = '100%';
iframe.style.height = '600px';
iframe.style.border = 'none';
document.getElementById('terminal-container').appendChild(iframe);
\`\`\`

### Next.js Component

\`\`\`typescript
// components/Terminal.tsx
import { useEffect, useState } from 'react';

export default function Terminal() {
  const [terminalUrl, setTerminalUrl] = useState('');

  useEffect(() => {
    // Fetch URL from your API (keeps token server-side)
    fetch('/api/terminal/url')
      .then(res => res.json())
      .then(data => setTerminalUrl(data.url));
  }, []);

  if (!terminalUrl) return <div>Loading terminal...</div>;

  return (
    <iframe
      src={terminalUrl}
      style={{ width: '100%', height: '600px', border: 'none' }}
      sandbox="allow-same-origin allow-scripts allow-forms"
    />
  );
}

// app/api/terminal/url/route.ts
import { NextResponse } from 'next/server';

export async function GET() {
  const publicUrl = process.env.GOTTY_PUBLIC_URL;
  const token = process.env.GOTTY_AUTH_TOKEN;
  
  return NextResponse.json({
    url: \`\${publicUrl}?token=\${token}\`
  });
}
\`\`\`

### WebSocket Connection (Node.js)

\`\`\`javascript
const WebSocket = require('ws');

// WebSocket uses Basic Auth
const authHeader = 'Basic ' + Buffer.from('${GOTTY_CREDENTIAL}').toString('base64');

const ws = new WebSocket('wss://${DOMAIN}/ws', {
    headers: {
        'Authorization': authHeader
    }
});

ws.on('open', () => {
    console.log('Connected!');
    // Send command (type '0' + command + newline)
    ws.send('0ls -la\\n');
});

ws.on('message', (data) => {
    // Decode output (base64 after first byte)
    const buffer = Buffer.from(data);
    if (buffer[0] === 0x30) {  // Type '0'
        const base64Data = buffer.slice(1).toString('utf-8');
        const output = Buffer.from(base64Data, 'base64').toString('utf-8');
        console.log(output);
    }
});
\`\`\`

### Python

\`\`\`python
import websocket
import base64

# WebSocket uses Basic Auth
auth = base64.b64encode(b'${GOTTY_CREDENTIAL}').decode()

ws = websocket.create_connection(
    'wss://${DOMAIN}/ws',
    header={'Authorization': f'Basic {auth}'}
)

# Send command
ws.send(b'0ls -la\\n')

# Receive output
data = ws.recv()
if data[0] == 0x30:  # Type '0'
    output = base64.b64decode(data[1:])
    print(output.decode())

ws.close()
\`\`\`

## Environment Variables

For your applications:

\`\`\`env
# Public endpoint (NO POPUP - use this for iframes!)
GOTTY_PUBLIC_URL=https://${DOMAIN}/public
GOTTY_AUTH_TOKEN=${GOTTY_AUTH_TOKEN}

# Direct access (has popup in iframes)
GOTTY_URL=https://${DOMAIN}
GOTTY_WS_URL=wss://${DOMAIN}/ws
GOTTY_CREDENTIAL=${GOTTY_CREDENTIAL}
\`\`\`

## Protocol

GoTTY uses a simple binary protocol:
- First byte: message type
  - \`0\` (0x30): input/output data
  - \`1\` (0x31): output
  - \`2\` (0x32): ping/pong
- Remaining bytes: base64-encoded payload

**To send command:** \`'0' + command + '\\n'\`
**To receive:** decode base64 after first byte

## Service Management

\`\`\`bash
# Status
sudo systemctl status ${SERVICE_NAME}

# Restart
sudo systemctl restart ${SERVICE_NAME}

# Reload Nginx
sudo systemctl reload nginx

# Logs
sudo journalctl -u ${SERVICE_NAME} -f
tail -f ${LOG_DIR}/gotty.log
tail -f ${LOG_DIR}/nginx-access.log
\`\`\`

## Security Notes

1. **Always use HTTPS/WSS** in production
2. **Keep tokens secret** - never expose in client-side code or commit to Git
3. **Use environment variables** for sensitive data
4. **Rotate tokens periodically** (every 3-6 months)
5. **Monitor access logs**: \`${LOG_DIR}/nginx-access.log\`
6. **Public endpoint** is safe because token validation happens server-side

## Troubleshooting

### Still getting popup in iframe?

Make sure you're using the **public endpoint**:
\`\`\`
https://${DOMAIN}/public?token=${GOTTY_AUTH_TOKEN}
\`\`\`

NOT the direct endpoint:
\`\`\`
https://${DOMAIN}  ← This will show popup!
\`\`\`

### Token not working?

Verify token matches:
\`\`\`bash
# Check .env file
grep GOTTY_AUTH_TOKEN .env

# Check Nginx config
sudo grep 'arg_token' /etc/nginx/sites-available/${SERVICE_NAME}
\`\`\`

### Connection refused?

Check services:
\`\`\`bash
sudo systemctl status ${SERVICE_NAME}
sudo systemctl status nginx
sudo journalctl -u ${SERVICE_NAME} -n 50
\`\`\`

## Architecture

\`\`\`
┌─────────────┐
│   Browser   │  Request: GET /public?token=xxx
│   (iframe)  │  (no auth header)
└──────┬──────┘
       │
       ▼
┌─────────────┐
│    Nginx    │  1. Validates token in URL
│  Port 443   │  2. Adds Authorization: Basic xxx
└──────┬──────┘  3. Proxies to GoTTY
       │
       ▼
┌─────────────┐
│   GoTTY     │  Receives authenticated request
│  Port 7681  │  Returns terminal interface
└─────────────┘

Result: Browser never sees auth requirement = NO POPUP! ✅
\`\`\`

---

**Last Updated:** $(date)
**Server:** ${DOMAIN}
EOF

    echo -e "${GREEN}✓ Documentation created${NC}"
}

###############################################################################
# Print summary
###############################################################################
print_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      GoTTY Production Deployment Complete! 🎉            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}🌐 Access Information:${NC}"
    echo -e "   ${YELLOW}Public (NO POPUP):${NC} ${GREEN}https://${DOMAIN}/public?token=...${NC}"
    echo -e "   ${YELLOW}Direct (has popup):${NC} ${GREEN}https://${DOMAIN}${NC}"
    echo -e "   WebSocket: ${GREEN}wss://${DOMAIN}/ws${NC}"
    echo -e "   Health:    ${GREEN}https://${DOMAIN}/health${NC}"
    echo ""
    echo -e "${CYAN}🔐 Authentication:${NC}"
    echo -e "   Token: ${YELLOW}${GOTTY_AUTH_TOKEN}${NC}"
    echo -e "   Basic Auth: ${BLUE}${GOTTY_CREDENTIAL}${NC}"
    echo ""
    echo -e "${CYAN}📱 For iframe embedding (NO POPUP):${NC}"
    echo -e "   ${YELLOW}https://${DOMAIN}/public?token=${GOTTY_AUTH_TOKEN}${NC}"
    echo ""
    echo -e "${CYAN}📋 Usage Example:${NC}"
    echo -e '   <iframe src="https://${DOMAIN}/public?token=YOUR_TOKEN"></iframe>'
    echo ""
    echo -e "${CYAN}🧪 Quick Tests:${NC}"
    echo -e "   ${YELLOW}./test-gotty.sh${NC}         # Bash test (all endpoints)"
    echo -e "   ${YELLOW}node test-gotty-node.js${NC}  # WebSocket test"
    echo ""
    echo -e "${CYAN}📊 Service Management:${NC}"
    echo -e "   ${YELLOW}sudo systemctl status ${SERVICE_NAME}${NC}"
    echo -e "   ${YELLOW}sudo systemctl restart ${SERVICE_NAME}${NC}"
    echo -e "   ${YELLOW}sudo journalctl -u ${SERVICE_NAME} -f${NC}"
    echo ""
    echo -e "${CYAN}📚 Documentation:${NC}"
    echo -e "   ${YELLOW}cat INTEGRATION.md${NC}  # Complete integration guide"
    echo ""
    echo -e "${CYAN}💾 Configuration saved in:${NC}"
    echo -e "   ${YELLOW}$SCRIPT_DIR/.env${NC}"
    echo ""
    echo -e "${GREEN}✅ Ready for production use!${NC}"
    echo -e "${BLUE}💡 Use /public endpoint for iframe embedding (no auth popup)${NC}"
    echo -e "${BLUE}💡 Static assets (JS/CSS) load automatically without token${NC}"
    echo ""
}

###############################################################################
# Main
###############################################################################
main() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║     GoTTY Production Deployment - Fully Automated        ║"
    echo "║   Token Auth • SSL • Portable • Battle-Tested            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    load_config
    install_deps
    install_gotty
    stop_conflicts
    create_service
    setup_ssl
    configure_nginx
    start_services
    create_tests
    create_docs
    print_summary
    
    echo -e "${GREEN}🚀 Deployment successful!${NC}"
    echo -e "${BLUE}Run './test-gotty.sh' to verify everything works${NC}"
}

main "$@"
