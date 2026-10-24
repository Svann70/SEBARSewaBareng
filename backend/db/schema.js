// Drizzle schema of the SEBAR database (public schema).
// Generated with `drizzle-kit pull` from a database built by the drizzle/ migrations, then fixed
// by hand: citext column type, operator classes removed (pull swapped them).
// Not represented here, kept as SQL in drizzle/ migrations: triggers, functions, the EXCLUDE
// constraint on court_slots and RLS policies (every table has RLS on: .enableRLS()).
// Queries use this schema; migrations stay authoritative.
import { customType, pgTable, uniqueIndex, index, foreignKey, check, uuid, timestamp, numeric, boolean, unique, text, jsonb, varchar, smallint, integer, bigserial, char, time, primaryKey, pgView, bigint, pgEnum } from "drizzle-orm/pg-core"
import { sql } from "drizzle-orm"

// Case-insensitive text (users.email).
const citext = customType({ dataType: () => "citext" });

export const bookingStatus = pgEnum("booking_status", ['CONFIRMED', 'COMPLETED', 'CANCELLED'])
export const checkinStatus = pgEnum("checkin_status", ['PENDING', 'SCANNED', 'EXPIRED', 'NO_SHOW'])
export const courtStatus = pgEnum("court_status", ['ACTIVE', 'MAINTENANCE'])
export const ledgerType = pgEnum("ledger_type", ['TOPUP', 'HOLD', 'RELEASE', 'CAPTURE', 'REFUND', 'PAYOUT', 'PENALTY'])
export const lobbyStatus = pgEnum("lobby_status", ['OPEN', 'FILLED', 'CONFIRMED', 'CANCELLED', 'EXPIRED', 'FAILED'])
export const memberRole = pgEnum("member_role", ['HOST', 'PLAYER'])
export const memberStatus = pgEnum("member_status", ['HOLDING', 'CONFIRMED', 'CANCELLED', 'REFUNDED', 'PENALIZED', 'NO_SHOW'])
export const payoutStatus = pgEnum("payout_status", ['PENDING', 'PAID'])
export const reliabilityReason = pgEnum("reliability_reason", ['CHECKIN', 'LATE_CANCEL', 'NO_SHOW', 'HOST_CANCEL', 'MANUAL_ADJUST'])
export const slotStatus = pgEnum("slot_status", ['OPEN', 'LOBBY_FULL', 'BOOKED', 'BLOCKED', 'PAST'])
export const sportType = pgEnum("sport_type", ['BADMINTON', 'FUTSAL', 'VOLLEY', 'MINISOCCER', 'BASKETBALL', 'TENNIS', 'PADEL'])
export const userRole = pgEnum("user_role", ['PLAYER', 'VENUE_ADMIN', 'SUPER_ADMIN'])
export const venueStatus = pgEnum("venue_status", ['ACTIVE', 'INACTIVE'])


export const courtSlots = pgTable("court_slots", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	courtId: uuid("court_id").notNull(),
	startAt: timestamp("start_at", { withTimezone: true, mode: 'string' }).notNull(),
	endAt: timestamp("end_at", { withTimezone: true, mode: 'string' }).notNull(),
	price: numeric({ precision: 12, scale:  2 }).notNull(),
	status: slotStatus().default('OPEN').notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	released: boolean().default(false).notNull(),
}, (table) => [
	uniqueIndex("court_slots_court_id_start_at_key").using("btree", table.courtId.asc().nullsLast(), table.startAt.asc().nullsLast()).where(sql`(NOT released)`),
	index("idx_slots_court_start").using("btree", table.courtId.asc().nullsLast(), table.startAt.desc().nullsFirst()),
	index("idx_slots_open").using("btree", table.startAt.asc().nullsLast()).where(sql`(status = 'OPEN'::slot_status)`),
	foreignKey({
			columns: [table.courtId],
			foreignColumns: [courts.id],
			name: "court_slots_court_id_fkey"
		}).onDelete("cascade"),
	check("court_slots_check", sql`end_at > start_at`),
	check("court_slots_price_check", sql`price > (0)::numeric`),
]).enableRLS();

export const venuePayouts = pgTable("venue_payouts", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	bookingId: uuid("booking_id").notNull(),
	venueId: uuid("venue_id").notNull(),
	amount: numeric({ precision: 12, scale:  2 }).notNull(),
	status: payoutStatus().default('PENDING').notNull(),
	disbursedAt: timestamp("disbursed_at", { withTimezone: true, mode: 'string' }),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	foreignKey({
			columns: [table.bookingId],
			foreignColumns: [bookings.id],
			name: "venue_payouts_booking_id_fkey"
		}).onDelete("restrict"),
	foreignKey({
			columns: [table.venueId],
			foreignColumns: [venues.id],
			name: "venue_payouts_venue_id_fkey"
		}).onDelete("restrict"),
	unique("venue_payouts_booking_id_key").on(table.bookingId),
	check("payouts_state_coherent", sql`((status = 'PENDING'::payout_status) AND (disbursed_at IS NULL)) OR ((status = 'PAID'::payout_status) AND (disbursed_at IS NOT NULL))`),
	check("venue_payouts_amount_check", sql`amount > (0)::numeric`),
]).enableRLS();

export const walletLedger = pgTable("wallet_ledger", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	walletId: uuid("wallet_id").notNull(),
	entryType: ledgerType("entry_type").notNull(),
	amount: numeric({ precision: 14, scale:  2 }).notNull(),
	balanceAfter: numeric("balance_after", { precision: 14, scale:  2 }).notNull(),
	heldAfter: numeric("held_after", { precision: 14, scale:  2 }).notNull(),
	refType: text("ref_type"),
	refId: uuid("ref_id"),
	idempotencyKey: text("idempotency_key"),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_ledger_ref").using("btree", table.refType.asc().nullsLast(), table.refId.asc().nullsLast()),
	index("idx_ledger_wallet").using("btree", table.walletId.asc().nullsLast(), table.createdAt.desc().nullsFirst()),
	foreignKey({
			columns: [table.walletId],
			foreignColumns: [wallets.id],
			name: "wallet_ledger_wallet_id_fkey"
		}).onDelete("restrict"),
	unique("wallet_ledger_idempotency_key_key").on(table.idempotencyKey),
	check("wallet_ledger_amount_check", sql`amount > (0)::numeric`),
]).enableRLS();

export const notifications = pgTable("notifications", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	userId: uuid("user_id").notNull(),
	type: text().notNull(),
	payload: jsonb().default({}).notNull(),
	readAt: timestamp("read_at", { withTimezone: true, mode: 'string' }),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_notifications_user_created").using("btree", table.userId.asc().nullsLast(), table.createdAt.desc().nullsFirst()),
	foreignKey({
			columns: [table.userId],
			foreignColumns: [users.id],
			name: "notifications_user_id_fkey"
		}).onDelete("cascade"),
]).enableRLS();

export const lobbies = pgTable("lobbies", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	slotId: uuid("slot_id").notNull(),
	hostId: uuid("host_id").notNull(),
	title: varchar({ length: 100 }).notNull(),
	minReliability: numeric("min_reliability", { precision: 5, scale:  2 }).default('0').notNull(),
	quota: smallint().notNull(),
	priceTotal: numeric("price_total", { precision: 12, scale:  2 }).notNull(),
	pricePerPerson: numeric("price_per_person", { precision: 12, scale:  2 }).generatedAlwaysAs(sql`ceil((price_total / (quota)::numeric))`),
	joinDeadline: timestamp("join_deadline", { withTimezone: true, mode: 'string' }).notNull(),
	status: lobbyStatus().default('OPEN').notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	sportType: sportType("sport_type"),
}, (table) => [
	index("idx_lobbies_search").using("btree", table.status.asc().nullsLast(), table.minReliability.asc().nullsLast(), table.createdAt.desc().nullsFirst()),
	uniqueIndex("uq_lobbies_active_slot").using("btree", table.slotId.asc().nullsLast()).where(sql`(status = ANY (ARRAY['OPEN'::lobby_status, 'FILLED'::lobby_status, 'CONFIRMED'::lobby_status]))`),
	foreignKey({
			columns: [table.hostId],
			foreignColumns: [users.id],
			name: "lobbies_host_id_fkey"
		}).onDelete("restrict"),
	foreignKey({
			columns: [table.slotId],
			foreignColumns: [courtSlots.id],
			name: "lobbies_slot_id_fkey"
		}).onDelete("restrict"),
	check("lobbies_min_reliability_check", sql`(min_reliability >= (0)::numeric) AND (min_reliability <= (100)::numeric)`),
	check("lobbies_price_total_check", sql`price_total > (0)::numeric`),
	check("lobbies_quota_check", sql`(quota >= 2) AND (quota <= 30)`),
]).enableRLS();

export const users = pgTable("users", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	email: citext("email").notNull(),
	phone: varchar({ length: 20 }),
	fullName: varchar("full_name", { length: 80 }).notNull(),
	passwordHash: text("password_hash").notNull(),
	role: userRole().default('PLAYER').notNull(),
	reliabilityScore: numeric("reliability_score", { precision: 5, scale:  2 }).default('100').notNull(),
	isActive: boolean("is_active").default(true).notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	unique("users_email_key").on(table.email),
	unique("users_phone_key").on(table.phone),
	check("users_reliability_score_check", sql`(reliability_score >= (0)::numeric) AND (reliability_score <= (100)::numeric)`),
]).enableRLS();

export const venues = pgTable("venues", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	ownerId: uuid("owner_id").notNull(),
	name: varchar({ length: 120 }).notNull(),
	address: text().notNull(),
	city: varchar({ length: 60 }).notNull(),
	description: text(),
	photoUrl: text("photo_url"),
	status: venueStatus().default('ACTIVE').notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_venues_city_status").using("btree", table.city.asc().nullsLast(), table.status.asc().nullsLast()),
	foreignKey({
			columns: [table.ownerId],
			foreignColumns: [users.id],
			name: "venues_owner_id_fkey"
		}).onDelete("restrict"),
]).enableRLS();

export const bookings = pgTable("bookings", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	lobbyId: uuid("lobby_id").notNull(),
	slotId: uuid("slot_id").notNull(),
	bookingCode: varchar("booking_code", { length: 12 }).notNull(),
	grossAmount: numeric("gross_amount", { precision: 12, scale:  2 }).notNull(),
	platformFee: numeric("platform_fee", { precision: 12, scale:  2 }).notNull(),
	roundingSurplus: numeric("rounding_surplus", { precision: 12, scale:  2 }).default('0').notNull(),
	venuePayout: numeric("venue_payout", { precision: 12, scale:  2 }).notNull(),
	status: bookingStatus().default('CONFIRMED').notNull(),
	bookedAt: timestamp("booked_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_bookings_status_booked_at").using("btree", table.status.asc().nullsLast(), table.bookedAt.desc().nullsFirst()),
	foreignKey({
			columns: [table.lobbyId],
			foreignColumns: [lobbies.id],
			name: "bookings_lobby_id_fkey"
		}).onDelete("restrict"),
	foreignKey({
			columns: [table.slotId],
			foreignColumns: [courtSlots.id],
			name: "bookings_slot_id_fkey"
		}).onDelete("restrict"),
	unique("bookings_lobby_id_key").on(table.lobbyId),
	unique("bookings_slot_id_key").on(table.slotId),
	unique("bookings_booking_code_key").on(table.bookingCode),
	check("bookings_fee_is_5pct", sql`platform_fee = round((gross_amount * 0.05), 2)`),
	check("bookings_gross_amount_check", sql`gross_amount > (0)::numeric`),
	check("bookings_payout_invariant", sql`venue_payout >= (gross_amount - platform_fee)`),
	check("bookings_platform_fee_check", sql`platform_fee >= (0)::numeric`),
	check("bookings_rounding_surplus_check", sql`rounding_surplus >= (0)::numeric`),
	check("bookings_venue_payout_check", sql`venue_payout > (0)::numeric`),
]).enableRLS();

export const wallets = pgTable("wallets", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	userId: uuid("user_id").notNull(),
	balance: numeric({ precision: 14, scale:  2 }).default('0').notNull(),
	heldBalance: numeric("held_balance", { precision: 14, scale:  2 }).default('0').notNull(),
	version: integer().default(0).notNull(),
}, (table) => [
	foreignKey({
			columns: [table.userId],
			foreignColumns: [users.id],
			name: "wallets_user_id_fkey"
		}).onDelete("restrict"),
	unique("wallets_user_id_key").on(table.userId),
	check("wallets_balance_check", sql`balance >= (0)::numeric`),
	check("wallets_balance_gte_held", sql`balance >= held_balance`),
	check("wallets_held_balance_check", sql`held_balance >= (0)::numeric`),
]).enableRLS();

export const reliabilityEvents = pgTable("reliability_events", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	userId: uuid("user_id").notNull(),
	lobbyId: uuid("lobby_id"),
	delta: numeric({ precision: 5, scale:  2 }).notNull(),
	reason: reliabilityReason().notNull(),
	scoreAfter: numeric("score_after", { precision: 5, scale:  2 }).notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_reliability_user_created").using("btree", table.userId.asc().nullsLast(), table.createdAt.desc().nullsFirst()),
	foreignKey({
			columns: [table.lobbyId],
			foreignColumns: [lobbies.id],
			name: "reliability_events_lobby_id_fkey"
		}).onDelete("set null"),
	foreignKey({
			columns: [table.userId],
			foreignColumns: [users.id],
			name: "reliability_events_user_id_fkey"
		}).onDelete("cascade"),
	check("reliability_events_delta_check", sql`delta <> (0)::numeric`),
]).enableRLS();

export const auditLog = pgTable("audit_log", {
	id: bigserial({ mode: "bigint" }).primaryKey().notNull(),
	actorId: uuid("actor_id"),
	action: text().notNull(),
	entity: text().notNull(),
	entityId: uuid("entity_id"),
	before: jsonb(),
	after: jsonb(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_audit_entity").using("btree", table.entity.asc().nullsLast(), table.entityId.asc().nullsLast(), table.createdAt.desc().nullsFirst()),
	foreignKey({
			columns: [table.actorId],
			foreignColumns: [users.id],
			name: "audit_log_actor_id_fkey"
		}).onDelete("set null"),
]).enableRLS();

export const lobbyMembers = pgTable("lobby_members", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	lobbyId: uuid("lobby_id").notNull(),
	userId: uuid("user_id").notNull(),
	roleInLobby: memberRole("role_in_lobby").default('PLAYER').notNull(),
	status: memberStatus().default('HOLDING').notNull(),
	holdAmount: numeric("hold_amount", { precision: 12, scale:  2 }).notNull(),
	holdLedgerId: uuid("hold_ledger_id"),
	joinedAt: timestamp("joined_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	cancelledAt: timestamp("cancelled_at", { withTimezone: true, mode: 'string' }),
}, (table) => [
	index("idx_lobby_members_user").using("btree", table.userId.asc().nullsLast(), table.status.asc().nullsLast()),
	foreignKey({
			columns: [table.holdLedgerId],
			foreignColumns: [walletLedger.id],
			name: "lobby_members_hold_ledger_id_fkey"
		}).onDelete("set null"),
	foreignKey({
			columns: [table.lobbyId],
			foreignColumns: [lobbies.id],
			name: "lobby_members_lobby_id_fkey"
		}).onDelete("cascade"),
	foreignKey({
			columns: [table.userId],
			foreignColumns: [users.id],
			name: "lobby_members_user_id_fkey"
		}).onDelete("restrict"),
	unique("lobby_members_lobby_id_user_id_key").on(table.lobbyId, table.userId),
	check("lobby_members_hold_amount_check", sql`hold_amount > (0)::numeric`),
]).enableRLS();

export const checkins = pgTable("checkins", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	bookingId: uuid("booking_id").notNull(),
	userId: uuid("user_id").notNull(),
	tokenHash: char("token_hash", { length: 64 }).notNull(),
	tokenExpiresAt: timestamp("token_expires_at", { withTimezone: true, mode: 'string' }).notNull(),
	status: checkinStatus().default('PENDING').notNull(),
	scannedBy: uuid("scanned_by"),
	scannedAt: timestamp("scanned_at", { withTimezone: true, mode: 'string' }),
}, (table) => [
	index("idx_checkins_booking").using("btree", table.bookingId.asc().nullsLast(), table.status.asc().nullsLast()),
	foreignKey({
			columns: [table.bookingId],
			foreignColumns: [bookings.id],
			name: "checkins_booking_id_fkey"
		}).onDelete("restrict"),
	foreignKey({
			columns: [table.scannedBy],
			foreignColumns: [users.id],
			name: "checkins_scanned_by_fkey"
		}).onDelete("set null"),
	foreignKey({
			columns: [table.userId],
			foreignColumns: [users.id],
			name: "checkins_user_id_fkey"
		}).onDelete("restrict"),
	unique("checkins_booking_id_user_id_key").on(table.bookingId, table.userId),
	unique("checkins_token_hash_key").on(table.tokenHash),
]).enableRLS();

export const refreshTokens = pgTable("refresh_tokens", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	userId: uuid("user_id").notNull(),
	familyId: uuid("family_id").notNull(),
	tokenHash: char("token_hash", { length: 64 }).notNull(),
	expiresAt: timestamp("expires_at", { withTimezone: true, mode: 'string' }).notNull(),
	revokedAt: timestamp("revoked_at", { withTimezone: true, mode: 'string' }),
	replacedBy: uuid("replaced_by"),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_refresh_tokens_expires").using("btree", table.expiresAt.asc().nullsLast()),
	index("idx_refresh_tokens_family").using("btree", table.familyId.asc().nullsLast()),
	foreignKey({
			columns: [table.userId],
			foreignColumns: [users.id],
			name: "refresh_tokens_user_id_fkey"
		}).onDelete("cascade"),
	foreignKey({
			columns: [table.replacedBy],
			foreignColumns: [table.id],
			name: "refresh_tokens_replaced_by_fkey"
		}).onDelete("set null"),
	unique("refresh_tokens_token_hash_key").on(table.tokenHash),
]).enableRLS();

export const courts = pgTable("courts", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	venueId: uuid("venue_id").notNull(),
	name: varchar({ length: 60 }).notNull(),
	sportType: sportType("sport_type").notNull(),
	pricePerHour: numeric("price_per_hour", { precision: 12, scale:  2 }).notNull(),
	priceWeekend: numeric("price_weekend", { precision: 12, scale:  2 }),
	capacity: smallint().notNull(),
	status: courtStatus().default('ACTIVE').notNull(),
	openTime: time("open_time").default('06:00:00').notNull(),
	closeTime: time("close_time").default('22:00:00').notNull(),
}, (table) => [
	index("idx_courts_venue").using("btree", table.venueId.asc().nullsLast()),
	foreignKey({
			columns: [table.venueId],
			foreignColumns: [venues.id],
			name: "courts_venue_id_fkey"
		}).onDelete("cascade"),
	unique("courts_venue_id_name_key").on(table.venueId, table.name),
	check("courts_capacity_check", sql`(capacity >= 2) AND (capacity <= 30)`),
	check("courts_price_per_hour_check", sql`price_per_hour > (0)::numeric`),
	check("courts_hours_check", sql`close_time > open_time`),
]).enableRLS();

export const courtSports = pgTable("court_sports", {
	courtId: uuid("court_id").notNull(),
	sportType: sportType("sport_type").notNull(),
	capacity: smallint().notNull(),
}, (table) => [
	foreignKey({
			columns: [table.courtId],
			foreignColumns: [courts.id],
			name: "court_sports_court_id_fkey"
		}).onDelete("cascade"),
	primaryKey({ columns: [table.courtId, table.sportType], name: "court_sports_pkey"}),
	check("court_sports_capacity_check", sql`(capacity >= 2) AND (capacity <= 30)`),
]).enableRLS();
export const vwLobbySearch = pgView("vw_lobby_search", {	id: uuid(),
	slotId: uuid("slot_id"),
	hostId: uuid("host_id"),
	title: varchar({ length: 100 }),
	minReliability: numeric("min_reliability", { precision: 5, scale:  2 }),
	quota: smallint(),
	priceTotal: numeric("price_total", { precision: 12, scale:  2 }),
	pricePerPerson: numeric("price_per_person", { precision: 12, scale:  2 }),
	joinDeadline: timestamp("join_deadline", { withTimezone: true, mode: 'string' }),
	status: lobbyStatus(),
	startAt: timestamp("start_at", { withTimezone: true, mode: 'string' }),
	endAt: timestamp("end_at", { withTimezone: true, mode: 'string' }),
	sportType: sportType("sport_type"),
	courtName: varchar("court_name", { length: 60 }),
	venueId: uuid("venue_id"),
	venueName: varchar("venue_name", { length: 120 }),
	city: varchar({ length: 60 }),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	joined: bigint({ mode: "number" }),
}).as(sql`SELECT l.id, l.slot_id, l.host_id, l.title, l.min_reliability, l.quota, l.price_total, l.price_per_person, l.join_deadline, l.status, s.start_at, s.end_at, c.sport_type, c.name AS court_name, v.id AS venue_id, v.name AS venue_name, v.city, ( SELECT count(*) AS count FROM lobby_members m WHERE m.lobby_id = l.id AND (m.status = ANY (ARRAY['HOLDING'::member_status, 'CONFIRMED'::member_status]))) AS joined FROM lobbies l JOIN court_slots s ON s.id = l.slot_id JOIN courts c ON c.id = s.court_id JOIN venues v ON v.id = c.venue_id`);

export const vwVenueMonthlyRevenue = pgView("vw_venue_monthly_revenue", {	venueId: uuid("venue_id"),
	venueName: varchar("venue_name", { length: 120 }),
	bulan: timestamp({ withTimezone: true, mode: 'string' }),
	// You can use { mode: "bigint" } if numbers are exceeding js number limitations
	totalBooking: bigint("total_booking", { mode: "number" }),
	omzet: numeric(),
	feeSebar: numeric("fee_sebar"),
	payoutGor: numeric("payout_gor"),
}).as(sql`SELECT v.id AS venue_id, v.name AS venue_name, date_trunc('month'::text, b.booked_at) AS bulan, count(*) AS total_booking, sum(b.gross_amount) AS omzet, sum(b.platform_fee) AS fee_sebar, sum(b.venue_payout) AS payout_gor FROM bookings b JOIN lobbies l ON l.id = b.lobby_id JOIN court_slots s ON s.id = b.slot_id JOIN courts c ON c.id = s.court_id JOIN venues v ON v.id = c.venue_id WHERE b.status <> 'CANCELLED'::booking_status GROUP BY v.id, v.name, (date_trunc('month'::text, b.booked_at))`);