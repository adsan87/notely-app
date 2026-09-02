import { useEffect, useState } from 'react';
import { listNotes, getNote, createNote, updateNote, deleteNote } from './api.js';

const s = {
  page:  { fontFamily: 'system-ui, sans-serif', maxWidth: 720, margin: '2rem auto', padding: '0 1rem' },
  card:  { border: '1px solid #ddd', borderRadius: 8, padding: '1rem', marginBottom: '.75rem' },
  input: { width: '100%', padding: '.5rem', marginBottom: '.5rem', boxSizing: 'border-box' },
  btn:   { padding: '.5rem 1rem', marginRight: '.5rem', cursor: 'pointer' },
  err:   { background: '#fee', border: '1px solid #f99', padding: '.75rem', borderRadius: 6 },
};

export default function App() {
  const [notes, setNotes]       = useState([]);
  const [selected, setSelected] = useState(null);
  const [editing, setEditing]   = useState(null);
  const [error, setError]       = useState(null);
  const [loading, setLoading]   = useState(true);

  const guard = fn => async (...a) => {
    try { await fn(...a); setError(null); } catch (e) { setError(e.message); }
  };

  const refresh = guard(async () => {
    setLoading(true);
    try { setNotes(await listNotes()); } finally { setLoading(false); }
  });

  useEffect(() => { refresh(); }, []);

  const open = guard(async id => { setSelected(await getNote(id)); setEditing(null); });

  const save = guard(async e => {
    e.preventDefault();
    if (editing.id) await updateNote(editing.id, { title: editing.title, body: editing.body });
    else            await createNote({ title: editing.title, body: editing.body });
    setEditing(null); setSelected(null); await refresh();
  });

  const remove = guard(async id => {
    if (!confirm('Delete this note?')) return;
    await deleteNote(id); setSelected(null); await refresh();
  });

  return (
    <div style={s.page}>
      <h1>Notely</h1>
      {error && <p style={s.err}><strong>Error:</strong> {error}</p>}

      {editing ? (
        <form onSubmit={save} style={s.card}>
          <h2>{editing.id ? 'Edit note' : 'New note'}</h2>
          <input style={s.input} placeholder="Title" required value={editing.title}
                 onChange={e => setEditing({ ...editing, title: e.target.value })} />
          <textarea style={{ ...s.input, minHeight: 120 }} placeholder="Body" value={editing.body}
                    onChange={e => setEditing({ ...editing, body: e.target.value })} />
          <button style={s.btn} type="submit">Save</button>
          <button style={s.btn} type="button" onClick={() => setEditing(null)}>Cancel</button>
        </form>
      ) : selected ? (
        <div style={s.card}>
          <h2>{selected.title}</h2>
          <p style={{ whiteSpace: 'pre-wrap' }}>{selected.body}</p>
          <small>Updated: {selected.updatedAt}</small>
          <div style={{ marginTop: '1rem' }}>
            <button style={s.btn} onClick={() =>
              setEditing({ id: selected.id, title: selected.title, body: selected.body })}>Edit</button>
            <button style={s.btn} onClick={() => remove(selected.id)}>Delete</button>
            <button style={s.btn} onClick={() => setSelected(null)}>Back</button>
          </div>
        </div>
      ) : (
        <>
          <button style={s.btn} onClick={() => setEditing({ id: null, title: '', body: '' })}>
            New note
          </button>
          {loading ? <p>Loading…</p>
            : notes.length === 0 ? <p>No notes yet.</p>
            : notes.map(n => (
                <div key={n.id} style={s.card}>
                  <strong>{n.title}</strong>
                  <p style={{ color: '#666', margin: '.5rem 0' }}>
                    {n.body?.slice(0, 90)}{n.body?.length > 90 ? '…' : ''}
                  </p>
                  <button style={s.btn} onClick={() => open(n.id)}>View</button>
                </div>
              ))}
        </>
      )}
    </div>
  );
}
