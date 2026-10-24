// Room, peserta, booking, check-in.
// Part of the Drizzle schema (see ./index.js). Mirrors the database exactly: drizzle-kit generates
// migrations from the difference, so do not drop definitions that still exist in the database.
import { pgTable, uniqueIndex, index, foreignKey, check, uuid, timestamp, numeric, unique, varchar, smallint, char, primaryKey } from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { bookingStatus, checkinStatus, lobbyStatus, memberRole, memberStatus, sportType } from "./enums.js";
import { users } from "./users.js";
import { courtSlots } from "./venues.js";
import { walletLedger } from "./wallet.js";

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
	foreignKey({ name: "lobbies_host_id_fkey", columns: [table.hostId], foreignColumns: [users.id] }).onDelete("restrict"),
	foreignKey({ name: "lobbies_slot_id_fkey", columns: [table.slotId], foreignColumns: [courtSlots.id] }).onDelete("restrict"),
	check("lobbies_min_reliability_check", sql`(min_reliability >= (0)::numeric) AND (min_reliability <= (100)::numeric)`),
	check("lobbies_price_total_check", sql`price_total > (0)::numeric`),
	check("lobbies_quota_check", sql`(quota >= 2) AND (quota <= 30)`),
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
	foreignKey({ name: "lobby_members_hold_ledger_id_fkey", columns: [table.holdLedgerId], foreignColumns: [walletLedger.id] }).onDelete("set null"),
	foreignKey({ name: "lobby_members_lobby_id_fkey", columns: [table.lobbyId], foreignColumns: [lobbies.id] }).onDelete("cascade"),
	foreignKey({ name: "lobby_members_user_id_fkey", columns: [table.userId], foreignColumns: [users.id] }).onDelete("restrict"),
	unique("lobby_members_lobby_id_user_id_key").on(table.lobbyId, table.userId),
	check("lobby_members_hold_amount_check", sql`hold_amount > (0)::numeric`),
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
	foreignKey({ name: "bookings_lobby_id_fkey", columns: [table.lobbyId], foreignColumns: [lobbies.id] }).onDelete("restrict"),
	foreignKey({ name: "bookings_slot_id_fkey", columns: [table.slotId], foreignColumns: [courtSlots.id] }).onDelete("restrict"),
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
	foreignKey({ name: "checkins_booking_id_fkey", columns: [table.bookingId], foreignColumns: [bookings.id] }).onDelete("restrict"),
	foreignKey({ name: "checkins_scanned_by_fkey", columns: [table.scannedBy], foreignColumns: [users.id] }).onDelete("set null"),
	foreignKey({ name: "checkins_user_id_fkey", columns: [table.userId], foreignColumns: [users.id] }).onDelete("restrict"),
	unique("checkins_booking_id_user_id_key").on(table.bookingId, table.userId),
	unique("checkins_token_hash_key").on(table.tokenHash),
]).enableRLS();
