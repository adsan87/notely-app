#!/usr/bin/env bash
# Exercise 1 - two VMs, no containers: notely-api (port 3000) and notely-web (port 80)
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
D="$(dirname "$0")"
gcloud services enable compute.googleapis.com

# Firewall: port 3000 to VMs tagged notely-api, port 80 to VMs tagged notely-web
gcloud compute firewall-rules create notely-allow-api-3000 --network=default --allow=tcp:3000 --source-ranges=0.0.0.0/0 --target-tags=notely-api
gcloud compute firewall-rules create notely-allow-web-80   --network=default --allow=tcp:80   --source-ranges=0.0.0.0/0 --target-tags=notely-web

# The API VM (Debian 12 image, startup script installs Node.js 22, clones and starts the API)
sed "s|REPO_URL|${REPO_URL}|" "${D}/startup-api.sh" > /tmp/startup-api.sh
gcloud compute instances create notely-api --zone="${ZONE}" --machine-type=e2-micro \
  --image-family=debian-12 --image-project=debian-cloud --tags=notely-api \
  --metadata-from-file=startup-script=/tmp/startup-api.sh
API_IP=$(gcloud compute instances describe notely-api --zone="${ZONE}" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

# The frontend VM, pointing at the API
sed -e "s|REPO_URL|${REPO_URL}|" -e "s|API_IP|${API_IP}|" "${D}/startup-web.sh" > /tmp/startup-web.sh
gcloud compute instances create notely-web --zone="${ZONE}" --machine-type=e2-micro \
  --image-family=debian-12 --image-project=debian-cloud --tags=notely-web \
  --metadata-from-file=startup-script=/tmp/startup-web.sh
WEB_IP=$(gcloud compute instances describe notely-web --zone="${ZONE}" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
echo "API: http://${API_IP}:3000/health   Web: http://${WEB_IP}   (allow 2-3 minutes: Node installs and the page builds)"
