// Table public.checkins.
// Mirrors the database exactly (drizzle-kit generates migrations from the difference),
// so do not drop definitions that still exist in the database. See ./index.js.
import { pgTable, index, foreignKey, uuid, timestamp, unique, char, varchar } from "drizzle-orm/pg-core";
import { checkinStatus } from "./enums.js";
import { bookings } from "./bookings.js";
import { users } from "./users.js";

export const checkins = pgTable("checkins", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	bookingId: uuid("booking_id").notNull(),
	userId: uuid("user_id").notNull(),
	tokenHash: char("token_hash", { length: 64 }).notNull(),
	tokenExpiresAt: timestamp("token_expires_at", { withTimezone: true, mode: 'string' }).notNull(),
	status: checkinStatus().default('PENDING').notNull(),
	scannedBy: uuid("scanned_by"),
	scannedAt: timestamp("scanned_at", { withTimezone: true, mode: 'string' }),
	// Per-player check-in code (10 hex chars) the venue types in; shown on the ticket.
	code: varchar({ length: 10 }),
}, (table) => [
	index("idx_checkins_booking").using("btree", table.bookingId.asc().nullsLast(), table.status.asc().nullsLast()),
	foreignKey({ name: "checkins_booking_id_fkey", columns: [table.bookingId], foreignColumns: [bookings.id] }).onDelete("restrict"),
	foreignKey({ name: "checkins_scanned_by_fkey", columns: [table.scannedBy], foreignColumns: [users.id] }).onDelete("set null"),
	foreignKey({ name: "checkins_user_id_fkey", columns: [table.userId], foreignColumns: [users.id] }).onDelete("restrict"),
	unique("checkins_booking_id_user_id_key").on(table.bookingId, table.userId),
	unique("checkins_token_hash_key").on(table.tokenHash),
	unique("checkins_code_key").on(table.code),
]).enableRLS();
