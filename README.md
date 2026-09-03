# Notely

A small notes app used as the running example for a cloud deployment exercise.
An Express API on the backend, a React + Vite single-page app on the frontend.

```
notely-app/
├── backend/          Express API (Node 20+, ES modules)
│   └── src/
│       ├── index.js      routes and middleware
│       ├── repository.js storage (currently in-memory)
│       └── instance.js   which instance is serving — see INSTANCE-IDENTITY.md
├── frontend/         React + Vite SPA
│   ├── public/config.json   runtime config, read by the browser at load time
│   └── src/
└── docker-compose.yml
```

Notes live in memory, so **they disappear when the backend restarts**. That is
deliberate: it is the constraint that motivates moving to shared storage later.

## Requirements

- Node.js 20 or newer (the backend is pinned to `>=20`, and was tested on 22)
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
| `CORS_ORIGIN` | `*` | Allowed origin. Narrow this once the frontend has a fixed URL |
| `METADATA_TIMEOUT_MS` | `1000` | Timeout for the GCP metadata probe at startup |

### Endpoints

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/health` | Status, storage kind, and the serving instance |
| `GET` | `/api/notes` | List notes, newest first |
| `GET` | `/api/notes/:id` | Fetch one note (404 if missing) |
| `POST` | `/api/notes` | Create a note. Body: `{ "title": "...", "body": "..." }` |
| `PUT` | `/api/notes/:id` | Update a note |
| `DELETE` | `/api/notes/:id` | Delete a note (204 on success) |
| `GET` | `/api/boom` | Throws on purpose, to exercise error handling and alerting |

`Notely.postman_collection.json` covers all of these. Its `protocol` / `host` /
`port` variables default to `http` / `localhost` / `3000`.

## Running the frontend on its own

```bash
cd frontend
npm install
npm run dev
```

The app opens on **http://localhost:5173**. In dev mode Vite proxies `/api` to
`http://localhost:3000`, so **start the backend first** and leave
`public/config.json` with an empty `apiBaseUrl`.

To serve a production build instead:

```bash
npm run build     # outputs to dist/
npm run preview
```

`npm run preview` does **not** proxy `/api`. Point the app at the API by setting
`apiBaseUrl` in `public/config.json` before building, or by editing
`dist/config.json` afterward:

```json
{ "apiBaseUrl": "http://localhost:3000", "frontendInstance": null }
```

### Frontend runtime config

`config.json` is fetched by the browser at load time with `cache: no-store`,
never baked into the bundle. That means one build can be pointed at any backend
just by editing the file — no rebuild.

| Key | Purpose |
|---|---|
| `apiBaseUrl` | Base URL of the API. Empty string means same origin (dev proxy) |
| `frontendInstance` | Label for whoever serves the static files. `null` when there is nothing to name |

Both values show up in the footer of the running app, next to the backend
instance that answered. See [INSTANCE-IDENTITY.md](INSTANCE-IDENTITY.md).

## Running both with Docker Compose

From the repository root:

```bash
docker compose up --build
```

| Service | URL |
|---|---|
| Frontend | http://localhost:5173 |
| Backend | http://localhost:3000 |

Compose mounts `frontend/config.docker.json` over `public/config.json` inside the
container, which points the browser at `http://localhost:3000`. The browser talks
to the backend **published on the host**, not to the `backend` service name, so
that URL is only knowable at deploy time — which is exactly why the config is
loaded at runtime.

`CORS_ORIGIN` is set to `http://localhost:5173` for the backend service, so the
browser is allowed to call the API across origins.

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
`npm install` inside `backend/`.

**`EADDRINUSE`** — something already holds the port. Either stop it or pick
another one with `PORT=3099 npm start`.

**Frontend loads but every request fails** — the backend is not running, or
`apiBaseUrl` points somewhere else. Check the footer: it reads `no response`
when `/health` cannot be reached.

**CORS errors in the browser console** — `CORS_ORIGIN` on the backend does not
match the origin the frontend is served from.

**Notes vanished** — expected. Storage is in memory and resets on restart.
