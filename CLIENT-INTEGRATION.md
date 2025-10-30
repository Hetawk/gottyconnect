# Client Integration Guide

## 🔐 Token-Based Authentication

Your ttyd terminal uses **token-based authentication** for security. All requests must include the `X-Auth-Token` header.

### Connection Details

```bash
# Add these to your app's environment variables:
TTYD_URL=https://ttydconnect.ekddigital.com
TTYDCONNECT_AUTH_TOKEN=<your-generated-token-from-deployment>
```

The `TTYDCONNECT_AUTH_TOKEN` is **automatically generated** during deployment and saved in `.env`.

### Security Notes

⚠️ **Important**:
- Keep your `TTYDCONNECT_AUTH_TOKEN` **SECRET** - treat it like a password
- Never commit the token to version control
- Only share with trusted applications
- All connections are **encrypted via HTTPS/WSS**
- Rotate the token if compromised

---

## 📱 Integration Examples

### 1. Next.js/Vercel (Server-Side API Route)

```javascript
// pages/api/execute-command.js
export default async function handler(req, res) {
  const { command } = req.body;
  
  // Server-side can send auth header
  const ws = require('ws');
  const socket = new ws.WebSocket('wss://ttydconnect.ekddigital.com', {
    headers: {
      'X-Auth-Token': process.env.TTYDCONNECT_AUTH_TOKEN,
    },
  });

  socket.on('open', () => {
    socket.send(command + '\n');
  });

  socket.on('message', (data) => {
    res.status(200).json({ output: data.toString() });
    socket.close();
  });
}
```

**Vercel Environment Variables:**
```
TTYD_URL=https://ttydconnect.ekddigital.com
TTYDCONNECT_AUTH_TOKEN=your_generated_token_here
```

### 2. Node.js Backend (Full Example)

```javascript
const WebSocket = require('ws'); // npm install ws

const TTYD_URL = 'wss://ttydconnect.ekddigital.com';
const AUTH_TOKEN = process.env.TTYDCONNECT_AUTH_TOKEN;

// Connect with authentication
const ws = new WebSocket(TTYD_URL, {
  headers: {
    'X-Auth-Token': AUTH_TOKEN,
  },
});

ws.on('open', () => {
  console.log('✅ Connected to terminal');
  
  // Send commands
  ws.send('pwd\n');
  ws.send('ls -la\n');
});

ws.on('message', (data) => {
  console.log('Output:', data.toString());
});

ws.on('error', (error) => {
  console.error('❌ Error:', error.message);
});

ws.on('close', () => {
  console.log('Connection closed');
});
```

### 3. Python Backend

```python
import websocket
import os

TTYD_URL = "wss://ttydconnect.ekddigital.com"
AUTH_TOKEN = os.getenv("TTYDCONNECT_AUTH_TOKEN")

# Connect with auth header
ws = websocket.create_connection(
    TTYD_URL,
    header={
        "X-Auth-Token": AUTH_TOKEN
    }
)

# Send command
ws.send("ls -la\n")

# Receive output
result = ws.recv()
print(f"Output: {result}")

ws.close()
```

### 4. cURL Testing

```bash
# Test with token (should work)
curl -H "X-Auth-Token: your_token_here" \
     https://ttydconnect.ekddigital.com

# Test without token (should return 401)
curl https://ttydconnect.ekddigital.com
# Returns: 401 Unauthorized: Invalid or missing X-Auth-Token header
```

### 5. React Native (via Backend Proxy)

Since React Native WebSocket doesn't support custom headers, use a backend proxy:

```javascript
// Your Backend API
app.post('/api/terminal/execute', async (req, res) => {
  const { command } = req.body;
  const ws = new WebSocket('wss://ttydconnect.ekddigital.com', {
    headers: { 'X-Auth-Token': process.env.TTYDCONNECT_AUTH_TOKEN }
  });
  
  ws.on('open', () => ws.send(command + '\n'));
  ws.on('message', (data) => {
    res.json({ output: data.toString() });
    ws.close();
  });
});

// React Native App
const executeCommand = async (command) => {
  const response = await fetch('https://your-api.com/api/terminal/execute', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ command }),
  });
  return await response.json();
};
```

### 6. Express.js Proxy Server

```javascript
const express = require('express');
const WebSocket = require('ws');
const app = express();

app.post('/terminal/execute', (req, res) => {
  const { command } = req.body;
  
  const ws = new WebSocket('wss://ttydconnect.ekddigital.com', {
    headers: {
      'X-Auth-Token': process.env.TTYDCONNECT_AUTH_TOKEN,
    },
  });

  let output = '';

  ws.on('open', () => {
    ws.send(command + '\n');
  });

  ws.on('message', (data) => {
    output += data.toString();
  });

  setTimeout(() => {
    ws.close();
    res.json({ success: true, output });
  }, 2000);
});

app.listen(3000, () => console.log('Proxy running on port 3000'));
```

---

## ⚠️ Important: Browser WebSocket Limitations

**The browser WebSocket API does NOT support custom headers!**

### Solutions:

#### Option 1: Backend Proxy (Recommended) ✅
```
Browser → Your Backend API → ttyd (with auth header)
```

#### Option 2: Query Parameter Authentication
Requires modifying nginx config to accept `?token=xxx` instead of headers.

#### Option 3: Server-Side Only
Only access ttyd from server-side code (Node.js, Python, etc.)

---

## 🔧 Deployment Platform Setup

### Vercel
```bash
# Settings → Environment Variables
TTYD_URL=https://ttydconnect.ekddigital.com
TTYDCONNECT_AUTH_TOKEN=<your_token>
```

### Netlify
```bash
# Site settings → Environment variables
TTYD_URL=https://ttydconnect.ekddigital.com
TTYDCONNECT_AUTH_TOKEN=<your_token>
```

### Heroku
```bash
heroku config:set TTYD_URL=https://ttydconnect.ekddigital.com
heroku config:set TTYDCONNECT_AUTH_TOKEN=<your_token>
```

### Docker
```dockerfile
ENV TTYD_URL=https://ttydconnect.ekddigital.com
ENV TTYDCONNECT_AUTH_TOKEN=your_token
```

---

## 🔄 Regenerate Token

If your token is compromised:

```bash
cd /home/hetawk/coding/ttyd

# Clear the token
nano .env
# Set: TTYDCONNECT_AUTH_TOKEN=

# Redeploy (generates new token)
sudo ./deploy-ttyd.sh
```

---

## 📊 Testing Your Connection

```bash
# Install wscat
npm install -g wscat

# Test WITH token (should work)
wscat -c wss://ttydconnect.ekddigital.com \
  -H "X-Auth-Token: your_token_here"

# Test WITHOUT token (should fail with 401)
wscat -c wss://ttydconnect.ekddigital.com
```

---

## 🛠️ Troubleshooting

### 401 Unauthorized Error
- Check if `X-Auth-Token` header is being sent
- Verify token matches the one in `.env` on VPS
- Token must be exact match (no extra spaces)

### Connection Refused
- Check if service is running: `sudo systemctl status ttydconnect`
- Check nginx: `sudo systemctl status nginx`
- View logs: `sudo journalctl -u ttydconnect -f`

### Browser Can't Connect
- Remember: Browser WebSocket doesn't support custom headers
- Use a backend proxy instead

---

## 📞 Need Help?

```bash
# Check service logs
sudo journalctl -u ttydconnect -f

# Check nginx logs
sudo tail -f /var/log/ttydconnect/nginx-access.log
sudo tail -f /var/log/ttydconnect/nginx-error.log

# Restart service
sudo systemctl restart ttydconnect

# Test nginx config
sudo nginx -t
```
