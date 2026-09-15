/**
 * NEXUS — بک‌اند | تقسیمِ SQL (تسک ۹.۲)
 * =====================================
 * چرا خودمان split می‌کنیم و `node-postgres` را درگیر نمی‌کنیم؟ چون `pg` یک statement در
 * هر `query()` می‌پذیرد ✗✓ و فایلِ اسکیما چندِstatementی است؛ و مهم‌تر: همین تابع در تست
 * روی `pg-mem` هم مصرف می‌شود ⇒ یک پیاده، دو محیط ✓ (تستِ واحدش، مرزِ «کامنت/؛» را می‌پاید ✓✓).
 *
 * محدودیتِ مستند: پیکربندی `$$ … $$` (توابع PL/pgSQL) پشتیبانی نمی‌شود ⇒ اگر اسکیما روزی
 * تابع/تریگر گرفت، این تابع باید tokenizer بشود ✗✓ و فعلاً با خطای صریح می‌گوید نه سکوت ✓
 */

/** کامنت‌های `--` را پاک می‌کند؛ رشته‌های `'…'` داخل خط محترم می‌مانند ✓ */
export function stripLineComments(sql: string): string {
  const out: string[] = [];
  for (const line of sql.split("\n")) {
    let inString = false;
    let cut = -1;
    for (let i = 0; i < line.length; i += 1) {
      const ch = line[i];
      if (ch === "'") {
        // '' escape در SQL ⇒ جفتِ کووت معنای «کاراکتر» دارد، نه پایانِ رشته ✓
        if (inString && line[i + 1] === "'") {
          i += 1;
          continue;
        }
        inString = !inString;
      } else if (!inString && ch === "-" && line[i + 1] === "-") {
        cut = i;
        break;
      }
    }
    // `trimEnd` عمداً: فاصلۀ قبلِ `--` معنایی ندارد و اگر بماند، «خطِ خالیِ پر از فاصله»
    // در splitStatement بعدی به شکلِ عجیب دیده می‌شود ✗✓ (تستِ `stripLineComments` همین را گرفت)
    out.push((cut >= 0 ? line.slice(0, cut) : line).trimEnd());
  }
  return out.join("\n");
}

export function splitStatements(sql: string): string[] {
  if (/\$\$/.test(sql)) {
    throw new Error("splitStatements: `$$` پشتیبانی نمی‌شود ✗ (لازم است tokenizer واقعی شد ✓)");
  }
  const body = stripLineComments(sql);
  const statements: string[] = [];
  let current = "";
  let inString = false;
  for (let i = 0; i < body.length; i += 1) {
    const ch = body[i];
    if (ch === "'") {
      if (inString && body[i + 1] === "'") {
        current += "''";
        i += 1;
        continue;
      }
      inString = !inString;
    }
    if (ch === ";" && !inString) {
      const trimmed = current.trim();
      if (trimmed.length > 0) statements.push(trimmed);
      current = "";
      continue;
    }
    current += ch;
  }
  const tail = current.trim();
  if (tail.length > 0) statements.push(tail);
  return statements;
}

/** نامِ فایلِ مهاجرت ⇒ شناسهٔ ثبت‌شده در `nexus_migrations` ✓ (قابل‌مهاجرتِ مجدد نبودن ✓) */
export function migrationName(fileName: string): string {
  return fileName.replace(/\.sql$/i, "");
}
