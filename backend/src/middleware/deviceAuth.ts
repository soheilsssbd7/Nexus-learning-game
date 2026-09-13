/**
 * NEXUS — بک‌اند | احراز هویتِ دستگاه (تسک ۹.۵)
 * ==============================================
 * **stateless، بی‌جدول، بی‌PII** ✓ (ADR-063): §۶ برای `device_token` هیچ جدولی تعریف نکرده
 * و افزودنِ «جدولِ کاربران» به سرویسِ کودک‌محور یعنی وسوسۀ ذخیرۀ هویت ✗§۹؛ پس توکن یک
 * **HMAC** روی `player_id + زمان` است:
 *
 *      device_token = b64url({p, iat, exp}) ‖ "." ‖ hex(HMAC-SHA256(payload, secret))
 *
 *  • هیچ state سمتِ سرور نیست ⇒ ریستارت چیزی را می‌سوزاند؟ نه ✓ (برای MVP درست است؛
 *    اگر روزی «لغوِ توکنِ دزدی» لازم شد، همان‌جا به لیستِ لغو نیاز می‌شود ✗✓ فاز ۱۱)
 *  • توکن **به یک player گره خورده** ⇒ درخواستِ همگام‌سازی برای مدلِ دیگری ۴۰۳ می‌شود ✓✓
 *    (این تنها authzِ سرویس است و عمداً کوچک است: یک نصب = یک کودک = یک مدل ✓)
 *  • مقایسه با `timingSafeEqual` ✓ و پیام‌های ۴۰۱ فقط **کد** می‌دهند، نه خودِ توکن ✓
 *  • انقضا ۴۰۰ روز ✓ (کلاینت ۹.۶ قبل از انقضا تمدید می‌کند؛ «هرگز منقضی نشود» =
 *    توکنِ دزدیده‌شدهٔ ابدی ✗✓)
 */
import { createHmac, randomBytes, timingSafeEqual } from "node:crypto";
import type { NextFunction, Request, RequestHandler, Response } from "express";
import { isGamePlayerId } from "../ids.js";

export const DEVICE_TOKEN_TTL_DAYS = 400;
const DAY_MS = 86_400_000;

export type DeviceClaims = { p: string; iat: number; exp: number };
export type DeviceContext = { playerId: string; issuedAt: number; expiresAt: number };

export type VerifyResult =
  | { ok: true; claims: DeviceClaims }
  | { ok: false; code: "missing" | "malformed" | "signature" | "expired" | "bad_claims" };

function b64url(input: string | Buffer): string {
  return Buffer.from(input as never).toString("base64url");
}

function sign(payload: string, secret: string): string {
  return createHmac("sha256", secret).update(payload).digest("hex");
}

/** ساختِ توکن (endpointِ ۹.۵ و تست‌ها از همین یک تابع می‌خورند ⇒ دو مسیرِ ساخت نداریم ✓) */
export function issueDeviceToken(
  playerId: string,
  secret: string,
  now: number = Date.now(),
  ttlDays: number = DEVICE_TOKEN_TTL_DAYS
): string {
  if (!isGamePlayerId(playerId)) {
    throw new Error("issueDeviceToken: player_id باید قالبِ §۲ را داشته باشد ✗");
  }
  const claims: DeviceClaims = { p: playerId, iat: now, exp: now + ttlDays * DAY_MS };
  const payload = b64url(JSON.stringify(claims));
  return `${payload}.${sign(payload, secret)}`;
}

/** برای تستِ «هر نصبِ تازه واقعاً تصادفی است» ✓§۹ (توکن‌های یکسان = ردپای قابل‌سازگاری ✗) */
export function randomDeviceSeed(): string {
  return randomBytes(16).toString("hex");
}

export function verifyDeviceToken(token: string, secret: string, now: number = Date.now()): VerifyResult {
  const parts = token.split(".");
  if (parts.length !== 2 || parts[0] === undefined || parts[1] === undefined) {
    return { ok: false, code: "malformed" };
  }
  const [payload, signature] = [parts[0], parts[1]] as [string, string];
  const expected = Buffer.from(sign(payload, secret), "utf8");
  const got = Buffer.from(signature, "utf8");
  if (expected.length !== got.length || !timingSafeEqual(expected, got)) {
    return { ok: false, code: "signature" };
  }
  let claims: unknown;
  try {
    claims = JSON.parse(Buffer.from(payload, "base64url").toString("utf8"));
  } catch {
    return { ok: false, code: "malformed" };
  }
  if (
    typeof claims !== "object" ||
    claims === null ||
    typeof (claims as DeviceClaims).p !== "string" ||
    typeof (claims as DeviceClaims).iat !== "number" ||
    typeof (claims as DeviceClaims).exp !== "number"
  ) {
    return { ok: false, code: "bad_claims" };
  }
  const c = claims as DeviceClaims;
  if (!isGamePlayerId(c.p)) return { ok: false, code: "bad_claims" };
  if (c.exp <= now) return { ok: false, code: "expired" };
  if (c.iat > now + 60_000) return { ok: false, code: "bad_claims" }; // ساعتِ آینده ✗✓
  return { ok: true, claims: c };
}

function readToken(req: Request): string | null {
  const header = req.header("authorization") ?? "";
  const bearer = /^Bearer\s+(.+)$/i.exec(header);
  if (bearer?.[1] !== undefined) return bearer[1].trim();
  const legacy = req.header("x-nexus-device");
  if (typeof legacy === "string" && legacy.length > 0) return legacy.trim();
  return null;
}

/** مسیرهای داده‌دار باید این را بگذارند ✓ (DoD ۹.۵: بی‌توکن ⇒ ۴۰۱، با توکن ⇒ عبور ✓) */
export function requireDeviceToken(secret: string): RequestHandler {
  return (req: Request, res: Response, next: NextFunction) => {
    const token = readToken(req);
    if (token === null) {
      res.status(401).json({ error: { code: "missing", message: "device_token لازم است ✓§۹" } });
      return;
    }
    const result = verifyDeviceToken(token, secret);
    if (!result.ok) {
      res
        .status(401)
        .json({ error: { code: result.code, message: "device_token معتبر نیست ✗" } });
      return;
    }
    req.device = {
      playerId: result.claims.p,
      issuedAt: result.claims.iat,
      expiresAt: result.claims.exp,
    };
    next();
  };
}

/** همان توکن، ولی برای مسیرهایی که «مالکیتِ player» در body/params هست ⇒ ۴۰۳ نه ۴۰۱ ✓ */
export function requireSamePlayer(targetPlayerId: string): RequestHandler {
  return (req: Request, res: Response, next: NextFunction) => {
    const device = req.device;
    if (device === undefined) {
      res.status(401).json({ error: { code: "missing", message: "device لازم است ✗" } });
      return;
    }
    if (device.playerId !== targetPlayerId) {
      res.status(403).json({
        error: { code: "not_owner", message: "این device به این player bound نیست ✗✓" },
      });
      return;
    }
    next();
  };
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      device?: DeviceContext;
    }
  }
}
