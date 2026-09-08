import type { SQLiteDatabase } from 'expo-sqlite';
import { nativeIntents, type NativeEvent, type NativeSession } from './native';

export type Mode = 'SPEND' | 'INVEST';
export type SessionState = 'running' | 'needsWage' | 'finished' | 'manuallyClosed';

export type Session = {
  id: string;
  activityId: string;
  displayName: string;
  mode: Mode;
  startedAt: number;
  endedAt: number | null;
  elapsedMs: number;
  hourlyWage: number | null;
  state: SessionState;
  diagnostics: string[];
};

export type Diagnostic = {
  id: number;
  eventId: string | null;
  kind: string;
  message: string;
  createdAt: number;
};

export async function initDatabase(db: SQLiteDatabase) {
  await db.execAsync(`
    PRAGMA journal_mode = WAL;
    CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS sessions (
      id TEXT PRIMARY KEY NOT NULL,
      activity_id TEXT NOT NULL,
      display_name TEXT NOT NULL,
      mode TEXT NOT NULL CHECK(mode IN ('SPEND', 'INVEST')),
      started_at INTEGER NOT NULL,
      ended_at INTEGER,
      elapsed_ms INTEGER NOT NULL DEFAULT 0,
      hourly_wage REAL,
      state TEXT NOT NULL,
      diagnostics_json TEXT NOT NULL DEFAULT '[]'
    );
    CREATE TABLE IF NOT EXISTS native_events (
      event_id TEXT PRIMARY KEY NOT NULL,
      kind TEXT NOT NULL,
      imported_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS diagnostics (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id TEXT,
      kind TEXT NOT NULL,
      message TEXT NOT NULL,
      created_at INTEGER NOT NULL
    );
    CREATE UNIQUE INDEX IF NOT EXISTS diagnostics_event_id_unique ON diagnostics(event_id) WHERE event_id IS NOT NULL;
  `);
  await importNativeEvents(db);
}

function fromNativeSession(value: NativeSession): Session {
  return {
    id: value.id,
    activityId: value.activityId,
    displayName: value.displayName,
    mode: value.mode,
    startedAt: value.startedAt,
    endedAt: value.endedAt ?? null,
    elapsedMs: value.elapsedMs ?? 0,
    hourlyWage: value.hourlyWage ?? null,
    state: value.state,
    diagnostics: value.diagnostics ?? [],
  };
}

async function importNativeEvents(db: SQLiteDatabase) {
  const events = await nativeIntents.getPendingEvents();
  const acknowledged: string[] = [];

  for (const event of events) {
    const alreadyImported = await db.getFirstAsync<{ eventId: string }>(
      'SELECT event_id as eventId FROM native_events WHERE event_id = ?',
      event.eventId,
    );
    if (alreadyImported) {
      acknowledged.push(event.eventId);
      continue;
    }

    if (event.session) {
      const session = fromNativeSession(event.session);
      await db.runAsync(
        `INSERT INTO sessions (id, activity_id, display_name, mode, started_at, ended_at, elapsed_ms, hourly_wage, state, diagnostics_json)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(id) DO UPDATE SET
           ended_at = excluded.ended_at,
           elapsed_ms = excluded.elapsed_ms,
           hourly_wage = excluded.hourly_wage,
           state = excluded.state,
           diagnostics_json = excluded.diagnostics_json`,
        session.id,
        session.activityId,
        session.displayName,
        session.mode,
        session.startedAt,
        session.endedAt,
        session.elapsedMs,
        session.hourlyWage,
        session.state,
        JSON.stringify(session.diagnostics),
      );
    }

    if (event.diagnostic) {
      await db.runAsync(
        'INSERT OR IGNORE INTO diagnostics (event_id, kind, message, created_at) VALUES (?, ?, ?, ?)',
        event.eventId,
        event.kind,
        event.diagnostic,
        event.createdAt,
      );
    }
    // Write the import marker last. If the app is killed before this line,
    // the next launch safely retries the idempotent session upsert.
    await db.runAsync(
      'INSERT OR IGNORE INTO native_events (event_id, kind, imported_at) VALUES (?, ?, ?)',
      event.eventId,
      event.kind,
      Date.now(),
    );
    acknowledged.push(event.eventId);
  }

  if (acknowledged.length) await nativeIntents.acknowledgeEvents(acknowledged);
}

export async function syncNativeEvents(db: SQLiteDatabase) {
  await importNativeEvents(db);
  return nativeIntents.consumeOpenLastSessionRequest();
}

export async function getSetting(db: SQLiteDatabase, key: string) {
  const row = await db.getFirstAsync<{ value: string }>('SELECT value FROM settings WHERE key = ?', key);
  return row?.value ?? null;
}

export async function setSetting(db: SQLiteDatabase, key: string, value: string) {
  await db.runAsync('INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value', key, value);
}

export async function listSessions(db: SQLiteDatabase) {
  const rows = await db.getAllAsync<{
    id: string; activity_id: string; display_name: string; mode: Mode; started_at: number; ended_at: number | null;
    elapsed_ms: number; hourly_wage: number | null; state: SessionState; diagnostics_json: string;
  }>('SELECT * FROM sessions ORDER BY started_at DESC');
  return rows.map((row) => ({
    id: row.id,
    activityId: row.activity_id,
    displayName: row.display_name,
    mode: row.mode,
    startedAt: row.started_at,
    endedAt: row.ended_at,
    elapsedMs: row.elapsed_ms,
    hourlyWage: row.hourly_wage,
    state: row.state,
    diagnostics: JSON.parse(row.diagnostics_json || '[]') as string[],
  } satisfies Session));
}

export async function getDiagnostics(db: SQLiteDatabase) {
  return db.getAllAsync<Diagnostic>('SELECT id, event_id as eventId, kind, message, created_at as createdAt FROM diagnostics ORDER BY id DESC LIMIT 100');
}

export async function manuallyCloseSession(db: SQLiteDatabase, session: Session, endedAt = Date.now()) {
  const elapsedMs = Math.max(0, endedAt - session.startedAt);
  await db.runAsync(
    'UPDATE sessions SET ended_at = ?, elapsed_ms = ?, state = ?, diagnostics_json = ? WHERE id = ?',
    endedAt,
    elapsedMs,
    'manuallyClosed',
    JSON.stringify([...session.diagnostics, 'manual_end']),
    session.id,
  );
}

export function sessionAmount(session: Pick<Session, 'elapsedMs' | 'hourlyWage'>) {
  if (session.hourlyWage == null) return null;
  return Math.floor((session.elapsedMs / 3_600_000) * session.hourlyWage);
}
