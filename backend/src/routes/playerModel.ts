/**
 * NEXUS — بک‌اند | endpoint مدل بازیکن (تسک ۹.۳)
 * ===============================================
 * `POST /api/player-model/:id/sync` · `GET /api/player-model/:id` ✓§۹ (مسیرها **دقیقاً** همان
 * دو رشته‌ای هستند که `docs/04` نوشته؛ گیتِ `check_backend_schema_contract` رشته‌ها را از
 * همین فایل می‌خواند ⇒ تغییرِ بی‌سروصدا ممکن نیست ✓)
 *
 * سه دروازه به‌ترتیب، هرکدام با کدِ وضعیتِ متفاوت تا «چرا رد شد» قابل‌برنامه‌ریزی باشد ✓:
 *  ۱) ۴۰۱ بی‌device_token معتبر (۹.۵) → ۲) ۴۰۳ توکنِ بازیکنِ دیگر → ۳) ۴۰۰/۴۲۲ بدنه ✗§۲
 * و ۵۰۳ وقتی دیتابیس تنظیم نشده (بازی باید آفلاین کار کند ⇒ سرور «خراب» به‌نظر نرسد ✓§۹).
 */
import { Router, type Request, type Response } from "express";
import type { Db } from "../db/client.js";
import { selectPlayerModel, upsertPlayerModel } from "../db/store.js";
import { isGamePlayerId } from "../ids.js";
import { requireDeviceToken } from "../middleware/deviceAuth.js";
import { describeIssues, PlayerModelSchema } from "../schemas/playerModel.js";

export type PlayerModelRouteDeps = { db: Db | null; deviceSecret: string };

function badRequest(res: Response, code: string, message: string, issues?: unknown): void {
  res.status(400).json({ error: { code, message, ...(issues ? { issues } : {}) } });
}

export function playerModelRouter(deps: PlayerModelRouteDeps): Router {
  const router = Router();
  const auth = requireDeviceToken(deps.deviceSecret);

  router.post("/api/player-model/:id/sync", auth, async (req: Request, res: Response) => {
    const id = req.params.id ?? "";
    if (!isGamePlayerId(id)) {
      badRequest(res, "bad_player_id", "قالبِ player_id (§۲): p_ + ۸ هگزِ کوچک ✓");
      return;
    }
    const device = req.device;
    if (device === undefined || device.playerId !== id) {
      res.status(403).json({ error: { code: "not_owner", message: "این device مالکِ این مدل نیست ✗" } });
      return;
    }
    if (deps.db === null) {
      res.status(503).json({ error: { code: "db_disabled", message: "همگام‌سازی موقتاً در دسترس نیست ✓" } });
      return;
    }
    const parsed = PlayerModelSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(422).json({
        error: { code: "invalid_model", message: "مدل با §۳/§۲ نمی‌خواند ✗", issues: describeIssues(parsed.error) },
      });
      return;
    }
    if (parsed.data.player_id !== id) {
      res.status(422).json({
        error: { code: "player_id_mismatch", message: "`:id` با body.player_id یکی نیست ✗✓" },
      });
      return;
    }
    try {
      await upsertPlayerModel(deps.db, parsed.data);
      res.json({
        ok: true,
        player_id: parsed.data.player_id,
        schema_version: parsed.data.schema_version,
        skills_stored: Object.keys(parsed.data.skills).length,
        levels_completed: parsed.data.levels_completed.length,
      });
    } catch (err) {
      // هیچ متنِ SQL به کلاینت نمی‌رسد ✓ (detail فقط سرور-لاگ؛ §۹ دادهٔ کودک در لاگِ عمومی نه ✗)
      if (process.env.NODE_ENV !== "production") console.error("[nexus] sync failed", err);
      res.status(500).json({ error: { code: "store_failed", message: "ذخیره نشد ✗" } });
    }
  });

  router.get("/api/player-model/:id", auth, async (req: Request, res: Response) => {
    const id = req.params.id ?? "";
    if (!isGamePlayerId(id)) {
      badRequest(res, "bad_player_id", "قالبِ player_id (§۲): p_ + ۸ هگزِ کوچک ✓");
      return;
    }
    const device = req.device;
    if (device === undefined || device.playerId !== id) {
      res.status(403).json({ error: { code: "not_owner", message: "این device مالکِ این مدل نیست ✗" } });
      return;
    }
    if (deps.db === null) {
      res.status(503).json({ error: { code: "db_disabled", message: "همگام‌سازی موقتاً در دسترس نیست ✓" } });
      return;
    }
    try {
      const stored = await selectPlayerModel(deps.db, id);
      if (stored === null) {
        res.status(404).json({ error: { code: "not_found", message: "مدلی برای این player ثبت نشده ✓" } });
        return;
      }
      res.json({
        ok: true,
        player_id: id,
        schema_version: stored.schema_version,
        updated_at: stored.updated_at,
        model: stored.model,
      });
    } catch (err) {
      if (process.env.NODE_ENV !== "production") console.error("[nexus] read failed", err);
      res.status(500).json({ error: { code: "read_failed", message: "خوانده نشد ✗" } });
    }
  });

  return router;
}
