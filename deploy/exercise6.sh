#!/usr/bin/env bash
# Exercise 6 - least privilege for people and for the two services.
#  - The founders: one Google group with read-only roles on Cloud Run, Cloud SQL and Cloud Storage. Nothing else.
#  - The API: its own identity, the only one that may use the bucket and read the database password.
#  - The page: its own identity, with no grants at all.
#  - The broad grants of the earlier exercises go. You, the IT person, keep the Owner role you already have.
# Before running: create the founders' group and add their Google accounts to it (deploy/EXERCISE.md).
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
FOUNDERS_GROUP="notely-founders@googlegroups.com"                  # <- change: the group's e-mail address
OLD_GRANTS="user:founder@example.com user:cofounder@example.com"   # <- anyone given a broad role one by one before
BUCKET="gs://notely-attachments-${PROJECT_ID}"

# 1. The founders' group: they can look at the services, the database and the bucket, and change nothing.
#    (Storage Bucket Viewer is a Beta role; without it the Buckets page cannot list the bucket.)
for ROLE in roles/run.viewer roles/cloudsql.viewer roles/storage.objectViewer roles/storage.bucketViewer; do
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" --member="group:${FOUNDERS_GROUP}" --role="${ROLE}"
done
# No broad role for anyone one by one (earlier versions of this exercise gave the founders Viewer)
for P in ${OLD_GRANTS}; do
  gcloud projects remove-iam-policy-binding "${PROJECT_ID}" --member="${P}" --role=roles/viewer || true
done

# 2. Two runtime identities: the API (the bucket and the secret, nothing else), the page (nothing)
gcloud iam service-accounts create notely-api --display-name="Notely API (Cloud Run)"
gcloud iam service-accounts create notely-web --display-name="Notely frontend (Cloud Run) - no permissions"
API_SA="notely-api@${PROJECT_ID}.iam.gserviceaccount.com"; WEB_SA="notely-web@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud storage buckets add-iam-policy-binding "${BUCKET}" --member="serviceAccount:${API_SA}" --role=roles/storage.objectAdmin
gcloud secrets add-iam-policy-binding notely-db-password --member="serviceAccount:${API_SA}" --role=roles/secretmanager.secretAccessor
gcloud run services update notely-api --region "${REGION}" --service-account="${API_SA}"
gcloud run services update notely-web --region "${REGION}" --service-account="${WEB_SA}"

# 3. The broad grants go: the default service account, which both services ran as, loses the bucket,
#    the secret and the Editor role
gcloud storage buckets remove-iam-policy-binding "${BUCKET}" --member="serviceAccount:${DEFAULT_SA}" --role=roles/storage.objectAdmin
gcloud secrets remove-iam-policy-binding notely-db-password --member="serviceAccount:${DEFAULT_SA}" --role=roles/secretmanager.secretAccessor
gcloud projects remove-iam-policy-binding "${PROJECT_ID}" --member="serviceAccount:${DEFAULT_SA}" --role=roles/editor || true

# Check: the group's four roles; who may use the bucket; who may read the secret
gcloud projects get-iam-policy "${PROJECT_ID}" --flatten=bindings --filter="bindings.members:${FOUNDERS_GROUP}" --format='value(bindings.role)'
gcloud storage buckets get-iam-policy "${BUCKET}"
gcloud secrets get-iam-policy notely-db-password
