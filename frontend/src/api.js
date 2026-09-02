let baseUrl = null;

async function base() {
  if (baseUrl === null) {
    try {
      const r = await fetch('/config.json', { cache: 'no-store' });
      baseUrl = (await r.json()).apiBaseUrl ?? '';
    } catch { baseUrl = ''; }
  }
  return baseUrl;
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
