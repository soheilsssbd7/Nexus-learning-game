/**
 * NEXUS — بک‌اند | endpoint رویدادها (تسک ۹.۴ | DoD: «رویداد نمونه ارسال، در جدول `events` قابل‌مشاهده است»)
 * ==========================================================================================================
 * **فقط insert** ✓§۹ — هیچ aggregate/محاسبه‌ای در MVP نمی‌کنیم (تحلیل در فاز ۱۰ با SQL read-only
 * انجام می‌شود ✗✓ «منطق در مسیرِ نوشتن» یعنی باگ در دادهٔ خام ✓).
 *
 * دو شکلِ body پذیرفته می‌شود ✓ (هر دو با §۵):
 *   • تک‌رویداد:  `{ event_type, player_id, … }`
 *   • دسته‌ای:    `{ events: [ … ] }` ← همین را `NetworkClient` برای **صفِ آفلاین** می‌فرستد ✓۹.۶
 *
 * ۲۰۲ (نه ۲۰۰): پذیرفته شد، پردازش نشده ✓؛ و چون کلاینت ممکن است دوباره بفرستد (retry
 * بی‌دوطة شبکه §۹)، `event_id` اختیاریِ کلاینت را فعلاً **نمی‌گیریم** ✗✓ — یعنی تکراری
 * ممکن است و آمارگیر باید با `timestamp+type` dedup کند ✓ (ثبت در ADR-063؛ اگر dedup
 * لازم شد، `event_id UUID` + unique index افزودنیِ ۰۰۳ است ✓).
 */
import { Router, type Request, type Response } from "express";
import type { Db } from "../db/client.js";
import { insertEvents } from "../db/store.js";
import { requireDeviceToken } from "../middleware/deviceAuth.js";
import {
  describeEventIssues,
  EventsBatchSchema,
  EventSchema,
  MAX_EVENTS_PER_REQUEST,
  type AnalyticsEvent,
} from "../schemas/events.js";

export type EventsRouteDeps = { db: Db | null; deviceSecret: string };

function parseEvents(body: unknown): { ok: true; events: AnalyticsEvent[] } | { ok: false; issues: unknown } {
  const batch = EventsBatchSchema.safeParse(body);
  if (batch.success) return { ok: true, events: batch.data.events };
  const single = EventSchema.safeParse(body);
  if (single.success) return { ok: true, events: [single.data] };
  return { ok: false, issues: describeEventIssues(batch.error) };
}

export function eventsRouter(deps: EventsRouteDeps): Router {
  const router = Router();
  const auth = requireDeviceToken(deps.deviceSecret);

  router.post("/api/events", auth, async (req: Request, res: Response) => {
    const device = req.device;
    if (device === undefined) {
      res.status(401).json({ error: { code: "missing", message: "device لازم است ✗" } });
      return;
    }
    const parsed = parseEvents(req.body);
    if (!parsed.ok) {
      res.status(422).json({
        error: {
          code: "invalid_events",
          message: `رویدادها با §۵ نمی‌خوانند ✗ (حداکثر ${MAX_EVENTS_PER_REQUEST} در هر درخواست ✓)`,
          issues: parsed.issues,
        },
      });
      return;
    }
    // توکن = هویتِ نوشتن ⇒ هر رویداد باید همان player باشد ✓✓ (بدونِ این، هر نصبِ دارای
    // توکن می‌توانست برای کودکِ دیگری رویداد بسازد ✗§۹)
    const foreign = parsed.events.filter((e) => e.player_id !== device.playerId);
    if (foreign.length > 0) {
      res.status(403).json({
        error: { code: "not_owner", message: `${foreign.length} رویداد برای playerِ دیگری بود ✗` },
      });
      return;
    }
    if (deps.db === null) {
      res.status(503).json({ error: { code: "db_disabled", message: "آنالیتیکس موقتاً بسته است ✓" } });
      return;
    }
    try {
      const n = await insertEvents(deps.db, parsed.events);
      res.status(202).json({ ok: true, accepted: n });
    } catch (err) {
      if (process.env.NODE_ENV !== "production") console.error("[nexus] events insert failed", err);
      res.status(500).json({ error: { code: "store_failed", message: "ثبت نشد ✗" } });
    }
  });

  return router;
}
