/**
 * NEXUS — بک‌اند | تستِ یکپارچۀ مدل بازیکن (تسک ۹.۳ | DoD: «ارسال یک مدل نمونه، دریافت
 * مجدد آن، تطابق» ✓✓) — روی `pg-mem` با `createAppِ` واقعی ✗ هیچ mockی در مسیر نیست ✓
 */
import assert from "node:assert/strict";
import test from "node:test";
import request from "supertest";
import { createApp } from "../src/app.js";
import { countEvents } from "../src/db/store.js";
import { issueDeviceToken } from "../src/middleware/deviceAuth.js";
import { OTHER_PLAYER_ID, SAMPLE_MODEL } from "./fixtures.js";
import { createMemoryDb, testConfig } from "./helpers/db.js";

const SECRET = "nexus-test-secret";

async function build() {
  const h = await createMemoryDb();
  const config = testConfig({ DEVICE_TOKEN_SECRET: SECRET });
  const app = createApp({ config, db: h.db });
  return {
    app,
    db: h.db,
    close: h.close,
    token: (playerId: string) => issueDeviceToken(playerId, SECRET),
  };
}

function syncBody(over: Record<string, unknown> = {}): Record<string, unknown> {
  return { ...SAMPLE_MODEL, ...over } as Record<string, unknown>;
}

test("بی‌device_token ⇒ ۴۰۱ و با توکنِ معتبر عبور ✓ (DoD ۹.۵)", async () => {
  const h = await build();
  try {
    const noToken = await request(h.app)
      .post(`/api/player-model/${SAMPLE_MODEL.player_id}/sync`)
      .send(syncBody());
    assert.equal(noToken.status, 401, `بی‌توکن باید رد می‌شد (شد ${noToken.status}) ✗`);
    assert.equal(noToken.body.error.code, "missing", "کدِ خطا مشخص است ✓");

    const ok = await request(h.app)
      .post(`/api/player-model/${SAMPLE_MODEL.player_id}/sync`)
      .set("authorization", `Bearer ${h.token(SAMPLE_MODEL.player_id)}`)
      .send(syncBody());
    assert.equal(ok.status, 200, `با توکن باید می‌گذشت (شد ${ok.status}) ✗`);
    assert.equal(ok.body.skills_stored, 2, "دو مهارتِ §۲ ذخیره شد ✓");
  } finally {
    await h.close();
  }
});

test("ارسال مدلِ نمونه ⇒ دریافتِ **همان** مدل ✓✓ (DoD ۹.۳)", async () => {
  const h = await build();
  try {
    const token = h.token(SAMPLE_MODEL.player_id);
    const put = await request(h.app)
      .post(`/api/player-model/${SAMPLE_MODEL.player_id}/sync`)
      .set("authorization", `Bearer ${token}`)
      .send(syncBody());
    assert.equal(put.status, 200);

    const get = await request(h.app)
      .get(`/api/player-model/${SAMPLE_MODEL.player_id}`)
      .set("authorization", `Bearer ${token}`);
    assert.equal(get.status, 200, `بازگشتِ مدل (شد ${get.status}) ✗`);
    assert.deepEqual(get.body.model, SAMPLE_MODEL, "ردّ‌وبدلِ بایت‌به‌بایتِ §۲ ✗✓");
    assert.equal(get.body.schema_version, 1, "نسخۀ اسکیما در پاسخ هم هست ✓ (کلاینت ۹.۶ migrate می‌کند)");
    assert.equal(typeof get.body.updated_at, "string", "زمانِ همگام‌سازی برگشت ✓");
  } finally {
    await h.close();
  }
});

test("`skill_ratings` آینه می‌شود ✓ (نه فقط JSONB ⇒ §۶ باید زنده بماند)", async () => {
  const h = await build();
  try {
    const token = h.token(SAMPLE_MODEL.player_id);
    await request(h.app)
      .post(`/api/player-model/${SAMPLE_MODEL.player_id}/sync`)
      .set("authorization", `Bearer ${token}`)
      .send(syncBody());
    const rows = await h.db.exec.query<{ skill_key: string; elo: number }>(
      "SELECT skill_key, elo FROM skill_ratings ORDER BY skill_key"
    );
    assert.deepEqual(
      rows.rows.map((r) => `${r.skill_key}:${r.elo}`),
      ["addition_basic:1120", "subtraction_negative:980"],
      "هر دو مهارت با elo درست در جدولِ نرمال نشسته ✓✓"
    );
    const players = await h.db.exec.query<{ display_name: string }>(
      "SELECT display_name FROM players"
    );
    assert.equal(players.rows[0]?.display_name, "کارآموز", "players هم upsert شد ✓§۶");
  } finally {
    await h.close();
  }
});

test("syncِ دوباره مدل را به‌روز می‌کند، نه این‌که دو ردیف بسازد ✓ (snapshotِ آخر ✓)", async () => {
  const h = await build();
  try {
    const token = h.token(SAMPLE_MODEL.player_id);
    await request(h.app)
      .post(`/api/player-model/${SAMPLE_MODEL.player_id}/sync`)
      .set("authorization", `Bearer ${token}`)
      .send(syncBody());
    const next = syncBody({ total_playtime_sec: 9000 });
    await request(h.app)
      .post(`/api/player-model/${SAMPLE_MODEL.player_id}/sync`)
      .set("authorization", `Bearer ${token}`)
      .send(next);
    const rows = await h.db.exec.query<{ n: number | string }>(
      "SELECT COUNT(*) AS n FROM player_models"
    );
    assert.equal(Number(rows.rows[0]?.n ?? 0), 1, "یک بازیکن = یک ردیف ✓");
    const get = await request(h.app)
      .get(`/api/player-model/${SAMPLE_MODEL.player_id}`)
      .set("authorization", `Bearer ${token}`);
    assert.equal(Number(get.body.model.total_playtime_sec), 9000, "آخرین مقدار برنده شد ✓");
  } finally {
    await h.close();
  }
});

test("مدلِ نامعتبر ⇒ ۴۲۲ با pathها ✓ و بدونِ لو‌رفتنِ داده ✓§۹", async () => {
  const h = await build();
  try {
    const bad = syncBody({ player_id: "not_a_player_id", hint_usage_rate: 7, email: "kid@example.com" });
    const res = await request(h.app)
      .post(`/api/player-model/${SAMPLE_MODEL.player_id}/sync`)
      .set("authorization", `Bearer ${h.token(SAMPLE_MODEL.player_id)}`)
      .send(bad);
    assert.equal(res.status, 422, `باید رد می‌شد (شد ${res.status}) ✗`);
    const paths: string[] = (res.body.error.issues as Array<{ path: string }>).map((i) => i.path);
    assert.ok(paths.includes("player_id"), "مسیرِ خطا گزارش شد ✓");
    assert.ok(paths.includes("hint_usage_rate"), "بازه‌ی ۰..۱ نگه داشته شد ✓");
    // `.strict()` ⇒ فیلدِ ناشناخته **خطاست**، نه «بی‌صدا نادیده» ✓ (PIIِ قاچاقی در مرز می‌ماند ✗✓)
    const issueText = JSON.stringify(res.body.error.issues);
    assert.ok(issueText.includes("email"), "فیلدِ خارج از §۲ رد شد ✓§۹ (پیامِ strict، نه مقدار ✓)");
    assert.ok(paths.includes("(root)"), `کلیدِ ناشناخته در ریشۀ path است ✓ (شد ${paths.join("|")})`);
    const body = JSON.stringify(res.body);
    assert.ok(!body.includes("kid@example.com"), "مقدارِ ارسالی در پاسخ چاپ نشد ✓✓ (لاگِ عمومی ≠ آینهٔ داده)");
  } finally {
    await h.close();
  }
});

test("توکنِ playerِ دیگر ⇒ ۴۰۳ ✓ (یک نصب، یک مدل §۹)", async () => {
  const h = await build();
  try {
    const res = await request(h.app)
      .post(`/api/player-model/${SAMPLE_MODEL.player_id}/sync`)
      .set("authorization", `Bearer ${h.token(OTHER_PLAYER_ID)}`)
      .send(syncBody());
    assert.equal(res.status, 403, `توکنِ دیگری نباید بنویسد (شد ${res.status}) ✗`);
    assert.equal(res.body.error.code, "not_owner", "کدِ «مالک نیست» ✓");
  } finally {
    await h.close();
  }
});

test("`/:id` با `body.player_id` ناهمخوان ⇒ ۴۲۲ ✓ (جلوگیری از نوشتنِ اشتباهِ مسیر ✓)", async () => {
  const h = await build();
  try {
    const token = h.token(OTHER_PLAYER_ID);
    const res = await request(h.app)
      .post(`/api/player-model/${OTHER_PLAYER_ID}/sync`)
      .set("authorization", `Bearer ${token}`)
      .send(syncBody()); // هنوز p_193f2a7e در body ✗
    assert.equal(res.status, 422, "باید رد می‌شد ✗✓");
    assert.equal(res.body.error.code, "player_id_mismatch", "کدِ ناهمخوانی ✓");
  } finally {
    await h.close();
  }
});

test("GET برای بازیکنی که هنوز sync نکرده ⇒ ۴۰۴ ✓ (نه مدلِ تهی ✗)", async () => {
  const h = await build();
  try {
    const res = await request(h.app)
      .get(`/api/player-model/${OTHER_PLAYER_ID}`)
      .set("authorization", `Bearer ${h.token(OTHER_PLAYER_ID)}`);
    assert.equal(res.status, 404);
    assert.equal(res.body.error.code, "not_found", "پاسخِ ساختارمند ✓");
    // کمکیِ تست: `events` خالی است ⇒ helperهای شمارش هم به مسیرِ واقعی وصل‌اند ✓
    assert.equal(await countEvents(h.db, OTHER_PLAYER_ID), 0, "بی‌رویداد ✓");
  } finally {
    await h.close();
  }
});
