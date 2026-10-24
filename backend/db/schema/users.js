// Table public.users.
// Mirrors the database exactly (drizzle-kit generates migrations from the difference),
// so do not drop definitions that still exist in the database. See ./index.js.
import { pgTable, check, uuid, timestamp, numeric, boolean, unique, text, varchar } from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { citext, userRole } from "./enums.js";

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
