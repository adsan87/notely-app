#!/usr/bin/env bash
# Exercise 5 - only the page faces the internet.
#  a) The API stops accepting requests from the internet (ingress "internal"). The page becomes its reverse
#     proxy and reaches it through the VPC: Direct VPC egress with all traffic, Private Google Access on the
#     subnet that both services use (default, europe-north1).
#  b) The bucket becomes private for good, and the Cloud Run identity gets explicit access to it.
#  c) The database keeps only a private address; the API reaches it through the VPC, the page may not.
# Needs: Docker Desktop running (the page's image changes), gcloud signed in, deploy/00-env.sh filled in.
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
BUCKET="gs://notely-attachments-${PROJECT_ID}"
gcloud services enable compute.googleapis.com servicenetworking.googleapis.com

# c1. Private services access: an address range in the default network reserved for Cloud SQL
gcloud compute addresses create notely-psa-range --global --purpose=VPC_PEERING --prefix-length=16 --network=default
gcloud services vpc-peerings connect --service=servicenetworking.googleapis.com --ranges=notely-psa-range --network=default

# c2. Give the instance a private address (restarts the instance), then drop the public one and the open network
gcloud sql instances patch notely-db --network="projects/${PROJECT_ID}/global/networks/default"
gcloud sql instances patch notely-db --no-assign-ip --clear-authorized-networks
DB_IP=$(gcloud sql instances describe notely-db --flatten=ipAddresses \
  --format='value(ipAddresses.type,ipAddresses.ipAddress)' | awk '$1 == "PRIVATE" {print $2}')

# c3. The API: a path into the network for private addresses only, and the database's private address
gcloud run services update notely-api --region "${REGION}" \
  --network=default --subnet=default --vpc-egress=private-ranges-only \
  --update-env-vars "DB_HOST=${DB_IP}"

# a1. Private Google Access on the subnet both services use
gcloud compute networks subnets update default --region="${REGION}" --enable-private-ip-google-access

# c4. The page is about to join the same network as the database: a firewall rule denies it the database port
PSA_RANGE="$(gcloud compute addresses describe notely-psa-range --global --format='value(address)')/16"
gcloud compute firewall-rules create notely-deny-web-to-db --network=default --direction=EGRESS --action=DENY \
  --rules=tcp:5432 --destination-ranges="${PSA_RANGE}" --target-tags=notely-web --priority=900

# a2. The page becomes the API's reverse proxy: new image, all its outbound traffic through the VPC,
#     the network tag the firewall rule targets, and the API's address in API_URL
API_URL=$(gcloud run services describe notely-api --region "${REGION}" --format='value(status.url)')
docker build --platform linux/amd64 -t "${REGISTRY}/notely-web:v3" frontend && docker push "${REGISTRY}/notely-web:v3"
gcloud run services update notely-web --region "${REGION}" --image "${REGISTRY}/notely-web:v3" \
  --network=default --subnet=default --network-tags=notely-web --vpc-egress=all-traffic \
  --remove-env-vars=API_BASE_URL --update-env-vars "API_URL=${API_URL}"

# a3. Only now can the API stop listening to the internet: it accepts requests that arrive through the VPC
gcloud run services update notely-api --region "${REGION}" --ingress=internal

# b. The bucket: nobody on the internet reads it any more; the Cloud Run identity gets explicit access
gcloud storage buckets remove-iam-policy-binding "${BUCKET}" --member=allUsers --role=roles/storage.objectViewer
gcloud storage buckets update "${BUCKET}" --public-access-prevention
gcloud storage buckets add-iam-policy-binding "${BUCKET}" --member="serviceAccount:${DEFAULT_SA}" --role=roles/storage.objectAdmin

# Check
WEB_URL=$(gcloud run services describe notely-web --region "${REGION}" --format='value(status.url)')
curl -s -o /dev/null -w "API from the internet: %{http_code} (404 = refused by ingress)\n" "${API_URL}/health"
curl -s "${WEB_URL}/health"; echo "   <- the API, answering through the page"
gcloud sql instances describe notely-db --format='yaml(ipAddresses)'
gcloud storage buckets describe "${BUCKET}" --format='value(public_access_prevention)'
