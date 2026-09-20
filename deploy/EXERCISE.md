# Exercise 9 (extra) — deploy with one push

**What changes in the code:** `.github/workflows/app-deploy.yml`. On every push to `main` (or on
*Run workflow*), GitHub builds both images, pushes them to Artifact Registry and deploys a new revision
of each service. It signs in to Google Cloud with Workload Identity Federation — no key stored in GitHub.

**Set-up (once):** `bash deploy/exercise9.sh` creates the pool, the provider and the `github-deployer`
identity, and prints the values to paste into **Settings > Secrets and variables > Actions > Variables**
of your repository (`GCP_PROJECT_ID`, `GCP_REGION`, `GCP_WIF_PROVIDER`, `GCP_SERVICE_ACCOUNT`).
These are identifiers, not secrets. Never store a service-account key in the repository.
