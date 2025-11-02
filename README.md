# GoTTY Terminal Server - Production Deployment

Complete automated deployment for GoTTY web-based terminal server with SSL, authentication, and WebSocket support.

## ✨ Features

- 🚀 **Single-script deployment** - One command does everything
- 🔐 **Secure authentication** - HTTP Basic Auth for terminal access
- 🔒 **SSL/HTTPS** - Automatic Let's Encrypt certificates
- 🌐 **WebSocket support** - Full bidirectional communication
- 📦 **Portable** - Copy to any server and deploy
- 🛡️ **Production-ready** - Auto-restart, logging, and monitoring
- ⚙️ **Auto port detection** - No conflicts with existing services

## 🚀 Quick Start

### 1. Configure Environment

```bash
cp .env.example .env
nano .env
```

Update with your values:
```bash
GOTTY_DOMAIN=terminal.yourdomain.com
SSL_EMAIL=admin@yourdomain.com
GOTTY_CREDENTIAL=yourusername:yourpassword
```

### 2. Deploy

```bash
sudo ./deploy-gotty-production.sh
```

That's it! The script handles:
- ✅ Installing GoTTY and dependencies
- ✅ Configuring SSL certificates
- ✅ Setting up nginx reverse proxy
- ✅ Creating systemd service
- ✅ Auto port detection

### 3. Test

```bash
./test-gotty.sh
```

## 📡 Access Your Terminal

**Web Browser:**
```
https://your-domain.com
```
Login with your `GOTTY_CREDENTIAL` username:password

**Programmatic WebSocket:**
```bash
# Using websocat
websocat -H="Authorization: Basic $(echo -n 'username:password' | base64)" \
  wss://your-domain.com/ws

# Using Python
python3 test/websocket-client.py

# Using Node.js (optional - requires: npm install ws)
node test/test-gotty-command.js
```

---

## 📚 WebSocket API Documentation

### Connection

Connect to: `wss://your-domain.com/ws`

**Authentication:** HTTP Basic Auth in connection headers

```javascript
// Node.js
const WebSocket = require('ws');
const ws = new WebSocket('wss://your-domain.com/ws', {
    headers: {
        'Authorization': 'Basic ' + Buffer.from('username:password').toString('base64')
    }
});
```

```python
# Python
import websocket
import base64

auth = base64.b64encode(b'username:password').decode()
ws = websocket.create_connection(
    'wss://your-domain.com/ws',
    header={'Authorization': f'Basic {auth}'}
)
```

### Protocol

GoTTY uses a simple binary protocol:

**Message Format:**
```
[Type Byte][Base64 Payload]
```

**Type Bytes:**
- `0` (0x30): Input/Output data
- `1` (0x31): Output only
- `2` (0x32): Ping
- `3` (0x33): Set window title
- `4` (0x34): Set preferences

### Sending Commands

Send commands with type `0` followed by the command:

```javascript
// Format: '0' + command + '\n'
ws.send('0pwd\n');
ws.send('0ls -la\n');
ws.send('0echo "Hello"\n');
```

```python
# Python
ws.send(b'0pwd\n')
ws.send(b'0ls -la\n')
```

```bash
# Using websocat
echo "0pwd" | websocat -H="Authorization: Basic $(echo -n 'user:pass' | base64)" \
  wss://your-domain.com/ws
```

### Receiving Output

Output comes as binary messages starting with type byte `0` (0x30), followed by base64-encoded data:

```javascript
// Node.js
ws.on('message', (data) => {
    const buffer = Buffer.from(data);
    if (buffer[0] === 0x30) {  // Type '0'
        const base64Data = buffer.slice(1).toString('utf-8');
        const output = Buffer.from(base64Data, 'base64').toString('utf-8');
        console.log(output);
    }
});
```

```python
# Python
import base64

data = ws.recv()
if data[0] == 0x30:  # Type '0'
    output = base64.b64decode(data[1:]).decode('utf-8')
    print(output)
```

### Complete Example

```javascript
const WebSocket = require('ws');

// Connect with auth
const ws = new WebSocket('wss://your-domain.com/ws', {
    headers: {
        'Authorization': 'Basic ' + Buffer.from('user:pass').toString('base64')
    }
});

ws.on('open', () => {
    console.log('Connected!');
    
    // Send command
    ws.send('0pwd\n');
    
    // Send multiple commands
    setTimeout(() => ws.send('0whoami\n'), 1000);
    setTimeout(() => ws.send('0date\n'), 2000);
});

ws.on('message', (data) => {
    const buffer = Buffer.from(data);
    if (buffer[0] === 0x30) {
        const decoded = Buffer.from(buffer.slice(1).toString(), 'base64');
        console.log('Output:', decoded.toString());
    }
});

ws.on('error', (err) => console.error('Error:', err));
ws.on('close', () => console.log('Disconnected'));
```

### Error Handling

- **401 Unauthorized**: Invalid credentials
- **Connection refused**: Service not running or firewall blocking
- **Connection timeout**: Network issues or wrong domain

```javascript
ws.on('error', (error) => {
    if (error.message.includes('401')) {
        console.error('Authentication failed - check credentials');
    }
});
```

---

## 🔧 Service Management

```bash
# Check status
sudo systemctl status gottyconnect

# Restart
sudo systemctl restart gottyconnect

# View logs
sudo journalctl -u gottyconnect -f
tail -f /var/log/gottyconnect/gotty.log
```

## 🌍 Deploy on New Server

1. **Copy repository:**
```bash
git clone https://github.com/Hetawk/gottyconnect.git
cd gottyconnect
```

2. **Configure:**
```bash
cp .env.example .env
nano .env  # Update domain, email, credentials
```

3. **Deploy:**
```bash
sudo ./deploy-gotty-production.sh
```

## 🔐 Authentication

GoTTY uses HTTP Basic Authentication. Set credentials in `.env`:

```bash
GOTTY_CREDENTIAL=myuser:mypassword
```

For WebSocket connections, include the Authorization header:
```bash
Authorization: Basic <base64-encoded-username:password>
```

## 📋 Configuration Options

Edit `.env` to customize:

| Variable | Description | Default |
|----------|-------------|---------|
| `GOTTY_DOMAIN` | Your domain name | Required |
| `SSL_EMAIL` | Email for SSL cert | Required |
| `GOTTY_PORT` | Port (auto-detects conflicts) | 7680 |
| `GOTTY_CREDENTIAL` | username:password for auth | Required |

## 🧪 Testing

**Automated test:**
```bash
./test-gotty.sh
```

**Manual test:**
```bash
# Web interface
curl -u "username:password" https://your-domain.com

# Health check (if enabled)
curl https://your-domain.com/health
```

**WebSocket test (optional - requires Node.js):**
```bash
cd test/
npm install ws dotenv
node test-gotty-command.js
```

## 🛠️ Troubleshooting

**Port already in use?**
- Script auto-detects and uses next available port
- Check: `sudo ss -tlnp | grep gotty`

**SSL certificate fails?**
- Ensure DNS points to your server
- Check: `dig +short yourdomain.com`

**Can't connect?**
- Check firewall: `sudo ufw allow 443/tcp && sudo ufw allow 80/tcp`
- Check nginx: `sudo nginx -t`

**Service won't start?**
- Check logs: `sudo journalctl -u gottyconnect -xe`
- Check config: `sudo systemctl status gottyconnect`

## 📁 Project Structure

```
.
├── deploy-gotty-production.sh  # Main deployment script
├── .env.example                # Configuration template
├── test-gotty.sh              # Automated bash test script
├── test/                      # Optional test examples
│   └── test-gotty-command.js  # Node.js WebSocket example
└── README.md                  # This file
```

## 🔒 Security Features

- ✅ HTTPS/SSL only (Let's Encrypt)
- ✅ HTTP Basic Authentication
- ✅ Auto SSL certificate renewal
- ✅ Security headers (HSTS, X-Frame-Options)
- ✅ Credentials not logged or exposed
- ✅ Isolated systemd service

## 📝 Environment Variables

**Required:**
- `GOTTY_DOMAIN` - Your domain (e.g., terminal.example.com)
- `SSL_EMAIL` - Email for Let's Encrypt notifications
- `GOTTY_CREDENTIAL` - Authentication (format: username:password)

**Optional:**
- `GOTTY_PORT` - Port number (default: 7680, auto-detects conflicts)

## 🎯 Use Cases

- **Remote server management** via web browser
- **Mobile terminal access** from anywhere
- **Programmatic command execution** via WebSocket API
- **Embedded terminal** in web applications
- **Secure shell access** without SSH clients

## 🤝 Contributing

Contributions welcome! Please feel free to submit issues and pull requests.

## 📄 License

MIT License

## 🙏 Acknowledgments

Built with [GoTTY](https://github.com/yudai/gotty) - Share your terminal as a web application

---

**Need help?** Open an issue or check the test examples in the `test/` directory.
