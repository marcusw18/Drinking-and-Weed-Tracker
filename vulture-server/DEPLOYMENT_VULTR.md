# Vultr Deployment Guide

Deploy Vulture ML Server on Vultr VPS (Docker or native Python).

## Prerequisites

- Vultr account: https://www.vultr.com
- SSH client (built-in on Mac/Linux; PuTTY on Windows)
- Domain name (optional, or use your Vultr IP)

---

## Option A: Docker Deployment (Recommended)

### 1. Create Vultr Instance

1. Go to https://www.vultr.com/dashboard
2. Click **Products** → **Compute**
3. Click **Deploy New Server**
4. Select:
   - **Server Type:** Docker on Ubuntu 22.04 LTS (or your preferred distro)
   - **Server Size:** $6/month (2GB RAM, 1 CPU) minimum
   - **Region:** Pick closest to your team (e.g., New York, Toronto)
5. Click **Deploy**
6. Wait for server to start (~2 minutes)
7. Copy your **IP Address** (e.g., `203.0.113.45`)

### 2. SSH into Your Server

```bash
ssh root@YOUR_VULTR_IP
```

Example:
```bash
ssh root@203.0.113.45
```

### 3. Clone Your Repository

```bash
cd /root
git clone https://github.com/marcusw18/Drinking-and-Weed-Tracker.git
cd Drinking-and-Weed-Tracker
```

### 4. Deploy with Docker Compose

```bash
cd vulture-server
docker-compose up -d
```

This will:
- Build the Docker image
- Start the container
- Restart automatically on reboot
- Listen on port 8000

### 5. Verify It's Running

```bash
curl http://localhost:8000/health
```

Expected:
```json
{"status":"ok"}
```

### 6. Check Server Logs

```bash
docker logs vulture-ml-server -f
```

---

## Option B: Native Python Deployment (No Docker)

### 1. Create Vultr Instance

Same as Option A, but select **Ubuntu 22.04 LTS** (not Docker).

### 2. SSH into Server

```bash
ssh root@YOUR_VULTR_IP
```

### 3. Install Dependencies

```bash
apt update && apt upgrade -y
apt install -y python3.12 python3-pip python3-venv git ffmpeg

# Create app user
useradd -m -s /bin/bash vulture
```

### 4. Clone Repository

```bash
cd /home/vulture
sudo -u vulture git clone https://github.com/marcusw18/Drinking-and-Weed-Tracker.git
cd Drinking-and-Weed-Tracker/vulture-server
```

### 5. Setup Virtual Environment

```bash
sudo -u vulture python3 -m venv venv
sudo -u vulture venv/bin/pip install --upgrade pip
sudo -u vulture venv/bin/pip install -r requirements.txt
```

### 6. Create Systemd Service

```bash
cp vulture-server.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable vulture-server
systemctl start vulture-server
```

### 7. Verify Status

```bash
systemctl status vulture-server
curl http://localhost:8000/health
```

---

## Configure Reverse Proxy (Nginx)

Use Nginx to:
- Listen on port 80/443 (public)
- Forward to your app on port 8000 (private)
- Support SSL/HTTPS

### 1. Install Nginx

```bash
apt install -y nginx
```

### 2. Create Config

```bash
cat > /etc/nginx/sites-available/vulture << 'EOF'
server {
    listen 80;
    server_name YOUR_VULTR_IP;  # or your domain

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Allow large file uploads (for audio)
        client_max_body_size 100M;
    }
}
EOF
```

### 3. Enable Site

```bash
ln -s /etc/nginx/sites-available/vulture /etc/nginx/sites-enabled/
nginx -t  # Test config
systemctl restart nginx
```

### 4. Test

```bash
curl http://YOUR_VULTR_IP/health
```

Should return: `{"status":"ok"}`

---

## SSL/HTTPS with Let's Encrypt (Optional)

### 1. Install Certbot

```bash
apt install -y certbot python3-certbot-nginx
```

### 2. Get Certificate

If using a domain (e.g., `vulture.yourdomain.com`):

```bash
certbot --nginx -d vulture.yourdomain.com
```

Certbot will:
- Request certificate from Let's Encrypt
- Auto-update nginx config
- Auto-renew every 90 days

### 3. Test HTTPS

```bash
curl https://vulture.yourdomain.com/health
```

---

## Update iOS App

### In Config.swift:

```swift
// If using Vultr IP directly
static let vultureServerURL = "http://203.0.113.45:8000"

// If using domain with Nginx
static let vultureServerURL = "http://vulture.yourdomain.com"

// If using domain with HTTPS/SSL
static let vultureServerURL = "https://vulture.yourdomain.com"
```

---

## Monitoring & Logs

### Docker

```bash
# View logs
docker logs vulture-ml-server -f

# Check container status
docker ps

# Restart
docker restart vulture-ml-server
```

### Systemd (Native Python)

```bash
# View logs
journalctl -u vulture-server -f

# Check status
systemctl status vulture-server

# Restart
systemctl restart vulture-server
```

### Nginx

```bash
# View access logs
tail -f /var/log/nginx/access.log

# View error logs
tail -f /var/log/nginx/error.log

# Restart
systemctl restart nginx
```

---

## Firewall Rules

If using Vultr's firewall, allow:
- Port 22 (SSH)
- Port 80 (HTTP)
- Port 443 (HTTPS) — if using SSL
- Port 8000 (Direct API access) — optional

---

## Performance Tips

1. **Use 2GB+ RAM instance** — Whisper model is large
2. **SSD storage** — Faster model loading
3. **Closer region** — Lower latency for your team
4. **Monitor CPU/RAM** — Use Vultr dashboard → Metrics
5. **Enable auto-backups** — (Optional, in Vultr settings)

---

## Troubleshooting

### Can't SSH
- Check Vultr firewall rules
- Ensure port 22 is open
- Verify IP address is correct

### Port 8000 Connection Refused
- Check if container/service is running
- View logs for startup errors
- Ensure firewall allows port 8000 (if accessing directly)

### Nginx 502 Bad Gateway
- Service crashed. Check logs: `docker logs vulture-ml-server`
- Service not listening on 8000. Verify container/service started
- Wait 30+ seconds for Whisper model to download on first request

### High CPU on First Request
- Normal. Whisper model (~74MB) downloads and loads
- Subsequent requests <3 seconds
- Monitor with: `docker stats` (Docker) or `top` (native)

---

## Example Complete Setup

```bash
# SSH into Vultr
ssh root@203.0.113.45

# Clone repo
git clone https://github.com/marcusw18/Drinking-and-Weed-Tracker.git
cd Drinking-and-Weed-Tracker/vulture-server

# Start with Docker Compose
docker-compose up -d

# Test
curl http://localhost:8000/health

# Setup Nginx reverse proxy (optional)
# ... (follow Nginx section above)

# Done! Your teammates use:
# http://203.0.113.45:8000
# or
# http://vulture.yourdomain.com (if using domain + Nginx)
```

---

## Sharing with Teammates

```
Vulture ML Server is now live on Vultr!

URL: http://203.0.113.45:8000
(or: http://vulture.yourdomain.com if using domain)

Update Config.swift:
static let vultureServerURL = "http://203.0.113.45:8000"

Endpoints:
• GET  /health           → {"status":"ok"}
• POST /analyze/voice    → Send audio, get slur_score

First request slow (~30–45s). Subsequent: <3s.
```

---

## Cost

- **Vultr Server:** $6–12/month depending on specs
- **Domain (optional):** $10–15/year
- **SSL Certificate:** Free (Let's Encrypt via Certbot)

Much cheaper than other managed services once you hit scale.
