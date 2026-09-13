/**
 * NEXUS — بک‌اند | اعتبارسنجی رویدادها (تسک ۹.۴ | «فقط insert، بدون منطق پیچیده در MVP»)
 * ========================================================================================
 * `docs/03` §۵ حداقلِ رویدادهای MVP را **نام‌برده**: `session_start`, `session_end`,
 * `level_started`, `level_completed`, `hint_shown`, `error_occurred` ⇒ همان شش تا،
 * به‌صورت enum ✓ (رویدادِ ناشناخته = ۴۰۰؛ «بپذیر و بعداً نگاه کنیم» یعنی جدولِ بی‌قاعده ✗✓).
 *
 * صفِ آفلاینِ کلاینت (۹.۶) دسته‌ای می‌فرستد ⇒ `EventsBatchSchema` هم همین‌جاست ✓ و سقف
 * دارد تا یک نصبِ خراب، سرور را با ۱۰۰هزار رویدادِ انباشته نشکند ✓ (۴۱۳ نه ۵۰۰ ✓).
 */
import { z } from "zod";
import { isGamePlayerId } from "../ids.js";
import { LevelId } from "./playerModel.js";

export const EVENT_TYPES = [
  "session_start",
  "session_end",
  "level_started",
  "level_completed",
  "hint_shown",
  "error_occurred",
] as const;

export type EventType = (typeof EVENT_TYPES)[number];

const JsonScalar = z.union([z.number().finite(), z.string().max(200), z.boolean(), z.null()]);

export const EventSchema = z
  .object({
    event_type: z.enum(EVENT_TYPES),
    player_id: z.string().refine(isGamePlayerId, {
      message: "قالبِ player_id (§۲): p_ + ۸ هگزِ کوچک ✓",
    }),
    level_id: LevelId.nullish(),
    timestamp: z.string().datetime({ offset: true }),
    payload: z.record(JsonScalar).optional(),
  })
  .strict();

export type AnalyticsEvent = z.infer<typeof EventSchema>;

export const MAX_EVENTS_PER_REQUEST = 200;

export const EventsBatchSchema = z.object({
  events: z.array(EventSchema).min(1).max(MAX_EVENTS_PER_REQUEST),
}).strict();

/** پیام‌های خطا بدونِ مقدارِ داده ✓§۹ (همان قاعدهٔ `playerModel`) */
export function describeEventIssues(error: z.ZodError): Array<{ path: string; message: string }> {
  return error.issues.slice(0, 12).map((i) => ({
    path: i.path.length > 0 ? i.path.join(".") : "(root)",
    message: i.message,
  }));
}
