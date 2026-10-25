import { createSchema, idSchema, listSchema, memberParamsSchema } from './lobbies.schema.js';
import * as service from './lobbies.service.js';

function lobbyDto(r) {
  const { share, hostShare, joinCost } = service.shares(r);
  return {
    id: r.id,
    title: r.title,
    hostId: r.host_id,
    creatorId: r.creator_id,
    venue: { id: r.venue_id, name: r.venue_name, city: r.city },
    court: { name: r.court_name, sport: r.sport_type, photoUrl: r.court_photo ?? null },
    slot: { id: r.slot_id, startAt: r.start_at, endAt: r.end_at },
    priceTotal: r.price_total,
    quota: r.quota,
    // Patungan v2: share per seat now; joinCost = what joining costs now (null = full).
    share,
    hostShare,
    joinCost,
    pricePerPerson: joinCost ?? share,
    seats: r.seats,
    vacant: r.vacant,
    minReliability: r.min_reliability,
    joined: r.joined,
    joinDeadline: r.join_deadline,
    status: r.status,
  };
}

function memberDto(m) {
  return { id: m.id, lobbyId: m.lobby_id, userId: m.user_id, role: m.role_in_lobby, status: m.status, holdAmount: m.hold_amount, freeUntil: m.free_until, joinedAt: m.joined_at };
}

function myDto(m) {
  return m && {
    status: m.status,
    role: m.role_in_lobby,
    phase: m.phase,
    holdAmount: m.hold_amount,
    shareAtJoin: m.share_at_join,
    fineAmount: m.fine_amount,
    freeUntil: m.free_until,
    protectUntil: m.protect_until,
  };
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
  const [lobby, members, me] = await Promise.all([service.getById(id), service.listMembers(id), service.myMembership(id, req.user.id)]);
  res.json({
    ...lobbyDto(lobby),
    members: members.map((m) => ({ userId: m.user_id, fullName: m.full_name, reliabilityScore: m.reliability_score, role: m.role_in_lobby, status: m.status })),
    me: myDto(me),
  });
}

export async function join(req, res) {
  const { id } = idSchema.parse(req.params);
  const result = await service.join(id, req.user.id);
  res.status(result.created ? 201 : 200).json({ member: memberDto(result.member) });
}

export async function leave(req, res) {
  const { id } = idSchema.parse(req.params);
  res.json(await service.leave(id, req.user.id));
}

export async function kick(req, res) {
  const { id, userId } = memberParamsSchema.parse(req.params);
  res.json(await service.kick(id, req.user.id, userId));
}

export async function disband(req, res) {
  const { id } = idSchema.parse(req.params);
  res.json(await service.disband(id, req.user.id));
}
