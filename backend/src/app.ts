/**
 * NEXUS — بک‌اند | کارخانۀ اپ (تسک ۹.۱ | DoD: `GET /health` = 200)
 * ================================================================
 * `createApp(deps)` عمداً از `listen` جداست ✓✗ چون:
 *  ۱) تست‌های ۹.۳/۹.۴/۹.۵ همین اپ را با `supertest` و با **pg-mem** می‌سازند ✓✓ (بدونِ
 *     پورت، بدونِ سرور، بدونِ Postgres ⇒ در CIِ هر سه ثانیه‌ای ✓)
 *  ۲) `index.ts` تنها جایی است که `listen` می‌کند ⇒ «یک نقطۀ شروع» ✓§۱
 *
 * `/health` همیشه ۲۰۰ است (پروسه زنده است ✓) و `/health/ready` بی‌دیتابیس ۵۰۳ ✓
 * تفکیکِ این دو از عمد است: اگر «سلامتی» را به دیتابیس گره بزنیم، یک قطعیِ DB کل
 * k8s/load-balancer را وادار به restart می‌کند ✗✓ درحالی‌که بازی باید آفلاین کار کند ✓§۹
 */
import express, { type Express, type NextFunction, type Request, type Response } from "express";
import type { AppConfig } from "./config.js";
import type { Db } from "./db/client.js";
import { deviceRouter } from "./routes/device.js";
import { eventsRouter } from "./routes/events.js";
import { playerModelRouter } from "./routes/playerModel.js";

export type AppDeps = { config: AppConfig; db: Db | null };

export function createApp({ config, db }: AppDeps): Express {
  const app = express();
  app.disable("x-powered-by");
  app.use(express.json({ limit: config.maxBodyBytes }));

  app.get("/health", (_req: Request, res: Response) => {
    res.json({
      ok: true,
      service: "nexus-backend",
      env: config.env,
      data: db === null ? "disabled" : db.kind,
      sync_required: config.syncRequired,
    });
  });

  app.get("/health/ready", async (_req: Request, res: Response) => {
    if (db === null) {
      res.status(503).json({ ok: false, reason: "db_disabled", hint: "DATABASE_URL تنظیم نشده ✓" });
      return;
    }
    try {
      await db.exec.query("SELECT 1 AS ok");
      res.json({ ok: true, data: db.kind });
    } catch {
      res.status(503).json({ ok: false, reason: "db_unreachable" });
    }
  });

  app.use(deviceRouter(config.deviceTokenSecret));
  app.use(playerModelRouter({ db, deviceSecret: config.deviceTokenSecret }));
  app.use(eventsRouter({ db, deviceSecret: config.deviceTokenSecret }));

  app.use((req: Request, res: Response) => {
    res.status(404).json({ error: { code: "no_route", message: `${req.method} ${req.path} وجود ندارد ✓` } });
  });

  // خطای پارسِ JSON و سقفِ حجم ⇒ پاسخِ JSON (نه html/stack ✓§۹ لاگِ عمومی)
  // ⚠ چهار آرگومان **لازم** است ✗✓ (اگر `next` نیاید، Express این را error handler نمی‌داند
  // و پاسخ، HTMLِ پیش‌فرض با stack می‌شود ✗ — تستِ ۴۱۳ همین را در ۹.۱ گرفت ✓✓)
  app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
    const e = err as { status?: number; type?: string };
    if (e.type === "entity.parse.failed" || e.status === 400) {
      res.status(400).json({ error: { code: "bad_json", message: "بدنه JSON معتبر نیست ✗" } });
      return;
    }
    if (e.type === "entity.too.large" || e.status === 413) {
      res.status(413).json({
        error: { code: "too_large", message: "بدنه از سقفِ مجاز بزرگ‌تر است ✗", max_bytes: config.maxBodyBytes },
      });
      return;
    }
    if (config.env !== "production") console.error("[nexus] خطای مدیریت‌نشده:", err);
    res.status(500).json({ error: { code: "internal", message: "خطای داخلی ✗" } });
  });

  return app;
}
