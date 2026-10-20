import { createSchema, idSchema, listSchema } from './lobbies.schema.js';
import * as service from './lobbies.service.js';

function lobbyDto(r) {
  return {
    id: r.id,
    title: r.title,
    hostId: r.host_id,
    venue: { id: r.venue_id, name: r.venue_name, city: r.city },
    court: { name: r.court_name, sport: r.sport_type },
    slot: { id: r.slot_id, startAt: r.start_at, endAt: r.end_at },
    priceTotal: r.price_total,
    quota: r.quota,
    pricePerPerson: r.price_per_person,
    minReliability: r.min_reliability,
    joined: r.joined,
    joinDeadline: r.join_deadline,
    status: r.status,
  };
}

function memberDto(m) {
  return { id: m.id, lobbyId: m.lobby_id, userId: m.user_id, role: m.role_in_lobby, status: m.status, holdAmount: m.hold_amount, joinedAt: m.joined_at };
}

function bookingDto(b) {
  return b && { id: b.id, bookingCode: b.booking_code, status: b.status, grossAmount: b.gross_amount, bookedAt: b.booked_at };
}

export async function list(req, res) {
  const filters = listSchema.parse(req.query);
  res.json({ items: (await service.list(filters)).map(lobbyDto), page: filters.page });
}

export async function create(req, res) {
  res.status(201).json(lobbyDto(await service.create(req.user.id, createSchema.parse(req.body))));
}

export async function detail(req, res) {
  const { id } = idSchema.parse(req.params);
  const [lobby, members] = await Promise.all([service.getById(id), service.listMembers(id)]);
  res.json({
    ...lobbyDto(lobby),
    members: members.map((m) => ({ userId: m.user_id, fullName: m.full_name, reliabilityScore: m.reliability_score, role: m.role_in_lobby, status: m.status })),
  });
}

export async function join(req, res) {
  const { id } = idSchema.parse(req.params);
  const result = await service.join(id, req.user.id);
  res.status(result.created ? 201 : 200).json({ member: memberDto(result.member), booking: bookingDto(result.booking) });
}

export async function leave(req, res) {
  const { id } = idSchema.parse(req.params);
  res.json(await service.leave(id, req.user.id));
}

export async function cancel(req, res) {
  const { id } = idSchema.parse(req.params);
  res.json(await service.cancel(id, req.user.id));
}
