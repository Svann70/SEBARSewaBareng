// Drizzle schema of the SEBAR database (public schema), split by area.
// Generated with `drizzle-kit pull` from a database built by the drizzle/ migrations, then fixed by
// hand: citext column type, operator classes removed (pull swapped them), one line per foreign key.
// Every table has RLS on (.enableRLS()). Not represented here, kept as SQL in drizzle/ migrations:
// triggers, functions, views, the EXCLUDE constraint on court_slots and RLS policies.
export * from "./enums.js";
export * from "./users.js";
export * from "./wallet.js";
export * from "./venues.js";
export * from "./lobbies.js";
