// Dompet dan buku besar (aturan uang ada di trigger/function database).
// Part of the Drizzle schema (see ./index.js). Mirrors the database exactly: drizzle-kit generates
// migrations from the difference, so do not drop definitions that still exist in the database.
import { pgTable, index, foreignKey, check, uuid, timestamp, numeric, unique, text, integer, primaryKey } from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { ledgerType } from "./enums.js";
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

export const walletLedger = pgTable("wallet_ledger", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	walletId: uuid("wallet_id").notNull(),
	entryType: ledgerType("entry_type").notNull(),
	amount: numeric({ precision: 14, scale:  2 }).notNull(),
	balanceAfter: numeric("balance_after", { precision: 14, scale:  2 }).notNull(),
	heldAfter: numeric("held_after", { precision: 14, scale:  2 }).notNull(),
	refType: text("ref_type"),
	refId: uuid("ref_id"),
	idempotencyKey: text("idempotency_key"),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_ledger_ref").using("btree", table.refType.asc().nullsLast(), table.refId.asc().nullsLast()),
	index("idx_ledger_wallet").using("btree", table.walletId.asc().nullsLast(), table.createdAt.desc().nullsFirst()),
	foreignKey({ name: "wallet_ledger_wallet_id_fkey", columns: [table.walletId], foreignColumns: [wallets.id] }).onDelete("restrict"),
	unique("wallet_ledger_idempotency_key_key").on(table.idempotencyKey),
	check("wallet_ledger_amount_check", sql`amount > (0)::numeric`),
]).enableRLS();
