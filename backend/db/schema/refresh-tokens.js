// Table public.refresh_tokens.
// Mirrors the database exactly (drizzle-kit generates migrations from the difference),
// so do not drop definitions that still exist in the database. See ./index.js.
import { pgTable, index, foreignKey, uuid, timestamp, unique, char } from "drizzle-orm/pg-core";
import { users } from "./users.js";

export const refreshTokens = pgTable("refresh_tokens", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	userId: uuid("user_id").notNull(),
	familyId: uuid("family_id").notNull(),
	tokenHash: char("token_hash", { length: 64 }).notNull(),
	expiresAt: timestamp("expires_at", { withTimezone: true, mode: 'string' }).notNull(),
	revokedAt: timestamp("revoked_at", { withTimezone: true, mode: 'string' }),
	replacedBy: uuid("replaced_by"),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_refresh_tokens_expires").using("btree", table.expiresAt.asc().nullsLast()),
	index("idx_refresh_tokens_family").using("btree", table.familyId.asc().nullsLast()),
	foreignKey({ name: "refresh_tokens_user_id_fkey", columns: [table.userId], foreignColumns: [users.id] }).onDelete("cascade"),
	foreignKey({ name: "refresh_tokens_replaced_by_fkey", columns: [table.replacedBy], foreignColumns: [table.id] }).onDelete("set null"),
	unique("refresh_tokens_token_hash_key").on(table.tokenHash),
]).enableRLS();
