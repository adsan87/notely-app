# Exercise 7 — scale, watch, be told

**What changes in the code:** nothing. `GET /api/boom` (already in the code) fails on purpose so you
can prove the error alert fires.

**How it is deployed:**
- Both services scale out between **1 and 3 instances** (`--min-instances=1 --max-instances=3`): one
  copy is always warm, three is the cost fuse. Scaling out is automatic on Cloud Run.
- An **uptime check** calls `https://notely-web-…run.app/health` every minute. The page forwards it to
  the API, which runs `SELECT 1`, so one probe covers the page, the proxy, the API and the database:
  the path a user takes. (An uptime check of the same project could also reach the API's own `run.app`
  address despite its internal ingress; the page's address is the one users see.)
- Two alerts, in `deploy/alerts/`: *the app is down* (the uptime check fails for 5 minutes → IT and the
  founder) and *users get 5xx errors* (more than 5 in 5 minutes at `notely-api` → IT).
- Every `curl` goes to the page's address: since Exercise 5 the API answers nobody on the internet.

**Run it:** create the two e-mail notification channels in the console first, paste their names
into `deploy/exercise7.sh`, then `bash deploy/exercise7.sh`. Course document, Exercise 7.

**Check it:** `for i in $(seq 8); do curl -s -o /dev/null -w '%{http_code}\n' https://notely-web-…run.app/api/boom; done`
prints `500` eight times and the error e-mail arrives; `Monitoring > Uptime checks` shows the check passing.
