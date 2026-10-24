#!/bin/bash
# Startup script of the API VM (runs as root at every boot). Replace REPO_URL.
set -e
VER=v22.20.0
cd /usr/local
curl -fsSL https://nodejs.org/dist/$VER/node-$VER-linux-x64.tar.xz | tar -xJ --strip-components=1
# At first boot the package lists are empty and the guest agent may still be using apt: retry until it is free.
until apt-get update && apt-get install -y git; do echo "apt busy, retrying in 5s"; sleep 5; done
rm -rf /opt/notely && git clone -b exercise1 REPO_URL /opt/notely
cd /opt/notely/backend && npm install
PORT=3000 nohup node src/index.js > /var/log/notely-api.log 2>&1 &
