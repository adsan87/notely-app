# Exercise 5 — only the page faces the internet

**What changes in the code:** the frontend. `frontend/server.js` replaces `serve`: it serves the built
page and is a **reverse proxy** that forwards `/api/*` and `/health` to the API (`API_URL`), streaming
bodies both ways, so PDF uploads and downloads work as before. The proxy is about thirty lines of Node's
own `http`/`https` modules: read it, it is the whole idea. The browser now talks to one origin only:
`config.json` says `apiBaseUrl: ""`. `frontend/Dockerfile` runs `node server.js`; `frontend/package.json`
adds `express` (for the static files). `docker-compose.yml` mirrors the cloud: only the frontend
publishes a port. The backend does not change.

**How it is deployed:**
- **a) The API is not on the internet.** `notely-api` gets ingress **internal**: Cloud Run refuses any
  request that does not come through a VPC network of the project (404, no log entry).
  `notely-web` sends all its outbound traffic into the `default` network (Direct VPC egress, *all
  traffic*, subnet `default` in `europe-north1`), and that subnet gets **Private Google Access**, so the
  page's calls to the API's `run.app` address travel inside the VPC and count as internal.
- **b) The bucket is private.** The `allUsers` grant goes, *public access prevention* is enforced, and the
  identity Cloud Run runs as (still the Compute Engine default service account) gets *Storage Object
  Admin* on the bucket explicitly.
- **c) The database has no public address.** Private services access gives it an address in the `default`
  network; the public address and the `0.0.0.0/0` network go. The API reaches it with Direct VPC egress
  (*private ranges only*). A firewall rule denies `tcp:5432` to the revisions tagged `notely-web`, so only
  the API can even open a connection to it.

**Run it:** `bash deploy/exercise5.sh`. Console click-paths and the "what to tell the lawyer"
paragraph: course document, Exercise 5.

**Check it:** `curl https://notely-api-…run.app/health` from your laptop answers **404**;
`curl https://notely-web-…run.app/health` answers with the API's JSON (`"storage":"postgres"`);
the file's direct address `https://storage.googleapis.com/notely-attachments-…/notes/1/…` answers **401 or
403** (it answered 200 in Exercise 4);
`gcloud sql instances describe notely-db --format='yaml(ipAddresses)'` lists only a `PRIVATE` address.
