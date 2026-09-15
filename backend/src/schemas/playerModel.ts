/**
 * NEXUS — بک‌اند | اعتبارسنجی مدل بازیکن (تسک ۹.۳)
 * ================================================
 * **قرارداد = `docs/03` §۲** ✗✓ (گیتِ `check_backend_schema_contract` در `tools/` می‌سنجد که
 * هر کلیدِ سطح‌اولِ آن JSON همین‌جا وجود دارد ⇒ «zod که نصفه نوشته شده» نمی‌ماند ✓).
 *
 * سه تصمیمِ امنیتی/کودک‌محور (§۹ + ADR-009/010):
 *  • `.strict()` روی آبجکت‌ها ⇒ فیلدِ ناشناخته = ۴۰۰ ✓ (فیلدِ PIIِ قاچاقی مثل `email`
 *    باید در مرز رد شود، نه «ذخیره و بعداً نگاهش کنیم» ✗✓)
 *  • سقفِ اندازه برای هر آرایه ⇒ بدنهٔ بی‌نهایت از یک نصبِ بازی، دیتابیس کودک‌محور را
 *    بزرگ نمی‌کند ✓ (و `aria_transcript_log` عمداً **حذف نمی‌شود**؛ اگر از سقف رد شد،
 *    درخواست رد می‌شود تا «سکوتِ داده‌بر» نداشته باشیم ✓§۲ شفافیت)
 *  • هیچ مقدارِ ارسالی در پیامِ خطا چاپ نمی‌شود ✓ (path + قانون، نه داده ✓)
 */
import { z } from "zod";
import { isGamePlayerId } from "../ids.js";

const CURRENT_SCHEMA_VERSION = 1;

export const LevelId = z
  .string()
  .regex(/^tier[1-5]_level_[0-9]{2}$/, "قالبِ level_id: tier{1..5}_level_{NN} ✓§۱");

export const SkillRating = z.object({
  elo: z.number().int().min(600).max(2600),
  confidence: z.number().min(0).max(1),
  attempts: z.number().int().min(0).max(1_000_000),
  last_seen: z.string().date(),
}).strict();

export const ErrorPattern = z.object({
  type: z.string().min(1).max(64),
  count: z.number().int().min(0).max(1_000_000),
}).strict();

export const TranscriptEntry = z.object({
  timestamp: z.string().datetime({ offset: true }),
  hint_id: z.string().min(1).max(96),
  level_id: LevelId,
}).strict();

export const PlayerModelSchema = z
  .object({
    schema_version: z.literal(CURRENT_SCHEMA_VERSION),
    player_id: z.string().refine(isGamePlayerId, {
      message: "قالبِ player_id (§۲): p_ + ۸ هگزِ کوچک ✓",
    }),
    created_at: z.string().datetime({ offset: true }),
    display_name: z.string().min(1).max(40),
    skills: z.record(SkillRating).refine((v) => Object.keys(v).length <= 64, {
      message: "حداکثر ۶۴ مهارت در یک مدل ✓§۷",
    }),
    error_patterns: z.array(ErrorPattern).max(64),
    levels_completed: z.array(LevelId).max(64),
    current_level: LevelId.nullish(),
    hint_usage_rate: z.number().min(0).max(1),
    avg_time_to_solve_sec: z.number().finite().min(0).max(10_000),
    total_playtime_sec: z.number().int().min(0).max(1_000_000_000),
    aria_transcript_log: z.array(TranscriptEntry).max(400),
  })
  .strict();

export type PlayerModel = z.infer<typeof PlayerModelSchema>;

/** فقط خطاها را برمی‌گرداند — بدونِ مقدارِ داده ✓§۹ (لاگِ عمومی ≠ آینهٔ دادهٔ کودک ✗) */
export function describeIssues(error: z.ZodError): Array<{ path: string; message: string }> {
  return error.issues.map((i) => ({
    path: i.path.length > 0 ? i.path.join(".") : "(root)",
    message: i.message,
  }));
}
