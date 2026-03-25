#!/bin/bash
set -e

CONFIG_DIR="/root/.nanobot"
CONFIG_FILE="$CONFIG_DIR/config.json"
mkdir -p "$CONFIG_DIR"

# Build config.json from environment variables
cat > "$CONFIG_FILE" <<EOF
{
  "providers": {
    "openrouter": {
      "apiKey": "${OPENROUTER_API_KEY}"
    }
  },
  "agents": {
    "defaults": {
      "model": "${NANOBOT_MODEL:-deepseek/deepseek-chat:free}",
      "provider": "openrouter"
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "${TELEGRAM_TOKEN}",
      "allowFrom": ["${TELEGRAM_USER_ID}"]
    }
  }
}
EOF

echo "Config written to $CONFIG_FILE"
cat "$CONFIG_FILE"

# Start simple HTTP health-check server in background (keeps Render from sleeping)
python3 -c "
import http.server, threading, os
port = int(os.environ.get('PORT', 10000))
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'OK')
    def log_message(self, *a): pass
srv = http.server.HTTPServer(('', port), H)
t = threading.Thread(target=srv.serve_forever, daemon=True)
t.start()
print(f'Health server on port {port}')
" &

# Start nanobot gateway
exec nanobot gateway
