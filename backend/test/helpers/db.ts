/**
 * NEXUS — بک‌اند | کمکِ آزمون: Postgresِ درحافظه
 * ==============================================
 * DoDِ ۹.۲ می‌گوید «جداول در یک Postgres محلی/Docker ساخته می‌شوند» ✗ و DoDِ ۹.۳/۹.۴
 * «ارسال ⇒ دریافت ⇒ دیدنِ ردیف در جدول» ✗✓ در CIِ این ریپو Docker ندارد؛ `pg-mem`
 * **همان فایل‌های SQL واقعی** را اجرا می‌کند ✓✗ پس نه SQLite‌ای که SQL ما را نمی‌فهمد،
 * نه mockِ دروغگو ✓✓ (اسکیمای واقعی، SQLِ واقعی، فقط موتورِ جایگزین ✓).
 */
import { newDb } from "pg-mem";
import type { Db, SqlExecutor } from "../../src/db/client.js";
import { readMigrationSteps, runMigrations, type MigrationResult } from "../../src/db/migrate.js";
import { loadConfig, type AppConfig } from "../../src/config.js";

export type MemoryDb = {
  db: Db;
  exec: SqlExecutor;
  migrations: MigrationResult;
  close(): Promise<void>;
};

export async function createMemoryDb(): Promise<MemoryDb> {
  const mem = newDb();
  const { Pool } = mem.adapters.createPg();
  const pool = new Pool() as unknown as SqlExecutor;
  const migrations = await runMigrations(pool, readMigrationSteps());
  return {
    db: { kind: "memory", exec: pool },
    exec: pool,
    migrations,
    close: async () => pool.end(),
  };
}

/** configِ آزمون: صریح، بی‌envِ میزبان ✓ (وکلیدِ ثابت ⇒ توکن‌ها بین تست‌ها قابل‌تولیدند ✓) */
export function testConfig(over: Partial<NodeJS.ProcessEnv> = {}): AppConfig {
  return loadConfig({
    NODE_ENV: "test",
    DEVICE_TOKEN_SECRET: "nexus-test-secret",
    ...over,
  });
}
