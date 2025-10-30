# ttyd Web Terminal Deployment

A simple, robust one-script deployment solution for ttyd web terminal on your VPS. This allows you to access your server's terminal through a web browser, perfect for integrating with Vercel apps or mobile applications.

## Features

- ✅ **One-command installation** - Deploy everything with a single script
- 🔐 **Built-in authentication** - Username/password protection
- 🚀 **Systemd service** - Auto-start on boot, automatic restarts
- 🌐 **Optional Nginx reverse proxy** - SSL/HTTPS support with Let's Encrypt
- 📱 **Client-ready** - Generated `.env` file for your web/mobile apps
- 🔧 **Configurable** - Use `.env` file or interactive prompts

## Quick Start

### Method 1: Interactive Installation (Recommended for first-time users)

```bash
# Download the script
wget https://raw.githubusercontent.com/YOUR_REPO/deploy-ttyd.sh

# Make it executable
chmod +x deploy-ttyd.sh

# Run with sudo
sudo ./deploy-ttyd.sh
```

The script will prompt you for:
- Username (default: admin)
- Password (leave empty to auto-generate)
- Port (default: 7681)
- Nginx setup (optional)

### Method 2: Automated Installation with .env

```bash
# Copy the example configuration
cp .env.example .env

# Edit with your settings
nano .env

# Run the script (it will read from .env automatically)
sudo ./deploy-ttyd.sh
```

### Method 3: One-liner with environment variables

```bash
sudo TTYD_USERNAME=myuser TTYD_PASSWORD=mypass123 TTYD_PORT=7681 ./deploy-ttyd.sh
```

## Configuration Options

All options can be set via:
1. `.env` file in the same directory
2. Environment variables
3. Interactive prompts during installation

### Available Options

| Variable | Default | Description |
|----------|---------|-------------|
| `TTYD_VERSION` | `1.7.7` | ttyd version to install |
| `TTYD_PORT` | `7681` | Port for ttyd to listen on |
| `TTYD_USERNAME` | `admin` | Username for authentication |
| `TTYD_PASSWORD` | (generated) | Password for authentication |
| `INSTALL_NGINX` | `false` | Install and configure Nginx reverse proxy |
| `DOMAIN` | - | Your domain (e.g., terminal.yourdomain.com) |
| `SSL_EMAIL` | - | Email for Let's Encrypt SSL certificate |

## Usage Examples

### Basic Installation (Direct Access)

```bash
sudo ./deploy-ttyd.sh
```

Access via: `http://YOUR_SERVER_IP:7681`

### With Nginx and SSL

Create `.env` file:
```env
TTYD_USERNAME=admin
TTYD_PASSWORD=SuperSecure123!
TTYD_PORT=7681
INSTALL_NGINX=true
DOMAIN=terminal.yourdomain.com
SSL_EMAIL=you@example.com
```

Run:
```bash
sudo ./deploy-ttyd.sh
```

Access via: `https://terminal.yourdomain.com`

## After Installation

### Service Management

```bash
# Check status
sudo systemctl status ttyd

# Start service
sudo systemctl start ttyd

# Stop service
sudo systemctl stop ttyd

# Restart service
sudo systemctl restart ttyd

# View logs
sudo journalctl -u ttyd -f
```

### Important Files

- `/root/ttyd-config.txt` - Your credentials and configuration
- `/root/ttyd-client.env` - Environment variables for your client apps
- `/etc/systemd/system/ttyd.service` - Systemd service file
- `/etc/nginx/sites-available/ttyd` - Nginx configuration (if installed)

## Integrating with Your Applications

### For Vercel/Next.js Applications

1. After deployment, copy the contents of `/root/ttyd-client.env`
2. Add these variables to your Vercel project settings
3. Access in your code:

```javascript
// pages/terminal.js or app/terminal/page.js
export default function Terminal() {
  const ttydUrl = process.env.TTYD_URL;
  const username = process.env.TTYD_USERNAME;
  const password = process.env.TTYD_PASSWORD;

  return (
    <div className="terminal-container">
      <iframe
        src={ttydUrl}
        width="100%"
        height="600px"
        title="Terminal"
      />
    </div>
  );
}
```

### For React/Vue Apps

```javascript
// In your .env.local
VITE_TTYD_URL=https://terminal.yourdomain.com
VITE_TTYD_USERNAME=admin
VITE_TTYD_PASSWORD=your_password

// In your component
const terminalUrl = import.meta.env.VITE_TTYD_URL;
```

### For Mobile Apps (React Native / Flutter)

```javascript
// .env
TTYD_URL=https://terminal.yourdomain.com
TTYD_USERNAME=admin
TTYD_PASSWORD=your_password

// In your app
import { TTYD_URL, TTYD_USERNAME, TTYD_PASSWORD } from '@env';

<WebView 
  source={{ uri: TTYD_URL }}
  style={{ flex: 1 }}
/>
```

### Programmatic Access with Authentication

If you need to connect programmatically:

```javascript
const WebSocket = require('ws');

const username = 'admin';
const password = 'your_password';
const auth = Buffer.from(`${username}:${password}`).toString('base64');

const ws = new WebSocket('wss://terminal.yourdomain.com/ws', {
  headers: {
    'Authorization': `Basic ${auth}`
  }
});

ws.on('open', () => {
  console.log('Connected to terminal');
});

ws.on('message', (data) => {
  console.log('Received:', data.toString());
});
```

## Security Considerations

### ⚠️ Important Security Notes

1. **Always use HTTPS in production** - Use the Nginx + SSL option
2. **Use strong passwords** - Avoid common passwords
3. **Restrict access by IP** - Configure firewall rules if needed
4. **Regular updates** - Keep ttyd and your system updated
5. **Monitor logs** - Check for suspicious activity

### Additional Security: Restrict by IP

Edit `/etc/systemd/system/ttyd.service` and add:

```ini
ExecStart=/usr/local/bin/ttyd \
    --port 7681 \
    --credential admin:password \
    --interface 127.0.0.1 \  # Only allow local connections
    bash
```

Then configure Nginx to restrict by IP:

```nginx
location / {
    # Only allow specific IPs
    allow 1.2.3.4;
    deny all;
    
    proxy_pass http://127.0.0.1:7681;
    # ... rest of config
}
```

## Troubleshooting

### Service won't start

```bash
# Check service status
sudo systemctl status ttyd

# Check logs
sudo journalctl -u ttyd -n 50

# Test ttyd manually
sudo /usr/local/bin/ttyd --port 7681 bash
```

### Port already in use

```bash
# Find what's using the port
sudo lsof -i :7681

# Kill the process or change TTYD_PORT in .env
```

### Can't access from browser

```bash
# Check if ttyd is listening
sudo netstat -tulpn | grep 7681

# Check firewall
sudo ufw status

# Allow port through firewall
sudo ufw allow 7681/tcp
```

### Nginx SSL issues

```bash
# Manually run certbot
sudo certbot --nginx -d terminal.yourdomain.com

# Check nginx configuration
sudo nginx -t

# View nginx logs
sudo tail -f /var/log/nginx/error.log
```

## Updating ttyd

```bash
# Stop the service
sudo systemctl stop ttyd

# Download new version
export TTYD_VERSION=1.8.0  # or latest version
wget https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64

# Replace binary
sudo mv ttyd.x86_64 /usr/local/bin/ttyd
sudo chmod +x /usr/local/bin/ttyd

# Restart service
sudo systemctl start ttyd
```

## Uninstalling

```bash
# Stop and disable service
sudo systemctl stop ttyd
sudo systemctl disable ttyd

# Remove files
sudo rm /usr/local/bin/ttyd
sudo rm /etc/systemd/system/ttyd.service
sudo rm /etc/nginx/sites-enabled/ttyd
sudo rm /etc/nginx/sites-available/ttyd

# Reload systemd
sudo systemctl daemon-reload

# Restart nginx (if installed)
sudo systemctl restart nginx
```

## Supported Platforms

- ✅ Ubuntu 18.04+
- ✅ Debian 10+
- ✅ CentOS 7+
- ✅ RHEL 7+
- ✅ Fedora 30+

Supported architectures:
- x86_64 (Intel/AMD 64-bit)
- aarch64 (ARM 64-bit)
- armhf (ARM 32-bit)

## FAQ

**Q: Can I run multiple ttyd instances?**  
A: Yes! Just change the port for each instance and create separate service files.

**Q: How do I change the password after installation?**  
A: Edit `/etc/systemd/system/ttyd.service`, update the credential line, then run:
```bash
sudo systemctl daemon-reload
sudo systemctl restart ttyd
```

**Q: Can I use this with Docker?**  
A: While this script installs directly on the host, you can also run ttyd in Docker. This script is for bare-metal/VPS installations.

**Q: Does this work with mobile apps?**  
A: Yes! Use a WebView component to embed the terminal in your mobile app.

**Q: Can I customize the terminal appearance?**  
A: Yes! ttyd supports many options. Edit the service file to add options like `--theme` or custom fonts.

## Advanced Configuration

### Custom ttyd options

Edit `/etc/systemd/system/ttyd.service` to add more options:

```ini
ExecStart=/usr/local/bin/ttyd \
    --port 7681 \
    --credential admin:password \
    --writable \
    --reconnect 5 \
    --max-clients 10 \
    --once \
    --title-format "Terminal - {hostname}" \
    bash
```

See all options: `ttyd --help`

### Using with tmux

For persistent sessions:

```ini
ExecStart=/usr/local/bin/ttyd \
    --port 7681 \
    --credential admin:password \
    tmux new -A -s main
```

## Contributing

Found a bug or have a suggestion? Please open an issue!

## License

MIT License - Feel free to use and modify as needed.

## Resources

- [ttyd GitHub](https://github.com/tsl0922/ttyd)
- [ttyd Documentation](https://github.com/tsl0922/ttyd/wiki)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt](https://letsencrypt.org/)
