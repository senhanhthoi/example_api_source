#!/bin/bash

# Script to set up a Cloudflare Tunnel without credentials to forward 0.0.0.0:5001
# Prerequisites:
# - cloudflared installed (e.g., via `sudo apt install cloudflared` or equivalent)
# - No Cloudflare authentication or credentials required
# - Creates an ephemeral tunnel with a temporary public URL

# Enable verbose mode for debugging
set -x

# Configuration
LOCAL_ADDRESS="http://0.0.0.0:8080" # Using port 8080 from the API
LOG_FILE="/tmp/cloudflared_tunnel.log"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Wait for the API to become available
echo "Waiting for the API to start..."
for i in $(seq 1 30); do
    if curl -s "http://localhost:8080" > /dev/null; then
        echo "API is reachable at http://localhost:8080"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Error: API is not running at http://localhost:8080"
        exit 1
    fi
    echo "Waiting for API to start ($i/30)..."
    sleep 2
done

# Check if cloudflared is installed
if ! command -v cloudflared &> /dev/null; then
    echo "Error: cloudflared is not installed. Please install it first."
    echo "On Debian/Ubuntu, run: sudo apt install cloudflared"
    echo "Or download from: https://github.com/cloudflare/cloudflared/releases"
    exit 1
fi

# Start the ephemeral tunnel with verbose flags
echo "Starting Cloudflare Tunnel for $LOCAL_ADDRESS"
cloudflared tunnel --url "$LOCAL_ADDRESS" --logfile "$LOG_FILE" --loglevel debug &
TUNNEL_PID=$!

# Wait to ensure the tunnel starts and capture URL
sleep 10
