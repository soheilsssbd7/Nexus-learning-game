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
| **سایتِ محصول (Pages)** | https://soheilsssbd7.github.io/Nexus-learning-game/ ✓ (`site/**` با `tools/build_site.py` تولید می‌شود ✗✓ و `check_site()` می‌پاید که با مخزن هم‌زمان باشد ✓) |
| **نسخه** | `VERSION` (تنها منبع ✓ → `CHANGELOG.md` → footerِ سایت → `version/name` در build اندروید ✓✓ یک عدد، چهار مصرف ✓) |

---

## 🌐 محصول را از کجا ببینید (سه مسیر، سه سطحِ واقعیت ✓)
۱. **سایت/صفحۀ محصول (GitHub Pages)** ✓ → آدرسِ بالا. خانه (fa + en)، راهنمای والدین، سیاستِ حریم
   خصوصی (از همان `docs/privacy-policy-*.md` رندر می‌شود ✗✓ تک‌منبع)، پشتیبانی، بازخورد، وضعیتِ نسخۀ وب،
   و 404 ✓✗ اعدادِ روی صفحه (تعداد تست/دروازه/سطح) **محاسبه می‌شوند**، نه تایپ ✓✓
   - انتشار: Pagesِ این ریپو روی «Deploy from a branch → root» است ✓✗ پس **push روی این برانچ = انتشار** ✓
     (اگر منبع را به «GitHub Actions» عوض کنید، `pages.yml` همان سایت را build و deploy می‌کند ✓ و هیچ‌کدام
     لازم نیست که دستی چیزی بسازید ✓)
   - اگر Pages خطای «private repo / plan» داد ✗✓ مخزن خصوصیِ free فقط با public یا Pro سرو می‌شود ⇒
     تصمیمش با مالک است (من visibility را عوض نمی‌کنم ✗)
۲. **اجرای بازی (Godot)** ✓ → Godot 4.7.2 را نصب کنید، پوشۀ `game/` را باز کنید و ▶ ✓ بدونِ هیچ export ✓
۳. **بستۀ اندروید** ⚙ → workflowِ `Android export` (دستی ✓) `.apk/.aab` می‌سازد و `apkanalyzer` را روی
   **بستۀ واقعی** اجرا می‌کند ✓✗ نصبِ انسانی روی گوشی و `docs/smoke-checklist.md` §۲/§۳ هنوز ⏳ است ✓

**و آنچه «آمادهِ انتشار» شدن را نگه می‌دارد ⚠ (نه کمبودِ پنهان، اعلام‌شده ✓):** اجرای واقعیِ بستۀ اندروید +
نصب روی گوشی ارزان (§۱۰.۴ = L3 ✓✗ بدون آن اسکرین‌شاتِ واقعی هم ممکن نیست §۱۲.۱) · تأییدِ `package/unique_name`
پیش از اولین آپلود ✓§ADR-066 (بعدش عوض‌شدنی نیست ✗✗) · آدرسِ انسانیِ پشتیبانی/«درخواست حذفِ داده» §۱۲.۴
(`⚠ <host>` در سیاست و سایت ✓ و گیت، بی‌علامت‌بودنش را قرمز می‌کند ✓) · قیمت §۱۲.۶ ✓


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
