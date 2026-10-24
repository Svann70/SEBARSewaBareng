// Akun: pengguna, sesi, skor, notifikasi, audit.
// Part of the Drizzle schema (see ./index.js). Mirrors the database exactly: drizzle-kit generates
// migrations from the difference, so do not drop definitions that still exist in the database.
import { pgTable, index, foreignKey, check, uuid, timestamp, numeric, boolean, unique, text, jsonb, varchar, bigserial, char, primaryKey } from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { reliabilityReason, userRole, citext } from "./enums.js";
import { lobbies } from "./lobbies.js";

export const users = pgTable("users", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	email: citext("email").notNull(),
	phone: varchar({ length: 20 }),
	fullName: varchar("full_name", { length: 80 }).notNull(),
	passwordHash: text("password_hash").notNull(),
	role: userRole().default('PLAYER').notNull(),
	reliabilityScore: numeric("reliability_score", { precision: 5, scale:  2 }).default('100').notNull(),
	isActive: boolean("is_active").default(true).notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
	updatedAt: timestamp("updated_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	unique("users_email_key").on(table.email),
	unique("users_phone_key").on(table.phone),
	check("users_reliability_score_check", sql`(reliability_score >= (0)::numeric) AND (reliability_score <= (100)::numeric)`),
]).enableRLS();

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

export const auditLog = pgTable("audit_log", {
	id: bigserial({ mode: "bigint" }).primaryKey().notNull(),
	actorId: uuid("actor_id"),
	action: text().notNull(),
	entity: text().notNull(),
	entityId: uuid("entity_id"),
	before: jsonb(),
	after: jsonb(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_audit_entity").using("btree", table.entity.asc().nullsLast(), table.entityId.asc().nullsLast(), table.createdAt.desc().nullsFirst()),
	foreignKey({ name: "audit_log_actor_id_fkey", columns: [table.actorId], foreignColumns: [users.id] }).onDelete("set null"),
]).enableRLS();
