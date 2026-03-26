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
      "model": "${NANOBOT_MODEL:-meta-llama/llama-4-maverick:free}",
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

# Wait until Telegram polling slot is free (no 409 Conflict from old instance)
echo "Waiting for Telegram polling slot..."
while true; do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        --max-time 5 \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getUpdates?timeout=0&limit=1")
    if [ "$CODE" = "200" ]; then
        echo "Telegram polling available, starting nanobot..."
        break
    elif [ "$CODE" = "409" ]; then
        echo "Conflict (old instance running), retrying in 15s..."
        sleep 15
    else
        echo "Unexpected code $CODE, retrying in 5s..."
        sleep 5
    fi
done

exec nanobot gateway
