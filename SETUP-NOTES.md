# GoTTY Terminal Server - Setup Notes

Simple guide for deploying GoTTY terminal server for WebSocket-based VPS access.

## Purpose

Provides WebSocket API to execute terminal commands on VPS without direct SSH connections. Used by client apps (andvpn, xterm, etc.) to remotely manage VPS.

## Quick Deploy

```bash
# 1. Configure
cp .env.example .env
nano .env  # Set: GOTTY_DOMAIN, SSL_EMAIL, GOTTY_CREDENTIAL

# 2. Deploy
sudo ./deploy-gotty-production.sh

# 3. Test
./test-gotty.sh
```

## What It Does

- Installs GoTTY terminal server
- Configures SSL/HTTPS (Let's Encrypt)
- Sets up nginx reverse proxy
- Creates systemd service
- Auto-detects port conflicts

## WebSocket API

**Connect:**

```javascript
const ws = new WebSocket("wss://your-domain.com/ws", {
  headers: { Authorization: "Basic " + btoa("user:pass") },
});
```

**Send Command:**

```javascript
ws.send("0pwd\n"); // Type '0' + command + '\n'
```

**Receive Output:**

```javascript
ws.on("message", (data) => {
  if (data[0] === 0x30) {
    // Type '0'
    const output = Buffer.from(data.slice(1).toString(), "base64");
    console.log(output.toString());
  }
});
```

## Integration Example

Client apps connect using:

```typescript
const response = await fetch("https://terminal-api.com/api/ttyd/execute", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    Authorization: `Bearer ${API_KEY}`,
  },
  body: JSON.stringify({ command: "pwd" }),
});
```

## Maintenance

```bash
# Status
sudo systemctl status gottyconnect

# Logs
sudo journalctl -u gottyconnect -f

# Restart
sudo systemctl restart gottyconnect
```

## Notes

- `.env` file contains secrets - never commit
- API keys managed per client app
- SSL auto-renews via certbot
- Port auto-detection prevents conflicts

---

**Status**: Production Ready  
**Updated**: November 2025
