let nextId = 1;
const notes = new Map();
const now = () => new Date().toISOString();

export async function createRepository() {
  const t = now();
  notes.set(1, { id: 1, title: 'First note',
                 body: 'This lives in memory. It disappears when the process restarts.',
                 createdAt: t, updatedAt: t });
  nextId = 2;

  return {
    kind: 'memory',
    async list()  { return [...notes.values()].sort((a, b) => b.id - a.id); },
    async get(id) { return notes.get(Number(id)) ?? null; },
    async create({ title, body }) {
      const t = now();
      const note = { id: nextId, title, body, createdAt: t, updatedAt: t };
      notes.set(nextId++, note);
      return note;
    },
    async update(id, { title, body }) {
      const note = notes.get(Number(id));
      if (!note) return null;
      if (title !== undefined) note.title = title;
      if (body  !== undefined) note.body  = body;
      note.updatedAt = now();
      return note;
    },
    async remove(id) { return notes.delete(Number(id)); },
    async ping()     { return true; },
  };
}
