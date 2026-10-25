import { query, tx } from '../../db/pool.js';
import { closeLobby, dueLobbies, remindFreePeriod, settleLobby } from './patungan.service.js';

// One pass of the patungan jobs. Each room runs in its own transaction, so one failing room
// (e.g. a deadlock, retried next minute) does not block the others.
export async function runLobbyJobs() {
  try {
    await tx(remindFreePeriod);
  } catch (err) {
    // Reminders are best effort; closing and settling rooms must still run.
    console.error(JSON.stringify({ level: 'error', msg: 'reminder job failed', error: err.message }));
  }
  const due = await dueLobbies(query);
  const results = { closed: 0, settled: 0, failed: 0 };
  for (const [ids, fn, key] of [[due.close, closeLobby, 'closed'], [due.settle, settleLobby, 'settled']]) {
    for (const id of ids) {
      try {
        if (await tx((c) => fn(c, id))) results[key]++;
      } catch (err) {
        results.failed++;
        console.error(JSON.stringify({ level: 'error', msg: 'lobby job failed', lobbyId: id, job: key, error: err.message }));
      }
    }
  }
  return results;
}
