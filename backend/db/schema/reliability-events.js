// Table public.reliability_events.
// Mirrors the database exactly (drizzle-kit generates migrations from the difference),
// so do not drop definitions that still exist in the database. See ./index.js.
import { pgTable, index, foreignKey, check, uuid, timestamp, numeric } from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { reliabilityReason } from "./enums.js";
import { lobbies } from "./lobbies.js";
import { users } from "./users.js";

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
	foreignKey({ name: "reliability_events_lobby_id_fkey", columns: [table.lobbyId], foreignColumns: [lobbies.id] }).onDelete("set null"),
	foreignKey({ name: "reliability_events_user_id_fkey", columns: [table.userId], foreignColumns: [users.id] }).onDelete("cascade"),
	check("reliability_events_delta_check", sql`delta <> (0)::numeric`),
]).enableRLS();
