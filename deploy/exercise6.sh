#!/usr/bin/env bash
# Exercise 6 - founders can look, IT can do everything, the API has its own identity
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
FOUNDER="founder@example.com"; COFOUNDER="cofounder@example.com"   # <- change (Owner for IT: grant in the console)

# 1. People (Viewer), then remove the bucket "convenience" grants so Viewers cannot read the PDFs
gcloud projects add-iam-policy-binding "${PROJECT_ID}" --member="user:${FOUNDER}"   --role=roles/viewer
gcloud projects add-iam-policy-binding "${PROJECT_ID}" --member="user:${COFOUNDER}" --role=roles/viewer
gcloud storage buckets remove-iam-policy-binding "gs://notely-attachments-${PROJECT_ID}" --member="projectViewer:${PROJECT_ID}" --role=roles/storage.legacyObjectReader
gcloud storage buckets remove-iam-policy-binding "gs://notely-attachments-${PROJECT_ID}" --member="projectViewer:${PROJECT_ID}" --role=roles/storage.legacyBucketReader

# 2. Two runtime identities: the API (bucket + secret), the page (nothing)
gcloud iam service-accounts create notely-api --display-name="Notely API (Cloud Run)"
gcloud iam service-accounts create notely-web --display-name="Notely frontend (Cloud Run) - no permissions"
API_SA="notely-api@${PROJECT_ID}.iam.gserviceaccount.com"; WEB_SA="notely-web@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud storage buckets add-iam-policy-binding "gs://notely-attachments-${PROJECT_ID}" --member="serviceAccount:${API_SA}" --role=roles/storage.objectAdmin
gcloud secrets add-iam-policy-binding notely-db-password --member="serviceAccount:${API_SA}" --role=roles/secretmanager.secretAccessor
gcloud run services update notely-api --region "${REGION}" --service-account="${API_SA}"
gcloud run services update notely-web --region "${REGION}" --service-account="${WEB_SA}"

# 3. Take the grants (and Editor, if present) away from the default service account
gcloud storage buckets remove-iam-policy-binding "gs://notely-attachments-${PROJECT_ID}" --member="serviceAccount:${DEFAULT_SA}" --role=roles/storage.objectAdmin
gcloud secrets remove-iam-policy-binding notely-db-password --member="serviceAccount:${DEFAULT_SA}" --role=roles/secretmanager.secretAccessor
gcloud projects remove-iam-policy-binding "${PROJECT_ID}" --member="serviceAccount:${DEFAULT_SA}" --role=roles/editor || true
