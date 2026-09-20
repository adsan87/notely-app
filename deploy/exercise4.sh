#!/usr/bin/env bash
# Exercise 4 - PDF attachments in a private Cloud Storage bucket, written and read only by the API
set -euo pipefail
source "$(dirname "$0")/00-env.sh"

# 1. A private, versioned bucket in Finland (IAM only, never public)
gcloud storage buckets create "gs://notely-attachments-${PROJECT_ID}" --location="${REGION}" --uniform-bucket-level-access
gcloud storage buckets update "gs://notely-attachments-${PROJECT_ID}" --versioning
gcloud storage buckets add-iam-policy-binding "gs://notely-attachments-${PROJECT_ID}" --member="serviceAccount:${DEFAULT_SA}" --role=roles/storage.objectAdmin

# 2. New images (this branch adds the routes and the button), built on your laptop
docker build --platform linux/amd64 -t "${REGISTRY}/notely-api:v3" backend && docker push "${REGISTRY}/notely-api:v3"
docker build --platform linux/amd64 -t "${REGISTRY}/notely-web:v2" frontend && docker push "${REGISTRY}/notely-web:v2"

# 3. New revisions: the API learns the bucket's name
gcloud run services update notely-api --region "${REGION}" --image "${REGISTRY}/notely-api:v3" \
  --update-env-vars "ATTACHMENTS_BUCKET=notely-attachments-${PROJECT_ID}"
gcloud run services update notely-web --region "${REGION}" --image "${REGISTRY}/notely-web:v2"
