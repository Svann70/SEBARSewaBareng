import * as service from './notifications.service.js';

export async function list(req, res) {
  const rows = await service.listMine(req.user.id);
  res.json({
    unread: rows[0]?.unread ?? 0,
    items: rows.map((r) => ({ id: r.id, type: r.type, payload: r.payload, readAt: r.read_at, createdAt: r.created_at })),
  });
}

export async function readAll(req, res) {
  res.json({ updated: await service.markAllRead(req.user.id) });
}
