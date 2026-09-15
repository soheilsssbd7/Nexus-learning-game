/**
 * NEXUS — بک‌اند | تستِ endpoint رویدادها (تسک ۹.۴ | DoD: «رویداد نمونه ارسال، در جدول
 * `events` قابل‌مشاهده است» ⇒ همین‌جا جدول **خوانده** می‌شود ✓✗ نه فقط status 2xx گرفتن ✓)
 */
import assert from "node:assert/strict";
import test from "node:test";
import request from "supertest";
import { createApp } from "../src/app.js";
import { countEvents } from "../src/db/store.js";
import { issueDeviceToken } from "../src/middleware/deviceAuth.js";
import { OTHER_PLAYER_ID, SAMPLE_EVENT } from "./fixtures.js";
import { createMemoryDb, testConfig } from "./helpers/db.js";

const SECRET = "nexus-test-secret";

async function build() {
  const h = await createMemoryDb();
  const app = createApp({ config: testConfig({ DEVICE_TOKEN_SECRET: SECRET }), db: h.db });
  return { app, db: h.db, close: h.close, token: (p: string) => issueDeviceToken(p, SECRET) };
}

test("تک‌رویداد پذیرفته و در جدول نوشته می‌شود ✓ (DoD ۹.۴)", async () => {
  const h = await build();
  try {
    const res = await request(h.app)
      .post("/api/events")
      .set("authorization", `Bearer ${h.token(SAMPLE_EVENT.player_id)}`)
      .send(SAMPLE_EVENT);
    assert.equal(res.status, 202, `۲۰۲ = پذیرفته (شد ${res.status}) ✗`);
    assert.equal(res.body.accepted, 1, "یک رویداد ✓");
    assert.equal(await countEvents(h.db, SAMPLE_EVENT.player_id), 1, "در جدول `events` دیده شد ✓✓");
    const row = await h.db.exec.query<{ event_type: string; level_id: string; payload: unknown }>(
      "SELECT event_type, level_id, payload FROM events"
    );
    const r = row.rows[0];
    assert.equal(r?.event_type, "level_completed", "نوعِ رویداد حفظ شد ✓");
    assert.equal(r?.level_id, "tier1_level_03", "level_id نشست ✓");
    const payload = typeof r?.payload === "string" ? JSON.parse(r.payload) : r?.payload;
    assert.equal((payload as { attempts: number }).attempts, 4, "payload JSONB ⇒ عدد حفظ شد ✓§۵");
  } finally {
    await h.close();
  }
});

test("دسته‌ای (صفِ آفلاین ۹.۶) هم کار می‌کند ✓", async () => {
  const h = await build();
  try {
    const events = [
      { ...SAMPLE_EVENT, event_type: "session_start" as const, payload: { idx: 0 } },
      { ...SAMPLE_EVENT, event_type: "level_started" as const, payload: { idx: 1 } },
      { ...SAMPLE_EVENT, event_type: "hint_shown" as const, payload: { idx: 2 } },
    ];
    const res = await request(h.app)
      .post("/api/events")
      .set("authorization", `Bearer ${h.token(SAMPLE_EVENT.player_id)}`)
      .send({ events });
    assert.equal(res.status, 202);
    assert.equal(res.body.accepted, 3, "سه رویداد پذیرفته شد ✓");
    assert.equal(await countEvents(h.db, SAMPLE_EVENT.player_id), 3, "هر سه در جدول‌اند ✓✓");
  } finally {
    await h.close();
  }
});

test("رویدادِ ناشناخته ⇒ ۴۲۲ ✓ (§۵ فقط شش نوعِ MVP را نام برده — «بپذیر و بعداً ببینیم» ✗)", async () => {
  const h = await build();
  try {
    const res = await request(h.app)
      .post("/api/events")
      .set("authorization", `Bearer ${h.token(SAMPLE_EVENT.player_id)}`)
      .send({ ...SAMPLE_EVENT, event_type: "pixel_clicked" });
    assert.equal(res.status, 422, `نباید می‌گذشت (شد ${res.status}) ✗`);
    assert.equal(await countEvents(h.db, SAMPLE_EVENT.player_id), 0, "چیزی وارد جدول نشد ✓");
  } finally {
    await h.close();
  }
});

test("رویداد برای playerِ دیگر ⇒ ۴۰۳ ✓ (توکن = هویتِ نوشتن ✗§۹)", async () => {
  const h = await build();
  try {
    const res = await request(h.app)
      .post("/api/events")
      .set("authorization", `Bearer ${h.token(SAMPLE_EVENT.player_id)}`)
      .send({ events: [{ ...SAMPLE_EVENT, player_id: OTHER_PLAYER_ID }] });
    assert.equal(res.status, 403, "نصبِ من نباید برای کودکِ دیگری رویداد بسازد ✗✓");
    assert.equal(await countEvents(h.db, OTHER_PLAYER_ID), 0, "حتی یک ردیف هم ننشست ✓ (atomicityِ سطحِ درخواست ✓)");
  } finally {
    await h.close();
  }
});

test("بی‌توکن ⇒ ۴۰۱ ✓ و دسته‌ی بیش از سقف ⇒ ۴۲۲ ✓", async () => {
  const h = await build();
  try {
    const noAuth = await request(h.app).post("/api/events").send(SAMPLE_EVENT);
    assert.equal(noAuth.status, 401, "دروازهٔ ۹.۵ روی events هم هست ✓");

    const many = Array.from({ length: 201 }, () => ({ ...SAMPLE_EVENT }));
    const big = await request(h.app)
      .post("/api/events")
      .set("authorization", `Bearer ${h.token(SAMPLE_EVENT.player_id)}`)
      .send({ events: many });
    assert.equal(big.status, 422, `سقفِ ۲۰۰ نگه داشته شد ✗✓ (شد ${big.status})`);
  } finally {
    await h.close();
  }
});
