/**
 * NEXUS — بک‌اند | لایهٔ اتصال به داده (تسک ۹.۲/۹.۳)
 * ===================================================
 * یک interface کوچک (`SqlExecutor`) به‌جای کلاس‌بستنِ `pg.Pool` ✗✓ چون:
 *  ۱) تست‌های ۹.۳/۹.۴ روی **`pg-mem`** اجرا می‌شوند (بی‌Docker، بی‌سرور ✓§۹ DoDِ «ارسال ⇒
 *     دریافتِ همان مدل» با همین شدنی است ✓✓) و آن `Pool`ِ خودشان است، نه `pg` ✓
 *  ۲) اگر روزی Supabase/Neon/Pooler بین ما و Postgres بیاید، فقط کارخانه عوض می‌شود ✓
 * همچنین `db` **اختیاری** است: `/health` و `/health/ready` باید بدونِ دیتابیس هم جواب
 * بدهند ✗✓ (DoD ۹.۱) و routeهای داده‌دار ۵۰۳ می‌دهند، نه استثنا/کرش ✓
 */
import { Pool } from "pg";
import type { AppConfig } from "../config.js";

export interface SqlExecutor {
  query<Row = Record<string, unknown>>(
    text: string,
    params?: readonly unknown[]
  ): Promise<{ rows: Row[]; rowCount: number | null }>;
  end(): Promise<void>;
}

export type Db = {
  readonly exec: SqlExecutor;
  /** در لاگِ `/health` چاپ می‌شود تا معلوم باشد داده واقعی است یا شبیه‌سازیِ تست ✓ */
  readonly kind: "postgres" | "memory";
};

export function createPostgresDb(databaseUrl: string): Db {
  const pool = new Pool({ connectionString: databaseUrl, max: 10 });
  return { kind: "postgres", exec: pool };
}

/** از `AppConfig` می‌سازد؛ `null` یعنی «دیتابیس تنظیم نشده» ✗✓ (نه خطا — حالتِ آفلاین ✓§۹) */
export function dbFromConfig(config: AppConfig): Db | null {
  if (config.databaseUrl === null) return null;
  return createPostgresDb(config.databaseUrl);
}

/** JSONB در `pg` با پارامترِ **رشتهٔ JSON** نوشته می‌شود ✗✓ (اگر آبجکت بدهی، `pg` خودش
 *  `JSON.stringify` می‌کند ولی برای ستونی که `::jsonb` لازم دارد وابسته به شکلِ جمله است ⇒
 *  صریح عمل می‌کنیم تا رفتار در `pg` و `pg-mem` یکی باشد ✓✓) */
export type DbKind = "postgres" | "memory";

/** postgres: رشتهٔ JSON (ستون jsonb خودش coerce می‌کند ✓) — pg-mem: خودِ آبجکت ✗✓
 *  (شبیه‌ساز، `JSON.stringify` را «متن» می‌بیند و بعد در `->>` رفتارشان جدا می‌شود؛
 *   فرمتِ درست را `jsonParam` انتخاب می‌کند تا routeها این تفاوت را نبینند ✓✓) */
export function jsonParam(value: unknown, kind: DbKind): unknown {
  return kind === "postgres" ? JSON.stringify(value) : value;
}
