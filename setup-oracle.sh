#!/bin/bash
# Run this script on Oracle after reboot
# wget -qO- https://raw.githubusercontent.com/.../setup-oracle.sh | bash
# OR: copy-paste sections manually

set -e

echo "=== Step 1: Add 2GB swap ==="
if ! swapon --show | grep -q /swapfile; then
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  echo "Swap added"
else
  echo "Swap already exists"
fi
free -h

echo ""
echo "=== Step 2: Fix iptables (allow outbound HTTP/HTTPS) ==="
sudo iptables -D OUTPUT -p tcp --dport 443 -j DROP 2>/dev/null && echo "Removed HTTPS block" || echo "HTTPS block not present"
sudo iptables -D OUTPUT -p tcp --dport 80 -j DROP 2>/dev/null && echo "Removed HTTP block" || echo "HTTP block not present"
sudo netfilter-persistent save 2>/dev/null || true

echo ""
echo "=== Step 3: Install uv ==="
if ! command -v uv &>/dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="$HOME/.local/bin:$PATH"
uv --version

echo ""
echo "=== Step 4: Install nanobot-ai ==="
uv tool install nanobot-ai
export PATH="$HOME/.local/bin:$HOME/.local/share/uv/tools/nanobot-ai/bin:$PATH"
which nanobot

echo ""
echo "=== Step 5: Write config ==="
mkdir -p ~/.nanobot
cat > ~/.nanobot/config.json <<'CFGEOF'
{
  "providers": {
    "openrouter": {
      "apiKey": "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"
    }
  },
  "agents": {
    "defaults": {
      "model": "deepseek/deepseek-chat:free",
      "provider": "openrouter"
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "__TELEGRAM_TOKEN__",
      "allowFrom": ["934699065"]
    }
  }
}
CFGEOF
echo "Config written. EDIT IT: nano ~/.nanobot/config.json"
echo "Replace __TELEGRAM_TOKEN__ with your bot token!"

echo ""
echo "=== Step 6: Create systemd service ==="
NANOBOT_BIN=$(which nanobot)
sudo tee /etc/systemd/system/nanobot.service > /dev/null <<SVCEOF
[Unit]
Description=Nanobot AI Gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
Environment="PATH=/home/ubuntu/.local/bin:/home/ubuntu/.local/share/uv/tools/nanobot-ai/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=${NANOBOT_BIN} gateway
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SVCEOF

sudo systemctl daemon-reload
sudo systemctl enable nanobot
echo "Systemd service created"
echo ""
echo "=== DONE ==="
echo "After editing config, run: sudo systemctl start nanobot"
echo "Check logs: sudo journalctl -u nanobot -f"
