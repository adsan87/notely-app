# Exercise 1 — two VMs, no containers

**What changes in the code:** nothing. This branch is the original app plus this `deploy/` folder.
The Dockerfiles appear in the `exercise2` branch.

**How it is deployed:** two `e2-micro` VMs in `europe-north1-a`. Each VM runs a startup script
(`deploy/startup-api.sh`, `deploy/startup-web.sh`) that installs Node.js 22, clones this repository,
installs the dependencies and starts its part. The frontend VM writes `dist/config.json` with the
API VM's address and serves the built page on port 80. Two firewall rules open ports 3000 and 80.

**Run it:** `source deploy/00-env.sh` (fill in your values first), then `bash deploy/exercise1.sh`.
The console click-paths are in the course document, Exercise 1.

**Check it:** `curl http://API_IP:3000/health` → `"storage":"memory"`. Create a note, reset the
API VM, reload: the note is gone (notes live in memory). That is what Exercise 3 fixes.
