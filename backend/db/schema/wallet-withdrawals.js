import { pgTable, foreignKey, check, uuid, timestamp, numeric, text, unique } from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { withdrawalStatus } from "./enums.js";
import { wallets } from "./wallets.js";

export const walletWithdrawals = pgTable("wallet_withdrawals", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	walletId: uuid("wallet_id").notNull(),
	amount: numeric({ precision: 14, scale:  2 }).notNull(),
	fee: numeric({ precision: 14, scale:  2 }).notNull(),
	totalAmount: numeric("total_amount", { precision: 14, scale:  2 }).notNull(),
	bankCode: text("bank_code").notNull(),
	accountNumber: text("account_number").notNull(),
	accountName: text("account_name").notNull(),
	status: withdrawalStatus().default('PENDING').notNull(),
	idempotencyKey: text("idempotency_key").notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	processedAt: timestamp("processed_at", { withTimezone: true, mode: 'string' }),
}, (table) => [
	foreignKey({ name: "wallet_withdrawals_wallet_id_fkey", columns: [table.walletId], foreignColumns: [wallets.id] }).onDelete("restrict"),
	unique("wallet_withdrawals_idempotency_key_key").on(table.idempotencyKey),
	check("wallet_withdrawals_amount_check", sql`amount > (0)::numeric`),
	check("wallet_withdrawals_fee_check", sql`fee >= (0)::numeric`),
	check("wallet_withdrawals_total_check", sql`total_amount = amount + fee`),
]).enableRLS();
