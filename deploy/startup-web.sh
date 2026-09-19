#!/bin/bash
# Startup script of the frontend VM. Replace REPO_URL and API_IP.
set -e
VER=v22.20.0
cd /usr/local
curl -fsSL https://nodejs.org/dist/$VER/node-$VER-linux-x64.tar.xz | tar -xJ --strip-components=1
apt-get install -y git
rm -rf /opt/notely && git clone REPO_URL /opt/notely
cd /opt/notely/frontend && npm install && npm run build
echo '{"apiBaseUrl":"http://API_IP:3000","frontendInstance":"notely-web"}' > dist/config.json
nohup npx -y serve -s dist -l 80 > /var/log/notely-web.log 2>&1 &
