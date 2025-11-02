# GoTTY Connect - Web Terminal with iframe Support# GoTTY Terminal Server - Production Deployment



A production-ready GoTTY deployment solution that works seamlessly in iframes **without authentication popups**. Perfect for embedding terminal access in web applications.Complete automated deployment for GoTTY web-based terminal server with SSL, authentication, and WebSocket support.



## ✨ Features## ✨ Features



- 🚀 **Single-Script Deployment** - Complete setup in ~3 minutes- 🚀 **Single-script deployment** - One command does everything

- 🔐 **No Auth Popup in iframes** - Token-based authentication via URL parameters- 🔐 **Secure authentication** - HTTP Basic Auth for terminal access

- 🔒 **SSL/HTTPS** - Automatic Let's Encrypt certificate generation- 🔒 **SSL/HTTPS** - Automatic Let's Encrypt certificates

- 📱 **iframe-Friendly** - Works perfectly in Next.js, React, Vue, etc.- 🌐 **WebSocket support** - Full bidirectional communication

- 🔧 **Automatic Configuration** - Port detection, service setup, nginx config- 📦 **Portable** - Copy to any server and deploy

- 🌐 **WebSocket Support** - Full terminal functionality with proper WebSocket handling- 🛡️ **Production-ready** - Auto-restart, logging, and monitoring

- 📦 **Portable** - Works on any Linux server with a single command- ⚙️ **Auto port detection** - No conflicts with existing services



## 🚀 Quick Start## 🚀 Quick Start



### 1. Clone Repository### 1. Configure Environment



```bash```bash

git clone https://github.com/Hetawk/gottyconnect.gitcp .env.example .env

cd gottyconnectnano .env

``````



### 2. Create ConfigurationUpdate with your values:

```bash

```bashGOTTY_DOMAIN=terminal.yourdomain.com

cp .env.example .envSSL_EMAIL=admin@yourdomain.com

nano .envGOTTY_CREDENTIAL=yourusername:yourpassword

``````



**Required variables:**### 2. Deploy

```env

GOTTY_DOMAIN=your-domain.com```bash

SSL_EMAIL=your-email@example.comsudo ./deploy-gotty-production.sh

GOTTY_AUTH_TOKEN=your_secure_random_token_here```

```

That's it! The script handles:

**Generate secure token:**- ✅ Installing GoTTY and dependencies

```bash- ✅ Configuring SSL certificates

openssl rand -hex 32- ✅ Setting up nginx reverse proxy

```- ✅ Creating systemd service

- ✅ Auto port detection

### 3. Deploy

### 3. Test

```bash

sudo ./deploy-gotty-production.sh```bash

```./test-gotty.sh

```

That's it! 🎉 Your terminal server is now running.

## 📡 Access Your Terminal

## 📋 Requirements

**Web Browser:**

- Linux server (Ubuntu/Debian recommended)```

- Root or sudo accesshttps://your-domain.com

- Domain name pointing to your server```

- Ports 80 and 443 availableLogin with your `GOTTY_CREDENTIAL` username:password



## 🌐 Usage**Programmatic WebSocket:**

```bash

### Direct Browser Access# Using websocat

websocat -H="Authorization: Basic $(echo -n 'username:password' | base64)" \

```  wss://your-domain.com/ws

https://your-domain.com

```# Using Python

python3 test/websocket-client.py

**Note:** This will show HTTP Basic Auth popup (standard GoTTY behavior)

# Using Node.js (optional - requires: npm install ws)

### iframe Embedding (No Popup!)node test/test-gotty-command.js

```

```

https://your-domain.com/public?token=YOUR_TOKEN---

```

## 📚 WebSocket API Documentation

**No authentication popup!** Perfect for embedding in applications.

### Connection

### Next.js Example

Connect to: `wss://your-domain.com/ws`

```typescript

// components/Terminal.tsx**Authentication:** HTTP Basic Auth in connection headers

export default function Terminal() {

  const terminalUrl = `/api/terminal/url`;```javascript

// Node.js

  return (const WebSocket = require('ws');

    <iframeconst ws = new WebSocket('wss://your-domain.com/ws', {

      src={terminalUrl}    headers: {

      style={{ width: '100%', height: '600px', border: 'none' }}        'Authorization': 'Basic ' + Buffer.from('username:password').toString('base64')

      sandbox="allow-same-origin allow-scripts allow-forms"    }

    />});

  );```

}

```python

// app/api/terminal/url/route.ts# Python

import { NextResponse } from 'next/server';import websocket

import base64

export async function GET() {

  const url = `${process.env.GOTTY_PUBLIC_URL}/public?token=${process.env.GOTTY_AUTH_TOKEN}`;auth = base64.b64encode(b'username:password').decode()

  return NextResponse.json({ url });ws = websocket.create_connection(

}    'wss://your-domain.com/ws',

```    header={'Authorization': f'Basic {auth}'}

)

### Environment Variables for Your App```



```env### Protocol

GOTTY_PUBLIC_URL=https://your-gotty-domain.com

GOTTY_AUTH_TOKEN=your_token_hereGoTTY uses a simple binary protocol:

```

**Message Format:**

## 🧪 Testing```

[Type Byte][Base64 Payload]

```bash```

./test-gotty.sh

```**Type Bytes:**

- `0` (0x30): Input/Output data

Expected output:- `1` (0x31): Output only

```- `2` (0x32): Ping

✅ Health check OK- `3` (0x33): Set window title

✅ Public endpoint works (NO AUTH POPUP)- `4` (0x34): Set preferences

✅ Invalid token rejected (401)

✅ Basic Auth works### Sending Commands

```

Send commands with type `0` followed by the command:

## 🏗️ Architecture

```javascript

```// Format: '0' + command + '\n'

Browser (iframe) → Nginx (validates token) → GoTTY (authenticated)ws.send('0pwd\n');

Result: No popup! ✅ws.send('0ls -la\n');

```ws.send('0echo "Hello"\n');

```

### How It Works

```python

1. Browser loads `/public?token=xxx` (no auth header sent)# Python

2. Nginx validates token in URLws.send(b'0pwd\n')

3. Nginx adds Authorization header server-sidews.send(b'0ls -la\n')

4. Browser never sees auth requirement```

5. Terminal loads without popup!

```bash

## 🔐 Security# Using websocat

echo "0pwd" | websocat -H="Authorization: Basic $(echo -n 'user:pass' | base64)" \

✅ **Best Practices:**  wss://your-domain.com/ws

- Strong random tokens (64 characters)```

- HTTPS only (auto-enforced)

- Tokens in environment variables### Receiving Output

- Never committed to Git

- Server-side validationOutput comes as binary messages starting with type byte `0` (0x30), followed by base64-encoded data:



### Rotate Tokens```javascript

// Node.js

```bashws.on('message', (data) => {

# Generate new token    const buffer = Buffer.from(data);

openssl rand -hex 32    if (buffer[0] === 0x30) {  // Type '0'

        const base64Data = buffer.slice(1).toString('utf-8');

# Update .env file        const output = Buffer.from(base64Data, 'base64').toString('utf-8');

nano .env        console.log(output);

    }

# Update Nginx config});

sudo nano /etc/nginx/sites-available/gottyconnect```



# Reload```python

sudo systemctl reload nginx# Python

```import base64



## 📊 Service Managementdata = ws.recv()

if data[0] == 0x30:  # Type '0'

```bash    output = base64.b64decode(data[1:]).decode('utf-8')

# Check status    print(output)

sudo systemctl status gottyconnect```



# View logs### Complete Example

sudo journalctl -u gottyconnect -f

```javascript

# Restartconst WebSocket = require('ws');

sudo systemctl restart gottyconnect

```// Connect with auth

const ws = new WebSocket('wss://your-domain.com/ws', {

## 🐛 Troubleshooting    headers: {

        'Authorization': 'Basic ' + Buffer.from('user:pass').toString('base64')

### Terminal Not Loading    }

});

```bash

# Check servicews.on('open', () => {

sudo systemctl status gottyconnect    console.log('Connected!');

    

# Check logs    // Send command

sudo journalctl -u gottyconnect -n 50    ws.send('0pwd\n');

```    

    // Send multiple commands

### Still Getting Auth Popup    setTimeout(() => ws.send('0whoami\n'), 1000);

    setTimeout(() => ws.send('0date\n'), 2000);

Make sure you're using:});

```

✅ https://your-domain.com/public?token=xxx  (No popup)ws.on('message', (data) => {

❌ https://your-domain.com/                   (Has popup)    const buffer = Buffer.from(data);

```    if (buffer[0] === 0x30) {

        const decoded = Buffer.from(buffer.slice(1).toString(), 'base64');

### WebSocket Fails        console.log('Output:', decoded.toString());

    }

```bash});

# Check Nginx config

sudo nginx -tws.on('error', (err) => console.error('Error:', err));

ws.on('close', () => console.log('Disconnected'));

# Reload Nginx```

sudo systemctl reload nginx

```### Error Handling



## 📦 What's Included- **401 Unauthorized**: Invalid credentials

- **Connection refused**: Service not running or firewall blocking

```- **Connection timeout**: Network issues or wrong domain

gottyconnect/

├── deploy-gotty-production.sh   # Main deployment script```javascript

├── test-gotty.sh                # Test scriptws.on('error', (error) => {

├── .env.example                 # Environment template    if (error.message.includes('401')) {

├── README.md                    # This file        console.error('Authentication failed - check credentials');

├── COMPLETE-FIX-SUMMARY.md     # Technical documentation    }

└── test/});

    └── test-gotty-command.js    # WebSocket test```

```

---

## 📝 Configuration Reference

## 🔧 Service Management

| Variable | Required | Description |

|----------|----------|-------------|```bash

| `GOTTY_DOMAIN` | ✅ | Your domain name |# Check status

| `SSL_EMAIL` | ✅ | Email for SSL certificates |sudo systemctl status gottyconnect

| `GOTTY_AUTH_TOKEN` | ✅ | Authentication token |

| `GOTTY_PORT` | ⚠️ | Port (auto-detected if not set) |# Restart

sudo systemctl restart gottyconnect

## 🎯 Use Cases

# View logs

- **DevOps Dashboards** - Embed terminal in admin panelssudo journalctl -u gottyconnect -f

- **Educational Platforms** - Provide students terminal accesstail -f /var/log/gottyconnect/gotty.log

- **CI/CD Tools** - Real-time build monitoring```

- **System Monitoring** - Quick terminal access

- **Remote Support** - Share terminal sessions## 🌍 Deploy on New Server



## 🤝 Contributing1. **Copy repository:**

```bash

Contributions welcome! Please submit a Pull Request.git clone https://github.com/Hetawk/gottyconnect.git

cd gottyconnect

## 📄 License```



MIT License2. **Configure:**

```bash

## 🙏 Acknowledgmentscp .env.example .env

nano .env  # Update domain, email, credentials

- [GoTTY](https://github.com/yudai/gotty) - Terminal as a web application```

- [Let's Encrypt](https://letsencrypt.org/) - Free SSL certificates

- [Nginx](https://nginx.org/) - Web server3. **Deploy:**

```bash

## 📞 Supportsudo ./deploy-gotty-production.sh

```

- Check [Troubleshooting](#-troubleshooting)

- Review logs: `sudo journalctl -u gottyconnect -f`## 🔐 Authentication

- Open GitHub issue

- See [COMPLETE-FIX-SUMMARY.md](COMPLETE-FIX-SUMMARY.md)GoTTY uses HTTP Basic Authentication. Set credentials in `.env`:



---```bash

GOTTY_CREDENTIAL=myuser:mypassword

**Status:** ✅ Production Ready | **Deploy Time:** ~3 minutes | **Works:** Anywhere!```


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
