function required(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing env ${name}`);
  return value;
}

export const config = {
  port: Number(process.env.PORT ?? 3000),
  databaseUrl: required('DATABASE_URL'),
  // Path to Supabase's CA cert (Dashboard > Database > SSL). Unset = no TLS (local Postgres only).
  databaseCa: process.env.DATABASE_SSL_CA,
  jwtSecret: required('JWT_SECRET'),
  // Short-lived access token (SDD §10); the app renews it with the refresh token.
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '15m',
  refreshTtlDays: Number(process.env.REFRESH_TTL_DAYS ?? 30),
  // Requests per minute per IP on /auth/*, and login attempts per email per 15 minutes.
  authRateLimit: Number(process.env.AUTH_RATE_LIMIT ?? 20),
  loginRateLimit: Number(process.env.LOGIN_RATE_LIMIT ?? 10),
  // Express `trust proxy` (e.g. 1 behind one reverse proxy) so req.ip is the client, not the proxy.
  // Must equal the number of proxies in front: more lets clients spoof X-Forwarded-For.
  trustProxy: process.env.TRUST_PROXY ? Number(process.env.TRUST_PROXY) : false,
  // Sandbox top-up mints balance out of nothing: off unless explicitly enabled (dev/demo only).
  allowSandboxTopup: process.env.ALLOW_SANDBOX_TOPUP === '1',
  // Supabase Storage for court photos. The service role key bypasses RLS: backend only, never the app.
  // Unset = photo upload disabled (503), everything else works.
  supabaseUrl: process.env.SUPABASE_URL?.replace(/\/+$/, ''),
  supabaseServiceKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
  photoBucket: process.env.SUPABASE_PHOTO_BUCKET ?? 'courts-photos',
};

if (config.jwtSecret.length < 32) throw new Error('JWT_SECRET must be at least 32 characters');
for (const [name, value] of [['REFRESH_TTL_DAYS', config.refreshTtlDays], ['AUTH_RATE_LIMIT', config.authRateLimit], ['LOGIN_RATE_LIMIT', config.loginRateLimit]]) {
  if (!Number.isInteger(value) || value < 1) throw new Error(`${name} must be a positive integer`);
}
if (config.trustProxy !== false && !(Number.isInteger(config.trustProxy) && config.trustProxy >= 0)) {
  throw new Error('TRUST_PROXY must be a non-negative integer (number of proxies in front)');
}
// jsonwebtoken reads a bare number as milliseconds; require an explicit unit.
if (!/^\d+[smhd]$/.test(config.jwtExpiresIn)) throw new Error('JWT_EXPIRES_IN must look like 15m, 1h or 1d');
