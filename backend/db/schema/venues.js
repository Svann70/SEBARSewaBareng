// Table public.venues.
// Mirrors the database exactly (drizzle-kit generates migrations from the difference),
// so do not drop definitions that still exist in the database. See ./index.js.
import { pgTable, index, foreignKey, uuid, timestamp, text, varchar } from "drizzle-orm/pg-core";
import { venueStatus } from "./enums.js";
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
