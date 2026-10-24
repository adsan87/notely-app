#!/bin/bash
# Startup script of the frontend VM (runs as root at every boot). Replace REPO_URL and API_IP.
set -e
VER=v22.20.0
cd /usr/local
curl -fsSL https://nodejs.org/dist/$VER/node-$VER-linux-x64.tar.xz | tar -xJ --strip-components=1
# At first boot the package lists are empty and the guest agent may still be using apt: retry until it is free.
until apt-get update && apt-get install -y git; do echo "apt busy, retrying in 5s"; sleep 5; done
rm -rf /opt/notely && git clone -b exercise1 REPO_URL /opt/notely
cd /opt/notely/frontend && npm install && npm run build
echo '{"apiBaseUrl":"http://API_IP:3000","frontendInstance":"notely-web"}' > dist/config.json
nohup npx -y serve -s dist -l 80 > /var/log/notely-web.log 2>&1 &
