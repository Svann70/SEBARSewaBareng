// Table public.wallets.
// Mirrors the database exactly (drizzle-kit generates migrations from the difference),
// so do not drop definitions that still exist in the database. See ./index.js.
import { pgTable, foreignKey, check, uuid, numeric, unique, integer } from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { users } from "./users.js";

export const wallets = pgTable("wallets", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	userId: uuid("user_id").notNull(),
	balance: numeric({ precision: 14, scale:  2 }).default('0').notNull(),
	heldBalance: numeric("held_balance", { precision: 14, scale:  2 }).default('0').notNull(),
	version: integer().default(0).notNull(),
}, (table) => [
	foreignKey({ name: "wallets_user_id_fkey", columns: [table.userId], foreignColumns: [users.id] }).onDelete("restrict"),
	unique("wallets_user_id_key").on(table.userId),
	check("wallets_balance_check", sql`balance >= (0)::numeric`),
	check("wallets_balance_gte_held", sql`balance >= held_balance`),
	check("wallets_held_balance_check", sql`held_balance >= (0)::numeric`),
]).enableRLS();
