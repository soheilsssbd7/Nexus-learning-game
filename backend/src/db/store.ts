/**
 * NEXUS — بک‌اند | نوشتن/خواندنِ مدل بازیکن و رویدادها (تسک ۹.۳/۹.۴)
 * ==================================================================
 * تنها جایی که SQLِ ما نوشته می‌شود ✓ (routeها تصمیم نمی‌گیرند — قاعدۀ ADR-058 در سرور هم
 * کار می‌کند: «منطقِ داده یک‌جا، مصرف‌کننده نازک» ✓).
 *
 * چرا `upsert` دستی (SELECT بعد INSERT/UPDATE) به‌جای `ON CONFLICT`؟ چون لایهٔ تست ما
 * `pg-mem` است و پشتیبانیِ آن از `ON CONFLICT DO UPDATE` قابل‌اتکا نیست ✗✓؛ رفتارِ واقعیِ
 * Postgres را هم با همین می‌گیریم، فقط با یک ریسکِ مستندشده:
 * **همزمانیِ دو نصب روی یک player** ⇒ آخرین نوشتن برنده است ✓ (منطق بازی در کلاینت است
 * §۳ و مدل یک‌نصب‌یک‌بازیکن ⇒ در MVP قابل‌قبول ✓؛ اگر لازم شد `updated_at` optimistic lock ✓)
 */
import type { Db } from "./client.js";
import { jsonParam } from "./client.js";
import type { AnalyticsEvent } from "../schemas/events.js";
import type { PlayerModel } from "../schemas/playerModel.js";
import { playerIdToUuid } from "../ids.js";

export type StoredModel = {
  schema_version: number;
  model: PlayerModel;
  updated_at: string | null;
};

async function exists(exec: Db["exec"], sql: string, params: readonly unknown[]): Promise<boolean> {
  const r = await exec.query<{ n: number | string }>(sql, params);
  return Number(r.rows[0]?.n ?? 0) > 0;
}

export async function upsertPlayerModel(db: Db, model: PlayerModel): Promise<void> {
  const uuid = playerIdToUuid(model.player_id);
  const { exec } = db;

  const hasPlayer = await exists(
    exec,
    "SELECT COUNT(*) AS n FROM players WHERE player_id = $1",
    [uuid]
  );
  if (hasPlayer) {
    await exec.query(
      "UPDATE players SET display_name = $2, schema_version = $3 WHERE player_id = $1",
      [uuid, model.display_name, model.schema_version]
    );
  } else {
    await exec.query(
      "INSERT INTO players (player_id, display_name, schema_version) VALUES ($1, $2, $3)",
      [uuid, model.display_name, model.schema_version]
    );
  }

  // آینهٔ نرمال‌شدهٔ §۶ ⇒ همان `skills` مدل؛ حذف+درج چون «آخرین وضعیت» معتبر است ✓
  await exec.query("DELETE FROM skill_ratings WHERE player_id = $1", [uuid]);
  for (const [skillKey, rating] of Object.entries(model.skills)) {
    await exec.query(
      `INSERT INTO skill_ratings (player_id, skill_key, elo, confidence, attempts, last_seen)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [uuid, skillKey, rating.elo, rating.confidence, rating.attempts, rating.last_seen]
    );
  }

  const json = jsonParam(model, db.kind);
  const hasModel = await exists(
    exec,
    "SELECT COUNT(*) AS n FROM player_models WHERE player_id = $1",
    [uuid]
  );
  if (hasModel) {
    await exec.query(
      "UPDATE player_models SET schema_version = $2, model = $3, updated_at = now() WHERE player_id = $1",
      [uuid, model.schema_version, json]
    );
  } else {
    await exec.query(
      `INSERT INTO player_models (player_id, schema_version, model, updated_at)
       VALUES ($1, $2, $3, now())`,
      [uuid, model.schema_version, json]
    );
  }
}

export async function selectPlayerModel(db: Db, playerId: string): Promise<StoredModel | null> {
  const uuid = playerIdToUuid(playerId);
  const res = await db.exec.query<{ schema_version: number; model: unknown; updated_at: unknown }>(
    "SELECT schema_version, model, updated_at FROM player_models WHERE player_id = $1",
    [uuid]
  );
  const row = res.rows[0];
  if (row === undefined) return null;
  // pg رشته می‌دهد و pg-mem آبجکت ⇒ هر دو را به آبجکت می‌رسانیم ✓ (فقط مصرف‌کننده نداند ✓)
  const raw = row.model;
  const model = (typeof raw === "string" ? JSON.parse(raw) : raw) as PlayerModel;
  return {
    schema_version: Number(row.schema_version),
    model,
    updated_at: row.updated_at instanceof Date ? row.updated_at.toISOString() : String(row.updated_at ?? ""),
  };
}

/** ردیفِ players را اگر نبود می‌سازد ✓ (فقط برای کلیدِ خارجی — **هیچ نامی از کودک
 *  نمی‌سازد** ✗§۹ و اگر مدل بعداً sync شد، `upsertPlayerModel` همان ردیف را به‌روز می‌کند ✓✓)
 *  چرا لازم است؟ صفِ آفلاین ۹.۶ ممکن است پیش از اولین همگام‌سازی مدل، رویداد بفرستد ✗
 *  و §۶ `events.player_id` را FK به `players` کرده ⇒ بی‌این، هر flush با ۵۰۰ برمی‌گشت ✓✓ */
async function ensurePlayerRow(db: Db, playerId: string, displayName: string | null): Promise<void> {
  const uuid = playerIdToUuid(playerId);
  const { exec } = db;
  const has = await exec.query<{ n: number | string }>(
    "SELECT COUNT(*) AS n FROM players WHERE player_id = $1",
    [uuid]
  );
  if (Number(has.rows[0]?.n ?? 0) > 0) return;
  await exec.query(
    "INSERT INTO players (player_id, display_name, schema_version) VALUES ($1, $2, $3)",
    [uuid, displayName ?? PLACEHOLDER_DISPLAY_NAME, 1]
  );
}

/** رشته‌ای بی‌معنا برای کودک ✗ نه نامِ ساختگی ✓ (و در هیچ UI‌ای نشان داده نمی‌شود —
 *  داشبورد والدین از مدلِ محلی می‌خواند ✓§۶) */
export const PLACEHOLDER_DISPLAY_NAME = "(pending_sync)";

export async function insertEvents(db: Db, events: readonly AnalyticsEvent[]): Promise<number> {
  let n = 0;
  for (const e of events) {
    const uuid = playerIdToUuid(e.player_id);
    await ensurePlayerRow(db, e.player_id, null);
    await db.exec.query(
      `INSERT INTO events (player_id, event_type, level_id, payload, created_at)
       VALUES ($1, $2, $3, $4, $5)`,
      [
        uuid,
        e.event_type,
        e.level_id ?? null,
        jsonParam(e.payload ?? {}, db.kind),
        e.timestamp,
      ]
    );
    n += 1;
  }
  return n;
}

/** شمارشِ رویدادها — برای تستِ «واقعاً در جدول نشست» ✓§۹ (نه فقط ۲۰۰ گرفن ✓) */
export async function countEvents(db: Db, playerId: string): Promise<number> {
  const uuid = playerIdToUuid(playerId);
  const r = await db.exec.query<{ n: number | string }>(
    "SELECT COUNT(*) AS n FROM events WHERE player_id = $1",
    [uuid]
  );
  return Number(r.rows[0]?.n ?? 0);
}
