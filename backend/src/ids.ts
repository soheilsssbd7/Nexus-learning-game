/**
 * NEXUS — بک‌اند | تسک ۹.۳ (کمکیِ مشترک)
 * =======================================
 * **تعارضِ مستندات و حلّ آن** (ثبت‌شده در ADR-063 ✓):
 *  - `docs/03` §۲ بازیکن را با `player_id` رشته‌ایِ `p_193f2a7e` معرفی می‌کند ✗ «UUID نیست».
 *  - `docs/03` §۶ (DDL) همان `player_id` را `UUID PRIMARY KEY` می‌خواهد ✗ «رشته نمی‌پذیرد».
 * ما هیچ‌کدام را نقض نمی‌کنیم ✗✓: قراردادِ بازی همان رشته است، و در لایهٔ بک‌اند به یک
 * **UUIDv5 قطعی** (RFC 4122، SHA-1، فضای‌نامِ ثابتِ زیر) نگاشت می‌شود ⇒
 *  • یک‌رشته با یک uuid می‌ماند (بدون جدولِ نگاشت ✓ بدون حالتِ سروری ✓)
 *  • اگر بازی فردا خودش UUID واقعی بدهد، فقط `isGamePlayerId` عوض می‌شود ✓ یک‌منبعه
 *  • هیچ PII‌ای در این فرایند تولید/نگه‌داشته نمی‌شود ✓§۹ (hashِ بی‌بازگشتِ بی‌نمکِ
 *    هویتِ محلی است، نه دادهٔ حساس: توکنِ دستگاه جداست و آن HMAC است ✓۹.۵)
 */
import { createHash } from "node:crypto";

/** فضای‌نامِ ثابتِ NEXUS (ثابتِ انتخابیِ ما؛ تغییرش دادهٔ موجود را بی‌ربط می‌کند ✗✓) */
export const NEXUS_UUID_NAMESPACE = "6f7c1f0e-9a1e-5a2b-8b9c-0d1e2f3a4b5c";

/** قراردادِ §۲: `p_` + هشت هگزِ کوچک ✓ */
const GAME_PLAYER_ID = /^p_[0-9a-f]{8}$/;

export function isGamePlayerId(value: string): boolean {
  return GAME_PLAYER_ID.test(value);
}

/** UUIDv5 (RFC 4122) — SHA-1 روی `namespace || name`، بعد بایت‌های نسخه/واریانت ✓ */
export function uuidV5(name: string, namespaceHex: string = NEXUS_UUID_NAMESPACE): string {
  const ns = Buffer.from(namespaceHex.replace(/-/g, ""), "hex");
  if (ns.length !== 16) throw new Error("namespace باید ۱۶ بایت باشد ✗");
  const digest = createHash("sha1").update(ns).update(Buffer.from(name, "utf8")).digest();
  const out = Buffer.from(digest.subarray(0, 16));
  out.writeUInt8((out.readUInt8(6) & 0x0f) | 0x50, 6); // version = 5 ✓
  out.writeUInt8((out.readUInt8(8) & 0x3f) | 0x80, 8); // variant = RFC 4122 ✓
  const hex = out.toString("hex");
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20, 32),
  ].join("-");
}

/** `p_193f2a7e` ⇒ uuidِ قطعی ✓ (پیشوندِ صریح تا هیچ نامِ دیگری با همان uuid ننشیند ✗✓) */
export function playerIdToUuid(playerId: string): string {
  if (!isGamePlayerId(playerId)) {
    throw new Error(`player_id نامعتبر: «${playerId}» (§۲ = p_ + 8 هگز) ✗`);
  }
  return uuidV5(`nexus:player:${playerId}`);
}

/** برای تستِ شکل، نه برای بازگرداندنِ رشتهٔ بازی (نگاشت یک‌طرفه است ✓§۹) */
const UUID_TEXT = /^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

export function isUuidV5(value: string): boolean {
  return UUID_TEXT.test(value);
}
