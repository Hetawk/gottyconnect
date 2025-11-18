# GoTTY Terminal Server

WebSocket-based terminal server for secure remote VPS access. Provides WebSocket API for client applications to execute terminal commands without requiring direct SSH connections.

## Features

- 🔒 **Secure WebSocket Communication** - Encrypted WSS protocol
- 🔑 **Dual Authentication** - Token-based + Basic Auth support
- 🌐 **SSL/HTTPS** - Auto-configured with Let's Encrypt
- 🚀 **Auto-Installation** - One-command deployment
- 📊 **Systemd Service** - Auto-restart and monitoring
- 🔄 **Nginx Reverse Proxy** - Professional production setup

## Quick Start

### 1. Configure Environment

```bash
cp .env.example .env
nano .env
```

Set these required values:

- `GOTTY_DOMAIN` - Your domain name
- `SSL_EMAIL` - Email for SSL certificate
- `GOTTY_AUTH_TOKEN` - Generate with: `openssl rand -hex 32`
- `GOTTY_CREDENTIAL` - Basic auth credentials (username:password)

### 2. Deploy

```bash
sudo ./deploy-gotty-production.sh
```

The script automatically:

- Installs GoTTY binary
- Configures SSL certificates
- Sets up nginx reverse proxy
- Creates systemd service
- Detects and handles port conflicts

### 3. Test Connection

```bash
./test-gotty.sh
```

## WebSocket API

### Connection

```javascript
const ws = new WebSocket("wss://your-domain.com/ws", {
  headers: {
    Authorization: "Basic " + btoa("username:password"),
  },
});
```

### Send Command

Commands are prefixed with `0` (ASCII 48) and terminated with `\n`:

```javascript
ws.send("0pwd\n");
ws.send("0ls -la\n");
ws.send("0systemctl status nginx\n");
```

### Receive Output

Output messages start with `0` byte followed by base64-encoded text:

```javascript
ws.on("message", (data) => {
  if (data[0] === 0x30) {
    // Check for '0' prefix
    const encoded = data.slice(1).toString();
    const output = Buffer.from(encoded, "base64").toString();
    console.log(output);
  }
});
```

## Service Management

```bash
# Check status
sudo systemctl status gottyconnect

# View logs
sudo journalctl -u gottyconnect -f

# Restart service
sudo systemctl restart gottyconnect

# Stop service
sudo systemctl stop gottyconnect
```

## Access Methods

### Token-Based (Iframe-Friendly)

No browser authentication popup:

```
https://your-domain.com/public?token=YOUR_AUTH_TOKEN
```

### Basic Auth (Direct Access)

Browser will prompt for credentials:

```
https://your-domain.com
```

### WebSocket (API)

For programmatic access:

```
wss://your-domain.com/ws
```

## Security Notes

- Never commit `.env` file to version control
- Rotate tokens regularly
- Use strong credentials
- SSL certificates auto-renew via certbot
- Port conflicts auto-detected and resolved

## Client Integration

Client applications typically use an API middleware (like xterm) to proxy WebSocket connections:

```typescript
const response = await fetch(
  "https://api.yourservice.com/api/terminal/execute",
  {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${CLIENT_API_KEY}`,
    },
    body: JSON.stringify({
      command: "pwd",
    }),
  }
);
```

The middleware handles:

- Authentication with GoTTY server
- WebSocket connection management
- Command execution and response handling
- Error handling and retries

## Requirements

- Ubuntu/Debian VPS
- Root or sudo access
- Domain with DNS configured
- Ports 80, 443 open (for SSL verification)

## Troubleshooting

### Service Not Starting

```bash
sudo journalctl -u gottyconnect -n 50
```

### Port Conflict

The deploy script auto-detects conflicts. To manually check:

```bash
sudo lsof -i :7680
```

### SSL Issues

Verify DNS is pointing to your VPS:

```bash
dig your-domain.com +short
```

Manually renew certificate:

```bash
sudo certbot renew
```

### WebSocket Connection Failed

Check nginx configuration:

```bash
sudo nginx -t
sudo systemctl status nginx
```

## File Structure

```
gottyconnect/
├── .env.example           # Configuration template
├── deploy-gotty-production.sh  # Deployment script
├── test-gotty.sh         # Connection tests
├── SETUP-NOTES.md        # Quick reference guide
└── README.md             # This file
```

## Status

**Production Ready** - Deployed and tested in production environments.

Last Updated: November 2025
