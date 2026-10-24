// Exercise 5 - the page's own server, and the only way in to the API.
//
// It serves the built page (dist/) and forwards every request for /api/* and
// /health to the API, whose address is API_URL (the API's run.app URL on Cloud
// Run, http://backend:3000 in docker compose). The browser talks to one origin
// only and never learns where the API lives. On Cloud Run the API accepts no
// request from the internet (ingress "internal"); this server reaches it through
// the VPC (Direct VPC egress, all traffic, Private Google Access on the subnet).
import express from 'express';
import http from 'node:http';
import https from 'node:https';
import { fileURLToPath } from 'node:url';

const PORT    = Number(process.env.PORT || 8080);   // Cloud Run sets PORT
const DIST    = fileURLToPath(new URL('./dist/', import.meta.url));
if (!process.env.API_URL) {
  console.error(JSON.stringify({ severity: 'ERROR',
    message: 'API_URL is not set: the address of the API, e.g. https://notely-api-....run.app' }));
  process.exit(1);
}
const API    = new URL(process.env.API_URL);
const client = API.protocol === 'https:' ? https : http;

// Headers that belong to one connection, not to the request: never forwarded.
const HOP_BY_HOP = new Set(['connection', 'keep-alive', 'proxy-connection', 'transfer-encoding',
                            'te', 'trailer', 'upgrade', 'expect', 'host']);
const endToEnd = headers =>
  Object.fromEntries(Object.entries(headers).filter(([name]) => !HOP_BY_HOP.has(name)));

// The reverse proxy: method, path, query, headers and body go to the API as they
// came, streamed in both directions (PDF uploads and downloads included). The
// Host header becomes the API's host: Cloud Run routes a request on it.
function toApi(req, res) {
  const upstream = client.request(new URL(req.originalUrl, API), {
    method: req.method,
    headers: {
      ...endToEnd(req.headers),
      host: API.host,
      'x-forwarded-for': [req.headers['x-forwarded-for'], req.socket.remoteAddress].filter(Boolean).join(', '),
      'x-forwarded-host': req.headers.host,
    },
    timeout: 60_000,
  }, apiRes => {
    res.writeHead(apiRes.statusCode, endToEnd(apiRes.headers));
    apiRes.pipe(res);
  });
  upstream.on('timeout', () => upstream.destroy(new Error('the API did not answer within 60 s')));
  upstream.on('error', err => {
    console.error(JSON.stringify({ severity: 'ERROR', message: 'API unreachable',
      detail: err.message, path: req.originalUrl }));
    if (res.headersSent) return res.destroy();
    res.status(502).json({ error: 'API unreachable' });
  });
  res.on('close', () => { if (!res.writableFinished) upstream.destroy(); });   // the browser gave up
  req.pipe(upstream);
}

const app = express();
app.disable('x-powered-by');

// The browser reads config.json when the page starts. The API is on the same
// origin now, so apiBaseUrl is empty; the footer shows which revision served the page.
app.get('/config.json', (_req, res) => {
  res.set('Cache-Control', 'no-store').json({
    apiBaseUrl: '',
    frontendInstance: process.env.K_REVISION ?? process.env.K_SERVICE ?? 'local',
  });
});

app.use(['/api', '/health'], toApi);

// The page itself. Any other path gets index.html: it is a single-page app.
app.use(express.static(DIST));
app.get('*', (_req, res) => res.sendFile('index.html', { root: DIST }));

app.listen(PORT, () => console.log(JSON.stringify({ severity: 'INFO',
  message: `Notely page and proxy listening on ${PORT}; API at ${API.origin}` })));
