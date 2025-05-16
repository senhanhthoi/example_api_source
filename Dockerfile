# example_api_source/Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install curl and cloudflared
RUN apt-get update && apt-get install -y curl \
    && curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared \
    && chmod +x /usr/local/bin/cloudflared

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Make the cloudflare tunnel setup script executable
RUN chmod +x /app/setup_cloudflare_tunnel_no_credentials.sh

ENV PORT 8080
EXPOSE 8080

# Start both the API and the Cloudflare tunnel
CMD ["sh", "-c", "python main.py & /app/setup_cloudflare_tunnel_no_credentials.sh"]

