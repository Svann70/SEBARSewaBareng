// Table public.audit_log.
// Mirrors the database exactly (drizzle-kit generates migrations from the difference),
// so do not drop definitions that still exist in the database. See ./index.js.
import { pgTable, index, foreignKey, uuid, timestamp, text, jsonb, bigserial } from "drizzle-orm/pg-core";
import { users } from "./users.js";

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
