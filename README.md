# NEXUS — Balance Realm

**یک بازی آموزشی ریاضی برای اندروید (۹-۱۵ سال) که در آن «ترازو» موتور یادگیری است** —
پروژه‌ی MVP از دنیای NEXUS، ساخته‌شده با Godot 4 (GDScript) + بک‌اند Node/TypeScript،
کاملاً قابل‌بازی به‌صورت آفلاین.

| | |
|---|---|
| **موتور بازی** | **Godot 4.7.2-stable** (قفل‌شده — نسخه‌های دیگر می‌توانند `.godot/` و تنظیمات import را تغییر بدهند) |
| **پلتفرم هدف** | Android (عمودی 1080×1920، رندرر Mobile، API 24+ → target API 36) |
| **زبان رابط** | فارسی RTL (زیرساخت i18n-ready) |
| **مستندات** | [docs/00-START-HERE.md](docs/00-START-HERE.md) ← از اینجا شروع کن |
| **نقشه‌ی اجرا** | [docs/05-EXECUTION-PLAN.md](docs/05-EXECUTION-PLAN.md) (فاز/تسک + DoD + وضعیت) |
| **قوانین ایجنت** | [AGENTS.md](AGENTS.md) |

## شروع سریع (توسعه‌ی محلی)

```bash
./tools/setup-godot.sh            # Godot 4.7.2 را در .tools/ نصب می‌کند (خارج از گیت)
.tools/godot --path game          # اجرای بازی
python3 tools/validate_levels.py  # بررسی محتوای سطوح (قابل‌حل بودن + قانون طلایی راهنما)
```

تست‌ها (GUT، headless):

```bash
.tools/godot --headless --path game --import
.tools/godot --headless --path game -s addons/gut/gut_cmdln.gd \
  -gut_config_file=res://.gutconfig.json -gexit
```

اگر دانلود Godot در محیط شما ممکن نیست (شبکه‌ی محدود)، همین دستورات را **CI** اجرا می‌کند:
[.github/workflows/ci.yml](.github/workflows/ci.yml). مین‌های CI محدود است، پس
push با سنجش و `android-export.yml` فقط دستی (workflow_dispatch) اجرا می‌شود.

## ساختار ریپو

```
docs/     منبع حقیقت: معماری، Art Bible، اسکیماهای داده، Build Plan، نقشه‌ی اجرا
game/     پروژه‌ی Godot (scenes / scripts / data / tests / addons/gut)
backend/  سرویس Node+TS برای همگام‌سازی مدل بازیکن و رویدادها (فاز ۹)
tools/    اسکریپت‌های توسعه (نصب Godot، اعتبارسنج محتوا) — هیچ وابستگی به موتور بازی ندارد
```

توضیح کامل درخت پوشه‌ها: `docs/01-ARCHITECTURE.md` §2.

## قوانین غیرقابل‌مذاکره‌ی پروژه

1. **هیچ داده‌ی PII** در کلاینت یا بک‌اند ذخیره/ارسال نمی‌شود (کودک هدف است) — `docs/03-DATA-SCHEMAS.md` §۲/§۶.
2. **Aria در MVP زنده به هیچ LLM وصل نمی‌شود**؛ فقط قالب از پیش‌نوشته — `docs/01-ARCHITECTURE.md` §۵.
3. **هیچ عددی از «قرمز تهاجمی» برای خطا استفاده نمی‌شود** و هیچ راهنمایی جواب را لو نمی‌دهد — `docs/02-ART-BIBLE.md` §۲، `docs/03-DATA-SCHEMAS.md` §۴.
4. **بازی باید آفلاین کار کند**؛ شبکه فقط همگام‌سازی دیرهنگام (offline queue) است.
