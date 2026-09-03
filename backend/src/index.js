import express from 'express';
import cors from 'cors';
import { createRepository } from './repository.js';
import { resolveInstance } from './instance.js';

const INSTANCE = await resolveInstance();
console.log(JSON.stringify({ severity: 'INFO',
  message: `Instance: ${INSTANCE.name} (${INSTANCE.platform})`, instance: INSTANCE }));

const app  = express();
const PORT = process.env.PORT || 3000;

app.set('trust proxy', true);

// M6 narrows this to the bucket origin. M7 removes it entirely.
// exposedHeaders lets the browser read X-Served-By when the frontend lives on a
// different origin (bucket / separate Cloud Run service).
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  exposedHeaders: ['X-Served-By'],
}));
app.use(express.json());

// Every response states which instance produced it. With the LB in front of the
// MIG, a repeated `curl -I` shows the spread without touching /health.
app.use((_req, res, next) => {
  res.set('X-Served-By', INSTANCE.name);
  next();
});

const repo = await createRepository();
console.log(JSON.stringify({ severity: 'INFO', message: `Repository: ${repo.kind}` }));

app.get('/health', async (_req, res) => {
  const instance = { ...INSTANCE, uptimeSeconds: Math.round(process.uptime()) };
  try {
    await repo.ping();
    res.json({ status: 'ok', storage: repo.kind, instance });
  } catch (err) {
    console.error(JSON.stringify({ severity: 'ERROR',
      message: 'health check failed', detail: err.message }));
    res.status(503).json({ status: 'degraded', storage: repo.kind, instance });
  }
});

app.get('/api/notes', async (_req, res, next) => {
  try { res.json(await repo.list()); } catch (e) { next(e); }
});

app.get('/api/notes/:id', async (req, res, next) => {
  try {
    const n = await repo.get(req.params.id);
    n ? res.json(n) : res.status(404).json({ error: 'Note not found' });
  } catch (e) { next(e); }
});

app.post('/api/notes', async (req, res, next) => {
  try {
    const { title, body } = req.body ?? {};
    if (!title?.trim()) return res.status(400).json({ error: 'title is required' });
    res.status(201).json(await repo.create({ title: title.trim(), body: (body ?? '').trim() }));
  } catch (e) { next(e); }
});

app.put('/api/notes/:id', async (req, res, next) => {
  try {
    const { title, body } = req.body ?? {};
    const n = await repo.update(req.params.id, { title, body });
    n ? res.json(n) : res.status(404).json({ error: 'Note not found' });
  } catch (e) { next(e); }
});

app.delete('/api/notes/:id', async (req, res, next) => {
  try {
    (await repo.remove(req.params.id))
      ? res.status(204).end()
      : res.status(404).json({ error: 'Note not found' });
  } catch (e) { next(e); }
});

// On-demand 500. Needed in M10 to test the alerting policy.
app.get('/api/boom', () => { throw new Error('Deliberate error for alert testing'); });

app.use((err, req, res, _next) => {
  console.error(JSON.stringify({
    severity: 'ERROR', message: err.message,
    endpoint: req.path, method: req.method, status: 500,
  }));
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, () => console.log(
  JSON.stringify({ severity: 'INFO', message: `Notely listening on ${PORT}` })));
