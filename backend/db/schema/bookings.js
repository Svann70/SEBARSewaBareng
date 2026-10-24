// Table public.bookings.
// Mirrors the database exactly (drizzle-kit generates migrations from the difference),
// so do not drop definitions that still exist in the database. See ./index.js.
import { pgTable, index, foreignKey, check, uuid, timestamp, numeric, unique, varchar } from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { bookingStatus } from "./enums.js";
import { courtSlots } from "./court-slots.js";
import { lobbies } from "./lobbies.js";

export const bookings = pgTable("bookings", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	lobbyId: uuid("lobby_id").notNull(),
	slotId: uuid("slot_id").notNull(),
	bookingCode: varchar("booking_code", { length: 12 }).notNull(),
	grossAmount: numeric("gross_amount", { precision: 12, scale:  2 }).notNull(),
	platformFee: numeric("platform_fee", { precision: 12, scale:  2 }).notNull(),
	roundingSurplus: numeric("rounding_surplus", { precision: 12, scale:  2 }).default('0').notNull(),
	venuePayout: numeric("venue_payout", { precision: 12, scale:  2 }).notNull(),
	status: bookingStatus().default('CONFIRMED').notNull(),
	bookedAt: timestamp("booked_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_bookings_status_booked_at").using("btree", table.status.asc().nullsLast(), table.bookedAt.desc().nullsFirst()),
	foreignKey({ name: "bookings_lobby_id_fkey", columns: [table.lobbyId], foreignColumns: [lobbies.id] }).onDelete("restrict"),
	foreignKey({ name: "bookings_slot_id_fkey", columns: [table.slotId], foreignColumns: [courtSlots.id] }).onDelete("restrict"),
	unique("bookings_lobby_id_key").on(table.lobbyId),
	unique("bookings_slot_id_key").on(table.slotId),
	unique("bookings_booking_code_key").on(table.bookingCode),
	check("bookings_fee_is_5pct", sql`platform_fee = round((gross_amount * 0.05), 2)`),
	check("bookings_gross_amount_check", sql`gross_amount > (0)::numeric`),
	check("bookings_payout_invariant", sql`venue_payout >= (gross_amount - platform_fee)`),
	check("bookings_platform_fee_check", sql`platform_fee >= (0)::numeric`),
	check("bookings_rounding_surplus_check", sql`rounding_surplus >= (0)::numeric`),
	check("bookings_venue_payout_check", sql`venue_payout > (0)::numeric`),
]).enableRLS();
