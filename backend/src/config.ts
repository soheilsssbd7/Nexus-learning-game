/**
 * NEXUS — بک‌اند | تسک ۹.۱ (docs/04 §۹)
 * =====================================
 * تمام تنظیمات از محیط می‌آیند و **با `zod` اعتبارسنجی می‌شوند** ✗✓ (قاعدهٔ فاز ۹: هیچ
 * مقدارِ خامِ محیطی وارد منطق نمی‌شود — یک env غلط باید در `boot` بترکد، نه در اولین
 * درخواستِ کاربر کودک ✓).
 *
 * نکتهٔ عمدی: `databaseUrl` می‌تواند خالی باشد ⇒ سرور بالا می‌آید و `/health` جواب می‌دهد ✓
 * (DoD ۹.۱ «`npm run dev` + `GET /health` = 200» بدونِ Postgres هم باید پاس شود ✗✓؛
 * endpointهایی که به DB نیاز دارند در نبودِ اتصال **۵۰۳** می‌دهند، نه کرش ✓§۹).
 */
import { z } from "zod";

const EnvSchema = z.object({
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  /** `postgres://…` — اگر نباشد، لایهٔ داده «غیرفعال» گزارش می‌شود (نه کرش) ✓ */
  DATABASE_URL: z.string().min(1).optional(),
  /** رازِ امضای `device_token` (۹.۵). در dev مقدارِ پیش‌فرض دارد تا راه‌اندازی آسان باشد ✓
   *  در production الزامی است ✗✓ (کلیدِ پیش‌فرض = نبودِ احراز هویت واقعی) */
  DEVICE_TOKEN_SECRET: z.string().min(1).default("nexus-dev-only-insecure-secret"),
  /** حالتِ اجرا؛ فقط همین سه مقدار مجاز (جلوگیری از `NODE_ENV=producion` تایپویی ✗✓) */
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  /** سقفِ حجمِ body: مدل بازیکن یک JSON کوچک است ✗§۳ (هیچ transcript خامی به بک‌اند نمی‌رود ✓) */
  MAX_BODY_BYTES: z.coerce.number().int().min(1024).max(2 * 1024 * 1024).default(256 * 1024),
  /** اصلِ حریم کودکان §۹/ADR-010: همگام‌سازی پیش‌فرض **خاموش** است ⇒ اگر تنظیم نبود،
   *  سرور فقط رویدادهای بی‌نام‌ونشان را می‌پذیرد و هیچ‌چیز را «اجباری» نمی‌کند ✓ */
  SYNC_REQUIRED: z
    .enum(["true", "false"])
    .default("false")
    .transform((v) => v === "true"),
});

export type AppConfig = {
  port: number;
  databaseUrl: string | null;
  deviceTokenSecret: string;
  env: "development" | "test" | "production";
  maxBodyBytes: number;
  syncRequired: boolean;
};

/** فقط برای تست/جای‌گرفتنِ صریح؛ مصرف‌کننده‌ها `loadConfig()` را صدا می‌زنند ✓ (یک منبع ✓) */
export function loadConfig(raw: NodeJS.ProcessEnv = process.env): AppConfig {
  const parsed = EnvSchema.safeParse(raw);
  if (!parsed.success) {
    const flat = parsed.error.issues
      .map((i) => `  • ${i.path.join(".") || "(root)"}: ${i.message}`)
      .join("\n");
    // عمداً value چاپ نمی‌شود: `DATABASE_URL` پسورد دارد ✗✓ (لاگِ CI عمومی = نشتی ✓)
    throw new Error(`NEXUS backend: محیط نامعتبر است —\n${flat}`);
  }
  const e = parsed.data;
  if (e.NODE_ENV === "production" && e.DEVICE_TOKEN_SECRET === "nexus-dev-only-insecure-secret") {
    throw new Error(
      "NEXUS backend: در production نمی‌توان با کلیدِ پیش‌فرضِ dev کار کرد ✗✓ (DEVICE_TOKEN_SECRET بگذارید)"
    );
  }
  return {
    port: e.PORT,
    databaseUrl: e.DATABASE_URL ?? null,
    deviceTokenSecret: e.DEVICE_TOKEN_SECRET,
    env: e.NODE_ENV,
    maxBodyBytes: e.MAX_BODY_BYTES,
    syncRequired: e.SYNC_REQUIRED,
  };
}
