# Identifying which instance serves a request

`GET /health` returns an `instance` object that is resolved **once at startup**
(by querying the GCP metadata server) and then cached. On top of that, **every**
backend response carries an `X-Served-By` header.

Source: [`backend/src/instance.js`](backend/src/instance.js).

## What it returns at each deployment stage

### Local / docker-compose

```json
{ "status": "ok", "storage": "memory", "instance": {
  "platform": "local", "name": "my-laptop", "hostname": "my-laptop",
  "ip": "192.168.1.20", "pid": 8708, "node": "v22.x",
  "startedAt": "...", "uptimeSeconds": 4 }}
```

### Single GCE VM

```json
{ "instance": {
  "platform": "gce", "name": "notely-api-vm", "projectId": "my-project",
  "instanceId": "348...", "zone": "us-central1-b", "region": "us-central1",
  "internalIp": "10.204.0.2", "externalIp": "34.175.x.x",
  "machineType": "e2-micro", "uptimeSeconds": 120 }}
```

### MIG (several VMs)

Same as above, plus a `mig` field holding the name of the group manager. It comes
from `instance/attributes/created-by`, which only exists on VMs created by a MIG:

```json
{ "instance": { "name": "notely-mig-a7f3", "mig": "notely-mig", "zone": "..." }}
```

With in-memory storage, each VM in the MIG holds **its own set of notes**. The
`instance` field is exactly what makes that problem visible before you move to a
shared database.

### MIG + Load Balancer

The response does not change, but now it earns its keep. To watch the spread
without parsing JSON:

```bash
for i in $(seq 10); do curl -s -o /dev/null -D - http://LB_IP/api/notes \
  | grep -i x-served-by; done
```

Note that the load balancer's health check targets `/health`, so probe requests
show up in the logs too. `app.set('trust proxy', true)` was already in place,
which is what lets Express read the real client IP from `X-Forwarded-For` behind
the load balancer.

### Cloud Run

There is no VM name, so `name` becomes `revision/container-id`:

```json
{ "instance": {
  "platform": "cloud-run", "name": "notely-api-00007-xyz/a1b2c3d4e5f6",
  "service": "notely-api", "revision": "notely-api-00007-xyz",
  "configuration": "notely-api", "region": "us-central1",
  "instanceId": "00bf4b...", "internalIp": "169.254.8.1" }}
```

On Cloud Run `internalIp` identifies nothing (it is the sandbox address). The
identifying pair is `revision` + `hostname`: reload and you will see the hostname
change as Cloud Run spreads traffic across containers, and the revision change
when you deploy.

## Identifying the frontend too

`config.json` is fetched with `cache: no-store`, so each VM can rewrite it at
startup and announce itself. In the VM startup script (or the MIG instance
template):

```bash
NAME=$(curl -s -H 'Metadata-Flavor: Google' \
  http://metadata.google.internal/computeMetadata/v1/instance/name)
cat > /var/www/notely/config.json <<JSON
{ "apiBaseUrl": "http://API_LB_IP", "frontendInstance": "$NAME" }
JSON
```

In the final stage (a Cloud Storage bucket) there is no instance: leave
`frontendInstance` as `null` and the footer will read `local/bucket`.

The app's footer (the `ServedBy` component in `frontend/src/App.jsx`) shows both
layers and has a button to re-probe without reloading the page.

## Notes

- If the frontend lives on a different origin (a bucket, or a separate Cloud Run
  service), the browser can only read `X-Served-By` because CORS exposes it via
  `exposedHeaders`. When you lock `CORS_ORIGIN` down in M6, keep that option.
- Outside GCP the metadata probe fails immediately on DNS; even so there is a 1 s
  timeout (`METADATA_TIMEOUT_MS`) so a local startup can never hang.
- Fields without a value are dropped, so `/health` does not fill up with `null`.
