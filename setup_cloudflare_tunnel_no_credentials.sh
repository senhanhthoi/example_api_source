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

# Set the URL for the Flask manager API that will receive the tunnel URL
FLASK_MANAGER_API_URL="https://nano-breathing-mount-concentrations.trycloudflare.com/api/update_repository_status"

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

# Print logs to help debugging
echo "Cloudflare tunnel logs:"
tail -n 20 "$LOG_FILE"

# Check if the tunnel is running
if kill -0 $TUNNEL_PID 2>/dev/null; then
    echo "Tunnel is running successfully with PID: $TUNNEL_PID"
    
    # Try to extract and display the tunnel URL
    TUNNEL_URL=$(grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.com' "$LOG_FILE" | tail -1)
    if [ -n "$TUNNEL_URL" ]; then
        echo "Your application is available at: $TUNNEL_URL"
        
        # Get the repository name from the GitHub repository environment variable or use a default
        REPO_NAME=${GITHUB_REPOSITORY##*/}
        if [ -z "$REPO_NAME" ]; then
            # If not running in GitHub Actions, try to determine from directory name
            REPO_NAME=$(basename $(pwd))
        fi
        
        # Create JSON payload for the API request
        JSON_PAYLOAD=$(cat << EOF
{
  "repository_name": "$REPO_NAME",
  "status": "Active",
  "cloudflare_tunnel_url": "$TUNNEL_URL"
}
EOF
)
        
        # Send the request to update the database
        echo "Updating repository status in database..."
        curl -X POST \
          -H "Content-Type: application/json" \
          -d "$JSON_PAYLOAD" \
          -s "$FLASK_MANAGER_API_URL"
          
        echo "Database update request sent."
    else
        echo "Warning: Could not extract tunnel URL from logs."
    fi
else
    echo "Error: Tunnel failed to start. Check logs at $LOG_FILE"
    cat "$LOG_FILE"
    exit 1
fi

# Keep this script running to maintain the tunnel
wait $TUNNEL_PID 