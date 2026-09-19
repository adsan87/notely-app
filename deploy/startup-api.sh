#!/bin/bash
# Startup script of the API VM (runs as root at every boot). Replace REPO_URL.
set -e
VER=v22.20.0
cd /usr/local
curl -fsSL https://nodejs.org/dist/$VER/node-$VER-linux-x64.tar.xz | tar -xJ --strip-components=1
apt-get install -y git
rm -rf /opt/notely && git clone REPO_URL /opt/notely
cd /opt/notely/backend && npm install
PORT=3000 nohup node src/index.js > /var/log/notely-api.log 2>&1 &
