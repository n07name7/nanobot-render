#!/bin/bash
set -e

CONFIG_DIR="/root/.nanobot"
CONFIG_FILE="$CONFIG_DIR/config.json"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_FILE" <<EOF
{
  "providers": {
    "groq": {
      "apiKey": "${GROQ_API_KEY}"
    },
    "openrouter": {
      "apiKey": "${OPENROUTER_API_KEY}"
    }
  },
  "agents": {
    "defaults": {
      "model": "${NANOBOT_MODEL:-meta-llama/llama-4-scout-17b-16e-instruct}",
      "provider": "${NANOBOT_PROVIDER:-groq}"
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

# Health server — must start first so Render detects the port
python3 -c "
import http.server, os, threading, sys, time, urllib.request

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

# Keepalive ping every 10 min to prevent Render free tier sleep
url = os.environ.get('RENDER_EXTERNAL_URL', 'http://localhost:' + str(port))
while True:
    time.sleep(600)
    try:
        urllib.request.urlopen(url, timeout=5)
    except Exception:
        pass
" &

sleep 2

# Wait for Telegram polling slot — hold 10s proves old instance is dead
echo "Waiting for Telegram polling slot..."
python3 << 'PYEOF'
import urllib.request, urllib.error, os, time

token = os.environ["TELEGRAM_TOKEN"]
url = "https://api.telegram.org/bot" + token + "/getUpdates?timeout=10&limit=1"

while True:
    try:
        urllib.request.urlopen(url, timeout=15)
        print("Held polling slot for 10s — old instance is gone, starting nanobot...")
        break
    except urllib.error.HTTPError as e:
        if e.code == 409:
            print("Conflict (old instance still alive), retrying in 5s...")
            time.sleep(5)
        else:
            print("HTTP " + str(e.code) + ", retrying in 5s...")
            time.sleep(5)
    except Exception as e:
        print("Error: " + str(e) + ", retrying in 5s...")
        time.sleep(5)
PYEOF

# Auto-restart nanobot if it crashes
while true; do
    echo "Starting nanobot..."
    nanobot gateway || true
    echo "nanobot exited, restarting in 10s..."
    sleep 10
done
