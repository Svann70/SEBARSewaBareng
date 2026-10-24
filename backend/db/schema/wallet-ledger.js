// Table public.wallet_ledger.
// Mirrors the database exactly (drizzle-kit generates migrations from the difference),
// so do not drop definitions that still exist in the database. See ./index.js.
import { pgTable, index, foreignKey, check, uuid, timestamp, numeric, unique, text } from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { ledgerType } from "./enums.js";
import { wallets } from "./wallets.js";

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
