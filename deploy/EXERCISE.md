# Exercise 2 — containers on Cloud Run

**What changes in the code:** `backend/Dockerfile`, `frontend/Dockerfile`, `.dockerignore` files and
`docker-compose.yml` (to run both containers on your laptop). The frontend image writes
`dist/config.json` from the `API_BASE_URL` variable when the container starts.

**How it is deployed:** build the two images on your laptop (Docker Desktop), push them to an
Artifact Registry repository in `europe-north1`, and create two Cloud Run services from them.
Cloud Run replicates a service across the zones of the region and adds instances with traffic.
Both services run with minimum instances 1 (one copy always warm) and maximum instances 2 (the cost fuse).

**Run it:** `bash deploy/exercise2.sh`. Console click-paths: course document, Exercise 2.

**Check it:** open the page's `https://…run.app` URL. Notes still live in memory — and now there
may be several instances, each with its own notes. That is the "notes appear and disappear"
problem Exercise 3 solves.
