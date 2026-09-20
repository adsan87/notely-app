#!/usr/bin/env bash
# Exercise 5 - the database gets a PRIVATE address inside the default network and loses its public one;
# the API reaches it through Direct VPC egress; the bucket can never be made public.
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
gcloud services enable compute.googleapis.com servicenetworking.googleapis.com

# 1. Private services access: an address range in the default network reserved for Cloud SQL
gcloud compute addresses create notely-psa-range --global --purpose=VPC_PEERING --prefix-length=16 --network=default
gcloud services vpc-peerings connect --service=servicenetworking.googleapis.com --ranges=notely-psa-range --network=default

# 2. Give the instance a private address (restarts the instance), then drop the public one and the open network
gcloud sql instances patch notely-db --network="projects/${PROJECT_ID}/global/networks/default"
gcloud sql instances patch notely-db --no-assign-ip --clear-authorized-networks
DB_IP=$(gcloud sql instances describe notely-db --format=json | jq -r '.ipAddresses[] | select(.type=="PRIVATE") | .ipAddress')

# 3. The API: a path into the network (Direct VPC egress) and the private address instead of the public one
gcloud run services update notely-api --region "${REGION}" \
  --network=default --subnet=default --vpc-egress=private-ranges-only \
  --update-env-vars "DB_HOST=${DB_IP}"

# 4. The bucket can never be made public
gcloud storage buckets update "gs://notely-attachments-${PROJECT_ID}" --public-access-prevention

# Check
gcloud sql instances describe notely-db --format='yaml(ipAddresses)'
gcloud storage buckets describe "gs://notely-attachments-${PROJECT_ID}" --format='value(public_access_prevention)'
