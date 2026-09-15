# NEXUS — بک‌اند (فاز ۹)

سرویسِ همگام‌سازی و آنالیتیکس. عمداً **باریک** است: هیچ منطقِ بازی اینجا نیست ✓ (`docs/01` §۳ —
مدلِ مهارت/سختی در `DifficultyEngine.gd` است و بک‌اند فقط می‌نویسد و می‌خواند ✓).

## اجرا

| کار | فرمان |
|---|---|
| توسعه (DoD ۹.۱) | `npm run dev` → `http://localhost:3000/health` (بی‌Postgres هم ۲۰۰ می‌دهد ✓) |
| تست‌ها | `npm test` — `node:test` + `supertest` + **`pg-mem`** ✓ (بی‌Docker، بی‌سرور ✓) |
| ساخت | `npm run build` (`tsc` + `scripts/copy-sql.mjs` ⇒ SQL هم به `dist/` می‌رود ✓) |
| مهاجرت | `npm run migrate` با `DATABASE_URL=postgres://…` ✓ |
| از ریشهٔ ریپو | `npm --prefix backend test` (`AGENTS.md` همین را قول داده ✓) |

Postgres محلی (اختیاری، برای دیدنِ اسکیما روی موتور واقعی):
```bash
docker run --rm -e POSTGRES_PASSWORD=nexus -p 5432:5432 postgres:16
DATABASE_URL=postgres://postgres:nexus@localhost:5432/postgres npm run migrate
```

## مسیرها

| مسیر | تسک | دروازه |
|---|---|---|
| `GET /health` · `GET /health/ready` | ۹.۱ | بی‌احراز ✓ (readiness فقط `SELECT 1`) |
| `POST /api/device` | ۹.۵ | بی‌توکن (mint می‌کند) — نرخ‌محدودیت: فاز ۱۱ ✓ |
| `POST /api/player-model/:id/sync` · `GET /api/player-model/:id` | ۹.۳ | توکن + **همان** `player_id` (۴۰۳ اگر نه) |
| `POST /api/events` | ۹.۴ | توکن؛ رویدادِ playerِ دیگر ⇒ ۴۰۳ |

## سه تصمیمی که بدونِ آن‌ها اینجا ناکارآمد بود (ADR-063)

1. **اسکیما دست‌نخورده + افزودنی جدا.** `docs/03` §۶ سه جدول دارد؛ §۲ «مدل بازیکن» چیزهایی
   دارد که در آن سه جدول نمی‌گنجند ⇒ `src/db/migrations/002_player_model.sql` **افزوده** می‌شود
   و `src/db/schema.sql` بایت‌به‌بایت همان §۶ است ✓ (گیتِ `check_backend_contract` می‌پاید ✓).
2. **`player_id` رشته‌ای ↔ ستونِ `UUID`.** قراردادِ بازی `p_193f2a7e` است و اسکیما `UUID`
   می‌خواهد ⇒ نگاشتِ قطعیِ **UUIDv5** (`src/ids.ts`)، بی‌جدولِ نگاشت و بی‌هیچ PII ✓
3. **توکنِ stateless.** هیچ «جدول کاربر» نداریم ✗§۹؛ `device_token` = HMAC روی
   `player_id + iat + exp` ✓ و منقضی می‌شود (۴۰۰ روز) ⇒ نه is‑active flag، نه ایمیل، نه رمز ✓

## حریم (کودک‌محور — `docs/00` §۹ / ADR-009/010)

- هیچ ستونی برای ایمیل/نام واقعی/موقعیت وجود ندارد ✓§۶
- پاسخ‌های خطا **کد** می‌دهند، نه داده: مقدارِ ارسالیِ کودک در لاگِ CI/سرور چاپ نمی‌شود ✓
  (تست دارد: `email` در بدنه ⇒ ۴۲۲، و رشته‌ی `kid@example.com` در پاسخ نیست ✓✓)
- `.strict()` ⇒ فیلدِ ناشناخته = رد، نه «ذخیرهٔ بی‌صدا» ✓
- همگام‌سازی **اختیاری** است: `SYNC_REQUIRED=false` پیش‌فرض ✓ و نبودِ دیتابیس = ۵۰۳، نه کرش ✓
  (بازی باید آفلاین بازی شود ✗§۹ — صفِ آفلاین سمتِ Godot است: تسک ۹.۶)
