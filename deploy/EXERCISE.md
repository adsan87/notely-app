# Exercise 7 — scale, watch, be told

**What changes in the code:** nothing. `GET /api/boom` (already in the code) fails on purpose so you
can prove the error alert fires.

**How it is deployed:** the API's instance limits (minimum 1, maximum 10 — scale *out* is automatic
on Cloud Run); an uptime check on `/health` every minute; two alerts: *the app is down* (IT and
the founder) and *users get 5xx errors* (IT). The policies are in `deploy/alerts/`.

**Run it:** create the two e-mail notification channels in the console first, paste their names
into `deploy/exercise7.sh`, then `bash deploy/exercise7.sh`. Course document, Exercise 7.
