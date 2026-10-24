#!/usr/bin/env bash
# Exercise 9 - keyless GitHub Actions (Workload Identity Federation)
set -euo pipefail
source "$(dirname "$0")/00-env.sh"
GITHUB_REPO="YOUR-USER/notely-app"   # <- OWNER/REPO
gcloud services enable iamcredentials.googleapis.com sts.googleapis.com
gcloud iam workload-identity-pools create github-pool --location=global --display-name="GitHub Actions"
gcloud iam workload-identity-pools providers create-oidc github-provider --location=global --workload-identity-pool=github-pool \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository == '${GITHUB_REPO}'"
POOL=$(gcloud iam workload-identity-pools describe github-pool --location=global --format='value(name)')
gcloud iam service-accounts create github-deployer --display-name="GitHub Actions deployer"
DEPLOYER="github-deployer@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud iam service-accounts add-iam-policy-binding "${DEPLOYER}" --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/${POOL}/attribute.repository/${GITHUB_REPO}"
gcloud artifacts repositories add-iam-policy-binding notely --location="${REGION}" --member="serviceAccount:${DEPLOYER}" --role=roles/artifactregistry.writer
gcloud projects add-iam-policy-binding "${PROJECT_ID}" --member="serviceAccount:${DEPLOYER}" --role=roles/run.developer
for SA in notely-api notely-web; do
  gcloud iam service-accounts add-iam-policy-binding "${SA}@${PROJECT_ID}.iam.gserviceaccount.com" --member="serviceAccount:${DEPLOYER}" --role=roles/iam.serviceAccountUser
done
echo "GCP_PROJECT_ID=${PROJECT_ID}"; echo "GCP_REGION=${REGION}"; echo "GCP_SERVICE_ACCOUNT=${DEPLOYER}"
echo "GCP_WIF_PROVIDER=$(gcloud iam workload-identity-pools providers describe github-provider --location=global --workload-identity-pool=github-pool --format='value(name)')"
