import assert from "node:assert/strict";
import test from "node:test";
import { readMigrationSteps, runMigrations } from "../src/db/migrate.js";
import { splitStatements, stripLineComments } from "../src/db/sql.js";
import { createMemoryDb } from "./helpers/db.js";

test("اسکیمای واقعیِ §۶ روی Postgresِ درحافظه ساخته می‌شود ✓ (DoD ۹.۲)", async () => {
  const h = await createMemoryDb();
  try {
    assert.deepEqual(h.migrations.applied, ["001_baseline", "002_player_model"],
      "هر دو مرحله باید اعمال می‌شد ✗✓");
    const t = await h.exec.query<{ table_name: string }>(
      "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'"
    );
    const names = t.rows.map((r) => r.table_name).sort();
    for (const want of ["players", "skill_ratings", "events", "player_models", "nexus_migrations"]) {
      assert.ok(names.includes(want), `جدول «${want}» ساخته نشد ✗ (یافت: ${names.join(", ")})`);
    }
  } finally {
    await h.close();
  }
});

test("اجرای دوباره بی‌ضرر است ✓ (migration idempotent — همان چیزی که DoDِ «ساخته می‌شوند» می‌خواهد)", async () => {
  const h = await createMemoryDb();
  try {
    const again = await runMigrations(h.exec, readMigrationSteps());
    assert.deepEqual(again.applied, [], "مرتبۀ دوم نباید چیزی بسازد ✗");
    assert.equal(again.skipped.length, 2, "هر دو مرحله «رد» باید ثبت شود ✓");
  } finally {
    await h.close();
  }
});

test("indexهای §۶ هم ساخته می‌شوند ✓ (بدونِ آن‌ها «کوئریِ فاز ۱۰» یعنی جدول‌اسکن ✗)", async () => {
  const h = await createMemoryDb();
  try {
    const sql = readMigrationSteps()[0]?.sql ?? "";
    assert.match(sql, /CREATE INDEX idx_events_player_id/);
    assert.match(sql, /CREATE INDEX idx_events_type/);
  } finally {
    await h.close();
  }
});

test("تقسیم‌کنندۀ SQL: کامنت، '; داخل رشته، و '' escape ✓", () => {
  const sql = [
    "-- یک کامنت با ; که نباید بشکند ✗",
    "INSERT INTO t (a) VALUES ('؛ نه؛ اینجا');",
    "INSERT INTO t (a) VALUES ('با '' کووت');",
    "",
  ].join("\n");
  const parts = splitStatements(sql);
  assert.equal(parts.length, 2, `شکست به ۲ فرمان ✗ (شد ${parts.length})`);
  assert.ok(parts[0]?.includes("'؛ نه؛ اینجا'"), "؛ داخل رشته باید حفظ شود ✗✓");
  assert.ok(parts[1]?.includes("''"), "کوتیشنِ دوتایی SQL نباید بلعیده شود ✗");
  assert.equal(stripLineComments("a -- b\nc").trim(), "a\nc", "کامنت پاک شد ✓");
});

test("`$$` عمداً رد می‌شود ✓ (سکوت/نیمه‌کاره بودن بدتر از خطاست ✓)", () => {
  assert.throws(() => splitStatements("CREATE FUNCTION f() RETURNS void AS $$ BEGIN END $$ LANGUAGE plpgsql;"),
    /پشتیبانی نمی/);
});
