// Table public.court_slots.
// Mirrors the database exactly (drizzle-kit generates migrations from the difference),
// so do not drop definitions that still exist in the database. See ./index.js.
import { pgTable, uniqueIndex, index, foreignKey, check, uuid, timestamp, numeric, boolean } from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { slotStatus } from "./enums.js";
import { courts } from "./courts.js";

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
