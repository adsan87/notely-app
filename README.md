# Notely

A small notes app used as the running example for a cloud deployment exercise.
An Express API on the backend, a React + Vite single-page app on the frontend,
served by a small Node server that is also the reverse proxy to the API.

```
notely-app/
├── backend/          Express API (Node 20+, ES modules)
│   └── src/
│       ├── index.js        routes and middleware
│       ├── repository.js   storage: in memory, or PostgreSQL when DB_HOST is set
│       ├── attachments.js  PDF attachments in a Cloud Storage bucket
│       └── instance.js     which instance is serving — see INSTANCE-IDENTITY.md
├── frontend/         React + Vite SPA
│   ├── server.js            serves the built page and forwards /api and /health to the API
│   ├── public/config.json   runtime config, read by the browser at load time
│   └── src/
├── deploy/           the gcloud script of this branch's exercise (see deploy/EXERCISE.md)
└── docker-compose.yml
```

Without `DB_HOST` the notes live in memory, so **they disappear when the backend
restarts**. That was the starting point of the course; with `DB_HOST` set they
live in PostgreSQL.

## Requirements

- Node.js 20 or newer (the backend is pinned to `>=20`; the images use Node 22)
- npm
- Docker and Docker Compose, only for the combined setup

## Running the backend on its own

```bash
cd backend
npm install
npm start           # or: npm run dev  (restarts on file changes)
```

The API listens on **http://localhost:3000**. Override with `PORT`:

```bash
PORT=3099 npm start
```

Quick check:

```bash
curl http://localhost:3000/health
curl http://localhost:3000/api/notes
```

### Backend environment variables

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | `3000` | Port the API listens on |
| `CORS_ORIGIN` | `*` | Allowed origin. Not needed when the page proxies the API (same origin) |
| `METADATA_TIMEOUT_MS` | `1000` | Timeout for the GCP metadata probe at startup |
| `DB_HOST` | — | PostgreSQL host. When set, notes are stored in PostgreSQL instead of memory |
| `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | `5432`, `notely`, —, `notely` | PostgreSQL connection |
| `DB_SSL` | — | `true` to encrypt the connection to the database |
| `ATTACHMENTS_BUCKET` | — | Cloud Storage bucket for the PDF attachments. Without it, the attachment routes answer 501 |

### Endpoints

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/health` | Status, storage kind, and the serving instance |
| `GET` | `/api/notes` | List notes, newest first |
| `GET` | `/api/notes/:id` | Fetch one note (404 if missing) |
| `POST` | `/api/notes` | Create a note. Body: `{ "title": "...", "body": "..." }` |
| `PUT` | `/api/notes/:id` | Update a note |
| `DELETE` | `/api/notes/:id` | Delete a note and its attachment (204 on success) |
| `POST` | `/api/notes/:id/attachment` | Attach a PDF (multipart field `file`, up to 10 MB) |
| `GET` | `/api/notes/:id/attachment` | Download the note's PDF |
| `GET` | `/api/boom` | Throws on purpose, to exercise error handling and alerting |

`Notely.postman_collection.json` covers the notes routes. Its `protocol` / `host` /
`port` variables default to `http` / `localhost` / `3000`. On Cloud Run, from
Exercise 5 on, the API is reachable only through the page: point Postman at the
page's address (`https`, the `notely-web` host, port 443).

## Running the frontend on its own

```bash
cd frontend
npm install
npm run dev
```

The app opens on **http://localhost:5173**. In dev mode Vite proxies `/api` and
`/health` to `http://localhost:3000`, so **start the backend first** and leave
`public/config.json` with an empty `apiBaseUrl`.

To run the production build the way the container runs it:

```bash
npm run build                                   # outputs to dist/
API_URL=http://localhost:3000 npm run serve     # page and proxy on http://localhost:8080
```

`server.js` serves `dist/`, answers `/config.json` itself and forwards every
request for `/api/*` and `/health` to `API_URL`, streaming bodies both ways (PDF
uploads and downloads included).

### Frontend runtime config

`config.json` is fetched by the browser at load time with `cache: no-store`,
never baked into the bundle.

| Key | Purpose |
|---|---|
| `apiBaseUrl` | Base URL of the API. Empty string means same origin (the page's server, or Vite in dev mode, forwards the calls) |
| `frontendInstance` | Label for whoever serves the page: the Cloud Run revision, or `local` |

Both values show up in the footer of the running app, next to the backend
instance that answered. See [INSTANCE-IDENTITY.md](INSTANCE-IDENTITY.md).

## Running both with Docker Compose

From the repository root:

```bash
docker compose up --build
```

| Service | URL |
|---|---|
| Frontend (page and proxy) | http://localhost:5173 |
| Backend | not published: reachable only through the frontend |
| PostgreSQL | not published: reachable only by the backend |

The browser talks to the frontend only. The frontend forwards `/api` and `/health`
to `http://backend:3000` over the compose network, as the Cloud Run page does with
the API's internal address. Check it with `curl http://localhost:5173/health`.

To stop and clean up:

```bash
docker compose down
```

Rebuild after changing dependencies or a Dockerfile:

```bash
docker compose up --build --force-recreate
```

## Troubleshooting

**`Cannot find package 'express'`** — dependencies were never installed. Run
`npm install` inside `backend/` (or `frontend/`).

**`EADDRINUSE`** — something already holds the port. Either stop it or pick
another one with `PORT=3099 npm start`.

**Frontend loads but every request fails** — the backend is not running, or
`API_URL` points somewhere else (the page's server logs `API unreachable` and
answers 502). Check the footer: it reads `no response` when `/health` cannot be
reached.

**The page on Cloud Run answers 404 for every `/api` call** — the API's ingress is
`internal` and the request did not come through the VPC: Cloud Run refuses it with
a 404 that leaves no log entry. The page must send its traffic through the VPC:
Direct VPC egress with *all traffic*, and Private Google Access on that subnet
(`deploy/EXERCISE.md`, Exercise 5).

**Notes vanished** — expected without `DB_HOST`: storage is in memory and resets on restart.


## Course branches (Cloud Computing Continuum, T630034401)

One branch per exercise, each built on the previous one; `main` is the final state.
Open `deploy/EXERCISE.md` on a branch to see what changed and how it is deployed;
on GitHub, **Compare** two branches to see the code diff between exercises.

| Branch | What is new |
|---|---|
| `exercise1` | Two VMs, no containers (`deploy/startup-*.sh`) |
| `exercise2` | Dockerfiles; both parts on Cloud Run (1 to 2 instances each) |
| `exercise3` | Notes in Cloud SQL (PostgreSQL, Enterprise edition); local `docker-compose.yml` with a database |
| `exercise4` | "Attach file": PDFs in a Cloud Storage bucket, through the backend; the bucket is still exposed |
| `exercise5` | The page becomes the API's reverse proxy (`frontend/server.js`); internal API, private database, private bucket |
| `exercise6` | Least privilege: a read-only group for the founders, one identity per service (no code change) |
| `exercise7` | 1 to 3 instances per service, an uptime check through the page, two alerts (no code change) |
| `exercise8` | Architecture review (no code change) |
| `exercise9` | GitHub Actions workflow: deploy with one push |

Never commit real project IDs, passwords or service-account keys: `deploy/00-env.sh` holds placeholders only.
