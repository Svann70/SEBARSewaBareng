// Table public.court_sports.
// Mirrors the database exactly (drizzle-kit generates migrations from the difference),
// so do not drop definitions that still exist in the database. See ./index.js.
import { pgTable, foreignKey, check, uuid, smallint, primaryKey } from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { sportType } from "./enums.js";
import { courts } from "./courts.js";

export const courtSports = pgTable("court_sports", {
	courtId: uuid("court_id").notNull(),
	sportType: sportType("sport_type").notNull(),
	capacity: smallint().notNull(),
}, (table) => [
	foreignKey({ name: "court_sports_court_id_fkey", columns: [table.courtId], foreignColumns: [courts.id] }).onDelete("cascade"),
	primaryKey({ columns: [table.courtId, table.sportType], name: "court_sports_pkey"}),
	check("court_sports_capacity_check", sql`(capacity >= 2) AND (capacity <= 30)`),
]).enableRLS();
