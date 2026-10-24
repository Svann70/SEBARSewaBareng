// Table public.court_photos: photos of a court in Supabase Storage (bucket SUPABASE_PHOTO_BUCKET).
// The lowest `sort` is the cover shown to players.
import { pgTable, uuid, text, smallint, timestamp, index } from "drizzle-orm/pg-core";
import { courts } from "./courts.js";

export const courtPhotos = pgTable("court_photos", {
	id: uuid().defaultRandom().primaryKey(),
	courtId: uuid("court_id").notNull().references(() => courts.id, { onDelete: "cascade" }),
	// Object path inside the bucket (used to delete the file); url = its public URL.
	path: text().notNull(),
	url: text().notNull(),
	sort: smallint().default(0).notNull(),
	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
}, (table) => [
	index("idx_court_photos_court").on(table.courtId, table.sort),
]).enableRLS();
