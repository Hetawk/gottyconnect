# ttydconnect - Secure Web Terminal Deployment

[![Deploy](https://img.shields.io/badge/deploy-script-blue)](https://github.com/Hetawk/ttydconnect/blob/master/deploy-ttyd.sh)

A complete, automated deployment solution for secure ttyd web terminals with token-based authentication, SSL, and client integration.

## 🚀 Quick Deploy

```bash
# Clone and deploy
git clone https://github.com/Hetawk/ttydconnect.git
cd ttydconnect
sudo ./deploy-ttyd.sh
```

That's it! Your secure terminal will be available at `https://yourdomain.com` with auto-generated authentication.

## ✨ Features

- **🔐 Token Authentication** - Secure header-based auth (no username/password)
- **🔒 SSL/HTTPS** - Automatic Let's Encrypt certificates
- **⚡ One-Command Setup** - Complete deployment in minutes
- **🔄 Auto-Restart** - Systemd service with automatic recovery
- **📱 Client Ready** - Pre-configured for web/mobile apps
- **📊 Monitoring** - Comprehensive logging and status checks
- **🔧 Configurable** - Environment-based configuration

## 📋 Requirements

- Ubuntu/Debian VPS with sudo access
- Domain name (optional, but recommended for SSL)
- Ports 80, 443 available (for SSL)

## ⚙️ Configuration

Create `.env` file or set environment variables:

```env
DOMAIN=ttydconnect.ekddigital.com
TTYD_PORT=7681
INSTALL_NGINX=true
SSL_EMAIL=your@email.com
```

| Variable | Default | Description |
|----------|---------|-------------|
| `DOMAIN` | - | Your domain for SSL |
| `TTYD_PORT` | `7681` | Internal ttyd port |
| `INSTALL_NGINX` | `false` | Enable reverse proxy + SSL |
| `SSL_EMAIL` | - | Email for Let's Encrypt |

## 🔧 Usage

### Deploy
```bash
sudo ./deploy-ttyd.sh
```

### Service Management
```bash
sudo systemctl status ttydconnect
sudo systemctl restart ttydconnect
sudo journalctl -u ttydconnect -f
```

### Client Integration

**Environment Variables** (add to your apps):
```env
TTYD_URL=https://yourdomain.com
TTYDCONNECT_AUTH_TOKEN=your_generated_token
```

**JavaScript/WebSocket**:
```javascript
const ws = new WebSocket('wss://yourdomain.com', {
  headers: { 'X-Auth-Token': process.env.TTYDCONNECT_AUTH_TOKEN }
});
```

**Next.js API Route**:
```javascript
// pages/api/terminal.js
export default async (req, res) => {
  const ws = new WebSocket(process.env.TTYD_URL, {
    headers: { 'X-Auth-Token': process.env.TTYDCONNECT_AUTH_TOKEN }
  });
  // Handle commands...
};
```

## 📁 Project Structure

```
ttydconnect/
├── deploy-ttyd.sh          # Main deployment script
├── .env.example           # Configuration template
├── CLIENT-INTEGRATION.md  # Detailed client examples
├── DEPLOYMENT-GUIDE.md    # Advanced deployment guide
└── examples/              # Integration examples
    ├── nextjs-terminal.js
    └── vercel-env-example.env
```

## 🔒 Security

- **Token-based authentication** - No exposed credentials
- **HTTPS only** - All connections encrypted
- **Header validation** - Nginx-level security
- **Auto-generated secrets** - Unique tokens per deployment
- **No direct browser access** - Requires programmatic auth

## 🐛 Troubleshooting

**Service not starting:**
```bash
sudo systemctl status ttydconnect
sudo journalctl -u ttydconnect -n 20
```

**SSL issues:**
```bash
sudo certbot renew
sudo nginx -t && sudo systemctl reload nginx
```

**Permission denied:**
```bash
sudo ./deploy-ttyd.sh  # Must run with sudo
```

## 📖 Documentation

- **[Client Integration Guide](CLIENT-INTEGRATION.md)** - Complete examples for web/mobile apps
- **[Deployment Guide](DEPLOYMENT-GUIDE.md)** - Advanced configuration and troubleshooting

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test deployment
5. Submit a pull request

## 📄 License

MIT License - Free for personal and commercial use.

## 🙏 Acknowledgments

- [ttyd](https://github.com/tsl0922/ttyd) - The amazing web terminal
- [Nginx](https://nginx.org/) - Reverse proxy and SSL termination
- [Let's Encrypt](https://letsencrypt.org/) - Free SSL certificates
