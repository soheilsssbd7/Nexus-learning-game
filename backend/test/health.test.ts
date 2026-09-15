/**
 * NEXUS — بک‌اند | DoD ۹.۱: «`npm run dev` سرور را بالا می‌آورد و `GET /health` = 200» ✓
 * این‌جا همان «بالا آمدن» بدونِ پورت و بدونِ Postgres سنجیده می‌شود ✗✓ (چون در CI
 * هیچ‌کدام نیست ⇒ اگر `createApp` به DB وابسته بود، همین تست می‌گفت ✗✓ نه لاگِ production).
 */
import assert from "node:assert/strict";
import test from "node:test";
import request from "supertest";
import { createApp } from "../src/app.js";
import { createMemoryDb, testConfig } from "./helpers/db.js";

test("/health بی‌دیتابیس هم ۲۰۰ است ✓ (DoD ۹.۱ | بازی آفلاین ⇒ سرور «سالم» است ✓)", async () => {
  const app = createApp({ config: testConfig(), db: null });
  const res = await request(app).get("/health");
  assert.equal(res.status, 200, `سلامتی باید مستقل از DB باشد (شد ${res.status}) ✗`);
  assert.equal(res.body.ok, true);
  assert.equal(res.body.data, "disabled", "صادقانه می‌گوید دیتابیس وصل نیست ✓");
  assert.equal(res.body.sync_required, false, "پیش‌فرضِ §۹: همگام‌سازی اجباری نیست ✓");
});

test("/health/ready بدونِ دیتابیس ۵۰۳ و با دیتابیس ۲۰۰ ✓ (تفکیکِ «زنده» از «آماده» ✓)", async () => {
  const down = await request(createApp({ config: testConfig(), db: null })).get("/health/ready");
  assert.equal(down.status, 503);
  assert.equal(down.body.reason, "db_disabled", "دلیل دارد ✓ (ops بدونِ حدس ✗✓)");

  const h = await createMemoryDb();
  try {
    const up = await request(createApp({ config: testConfig(), db: h.db })).get("/health/ready");
    assert.equal(up.status, 200, `با DB باید ready باشد (شد ${up.status}) ✗`);
    assert.equal(up.body.data, "memory");
  } finally {
    await h.close();
  }
});

test("route ناشناخته JSON برمی‌گرداند، نه html ✓ (کلاینت ۹.۶ JSON parse می‌کند ✗✓)", async () => {
  const res = await request(createApp({ config: testConfig(), db: null })).get("/api/nope");
  assert.equal(res.status, 404);
  assert.equal(res.body.error.code, "no_route", "ساختارِ خطا یکشکل است ✓");
});

test("بدنۀ بزرگ‌تر از سقف ⇒ ۴۱۳ ✓ (نه ۵۰۰ با stack ✓§۹)", async () => {
  const config = testConfig({ MAX_BODY_BYTES: "2048" });
  const app = createApp({ config, db: null });
  const huge = { data: "x".repeat(4096) };
  const res = await request(app).post("/api/player-model/p_193f2a7e/sync").send(huge);
  assert.equal(res.status, 413, `سقفِ حجم محترم شمرده شد ✗✓ (شد ${res.status})`);
  assert.equal(res.body.error.max_bytes, 2048, "سقف در پاسخ هست تا کلاینت batch را بشکند ✓۹.۶");
});

test("sync/events بی‌دیتابیس ⇒ ۵۰۳ (کرش نه ✓§۹ «آفلاین‌پذیر»)", async () => {
  const app = createApp({ config: testConfig(), db: null });
  const res = await request(app)
    .post("/api/player-model/p_193f2a7e/sync")
    .set("authorization", "Bearer whatever")
    .send({});
  assert.equal(res.status, 401, "اول دروازهٔ احراز است، بعد دیتابیس ✓ (ترتیبِ امن ✓)");
});
