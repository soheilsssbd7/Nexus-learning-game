/**
 * NEXUS — بک‌اند | صدورِ توکنِ دستگاه (تسک ۹.۵)
 * =============================================
 * تنها کاری که می‌کند: می‌پذیرد که «این نصب، همان `player_id` است» و یک توکنِ HMAC می‌دهد ✓
 *  • هیچ موجودیتی برای «کاربر» نمی‌سازد ✓§۹ (نه ایمیل، نه نام واقعی، نه موقعیت ✗)
 *  • بی‌نرخ‌محدودیت است و این **ثبت** شده است، نه فراموشی ✗✓: در MVP که بازیکنِ دیگری برای
 *    سرور وجود ندارد، minting بی‌هزینه است؛ فاز ۱۱ (سخت‌سازی/انتشار) باید `rate-limit` +
 *    «یک device = n توکن» را اضافه کند ✓ (ADR-063 پیامدها)
 */
import { Router } from "express";
import { z } from "zod";
import { isGamePlayerId } from "../ids.js";
import { DEVICE_TOKEN_TTL_DAYS, issueDeviceToken } from "../middleware/deviceAuth.js";

const Body = z.object({ player_id: z.string() }).strict();

export function deviceRouter(secret: string): Router {
  const router = Router();

  router.post("/api/device", (req, res) => {
    const parsed = Body.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: { code: "bad_body", message: "`player_id` لازم است ✓" } });
      return;
    }
    const playerId = parsed.data.player_id;
    if (!isGamePlayerId(playerId)) {
      res.status(422).json({
        error: { code: "bad_player_id", message: "قالبِ player_id (§۲): p_ + ۸ هگز ✗" },
      });
      return;
    }
    const token = issueDeviceToken(playerId, secret);
    res.status(201).json({
      device_token: token,
      expires_in_days: DEVICE_TOKEN_TTL_DAYS,
      scope: "player_model",
    });
  });

  return router;
}
