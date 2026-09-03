let configPromise = null;

// config.json is served with no-store: every frontend VM or container can
// rewrite it at startup to announce who is serving the static files.
function config() {
  configPromise ??= fetch('/config.json', { cache: 'no-store' })
    .then((r) => r.json())
    .catch(() => ({}));
  return configPromise;
}

async function base() {
  return (await config()).apiBaseUrl ?? '';
}

async function request(path, options = {}) {
  const res = await fetch(`${await base()}/api/notes${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
  return res.status === 204 ? null : res.json();
}

export const listNotes  = ()      => request('');
export const getNote    = (id)    => request(`/${id}`);
export const createNote = (d)     => request('', { method: 'POST', body: JSON.stringify(d) });
export const updateNote = (id, d) => request(`/${id}`, { method: 'PUT', body: JSON.stringify(d) });
export const deleteNote = (id)    => request(`/${id}`, { method: 'DELETE' });

// Who serves the static files. The VM startup script writes it into config.json;
// on the bucket (final stage) there is no instance, just Cloud Storage itself.
export const frontendId = async () => (await config()).frontendInstance ?? null;

export async function fetchHealth() {
  const res = await fetch(`${await base()}/health`, { cache: 'no-store' });
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
  return res.json();
}
