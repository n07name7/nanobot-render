#!/bin/bash
set -e

CONFIG_DIR="/root/.nanobot"
CONFIG_FILE="$CONFIG_DIR/config.json"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_FILE" <<EOF
{
  "providers": {
    "openrouter": {
      "apiKey": "${OPENROUTER_API_KEY}"
    }
  },
  "agents": {
    "defaults": {
      "model": "${NANOBOT_MODEL:-arcee-ai/trinity-mini:free}",
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

# Start health server first so Render detects the port immediately
python3 -c "
import http.server, os, threading, sys
port = int(os.environ.get('PORT', 10000))
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'OK')
    def log_message(self, *a): pass
srv = http.server.HTTPServer(('0.0.0.0', port), H)
t = threading.Thread(target=srv.serve_forever, daemon=True)
t.start()
sys.stdout.write('Health server on port ' + str(port) + '\n')
sys.stdout.flush()
import time; time.sleep(86400)
" &

sleep 2

exec nanobot gateway
