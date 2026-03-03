#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate

# Generate TLS certs if missing
if [ ! -f certs/server.crt ] || [ ! -f certs/server.key ]; then
    bash generate_certs.sh
fi

# Use HTTPS by default; set JARVIS_NO_TLS=1 to disable
if [ "${JARVIS_NO_TLS:-0}" = "1" ]; then
    echo "Starting Jarvis backend (HTTP) on port 8000..."
    exec uvicorn main:app --host 0.0.0.0 --port 8000
else
    echo "Starting Jarvis backend (HTTPS) on port 8000..."
    exec uvicorn main:app --host 0.0.0.0 --port 8000 \
        --ssl-keyfile certs/server.key \
        --ssl-certfile certs/server.crt
fi
