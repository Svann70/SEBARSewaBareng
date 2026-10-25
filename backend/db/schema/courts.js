// Table public.courts.
// Mirrors the database exactly (drizzle-kit generates migrations from the difference),
// so do not drop definitions that still exist in the database. See ./index.js.
import { pgTable, index, foreignKey, check, uuid, numeric, unique, varchar, smallint, time } from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { courtStatus, sportType } from "./enums.js";
import { venues } from "./venues.js";

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
