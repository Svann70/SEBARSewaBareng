// drizzle-kit: `npx drizzle-kit generate` (schema change -> new SQL migration in drizzle/),
// `npx drizzle-kit generate --custom --name=<x>` (hand-written SQL, e.g. triggers).
// Apply migrations with `npm run db:migrate` (db/migrate.js), not drizzle-kit migrate.
export default {
  dialect: 'postgresql',
  schema: './db/schema.js',
  out: './drizzle',
  schemaFilter: ['public'],
  dbCredentials: { url: process.env.DATABASE_URL },
};
