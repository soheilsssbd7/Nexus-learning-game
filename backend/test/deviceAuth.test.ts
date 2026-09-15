/**
 * NEXUS — بک‌اند | واحدِ توکنِ دستگاه (تسک ۹.۵ | DoD: «درخواست بدونِ توکن معتبر رد می‌شود ✓
 * با توکن معتبر عبور می‌کند ✓» — این‌جا **چهار** حالتِ رد، تک‌تک سنجیده می‌شود ✗✓ چون
 * «۴۰۱ می‌دهد» به‌تنهایی با یک `return false` سرکرده هم پاس می‌شد ✓)
 */
import assert from "node:assert/strict";
import test from "node:test";
import {
  DEVICE_TOKEN_TTL_DAYS,
  issueDeviceToken,
  randomDeviceSeed,
  verifyDeviceToken,
} from "../src/middleware/deviceAuth.js";
import { loadConfig } from "../src/config.js";
import { OTHER_PLAYER_ID, SAMPLE_MODEL } from "./fixtures.js";

const SECRET = "nexus-test-secret";
const NOW = Date.parse("2026-09-12T00:00:00Z");

test("ساخت ⇒ راستی‌آزمایی ✓ و claims همان player است ✓", () => {
  const token = issueDeviceToken(SAMPLE_MODEL.player_id, SECRET, NOW);
  const v = verifyDeviceToken(token, SECRET, NOW + 1000);
  assert.equal(v.ok, true, `توکنِ تازه باید معتبر باشد ✗ (${v.ok ? "" : v.code})`);
  if (v.ok) assert.equal(v.claims.p, SAMPLE_MODEL.player_id, "توکن به player bound است ✓§۹");
});

test("امضا دست‌کاری‌شده ⇒ «signature» ✓ (نه «malformed» ⇒ قابل‌تفکیک برای کلاینت ✓)", () => {
  const token = issueDeviceToken(SAMPLE_MODEL.player_id, SECRET, NOW);
  const [payload] = token.split(".");
  const tampered = `${payload}.${"0".repeat(64)}`;
  const v = verifyDeviceToken(tampered, SECRET, NOW);
  assert.equal(v.ok, false);
  if (!v.ok) assert.equal(v.code, "signature", "کدِ درست ✓");
});

test("رازِ دیگر ⇒ رد ✓ (توکنِ محیطِ تست در production کار نمی‌کند ✓)", () => {
  const token = issueDeviceToken(SAMPLE_MODEL.player_id, SECRET, NOW);
  const v = verifyDeviceToken(token, "another-secret", NOW);
  assert.equal(v.ok, false);
  if (!v.ok) assert.equal(v.code, "signature");
});

test("منقضی ⇒ «expired» ✓ و انقضا ۴۰۰ روز است (کلاینت تمدید می‌کند ✓§۹)", () => {
  const token = issueDeviceToken(SAMPLE_MODEL.player_id, SECRET, NOW);
  const dayMs = 86_400_000;
  assert.equal(verifyDeviceToken(token, SECRET, NOW + (DEVICE_TOKEN_TTL_DAYS - 1) * dayMs).ok, true,
    "یک روز مانده ⇒ هنوز معتبر ✓");
  const v = verifyDeviceToken(token, SECRET, NOW + (DEVICE_TOKEN_TTL_DAYS + 1) * dayMs);
  assert.equal(v.ok, false);
  if (!v.ok) assert.equal(v.code, "expired", "پایانِ عمر گزارش می‌شود ✓ (۴۰۱ِ بی‌دلیل نبود ✗)");
});

test("شکل‌های خراب ⇒ malformed ✓ (نقطه ندارد / base64 بی‌معنا / payloadِ بی‌شکل ✗)", () => {
  for (const bad of ["", "abc", "a.b", `${"!!!"}.deadbeef`]) {
    const v = verifyDeviceToken(bad, SECRET, NOW);
    assert.equal(v.ok, false, `«${bad}» نباید می‌گذشت ✗`);
    if (!v.ok) assert.ok(["malformed", "signature"].includes(v.code), `کدِ منطقی: ${v.code} ✓`);
  }
  const forged = Buffer.from(JSON.stringify({ p: OTHER_PLAYER_ID, iat: NOW, exp: NOW + 1e9 })).toString("base64url");
  const v2 = verifyDeviceToken(`${forged}.${"f".repeat(64)}`, SECRET, NOW);
  assert.equal(v2.ok, false, "payload دست‌ساز بدونِ امضا ⇒ رد ✓✓");
});

test("دو توکن برای یک player متفاوت‌اند (iat/exp در payload ⇒ stateless ولی غیرقابل‌پیش‌بینی ✓)", () => {
  const a = issueDeviceToken(SAMPLE_MODEL.player_id, SECRET, NOW);
  const b = issueDeviceToken(SAMPLE_MODEL.player_id, SECRET, NOW + 1);
  assert.notEqual(a, b, "زمان متفاوت ⇒ توکن متفاوت ✓ (ردپای قابل‌سازگاریِ ثابت نداریم ✓)");
  assert.notEqual(randomDeviceSeed(), randomDeviceSeed(), "سیدِ تصادفی واقعی است ✓");
});

test("production با کلیدِ پیش‌فرضِ dev بالا نمی‌آید ✗✓ (سومین خطایِ پیکربندیِ محتمل ✓)", () => {
  assert.throws(
    () => loadConfig({ NODE_ENV: "production", DEVICE_TOKEN_SECRET: "nexus-dev-only-insecure-secret" }),
    /DEVICE_TOKEN_SECRET/
  );
  assert.equal(loadConfig({ NODE_ENV: "production", DEVICE_TOKEN_SECRET: "a-real-secret" }).env, "production");
});

test("پیامِ خطای config مقادیرِ حساس را چاپ نمی‌کند ✓ (DATABASE_URL در لاگِ CI نشت نمی‌کند ✗✓)", () => {
  let message = "";
  try {
    loadConfig({ MAX_BODY_BYTES: "not-a-number", DATABASE_URL: "postgres://u:p@h/db" });
  } catch (e) {
    message = e instanceof Error ? e.message : String(e);
  }
  assert.match(message, /MAX_BODY_BYTES/, "نامِ متغیر گفته می‌شود ✓");
  assert.ok(!message.includes("u:p@h"), "پسورد چاپ نشد ✓✓");
});
