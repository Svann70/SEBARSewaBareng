// Table public.lobbies.
// Mirrors the database exactly (drizzle-kit generates migrations from the difference),
// so do not drop definitions that still exist in the database. See ./index.js.
import { pgTable, uniqueIndex, index, foreignKey, check, uuid, timestamp, numeric, varchar, smallint } from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { lobbyStatus, sportType } from "./enums.js";
import { courtSlots } from "./court-slots.js";
import { users } from "./users.js";

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
	// Patungan v2: the player who paid 100% (guarantor); host_id can move to another member on match day.
	creatorId: uuid("creator_id"),
	// Fines of replaced members were paid out (room finished).
	settledAt: timestamp("settled_at", { withTimezone: true, mode: 'string' }),
}, (table) => [
	index("idx_lobbies_search").using("btree", table.status.asc().nullsLast(), table.minReliability.asc().nullsLast(), table.createdAt.desc().nullsFirst()),
	uniqueIndex("uq_lobbies_active_slot").using("btree", table.slotId.asc().nullsLast()).where(sql`(status = ANY (ARRAY['OPEN'::lobby_status, 'FILLED'::lobby_status, 'CONFIRMED'::lobby_status]))`),
	foreignKey({ name: "lobbies_host_id_fkey", columns: [table.hostId], foreignColumns: [users.id] }).onDelete("restrict"),
	foreignKey({ name: "lobbies_slot_id_fkey", columns: [table.slotId], foreignColumns: [courtSlots.id] }).onDelete("restrict"),
	foreignKey({ name: "lobbies_creator_id_fkey", columns: [table.creatorId], foreignColumns: [users.id] }).onDelete("restrict"),
	check("lobbies_min_reliability_check", sql`(min_reliability >= (0)::numeric) AND (min_reliability <= (100)::numeric)`),
	check("lobbies_price_total_check", sql`price_total > (0)::numeric`),
	check("lobbies_quota_check", sql`(quota >= 2) AND (quota <= 30)`),
]).enableRLS();
