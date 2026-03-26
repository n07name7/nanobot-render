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
python3 - <<PYEOF
import urllib.request, urllib.error, os, time

token = os.environ["TELEGRAM_TOKEN"]
url = f"https://api.telegram.org/bot{token}/getUpdates?timeout=0&limit=1"

while True:
    try:
        urllib.request.urlopen(url, timeout=5)
        print("Telegram polling available, starting nanobot...")
        break
    except urllib.error.HTTPError as e:
        if e.code == 409:
            print("Conflict (old instance running), retrying in 15s...")
            time.sleep(15)
        else:
            print(f"HTTP {e.code}, retrying in 5s...")
            time.sleep(5)
    except Exception as e:
        print(f"Error: {e}, retrying in 5s...")
        time.sleep(5)
PYEOF

exec nanobot gateway
