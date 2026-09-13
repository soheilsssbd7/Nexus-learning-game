/**
 * NEXUS — build asset ✓ | `tsc` فایل‌های `.sql` را کپی نمی‌کند ✗✓ و اسکیما برای ما
 * **داده** است نه کد ⇒ `npm run build` بی‌این، خروجیِ بدونِ schema می‌ساخت که در
 * production موقعِ migrate می‌ترکید ✓ (این اسکریپتِ ۸‌خطی همان شکاف را می‌بندد ✓✓)
 */
import { cpSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const dest = join(root, "dist", "src", "db");
mkdirSync(join(dest, "migrations"), { recursive: true });
cpSync(join(root, "src", "db", "schema.sql"), join(dest, "schema.sql"));
for (const f of ["002_player_model.sql"]) {
  cpSync(join(root, "src", "db", "migrations", f), join(dest, "migrations", f));
}
process.stdout.write(`copy-sql ✓ → ${dest}\n`);
