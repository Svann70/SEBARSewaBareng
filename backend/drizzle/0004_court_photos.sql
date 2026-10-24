CREATE TABLE "court_photos" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"court_id" uuid NOT NULL,
	"path" text NOT NULL,
	"url" text NOT NULL,
	"sort" smallint DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "court_photos" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "court_photos" ADD CONSTRAINT "court_photos_court_id_courts_id_fk" FOREIGN KEY ("court_id") REFERENCES "public"."courts"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "idx_court_photos_court" ON "court_photos" USING btree ("court_id","sort");