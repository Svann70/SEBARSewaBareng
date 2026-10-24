// Venue, lapangan (olahraga + kapasitas, jam buka), slot, pencairan venue.
// Part of the Drizzle schema (see ./index.js). Mirrors the database exactly: drizzle-kit generates
// migrations from the difference, so do not drop definitions that still exist in the database.
import { pgTable, uniqueIndex, index, foreignKey, check, uuid, timestamp, numeric, boolean, unique, text, varchar, smallint, time, primaryKey } from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { courtStatus, payoutStatus, slotStatus, sportType, venueStatus } from "./enums.js";
import { bookings } from "./lobbies.js";
import { users } from "./users.js";

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
	foreignKey({ name: "venues_owner_id_fkey", columns: [table.ownerId], foreignColumns: [users.id] }).onDelete("restrict"),
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
	foreignKey({ name: "courts_venue_id_fkey", columns: [table.venueId], foreignColumns: [venues.id] }).onDelete("cascade"),
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
	foreignKey({ name: "court_sports_court_id_fkey", columns: [table.courtId], foreignColumns: [courts.id] }).onDelete("cascade"),
	primaryKey({ columns: [table.courtId, table.sportType], name: "court_sports_pkey"}),
	check("court_sports_capacity_check", sql`(capacity >= 2) AND (capacity <= 30)`),
]).enableRLS();

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
	foreignKey({ name: "court_slots_court_id_fkey", columns: [table.courtId], foreignColumns: [courts.id] }).onDelete("cascade"),
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
	foreignKey({ name: "venue_payouts_booking_id_fkey", columns: [table.bookingId], foreignColumns: [bookings.id] }).onDelete("restrict"),
	foreignKey({ name: "venue_payouts_venue_id_fkey", columns: [table.venueId], foreignColumns: [venues.id] }).onDelete("restrict"),
	unique("venue_payouts_booking_id_key").on(table.bookingId),
	check("payouts_state_coherent", sql`((status = 'PENDING'::payout_status) AND (disbursed_at IS NULL)) OR ((status = 'PAID'::payout_status) AND (disbursed_at IS NOT NULL))`),
	check("venue_payouts_amount_check", sql`amount > (0)::numeric`),
]).enableRLS();
