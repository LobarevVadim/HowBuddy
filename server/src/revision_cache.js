export function createRevisionCache({revision, load}) {
  const values = new Map();
  const pending = new Map();
  return {
    async get(key) {
      for (let retry = 0; retry < 5; retry++) {
        const version = String(await revision());
        if (values.get(key)?.version === version) return values.get(key).value;
        const pendingKey = `${version}:${key}`;
        let loading = pending.get(pendingKey);
        if (!loading) {
          loading = load(key);
          pending.set(pendingKey, loading);
        }
        let value;
        try { value = await loading; }
        finally { if (pending.get(pendingKey) === loading) pending.delete(pendingKey); }
        if (String(await revision()) !== version) continue;
        values.set(key, {version, value});
        return value;
      }
      throw new Error('Content is being updated. Please retry.');
    },
  };
}
