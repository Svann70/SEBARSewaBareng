// Table public.lobby_members.
// Mirrors the database exactly (drizzle-kit generates migrations from the difference),
// so do not drop definitions that still exist in the database. See ./index.js.
import { pgTable, index, uniqueIndex, foreignKey, check, uuid, timestamp, numeric, boolean } from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { memberRole, memberStatus } from "./enums.js";
import { lobbies } from "./lobbies.js";
import { users } from "./users.js";
import { walletLedger } from "./wallet-ledger.js";

export const lobbyMembers = pgTable("lobby_members", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	lobbyId: uuid("lobby_id").notNull(),
	userId: uuid("user_id").notNull(),
	roleInLobby: memberRole("role_in_lobby").default('PLAYER').notNull(),
	status: memberStatus().default('HOLDING').notNull(),
	holdAmount: numeric("hold_amount", { precision: 12, scale:  2 }).notNull(),
	holdLedgerId: uuid("hold_ledger_id"),
	joinedAt: timestamp("joined_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	cancelledAt: timestamp("cancelled_at", { withTimezone: true, mode: 'string' }),
	// Patungan v2 (backend PATUNGAN_V2.md).
	shareAtJoin: numeric("share_at_join", { precision: 12, scale:  2 }),
	fineAmount: numeric("fine_amount", { precision: 12, scale:  2 }).default('0').notNull(),
	freeUntil: timestamp("free_until", { withTimezone: true, mode: 'string' }),
	protectUntil: timestamp("protect_until", { withTimezone: true, mode: 'string' }),
	remindedAt: timestamp("reminded_at", { withTimezone: true, mode: 'string' }),
	// Removed by the host (counts for the disband fine even after the member is gone).
	kicked: boolean().default(false).notNull(),
}, (table) => [
	index("idx_lobby_members_user").using("btree", table.userId.asc().nullsLast(), table.status.asc().nullsLast()),
	foreignKey({ name: "lobby_members_hold_ledger_id_fkey", columns: [table.holdLedgerId], foreignColumns: [walletLedger.id] }).onDelete("set null"),
	foreignKey({ name: "lobby_members_lobby_id_fkey", columns: [table.lobbyId], foreignColumns: [lobbies.id] }).onDelete("cascade"),
	foreignKey({ name: "lobby_members_user_id_fkey", columns: [table.userId], foreignColumns: [users.id] }).onDelete("restrict"),
	// One seat per user per room; a member who left (cancelled_at set) may join again later.
	uniqueIndex("uq_lobby_members_seat").using("btree", table.lobbyId.asc().nullsLast(), table.userId.asc().nullsLast()).where(sql`(cancelled_at IS NULL)`),
	check("lobby_members_hold_amount_check", sql`hold_amount >= (0)::numeric`),
	check("lobby_members_fine_amount_check", sql`fine_amount >= (0)::numeric`),
]).enableRLS();
