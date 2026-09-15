/**
 * NEXUS — بک‌اند | نقطۀ شروع (تسک ۹.۱)
 * ====================================
 * `npm run dev` همین فایل را با `tsx` بالا می‌آورد ✓ و `npm start` هم همین ✓ (تفاوت فقط
 * `watch` است)؛ `/health` بدونِ Postgres جواب می‌دهد ✓ (DoD ۹.۱) و shutdown مرتب است ✓
 * (exit کدِ ۰ ⇒ «restart loop» در supervisor نه ✗✓)
 */
import { createApp } from "./app.js";
import { loadConfig } from "./config.js";
import { dbFromConfig } from "./db/client.js";

async function main(): Promise<void> {
  const config = loadConfig();
  const db = dbFromConfig(config);
  const app = createApp({ config, db });
  const server = app.listen(config.port, () => {  // سرور خودش node را زنده نگه می‌دارد ✓
    // (باگِ نسخهٔ اول: `main()` بعد از listen برمی‌گشت و `.then(code => process.exit(code))`
    //  سرور را ۰٫۹ ثانیه بعد می‌کشت ✗✗ — چیزی که فقط با «پورتِ در گوش» لو می‌رفت ✓✓)
    process.stdout.write(
      `NEXUS backend ✓ :${config.port} · env=${config.env} · data=${db === null ? "disabled (آفلاین ✓)" : db.kind}\n`
    );
    if (db === null) {
      process.stdout.write("· DATABASE_URL نیست ⇒ /health/ready = 503 و sync/events = 503 ✓§۹\n");
    }
  });

  const shutdown = (signal: string) => {
    process.stdout.write(`\n${signal} ⇒ بستنِ آرام…\n`);
    server.close(() => {
      void (async () => {
        try {
          if (db !== null) await db.exec.end();
        } finally {
          process.exit(0);
        }
      })();
    });
  };
  // فقط سیگنالِ بستن، خروج را مجاز می‌کند ✗✓ (هیچ مسیر «موفق ⇒ exit فوری» نداریم ✓)
  await new Promise<void>((resolve) => {
    process.once("SIGINT", () => {
      shutdown("SIGINT");
      resolve();
    });
    process.once("SIGTERM", () => {
      shutdown("SIGTERM");
      resolve();
    });
  });
}

main().catch((err: unknown) => {
  process.stderr.write(`NEXUS backend ناموفق ✗: ${err instanceof Error ? err.message : String(err)}\n`);
  process.exit(1);
});
