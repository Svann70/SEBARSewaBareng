// Table public.venue_payouts.
// Mirrors the database exactly (drizzle-kit generates migrations from the difference),
// so do not drop definitions that still exist in the database. See ./index.js.
import { pgTable, foreignKey, check, uuid, timestamp, numeric, unique } from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { payoutStatus } from "./enums.js";
import { bookings } from "./bookings.js";
import { venues } from "./venues.js";

export const venuePayouts = pgTable("venue_payouts", {
	id: uuid().defaultRandom().primaryKey().notNull(),
	bookingId: uuid("booking_id").notNull(),
	venueId: uuid("venue_id").notNull(),
	amount: numeric({ precision: 12, scale:  2 }).notNull(),
	status: payoutStatus().default('PENDING').notNull(),
	disbursedAt: timestamp("disbursed_at", { withTimezone: true, mode: 'string' }),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	foreignKey({ name: "venue_payouts_booking_id_fkey", columns: [table.bookingId], foreignColumns: [bookings.id] }).onDelete("restrict"),
	foreignKey({ name: "venue_payouts_venue_id_fkey", columns: [table.venueId], foreignColumns: [venues.id] }).onDelete("restrict"),
	unique("venue_payouts_booking_id_key").on(table.bookingId),
	check("payouts_state_coherent", sql`((status = 'PENDING'::payout_status) AND (disbursed_at IS NULL)) OR ((status = 'PAID'::payout_status) AND (disbursed_at IS NOT NULL))`),
	check("venue_payouts_amount_check", sql`amount > (0)::numeric`),
]).enableRLS();
