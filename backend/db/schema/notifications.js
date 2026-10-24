// Table public.notifications.
// Mirrors the database exactly (drizzle-kit generates migrations from the difference),
// so do not drop definitions that still exist in the database. See ./index.js.
import { pgTable, index, foreignKey, uuid, timestamp, text, jsonb } from "drizzle-orm/pg-core";
import { users } from "./users.js";

export const notifications = pgTable("notifications", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	userId: uuid("user_id").notNull(),
	type: text().notNull(),
	payload: jsonb().default({}).notNull(),
	readAt: timestamp("read_at", { withTimezone: true, mode: 'string' }),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_notifications_user_created").using("btree", table.userId.asc().nullsLast(), table.createdAt.desc().nullsFirst()),
	foreignKey({ name: "notifications_user_id_fkey", columns: [table.userId], foreignColumns: [users.id] }).onDelete("cascade"),
]).enableRLS();
