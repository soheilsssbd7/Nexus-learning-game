# NEXUS — دفتر تصمیمات مهندسی (ADR Ledger)

هر انحراف از `docs/00..04`، هر «حدس منطقی» که `00-START-HERE.md` نوشته‌ی آن را الزامی کرده،
و هر تصمیمی که یک سند دیگر را مقید می‌کند **فقط در این فایل** ثبت می‌شود.
قاعده: بدون ADR، تغییر رفتار/ساختار/اسکیما merge نمی‌شود. وضعیت: `تأییدمنتظر=مالک` یعنی
من بر اساس منطقی‌ترین فرض جلو رفته‌ام و تو باید در ریویو تأیید/رد کنی.

| ADR | عنوان | وضعیت |
|---|---|---|
| 001 | قفل نسخه‌ی موتور: Godot 4.7.2-stable | قطعی |
| 002 | انحراف از workflow دو-شاخه‌ای (PR/تسک) | قطعی (مجبور به محیط) |
| 003 | ignore کردن `*.import` طبق سند `04` | قطعی |
| 004 | CI: دو workflow؛ امضای release در CI، بدون رمز در ریپو | قطعی |
| 005 | `player_id` غیر-UUID → DDL بک‌اند اصلاح شد + `device_tokens` | تأییدمنتظر=مالک |
| 006 | گسترش اسکیمای سطح: `solution_spec` + گرامر trigger | تأییدمنتظر=مالک |
| 007 | خط تولید هنر: SVG/پروسیجرال به‌جای PNG حجیم | قطعی |
| 008 | صدای placeholder پروسیجرال + autoload `AudioManager` | قطعی |
| 009 | پیکربندی اندروید: compile/target 36، min 24، مجوزها | قطعی (سیاست ۲۰۲۶) |
| 010 | آنالیتیکس داخلی، بدون SDK شخص ثالث، batch + حذف پس از sync | قطعی |
| 011 | RTL/i18n: تم + `layout_direction` + CSV translation | قطعی |
| 012 | پروفایل: MVP تک‌پروفایل با هک چندپروفایلی | تأییدمنتظر=مالک |
| 013 | استراتژی تست بدون Godot محلی (CI مرجع + تزریق input) | قطعی |
| 014 | بک‌اند: Postgres + pg-mem برای تست؛ استقرار بعداً | تأییدمنتظر=مالک |
| 015 | ریاضیات مدل بازیکن (confidence، EMA، وزن‌دهی راهنما) | تأییدمنتظر=مالک |
| 016 | رجیستری autoloadها (+`FeatureFlags`, `Log`, `AudioManager`) | قطعی |
| 017 | تایپوگرافی: Vazirmatn (OFL) + `NexusTheme.tres` | قطعی |
| 018 | افزودن `game/themes/`، `tools/`، شماره‌ی اسناد ۰۵..۰۸ | قطعی |
| 019 | امنیت/نگهداری/حذف save | قطعی |
| 020 | parent-gate و شفافیت transcript و لینک بازخورد | قطعی |
| 021 | بازسازی GDD در `docs/07` (چون GDD اصلی در ریپو نبود) | تأییدمنتظر=مالک |

---

### ADR-001 — قفل نسخه‌ی Godot
**زمینه:** `00-START-HERE.md` می‌گوید آخرین 4.x پایدار (حداقل 4.6) و نسخه را در README قفل کن؛
در زمان اجرا (سپتامبر ۲۰۲۶) آخرین stable روی GitHub **4.7.2-stable** (۱۸ اوت ۲۰۲۶) است.
**تصمیم:** همه‌جا (README، CI، `tools/setup-godot.sh`، `config/features`) روی `4.7.2-stable` قفل می‌شود.
**پیامد:** اگر نسخه‌ی دیگری باز کند، ممکن است `.godot/` و `*.uid` را بازنویسی کند؛ به‌همین‌دلیل
`.godot/` ignore و فایل‌های `.uid` commit می‌شوند. تغییر نسخه = ADR تازه + اجرای کامل CI.

### ADR-002 — workflow تک‌شاخه‌ای
**زمینه:** `01` §۴ «هر تسک = یک PR به `develop`»؛ اما محیط کاری فعلی روی یک شاخه‌ی ثابت
(`arena/01a07efb-nexus-learning-game`) قفل است و ساخت/فشار شاخه‌ی دیگر مجاز نیست.
**تصمیم:** هر تسک = یک commit با پیشوند `[P<phase>.<task>]`؛ پایان هر فاز = یک PR به `main` با
توضیح DoD و لینک run سبز CI. `develop` فعلاً ساخته نمی‌شود (هنگام ورود تیم، فقط یک `git branch`).
**پیامد:** تاریخچه‌ی reviewable حفظ می‌شود؛ ریویو در سطح فاز به‌جای تسک.

### ADR-003 — `*.import` در گیت نمی‌آید
**زمینه:** تسک ۰.۱ خواسته `*.import` را ignore کنیم (Godot 4 رسماً commit کردنش را توصیه می‌کند).
**تصمیم:** طبق سند ignore شد. تمام تنظیمات import که واقعاً مهم‌اند به سطح **project** منتقل شدند
(`textures/vram_compression/import_etc2_astc=true` برای موبایل، stretch، renderer) تا رفتار بین
ماشین‌ها یکسان بماند؛ هر تنظیمِ import-خاصِ لازم در کد/تم انجام می‌شود (نه در فایل `.import`).
**پیامد:** diff تمیز؛ ریسک = اگر روزی «compress mode» خاصِ تکسچری لازم شد، باید override در کد
یا استثنای گیت‌ایگنور ثبت کنیم (با ADR).

### ADR-004 — CI و build اندروید
**زمینه:** `01` §۲ فقط `ci.yml` دارد؛ اما DoD فاز ۱۰ «APK امضاشده روی دستگاه واقعی» است و در این
سندباکس JDK/Android SDK قابل نصب نیست. ریپو خصوصی است → دقیقه‌ی CI محدود.
**تصمیم:** `ci.yml` (import + GUT + gdlint + validate_levels) روی push/PR به `main`/`develop` +
`workflow_dispatch`، با کش باینری و `concurrency`. `android-export.yml` (فاز ۱۰) فقط دستی: نصب
JDK 17 + Android SDK (platform 36, build-tools 36)، دانلود `export_templates.tpz` (۱.۳GB)، export
`--export-release "Android" ... --keystore $KS --keystore-pass "$KS_PASS"`، آپلود AAB/APK به artifact.
`export_presets.cfg` commit می‌شود ولی **فیلدهای رمز خالی**؛ رمزها فقط در GitHub Secrets.
**پیامد:** هیچ رازی در ریپو؛ build واقعی از artifact؛ مصرف CI کنترل‌شده.

### ADR-005 — شناسه‌ی بازیکن و احراز هویت دستگاه
**زمینه:** `03` §۲ نمونه `p_193f2a7e` (غیر-UUID) در برابر `03` §۶ `player_id UUID PRIMARY KEY` → INSERT می‌شکند؛
همچنین `deviceAuth` (تسک ۹.۵) هیچ جدولی برای ذخیره‌ی توکن ندارد.
**تصمیم:** `players.player_id TEXT PRIMARY KEY` با قاعده‌ی `p_<12 hex>` (کلاینت از `UUID.v4()`
برش می‌زند)؛ جدول `device_tokens(device_token TEXT PK, player_id TEXT, created_at, last_seen_at)`؛
هر درخواست با `X-Nexus-Device-Token`؛ توکن نامعتبر = 401. هیچ ستون PII اضافه نمی‌شود.
**پیامد:** DDL بک‌اند با نمونه‌ی سند فرق دارد (این فایل، مرجع اصلاح است)؛ در `backend/src/db/schema.sql`
مستند + مهاجرت شماره‌دار.

### ADR-006 — گسترش اسکیمای سطح (قابل‌طبقه‌بندی‌کردن خطا)
**زمینه:** تسک ۴.۲ خطاها را با «ساختار مورد انتظار» مقایسه می‌کند ولی §1 هیچ expected solution ندارد؛
تسک ۴.۳ آستانه‌ی idle را hardcode می‌کند درحالی‌که trigger داده‌محور است.
**تصمیم:** دو افزوده به §1:
```jsonc
"solution_spec": {                       // اختیاری ولی لازم برای Tier ≥ 2
  "intended": { "right_orbs": [5, 2, 1], "operations": ["add", "add", "add"] },
  "wrong_ops": { "remove_from_left": [5] } // حرکتی که بازیکن «نباید» انجام دهد/نمونه‌ی اشتباه متعارف
},
"tolerance_strategy": "exact" | "range",   // فقط برای خوانایی؛ tolerance عدد مرجع است
```
`HintTimingSystem` رشته‌ی trigger را پارس می‌کند: `idle_<n>s`، `fail_<n>x`، `help_requested`،
`first_wrong_attempt`؛ مقدار پیش‌فرض ۴۵s فقط وقتی سطح هیچ تریگری ندارد.
**پیامد:** `tools/validate_levels.py` این‌ها را چک می‌کند؛ `LevelData.gd` فیلدها را اختیاری می‌گیرد
(سطح بدون `solution_spec` → ErrorClassifier فقط `computation_error`/`idle` می‌دهد، نه ادعای دروغ).

### ADR-007 — خط تولید هنر: برداری/پروسیجرال
**زمینه:** `02` §۱ سبک «Flat Vector + Soft Gradient»، §۸ ترجیح SVG، و A9 (۴۸ ترکیب آواتار).
همچنین سقف حجم ورک‌اسپیس.
**تصمیم:** هنر بازی از این جنس باشد: (الف) SVG برای UI/آیکون‌ها/پس‌زمینه‌های ساده؛
(ب) `Polygon2D`/`CustomDraw2D` + shader برای Aria (ایکوساهدرون + هسته‌ی نورانیِ رنگ‌تغییرکننده) و
ذرات؛ (ج) آواتار = ۳ لایه (پوست/مو/لباس) با `CanvasItem.material` و palette-swap → ۶ تُن × ۸ مو ×
رنگ آزاد بدون هیچ اسپرایت اضافی؛ (د) تصاویر AI فقط مرجع طراحی در `/tmp` (commit نمی‌شوند).
**پیامد:** حجم ریپو پایین، مقیاس‌پذیر روی DPIهای موبایل، بدون آتی‌فکت؛ هزینه = کد رندر بیشتر،
و نیاز به ریویو چشمی human در پایان فاز ۸.

### ADR-008 — صدا
**زمینه:** تسک ۷.۶ لیست SFX/موسیقی را می‌خواهد ولی هیچ منبع صوتی در سندباکس قابل دانلود نیست
(archive.org/freesound مسدود). DoD: «نسخه‌ی placeholder قابل‌شنیدن».
**تصمیم:** `tools/gen_audio_placeholder.py` فایل‌های WAV کوتاه (mono 22.05kHz، ۱۶bit، بدون وابستگی)
تولید می‌کند: SFX برداشتن/رهاکردن/کج‌شدن/موفقیت/دروازه و یک پَد حلقه‌ای Hub. همه از یک
`AudioManager` autoload با ۲ bus (`Music`, `SFX`) و ذخیره‌ی سطح صدا در `user://settings.cfg`.
موسیقی نهایی = دارایی سفارش‌داده‌شده توسط مالک، جایگزینی فقط در فایل (بدون تغییر کد).
**پیامد:** بازی از فاز ۶ صدا دارد؛ حجم placeholder ≤ ۱MB؛ هیچ فایل صوتی حقوق-سردرگم در ریپو نیست.

### ADR-009 — پیکربندی اندروید
**زمینه:** تسک ۱۰.۴ فقط «minSdk 24+» را گفته. Google Play: از ۳۱ اوت ۲۰۲۶ هر اپ/آپدیت جدید باید
**target API 36** (اندروید ۱۶) داشته باشد (تمدید قابل‌درخواست تا ۱ نوامبر)؛ سیاست Families: بدون
تبلیغ شخصی‌سازی‌شده، بدون AAID/IMEI/MAC/location، SDK تأییدشده، privacy policy، Data Safety صادقانه.
**تصمیم:** `minSdk=24`، `targetSdk=36`، `compileSdk=36`، build-tools 36.۰.۰؛ مجوزها فقط
`INTERNET` (sync) و `VIBRATE` (بازخورد لمسی `02` §۷ — `Input.vibrate_handheld`). بدون AdMob، بدون
Crashlytics/Sentry (ADR-010). `keep_screen_on=true` (یادگیری طولانی‌مدت). edge-to-edge و
predictive-back در APK واقعی روی دستگاه چک می‌شود (فاز ۱۰).
**پیامد:** ریسک سازگاری Godot Mobile renderer + API 36 → پوشش با L3؛ حذف هر SDK شخص ثالث = مسیر
انطباق هموار برای «مخاطب کودک».

### ADR-010 — آنالیتیکس بدون SDK
**تصمیم:** `AnalyticsManager` فقط ۶ رویداد §5، batch (هر ۲۰ رویداد یا `session_end`)، حداکثر
۵۰۰ رویداد معوق، backoff نمایی (۵s→۵m، ۵ تلاش)، حذف پس از 2xx؛ crash log **محلی** حلقوی
(`user://logs/crash.log`، ۲۵۶KB) که فقط در Parent Dashboard نشان داده می‌شود، ارسال نمی‌شود.
والد می‌تواند «بهبود تجربه» (sync) را خاموش کند؛ بازی بی‌تغییر کار می‌کند.

### ADR-011 — RTL و i18n
**تصمیم:** همه‌ی متن‌های UI از `tr("KEY")` با فایل‌های `game/locales/fa.csv` + `en.csv` (Godot CSV
translation)؛ پیش‌فرض `fa` و RTL با `layout_direction = LAYOUT_DIRECTION_RTL` روی ریشه‌ی هر صحنه +
`TextServer` BiDi برای متن. عدد درون ترازو/کره‌ها **لاتین** می‌ماند (خوانایی ریاضی) ولی متن فارسی
با ارقام فارسی در روایت/داشبورد — هر دو مسیر در `LocaleFormat.gd` متمرکز است تا یک‌جا عوض شود.
**پیامد:** افزودن زبان = یک CSV؛ ریسک برهم‌ریختگی BiDi در مخلوط عدد/متن → تست خودکار RTL (فاز ۶).

### ADR-012 — پروفایل‌ها
**تصمیم:** MVP تک‌پروفایل در هر دستگاه (`user://profiles/default/`). مسیر save از همان ابتدا
پارامتریک است (`SaveSystem` یک `profile_dir` می‌گیرد) تا افزودن چندپروفایلی فقط یک UI منو باشد.
**تأییدمنتظر=مالک:** اگر کلاس/چندبچه‌ای اولویت است، جابه‌جایی به فاز ۶ (هزینه‌ی کم، همین حالا).

### ADR-013 — تست بدون موتور محلی
**زمینه:** در سندباکس Godot اجرا نمی‌شود (دانلود binary مسدود)؛ DoD چند فاز «پلی‌تست دستی» می‌خواهد.
**تصمیم:** (الف) L2 = CI تنها مرجع «کد Godot درست کار می‌کند»؛ (ب) به‌جای چک چشمی، تست‌های
«playable» نوشته می‌شود که صحنه را با `load()` + `add_child()` بالا می‌آورند و `InputEvent*`
تزریق می‌کنند تا یک سطح واقعی تا `level_completed` پیش برود؛ (ج) تست‌های ریاضی/داده کاملاً
headless و بدون scene. (د) یک اسکریپت `tools/render_shot.gd` در CI رندر ۱۶۸۰×۱۹۲۰ می‌گیرد و به‌عنوان
artifact آپلود می‌کند تا تو با چشم ببینی (بدون بزرگ‌شدن ریپو: imageها commit **نمی‌شوند**).

### ADR-014 — بک‌اند: runtime و DB
**تصمیم:** Node 22 + TS + Express 4 + `pg` + `zod`. تست‌ها با `pg-mem` (بدون داکر در سندباکس) و
همزمان در CI روی Postgres 16 واقعی (service container). اسکریپت `db/migrate.ts` فایل‌های
`migrations/*.sql` را به‌ترتیب شماره اجرا می‌کند. استقرار (Render/Fly/…) = تصمیم مالک؛ API بدون
state و stateless scaling-friendly نوشته می‌شود تا انتقال ارزان بماند.

### ADR-015 — ریاضیات مدل بازیکن (فرض‌های مستند)
```
confidence = clamp(attempts / (attempts + 12), 0, 1)          // ۱۲ تلاش ≈ اعتماد کامل
score      = 1.0 - 0.15*min(hints_used,2) - 0.05*min(extra_attempts,4)   // 0.6..1.0
hint_usage_rate, avg_time_to_solve_sec: EMA(α=0.3)
skill_key  = اولین tag از concept_tags که در SKILL_KEYS باشد (mapping ثابت)
```
`score` در `ErrorClassifier` محاسبه و به `SkillRating.update_elo` داده می‌شود (دقیقاً طبق نکته‌ی §3 سند داده‌ها).
**تأییدمنتظر=مالک:** این‌ها قابل‌تنظیم در `data/balance.json` خواهند بود تا بعد از بتا تیون شوند.

### ADR-016 — رجیستری autoload
**زمینه:** A5 (FeatureFlags غایب) + A6 (AudioManager غایب).
**تصمیم:** ترتیب ثبت در `project.godot` (وابستگی به این ترتیب دارد):
`EventBus → FeatureFlags → Log → GameState → SaveSystem → AudioManager → AnalyticsManager → NetworkClient → LevelLoader → DifficultyEngine`.
هر autoload جدید = ویرایش همین جدول + ADR.

### ADR-017 — فونت و مجوز آن
**تصمیم:** `Vazirmatn-Medium.ttf` + `Vazirmatn-Bold.ttf` (v33.0.3، SIL OFL) + `OFL.txt` + `AUTHORS.txt`
در `game/assets/fonts/`. تم بازی (`game/themes/NexusTheme.tres`) در فاز ۸ همین را به‌عنوان
`default_font` ست می‌کند؛ اندازه‌ی پیش‌فرض گفت‌وگو ۲۴px (`02` §۷).
**پیامد:** تعهد حفظ فایل مجوز در ریپو و در «پکیج فروشگاه» (باید در About/لیستینگ ذکر شود).

### ADR-018 — افزوده‌های ساختاری به درخت سند `01`
`game/themes/` (تم Godot)، `tools/` (اسکریپت توسعه، خارج از بازی)، `game/data/balance.json`
(پارامترهای تیونینگ)، `docs/05..08`. باقی درخت ۱۰۰٪ مطابق §2 سند معماری است (تست ۰.۳ این را چک می‌کند).

### ADR-019 — save: امنیت، نگهداری، حذف
MVP همان JSON ساده‌ی `03` §۲ (بدون PII → ریسک پایین)، `FileAccess` با flag read/write، نوشتن
اتمیک (`*.tmp` → rename)، و یک `SaveSystem.export_for_parent()/delete_all()` برای درخواست حذف.
نسخه‌ی post-MVP: رمز `AESContext` با کلید محلی (نه برای تهدید امنیتی، برای سازگاری ادعای Data Safety).
حفظ log گفت‌وگو: تا ۵۰۰ ورودی، چرخشی — «بدون حذف» طبق §۲ یعنی «تا وقتی والد نگاه می‌کند»، نه تا ابد.

### ADR-020 — parent-gate و شفافیت
پرسش دروازه: ضرب دو عدد دو رقمی با ورودی عددی تصادفی (کودک ۹ ساله در ۵ ثانیه نمی‌زند؛ بزرگ‌سال
۲ ثانیه). سه تلاش غلط → بازگشت به منو (قفل نرم، نه تنبیه). داشبورد: نمودار میله‌ی `elo` (نه برچسب
«ضعیف»)، زمان کل، و `aria_transcript_log` قابل‌اسکرول + لینک بازخورد **متنِ باز، بدون فیلد PII**
(فقط کپی در کلیپ‌بورد یا mailto بدون گیرنده‌ی شخصی) تا فرمِ وبی که داده جمع کند وجود نداشته باشد.

### ADR-021 — GDD بازسازی‌شده
چون GDD اصلی در ریپو نیست، `docs/07-GDD-BALANCE-REALM.md` نوشته می‌شود: پله‌ی آموزشی ۵ Tier با
مفهوم/مکانیک/نمونه‌ی مسئله/معیار تسلط، حلقه‌ی تعادل‌سنجی، قوانین ایمنی Aria، نقشه‌ی روایت، و
حریم‌خصوصیت — همه **استخراج‌شده از `00..04`** و با برچسب «بازسازی ایجنت ← تأییدمالک». هر تسک فاز ۷
به این سند ارجاع می‌دهد؛ اگر GDD واقعیِ تو متفاوت است، فقط §های ۰۷ عوض می‌شود و کد (به‌لطف ADR-006)
دست‌نخورده می‌ماند.
