import fs from 'node:fs';

const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1', '::1']);

// TLS is built here, never from the URL: pg lets ?sslmode= override the ssl option and silently drop the CA.
export function connectionOptions(databaseUrl, caPath) {
  const url = new URL(databaseUrl);
  for (const key of [...url.searchParams.keys()]) if (key.startsWith('ssl')) url.searchParams.delete(key);
  if (caPath) return { connectionString: url.toString(), ssl: { ca: fs.readFileSync(caPath, 'utf8') } };
  if (!LOCAL_HOSTS.has(url.hostname)) throw new Error('DATABASE_SSL_CA is required for a non-local database');
  return { connectionString: url.toString() };
}
