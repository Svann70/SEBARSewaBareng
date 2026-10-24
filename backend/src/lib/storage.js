import { config } from '../config/env.js';
import { AppError } from './errors.js';

// Supabase Storage over its REST API (no SDK). Objects live in a public bucket, so players read
// photos straight from the public URL; writes go through the backend with the service role key.

export const storageEnabled = () => Boolean(config.supabaseUrl && config.supabaseServiceKey);

function headers(extra = {}) {
  return { Authorization: `Bearer ${config.supabaseServiceKey}`, apikey: config.supabaseServiceKey, ...extra };
}

const objectUrl = (path) => `${config.supabaseUrl}/storage/v1/object/${config.photoBucket}/${path}`;

export const publicUrl = (path) => `${config.supabaseUrl}/storage/v1/object/public/${config.photoBucket}/${path}`;

const TIMEOUT_MS = 15_000;

export async function uploadObject(path, body, contentType) {
  let res;
  try {
    res = await fetch(objectUrl(path), {
      method: 'POST',
      signal: AbortSignal.timeout(TIMEOUT_MS),
    // Names are random and never overwritten; 1 hour keeps a deleted photo from lingering on the CDN.
      headers: headers({ 'Content-Type': contentType, 'x-upsert': 'false', 'Cache-Control': 'max-age=3600' }),
      body,
    });
  } catch (err) {
    console.error(JSON.stringify({ level: 'error', msg: 'storage upload failed', error: err.message }));
    throw new AppError(502, 'STORAGE_ERROR', 'Foto gagal diunggah. Coba lagi.');
  }
  if (!res.ok) {
    // Body trimmed: upstream text only, request headers (service key) are never logged.
    const detail = (await res.text().catch(() => '')).slice(0, 200);
    console.error(JSON.stringify({ level: 'error', msg: 'storage upload failed', status: res.status, body: detail }));
    throw new AppError(502, 'STORAGE_ERROR', 'Foto gagal diunggah. Coba lagi.');
  }
}

// Best effort: a leftover file is harmless, a failed delete must not block removing the DB row.
export async function deleteObject(path) {
  try {
    const res = await fetch(`${config.supabaseUrl}/storage/v1/object/${config.photoBucket}`, {
      method: 'DELETE',
      signal: AbortSignal.timeout(TIMEOUT_MS),
      headers: headers({ 'Content-Type': 'application/json' }),
      body: JSON.stringify({ prefixes: [path] }),
    });
    if (!res.ok) console.error(JSON.stringify({ level: 'error', msg: 'storage delete failed', status: res.status, path }));
  } catch (err) {
    console.error(JSON.stringify({ level: 'error', msg: 'storage delete failed', error: err.message, path }));
  }
}
