/**
 * NEXUS — بک‌اند | مهاجرت (تسک ۹.۲ | DoD: «جداول با موفقیت ساخته می‌شوند + اسکریپت migration ساده»)
 * ==================================================================================================
 * ترتیبِ منابع (قصدِ «یک‌منبعه» بودن ✗§۶ را می‌پاید ✓✓):
 *   ۱) `001_baseline` = **همان بایت‌های** `src/db/schema.sql` که از `docs/03` §۶ استخراج شده
 *      (گیتِ `check_backend_schema_contract` در `tools/validate_levels.py` برابریِ این دو را
 *      می‌سنجد ⇒ اگر کسی SQL را دستی ویرایش کند و سند بماند، CI قرمز است ✓✗ نه برعکس ✓)
 *   ۲) `NNN_نام.sql` داخل `src/db/migrations/` ⇒ افزودنی‌ها ✓ (۰۰۲ = snapshotِ مدل بازیکن،
 *      که §۶ جایش را نگذاشته بود ✗✓ توضیح در ADR-063)
 *
 * جدولِ `nexus_migrations` زیرساختِ خودِ ابزار است، نه بخشی از اسکیما؛ **بی‌افزایش به §۶**
 * ساخته می‌شود تا اجرای دوباره بی‌ضرر بماند ✓✓ (DoD ۹.۲: «با موفقیت ساخته می‌شوند» ⇒
 * یعنی «دوباره هم بشود» ✗✓) و تستِ idempotency همین را می‌سنجد ✓
 */
import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { migrationName, splitStatements } from "./sql.js";
import type { SqlExecutor } from "./client.js";

export type MigrationStep = { name: string; sql: string };

const HERE = dirname(fileURLToPath(import.meta.url));

function readIfPresent(path: string): string | null {
  try {
    return readFileSync(path, "utf8");
  } catch {
    return null;
  }
}

/** پیکربندیِ فایل‌ها: baseline از §۶، افزودنی‌ها از `migrations/` ✓ (مرتب، نام‌محور ✓) */
export function readMigrationSteps(): MigrationStep[] {
  const steps: MigrationStep[] = [];
  const baseline = readIfPresent(join(HERE, "schema.sql"));
  if (baseline === null) {
    throw new Error(`migrate: \`schema.sql\` کنارِ این فایل نیست ✗ (${HERE})`);
  }
  steps.push({ name: "001_baseline", sql: baseline });

  const dir = join(HERE, "migrations");
  let files: string[] = [];
  try {
    files = readdirSync(dir).filter((f) => f.endsWith(".sql")).sort();
  } catch {
    files = []; // افزودنی نداشتیم ⇒ فقط baseline ✓ (خطا ندادن اینجا یعنی شکستنِ ۰۰۱ برای ۰۰۲ ✗✓)
  }
  for (const f of files) {
    const sql = readFileSync(join(dir, f), "utf8");
    steps.push({ name: migrationName(f), sql });
  }
  return steps;
}

export type MigrationResult = { applied: string[]; skipped: string[] };

/** اجرای مهاجرت‌های انجام‌نشده ✓ بی‌ضرر در اجرای دوم ✓ (برای تست و برای CI ✓) */
export async function runMigrations(
  exec: SqlExecutor,
  steps: MigrationStep[] = readMigrationSteps(),
  log: (line: string) => void = () => {}
): Promise<MigrationResult> {
  // «ساختن اگر نبود» را خودمان پرس‌وجو می‌کنیم ✗✓ نه با `IF NOT EXISTS`:
  // pg-mem (لایهٔ تستِ ۹.۲) روی مسیرِ «جدول هست»ِ آن خطا می‌دهد و Postgres هم همان را
  // می‌پذیرد ⇒ پرس‌وجو، یک رفتار در هر دو ✓✓ (و پیامدِ دوم: لاگِ تمیزتر ✓)
  const probe = await exec.query<{ table_name: string }>(
    "SELECT table_name FROM information_schema.tables WHERE table_name = 'nexus_migrations'"
  );
  if (probe.rows.length === 0) {
    await exec.query(`CREATE TABLE nexus_migrations (
        name TEXT PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
     )`);
  }
  const { rows } = await exec.query<{ name: string }>(
    "SELECT name FROM nexus_migrations ORDER BY name"
  );
  const appliedSet = new Set(rows.map((r) => String(r.name)));

  const applied: string[] = [];
  const skipped: string[] = [];
  for (const step of steps) {
    if (appliedSet.has(step.name)) {
      skipped.push(step.name);
      log(`· ${step.name} (قبلاً اعمال شده ✓)`);
      continue;
    }
    const statements = splitStatements(step.sql);
    if (statements.length === 0) {
      throw new Error(`migrate: «${step.name}» هیچ statementی ندارد ✗ (فایل خالی = سکوت خطرناک)`);
    }
    for (const stmt of statements) {
      await exec.query(stmt);
    }
    await exec.query("INSERT INTO nexus_migrations (name) VALUES ($1)", [step.name]);
    applied.push(step.name);
    log(`✓ ${step.name} — ${statements.length} فرمان اجرا شد`);
  }
  return { applied, skipped };
}

/* ------------------------------------------------------------------ CLI ---- */
async function main(): Promise<number> {
  const [{ loadConfig }, { dbFromConfig }] = await Promise.all([
    import("../config.js"),
    import("./client.js"),
  ]);
  const config = loadConfig();
  const db = dbFromConfig(config);
  if (db === null) {
    process.stderr.write(
      "migrate: DATABASE_URL تنظیم نشده ✗ (برای اجرای محلی: `docker run --rm -e POSTGRES_PASSWORD=nexus -p 5432:5432 postgres:16` سپس `DATABASE_URL=postgres://postgres:nexus@localhost:5432/postgres npm run migrate`)\n"
    );
    return 2;
  }
  try {
    const res = await runMigrations(db.exec, readMigrationSteps(), (l) => process.stdout.write(l + "\n"));
    process.stdout.write(`\nمهاجرت: ${res.applied.length} اعمال شد، ${res.skipped.length} رد شد ✓\n`);
    return 0;
  } finally {
    await db.exec.end();
  }
}

const invokedDirectly = import.meta.url === pathToFileURL(process.argv[1] ?? "").href;
if (invokedDirectly) {
  main().then(
    (code) => process.exit(code),
    (err: unknown) => {
      process.stderr.write(`migrate ناموفق ✗: ${err instanceof Error ? err.message : String(err)}\n`);
      process.exit(1);
    }
  );
}
