// Table public.lobby_members.
// Mirrors the database exactly (drizzle-kit generates migrations from the difference),
// so do not drop definitions that still exist in the database. See ./index.js.
import { pgTable, index, foreignKey, check, uuid, timestamp, numeric, unique } from "drizzle-orm/pg-core";
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
}, (table) => [
	index("idx_lobby_members_user").using("btree", table.userId.asc().nullsLast(), table.status.asc().nullsLast()),
	foreignKey({ name: "lobby_members_hold_ledger_id_fkey", columns: [table.holdLedgerId], foreignColumns: [walletLedger.id] }).onDelete("set null"),
	foreignKey({ name: "lobby_members_lobby_id_fkey", columns: [table.lobbyId], foreignColumns: [lobbies.id] }).onDelete("cascade"),
	foreignKey({ name: "lobby_members_user_id_fkey", columns: [table.userId], foreignColumns: [users.id] }).onDelete("restrict"),
	unique("lobby_members_lobby_id_user_id_key").on(table.lobbyId, table.userId),
	check("lobby_members_hold_amount_check", sql`hold_amount > (0)::numeric`),
]).enableRLS();
