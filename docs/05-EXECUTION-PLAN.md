# NEXUS — نقشه‌ی اجرای مشترک (Execution Plan & Phase Ledger)

**این سند پلِ بین «۴ سند فنی» و «کار واقعی در ریپو» است.** سه کار می‌کند:
(۱) ممیزی دقیق `docs/00..04` و همه‌ی حفره‌ها/تعارض‌هایی که برای ساختن محصول لازم است بسته شوند،
(۲) واقعیت‌های محیط توسعه و حلقه‌های راستی‌آزمایی که پروژه با آن‌ها «باگ‌less» نگه داشته می‌شود،
(۳) جدول فاز→تسک→DoD→وضعیت که تنها جای رسمی تیک‌زدن پیشرفت است.

منبع حقیقت برای **تصمیمات و فرض‌ها**: `docs/06-ENGINEERING-DECISIONS.md` (هر یافته‌ی اینجا یک ADR دارد).

---

## ۰) نحوه‌ی کار مشترک (مالک + ایجنت)

- هر session کاری = یک یا دو فاز از `docs/04-BUILD-PLAN.md`، به همان ترتیب، با commit جدا به ازای تسک.
- من در پایان هر فاز: گزارش «چه شد / چه چیزی تأیید شده / چه چیزی تأیید نشده و چرا» می‌دهم و **منتظر تأیید تو برای فاز بعد می‌مانم** (قاعده‌ی خودِ `00-START-HERE.md`: بدون DoD سبز، فاز بعد ممنوع).
- چیزی که فقط مالک می‌تواند بکند (ثبت‌نام Play Console، خرید فونت/موسیقی، پلی‌تست با کودک، پرداخت): در بخش ۷ و ۹ لیست شده و به تو برگردانده می‌شود.
- وضعیت‌ها: `✅ انجام و تأییدشده` · `🟡 انجام، تأیید در CI/دستگاه مانده` · `⬜ نشده` · `🔴 بلوکه (منتظر تصمیم مالک)`.

---

## ۰-الف) وضعیت کلی (در انتهای هر session به‌روز می‌شود)

| فاز | موضوع | وضعیت | شواهد |
|---|---|---|---|
| ۰ | راه‌اندازی | ✅ | CI run `34183214543` سبز (۲۴ ثانیه): import + GUT + gdlint + اعتبارسنج محتوا |
| ۱ | هسته: autoloadها و مدل داده | ✅ | CI `34184179791` سبز: **۵ اسکریپت / ۳۲ تست / ۳۲ PASS** روی Godot 4.7.2 headless؛ دام‌های Godot در ADR-026 ثبت و رفع شد |
| ۲ | مکانیک ترازو | ✅ | CI `34187312720` (push) و `34187317175` (PR) سبز: **۱۱ اسکریپت / ۸۸ تست / ۸۸ PASS** روی Godot 4.7.2 headless، با گارد جدید «کشف تست» (files_on_disk=11) |
| ۳ | سیستم داده‌ی سطح | ✅ | CI run `34188857587` (push) سبز: **۱۶ اسکریپت / ۱۲۷ تست / ۱۲۷ PASS** روی Godot 4.7.2 headless + `tools/validate_levels.py` (۵ سطح، ۵/۵ قابل‌حل با DP). چهار دور رفع خطا با L2 (سه خطای واقعی کد + یک دام فرمتی) — ببند بخش «فاز ۳» در §۵ |
| ۴ | موتور دشواری و مدل بازیکن | ✅ | CI سبز: **۲۲ اسکریپت / ۱۸۸ تست / ۱۸۸ PASS** (۳ دور رفع خطا) روی Godot 4.7.2 headless (شامل شبیه‌سازی ۳۰ سطحی و اتصال روی صحنه‌ی واقعی) + `validate_levels.py` (۵/۵) |
| ۵ | همراه Aria (دیالوگ، آواتار، جعبه‌ی گفت‌وگو) | ✅ | CI run `34326354282` سبز: **۲۷ اسکریپت / ۲۲۹ تست / ۲۲۹ PASS** روی Godot 4.7.2 headless + `validate_levels.py` (۵ سطح، ۵/۵ قابل‌حل، ۱۸ قالب دیالوگ). شش دور رفع خطا که همگی فقط با اجرای واقعی گرفته شدند — §«فاز ۵» در همین سند |
| ۶..۱۲ | بقیه | ⬜ | — |

**بدهی بازِ فاز ۱:** «اجرای صحنه روی دستگاه» (بخش DoD ۰.۲/۲.۶ که فقط با L3 بسته می‌شود) —
هنگام فاز ۱۰ با APK واقعی بسته خواهد شد.


---

## ۱) ممیزی اسناد — یافته‌ها و حفره‌ها (۱۸ مورد)

شدت: 🔴 بلاک‌کننده‌ی منطق/محصول · 🟠 باید پیش از شروع بخش مربوطه بسته شود · 🟡 بهبود کیفیت.

| # | سند/بخش | یافته | شدت | اقدام (ADR) |
|---|---|---|---|---|
| A1 | همه‌ی اسناد به «سند GDD اصلی» ارجاع می‌دهند | خود GDD در ریپو **نیست**؛ درحالی‌که مقیاس ۵ Tier، حریم‌خصوصیت، roadmap بتا و guardrailهای Aria آنجاست. بدون آن، فاز ۷ (تسک ۷.۱-۷.۵) و بخش‌های ۱۱ معلق‌اند. | 🔴 | بازسازی یک GDD حداقلی در `docs/07-GDD-BALANCE-REALM.md` با برچسب «بازسازی‌شده توسط ایجنت ← نیازمند تأیید مالک» (ADR-021) |
| A2 | `03` §1 vs `04` تسک ۴.۲ | ErrorClassifier باید ۴ نوع خطا را از «ساختار مورد انتظار سطح» استنتاج کند، ولی **اسکیمای سطح هیچ `solution_spec`/حرکت مورد انتظار ندارد**. طبقه‌بندی بدون آن حدسی می‌شود. | 🔴 | افزودن فیلد اختیاری `solution_spec` به §1 و پیاده‌سازی fallback تحلیلی (ADR-006) |
| A3 | `03` §6 vs §2 | بک‌اند `player_id UUID PRIMARY KEY` می‌خواهد؛ مدل بازیکن `p_193f2a7e` (غیر-UUID) تولید می‌کند. INSERT در Postgres با خطا می‌شکند. | 🔴 | `player_id TEXT` + جدول `device_tokens`؛ قالب `p_<12hex>` (ADR-005) |
| A4 | `03` §2 | `confidence` فرمول ندارد؛ `hint_usage_rate` و `avg_time_to_solve_sec` قاعده‌ی به‌روزرسانی ندارند. | 🟠 | فرمول‌های تعریف‌شده و تست‌پذیر در ADR-015 |
| A5 | `04` تسک ۵.۶ | به `FeatureFlags` ارجاع می‌کند ولی این autoload در درخت `01` §2 **وجود ندارد**. | 🟠 | `scripts/autoload/FeatureFlags.gd` اضافه شد به لیست autoload (ADR-016) |
| A6 | `04` تسک ۷.۶ | `AudioManager` هم در §2 `01` نیست؛ همچنین جمله «`AnalyticsManager`-مانند» اشتباه تایپی/مفهومی به‌نظر می‌رسد. | 🟠 | ثبت autoload `AudioManager`؛ پیاده‌سازی مستقل (ADR-008) |
| A7 | `03` §1 نمونه در برابر `04` تسک ۴.۳ | تریگرهای `idle_45s` / `fail_3x` داده‌محورند، ولی تسک ۴.۳ آستانه‌ها را hardcode (۴۵ ثانیه) می‌کند → با سطحی که `idle_30s` دارد ناسازگار. | 🟠 | `HintTimingSystem` رشته‌ی trigger را **پارس** می‌کند؛ ۴۵ فقط پیش‌فرض است (ADR-006) |
| A8 | `02` §۷ در برابر `01` §۲ | هیچ مسیر فونت/تم در درخت نیست (`assets/fonts` هست ولی نه فایل، نه theme). RTL در Godot باید **صریح** در هر Control ست شود. | 🟠 | فونت Vazirmatn (OFL) اضافه شد + `game/themes/NexusTheme.tres` در فاز ۸ (ADR-017) |
| A9 | `04` تسک ۶.۲ و `02` §۴ | آواتار «۶ تُن پوست × ۸ مدل مو × رنگ مو» می‌خواهد؛ این در یک اسپرایت‌شیت PNG ≈ چند مگابایت می‌شود و با «بدون ۴۸ اسپرایت جدا» در تضاد عملی است. | 🟡 | رندر **لایه‌ایِ shader/palette-swap** (بدون bitmap) — هم کوچک‌تر هم بی‌نقص در هر DPI (ADR-007) |
| A10 | `04` تسک ۰.۱ | `.gitignore` باید `*.import` را ignore کند؛ Godot 4 رسماً **commit کردن** `.import` را توصیه می‌کند (تثبیت تنظیمات import برای همه). | 🟡 | طبق سند ignore شد؛ جبران با تنظیمات project-level و یک ADR (ADR-003) |
| A11 | `04` تسک ۰.۵ و `01` §۲ | فقط `ci.yml` تعریف شده: نه workflow ساخت APK/AAB، نه artifact، نه lint، نه release. برای «محصول قابل‌فروش» این یک حفره‌ی واقعی است. | 🟠 | افزودن `android-export.yml` (دستی، فاز ۱۰) و `gdlint`/content-validate به CI (ADR-004) |
| A12 | `04` تسک ۱۰.۴ | «API 24+» برای minSdk؛ ولی **target API** ذکر نشده و Google Play از ۳۱ اوت ۲۰۲۶ برای اپ‌های جدید target API 36 (Android 16) را الزامی کرده، با مهلت قابل‌درخواست تا ۱ نوامبر ۲۰۲۶. یک اپ جدید امروز **باید** targetSdk 36 و compileSdk 36 داشته باشد. | 🔴 | `targetSdk=36`، `compileSdk=36`، `minSdk=24` (ADR-009). تست edge-to-edge/predictive-back در فاز ۱۰. |
| A13 | `04` فاز ۱۱ | «اپ‌های کودک‌محور» فقط به‌صورت کلی. Families Policy: بدون تبلیغ شخصی‌سازی‌شده، بدون AAID/IMEI/MAC/location، فقط SDK تأییدشده، privacy policy، فرم Data Safety، IARC rating، و اگر مخاطب مختلط است neutral age screen. **ساده‌ترین مسیر انطباق: بدون تبلیغات، بدون SDK خارجی** (که ما داریم). | 🟠 | چک‌لیست فاز ۱۲ در همین سند §۷ + `docs/08-STORE-READINESS.md` (ADR-009/010) |
| A14 | `04` فاز ۱۰ | هیچ هدف «سایز/عملکرد» برای گوشی ارزان تعریف نشده؛ DoD می‌گوید «روی دستگاه ارزان اجرا شود» ولی معیار کمی ندارد. | 🟡 | بودجه‌های قابل‌سنجش: APK ≤ ۴۰MB، حافظه resident ≤ ۲۵۰MB، ۶۰fps هدف/۳۰fps کف روی Cortex-A53، startup ≤ ۳s (ADR-018) |
| A15 | `03` §2 | ذخیره‌ی محلی «JSON رمزنگاری‌نشده» صراحتاً برای MVP. روی اندروید، `user://` در سندروارد اپ است — برای داده‌ی غیر PII قابل‌قبول، ولی برای یک اپ کودک‌محور بهتر است از قبل روشن باشد. | 🟡 | MVP همان JSON + `0600`؛ در ADR توضیح ریسک و مسیر ارتقا (فایل AES ساده) در post-MVP (ADR-019) |
| A16 | `00-START-HERE` §۳/`01` §۴ | تعارض فرآیندی: «هر تسک = یک commit» و همزمان «هر تسک = یک PR به develop». با تک‌نفر/ایجنت و محدودیت شاخه‌ی Arena (`arena/01a07efb-nexus-learning-game`) شدنی نیست. | 🟠 | سازش مستند: commit/تسک روی شاخه‌ی session + PR در پایان هر فاز (ADR-002) |
| A17 | `04` فاز ۰ تا ۱۱ | فازِ «انتشار واقعی» (آیکون ۵۱۲، feature graphic، ۸ اسکرین‌شات فارسی، متن لیستینگ، ویدیو، قیمت‌گذاری، rollout تدریجی، پشتیبانی) تعریف نشده؛ «قابل‌فروش» بدون آن محقق نمی‌شود. | 🟠 | افزودن **فاز ۱۲ — انتشار** به همین سند (§۵.۱۲) |
| A18 | `04` تسک ۲.۶ | DoD فاز ۲ «پلی‌تست دستی» است و در سندباکس امکان‌پذیر نیست (بدون نمایشگر/دستگاه). | 🟡 | شبیه‌سازی هدلسِ in/out (in-engine `tests/gut/test_playable_p2.gd` که واقعاً input تزریق می‌کند) + یک GIF/ویدیوی کوتاه از اجرای دسکتاپ برای چشم مالک (ADR-013) |

**مواردی که ممیزی کردیم و سالم‌اند** (تا ریویوی بعدی دوباره بازسازی نشود): شمارش تسک‌ها («۱۲ فاز، ~۶۰ تسک» = دقیقاً ۶۰ تسک در `04`)؛ بازه‌ی Elo و clamp در `03` §۳ با `update_elo` سازگار است؛ رنگ‌های `02` §۲ در همه‌ی اسناد یکسان‌اند؛ قانون «ghost_orbs فقط Tier 3+» در `03` و `02` §۶ هم‌خوان است؛ الگوی نام‌گذاری فایل/شناسه (`level_1_01.json` ↔ `tier1_level_01`) به‌عنوان قاعده در اعتبارسنج خودکار پیاده شد.

---

## ۲) واقعیت‌های محیط توسعه (چیزی که اسناد پیش‌بینی نکرده بودند)

| ابزار/قابلیت | وضعیت در سندباکس | پیامد |
|---|---|---|
| Godot editor/headless | ❌ نصب نیست؛ **دانلود release asset مسدود است** (شبکه‌ی allowlist: `github.com`, `api.github.com`, `codeload`, `registry.npmjs.org`, `pypi.org` باز؛ `objects.githubusercontent.com`, `downloads.godotengine.org`, `tuxfamily`, `jsdelivr` بسته) | اجرای Godot و GUT فقط در **CI**؛ `tools/setup-godot.sh` برای ماشین محلی تو |
| `gdparse`/`gdlint` (gdtoolkit 4.5) | ✅ از PyPI نصب شد | گرامر GDScript محلی، قبل از push |
| Node 22 + npm | ✅ (registry باز) | بک‌اند TS قابل build/test است |
| Java / Gradle / Android SDK | ❌ (و ~۳GB دانلود مسدود/پر‌هزینه) | ساخت APK در CI با `android.yml` (artifact) |
| Docker / PostgreSQL | ❌ | بک‌اند با `pg-mem` تست می‌شود؛ Postgres واقعی در CI (service) و در ماشین تو |
| RAM/CPU | ۲ core / 4GB | هیچ Godot GUI، هیچ x86 emulator؛ export در CI |
| GitHub | ✅ push/PR با احراز هویت Arena؛ ریپو **خصوصی** (~۲۰۰۰ دقیقه/ماه CI) | CI سبک، کش باینری، `concurrency`، بدون cron؛ build اندروید فقط `workflow_dispatch` |

### حلقه‌های راستی‌آزمایی (Validation loop)

```
L1 محلی (<۵ ثانیه، هر تغییر)   : gdparse + gdlint + validate_levels.py + npm test (بک‌اند)
L2 CI (هر push، authoritative)  : Godot --import (کل assetها parse می‌شوند) + GUT headless
L3 دستگاه/انسان (پایان هر فاز)  : APK از artifact CI، پلی‌تست روی گوشی واقعی، چک چشمی بصری
```

**قاعده:** L2 سبز = تنها تعریف «کار تمام‌شده» برای کد Godot. من هیچ تسکی را «تأییدشده» علامت
نمی‌زنم مگر CI سبز باشد (و آن را در جدول §۵ ثبت می‌کنم با لینک run).

---

## ۳) بودجه‌ی ورک‌اسپیس (سقف نرم ۲۵MB در ریپو؛ سقف Artifact Arena ~۱۲۸MB)

| قلم | حجم | سقف برنامه‌ریزی‌شده |
|---|---|---|
| `docs/*.md` | ~۱۲۰KB | ≤ ۵۰۰KB |
| `game/addons/gut` (v9.7.1، ۲۵۹ فایل) | ۲.۹MB | ثابت (vendor، بدون zips) |
| `game/assets/fonts/Vazirmatn` (2 × ttf + OFL) | ۲۴۶KB | ≤ ۴۰۰KB |
| هنر بازی (SVG-first) | ۰ | **≤ ۴MB** — PNG فقط در استثنا، هر فایل ≤ ۱۵۰KB |
| صدای placeholder (WAV/OGG مونو) | ۰ | **≤ ۶MB**؛ موسیقی نهایی بیرون از ریپو یا ≤ ۸MB |
| کد + داده‌ها | ~۱MB | ≤ ۳MB |
| **جمع کنونی** | **≈ ۳.۴MB** | **هدف ≤ ۱۵MB، سقف ۲۵MB** |

قوانین اجرایی: `/tmp` برای هر چیز موقت (رندر AI، فایل‌های بزرگ)؛ `.tools/`، `node_modules/`، `builds/`، `*.apk/aab` ignore؛ هیچ `git add -A` کورکورانه (فقط مسیرهای مشخص)؛ هر commit > ۳MB با `git diff --stat` بازبینی می‌شود؛ تصویر AI خام در ریپو commit **نمی‌شود**.

---

## ۴) اصل معماری که باید حفظ شود (خلاصه‌ی قابل‌تست)

- همه‌چیز از یک لایه‌ی «داده = JSON» تغذیه می‌کند → محتوای جدید بدون compile.
- جریان اصلی: `LevelLoader → LevelController → BalanceScale → (Orbs) → EventBus → ErrorClassifier → HintTimingSystem → AriaController → DialogueBox`، و `PlayerModel ← DifficultyEngine ← level_completed` → `SaveSystem` → (`NetworkClient` فقط هنگام اتصال).
- `ErrorClassifier`/`DifficultyEngine`/`LevelLoader` **قطعی و بدون AI**؛ Aria فقط قالب انتخاب می‌کند.

---

## ۵) جدول فازها (منبع رسمی وضعیت)

### فاز ۰ — راه‌اندازی ✅ (این session)
| تسک | خروجی | DoD | تأیید | وضعیت |
|---|---|---|---|---|
| ۰.۱ ریپازیتوری | `.gitignore`, `README.md`, ساختار اولیه | commit اولیه + clone سالم | بررسی محلی + push | ✅ |
| ۰.۲ پروژه Godot | `game/project.godot` (1080×1920، `canvas_items`/`expand`، Mobile renderer، `drag_start/drag_end`، RTL-ready) | پروژه در Godot باز/اجرا شود | Godot `--import` در CI (L2) | 🟡 |
| ۰.۳ درخت پوشه‌ها | ۴۲ دایرکتوری مطابق `01` §2 (± additions: `themes/`) | ۱۰۰٪ مطابقت | تست GUT `test_required_folder_layout_exists` | 🟡 |
| ۰.۴ نصب GUT | `game/addons/gut` (v9.7.1) + `game/.gutconfig.json` + `tests/gut/test_smoke.gd` | اجرای headless با یک PASS | CI L2 | 🟡 |
| ۰.۵ CI پایه | `.github/workflows/ci.yml` (import + GUT + gdlint + content validate) | CI سبز/قرمز درست گزارش می‌دهد | run واقعی CI | 🟡 |

### فاز ۱ — هسته‌ی معماری (EventBus / PlayerModel / SaveSystem / GameState)
تسک‌ها: ۱.۱ `EventBus.gd` (۵ سیگنال + ثبت autoload) · ۱.۲ `PlayerModel.gd` (`Resource` + `to_dict/from_dict`) · ۱.۳ `SaveSystem.gd` (`user://player_model.save` + migration بر اساس `schema_version`) · ۱.۴ `GameState.gd`.
خروجی جانبی من: `FeatureFlags.gd` (حلقه‌ی A5) و `Log.gd` (لاگ سطح‌دار) — ثبت در ADR-016.
DoD (✅ در CI): `test_player_model.gd` (round-trip عمیق + re-type شدن int پس از JSON)،
`test_save_system.gd` (save→load یکسان، عدم‌بقای `.tmp`، save خراب قرنطینه می‌شود، مهاجرت v0→v1،
`delete_all()`، و گارد «هیچ کلید PII در export والدین نباشد»)، `test_game_state.gd`
(مقادیر نوشته‌شده در یک صحنه در صحنه‌ی دیگر خوانده می‌شود)، `test_event_bus.gd` (emit → شنونده).
**افزوده‌های فاز ۱ که سند نداشت:** `Log.gd`، `FeatureFlags.gd`، `SaveSystem.ensure_dir()`،
`SkillRating.quantize()` (پایداری اعشار در save)، و کانال تشخیص CI (ADR-025).

### فاز ۲ — مکانیک ترازو ✅ (مهم‌ترین فاز؛ عجله ممنوع — ۱۳ کامیت، ۴ دور رفع خطا با L2)
| تسک | خروجی | DoD (سند ۰۴) | شواهد | وضعیت |
|---|---|---|---|---|
| ۲.۱ `WeightOrb` | `gameplay/WeightOrb.gd` + `scenes/gameplay/WeightOrb.tscn` + `OrbVisual.gd` (نود فرزند برای انیمیشن) | Area2D قابل‌درگ با لمس و موس | `test_weight_orb.gd` (۱۱ تست: روتینگ `InputEventScreenTouch`/`InputEventMouseButton`، grab offset، قفل درگ، والد کفه) | ✅ |
| ۲.۲ `BalanceScale` | `BalanceScale.gd` + `BalancePan.gd` (دو Area2D) + `BalanceScale.tscn` | «تست GUT برای `calculate_tilt()` با چند سناریوی وزن» | `test_balance_scale.gd` (۱۲ تست: فرمول `clamp((R−L)/20,−1,1)×14`، clamp لبه‌ها، tolerance، emit‌ها، افقی‌ماندن کفه‌ها بعد از Tween) | ✅ |
| ۲.۳ `GhostOrb` | `GhostOrb.gd` (وزن = `hidden_value`، متن همیشه «؟») | وزن لحاظ شود، عدد نمایش داده نشود | `test_ghost_orb.gd` (۶ تست، از جمله نشت‌نکردن عدد در UI و `reveal()`) | ✅ |
| ۲.۴ `NegativeOrb` | `NegativeOrb.gd` (وزن منفی + drift رو‌به‌بالا روی `Visual`) | کم‌کردن از وزن کفه در تست | `test_negative_orb.gd` (۷ تست: ۵−۲=۳، علامت از نوع نه داده، عدم drift روی کفه) | ✅ |
| ۲.۵ Win detection | `LevelController.gd` (برد، تلاش، `level_completed` با stats کامل) | «LevelScene یک کره را روی کفه بگذارد و `level_completed` منتشر کند» | `test_playable_p2.gd` (۱۶ تست: برد، تلاشِ ۰.۸ ثانیه‌ای، «درگ میانی تلاش نیست»، برد فقط یک‌بار، چندراه‌حل، روح/ضد-وزن/دو ترازو در سطح) | ✅ |
| ۲.۶ پلی‌تست «۳+۵=؟» | `scenes/gameplay/LevelScene.tscn` + `run/main_scene` + `default_config()` hardcode | صحنه در Godot باز و قابل‌بازی باشد | صحنه در CI `instantiate` و تا برد بازی می‌شود (نه فقط parse)؛ `F5` همان سطح را اجرا می‌کند | ✅ |

**تصمیم‌های ثبت‌شده در این فاز:** ADR-028 (قرارداد `config` + قاعده‌ی برد/tolerance/تلاش)،
ADR-029 (ترازوی ترکیبی‌پذیر + سیگنال `scale_state_changed`)، ADR-030 (پالت و هنر placeholder در کد)،
ADR-031 (جای‌گذاری هندسی به‌جای overlap فیزیک)، ADR-032 (صحنه = نقطه‌ی ترکیب، درخت در کد)،
ADR-033 (گارد کشف تست در CI). دام‌های تازه‌ی Godot 4.7 هم به ADR-026 اضافه شد (۸ مورد).

**انحراف‌ها/افزوده‌هایی که سند ۰۴ نداشت (صریح):** `Palette.gd`، `OrbVisual.gd`، `BalancePan.gd`،
`test_palette.gd` (قفل قانون «قرمز تهاجمی ممنوع» §۲ سند هنری)، `LevelController.resync/_apply_scale_layout`
(چیدمان دو ترازو)، helper `GameState`→`EventBus.attempt_failed`، و `tools/ci_annotate.py` که حالا
شکست‌ها را بسته‌ای (۱۲×۸ خط) به annotation تبدیل می‌کند — بدون آن ۳۵ fail قابل‌تشخیص نبودند.

**باز ماند (عمداً):** هنر/فونت و تم واقعی → فاز ۸ (برچسب‌های فاز ۲ عمداً لاتین‌رقم‌اند؛ هدلس فونت فارسی
ندارد)؛ طبقه‌بندی خطا و والوز‌کردن امتیاز → `ErrorClassifier`/`DifficultyEngine` فاز ۴ (در `_process`
نقطه‌ی اتصال با کامنت مشخص شده)؛ HUD/گفت‌وگو → فاز ۵/۶؛ Orphans≈۸۰۰ در خلاصه‌ی GUT (بیشتر Tween)
در فاز ۱۰ با پروفایل دستگاه بررسی می‌شود. **پلی‌تست انسانی** در فاز ۱۰ با APK واقعی انجام می‌شود
(ADR-013 جای تست خودکار را در CI گذاشته است).

### فاز ۳ — سیستم داده‌ی سطح ✅ (۹ کامیت، ۴ دور رفع خطا با L2)
| تسک | خروجی | DoD (سند ۰۴) | شواهد | وضعیت |
|---|---|---|---|---|
| ۳.۱ `LevelData` | `scripts/data/LevelData.gd` (`from_dict`/`from_json_text`/`validate()`/`to_config_dict()`) | «JSON نمونه پارس می‌شود، تمام فیلدها صحیح می‌خوانند» | `test_level_data.gd` (۹ تست: هر ۱۴ فیلد، سازگاری int/float، قرارداد ADR-028، ۱۵ شکل خراب → ≥۱ خطا، JSON شکسته، ghost بدون target) | ✅ |
| ۳.۲ `LevelLoader` | `scripts/autoload/LevelLoader.gd` + ثبت autoload | «`load_level("tier1_level_01")` صحنه‌ی قابل‌بازی را باز می‌کند» | `test_level_loader.gd` (۱۲ تست: `path_for`، کشف id از دیسک، کش + `clear_cache`، `level_load_failed` بدون crash، تزریق config به `LevelScene`، `first_unfinished_id`/`next_of`) | ✅ |
| ۳.۳ پنج سطح Tier 1 | `data/levels/tier1/level_1_01..05.json` + `solution_spec` | «هر ۵ سطح قابل‌حل و قابل‌بازی‌اند» | DP در `validate_levels.py` (۵/۵) **و** `test_playable_p3.gd` (۴ تست: هر پنج سطح با جواب `intended` می‌بَرند، `level_completed` در مدل ثبت می‌شود، چیدمان ناپایدار دقیقاً یک `attempt_failed` و بعد همان سطح برد می‌کند) | ✅ |
| ۳.۴ `WorldMap` | `scripts/ui/WorldMap.gd` + `scenes/main/WorldMap.tscn`، `run/main_scene`، `LevelResultBar` | «جریان کامل: منو → انتخاب سطح → بازی → برگشت به نقشه با سطح بعدی باز» | `test_world_map.gd` (۱۰ تست: اندازه‌ی لمسی ≥۴۸px، عدم هم‌پوشانی، ترتیب قفل‌ها، سطح قفل‌شده قابل‌کلیک نیست، جریان map→win→next→map) + `test_project_wiring.gd` (۴ تست سازماندهی پروژه) | ✅ |

**تصمیم‌های ثبت‌شده در این فاز:** ADR-034 (زوجیت `level_id` ↔ نام فایل، که `validate_levels.py` دیکته می‌کند)،
ADR-035 (الگوی `pending_config` + `change_scene_on_start` تا تست هرگز درخت خودش را نکنَد)،
ADR-036 (`*.json` باید در **Non-Resource Files** پریست Android باشد — وگرنه داده روی دستگاه نیست)،
ADR-037 (`target_value` = وزنی که بازیکن باید **اضافه** کند). چهار دام تازه به ADR-026 (بندهای ۱۴ تا ۱۷) اضافه شد.

**چهار خطایی که فقط با L2 (اجرای واقعی) گرفته شدند — و هیچ‌کدام با gdlint/gdparse/وِلییدیتور پایتون:**
۱) کامنت `#` در `project.godot` → autoload ثبت نشد و **چهار فایل تست اصلاً اجرا نشدند** (CI قرمزِ مبهم).
۲) `%g` در فرمت رشته‌ی Godot → «String formatting error» و پیام واقعیِ تست گم شد.
۳) کره‌های `right_side.fixed_orbs` هیچ‌وقت روی کفه‌ی راست گذاشته نمی‌شدند (آرک‌تایپ ۲ عملاً ساخته نمی‌شد)
   و کره‌ی روح هم‌زمان در `left_orbs` و `left_ghost_orbs` بود → وزن دوبله.
۴) دو تست از تست‌های من خودشان حساب غلط داشتند (نه کد) — اصلاح شدند تا رفتار درست توصیف شود.

**انحراف‌ها/افزوده‌هایی که سند ۰۴ نداشت (صریح):** `LevelResultBar` (حلقه‌ی «بعدی/نقشه» بی آن صحنه‌ی
نتیجه نداشت)، `game/tests/gut/test_project_wiring.gd` (نگهبان سازماندهی پروژه)، `hint_id`های ثابت در
داده (فاز ۵ **باید** دقیقاً همین‌ها را در `data/dialogue/aria_templates.json` بسازد: `gentle_nudge_01`،
`socratic_operation_01`، `socratic_specific_01`، `compare_sides_01`، `inventory_count_01`)، و
`expected_solve_time_sec` سطح ۰۱ روی ۴۰ نشست تا با نمونه‌ی `03-DATA-SCHEMAS.md` §۱ یکی باشد.

**باز ماند (عمداً):** هنر نقشه و تم → فاز ۸؛ پلکین/انیمیشن قفل‌ها → فاز ۶؛ `MainMenu.tscn` جای `run/main_scene`
را در فاز ۶ (تسک ۶.۱) می‌گیرد؛ **بسته‌بندی JSON در پریست Android** (ADR-036) تسک فاز ۱۰ است؛ پلی‌تست انسانی
این جریان روی دستگاه واقعی هم فاز ۱۰.

### فاز ۴ — موتور دشواری و مدل بازیکن ✅ (۶ کامیت، ۳ دور رفع خطا با CI)
| تسک | خروجی | DoD (سند ۰۴) | شواهد | وضعیت |
|---|---|---|---|---|
| ۴.۱ `SkillRating` | `scripts/data/SkillRating.gd` (`expected_success`/`update_elo`/`apply_result`/`compute_confidence`، K=32، clamp ۴۰۰..۲۰۰۰) | «فرمول Elo مطابق §۳ و در بازه‌ی مجاز» | `test_skill_rating.gd` (۸ تست: سناریوهای دست‌محاسبه، clamp، اعتماد ADR-015، ثبت مهارت در `PlayerModel`) | ✅ |
| ۴.۲ `ErrorClassifier` | `scripts/ai/ErrorClassifier.gd` (۴ نوع خطا + `need_right`ِ fallback، `success_score()`) — کاملاً rule-based، هیچ درخواست شبکه‌ای نیست | «خطاهای شناخته‌شده درست برچسب می‌خورند؛ جواب افشا نمی‌شود» | `test_error_classifier.gd` (۱۱ تست روی پنج سطح واقعی: جهت/علامت/هردوکفه/محاسبه، مرزهای تلورانس، `state_of`) | ✅ |
| ۴.۳ `HintTimingSystem` | `scripts/ai/HintTimingSystem.gd` (`parse_steps`، تایمر بی‌حرکتی، شمارش تلاش، `request_help`) | «۴۵ ثانیه بی‌حرکتی → پله‌ی اول؛ هر راهنما در `hints_used` می‌نشیند» | `test_hint_timing.gd` (۱۲ تست؛ آستانه‌ها با `tick()` جلو می‌روند، نه خوابِ CI) | ✅ |
| ۴.۴ `DifficultyEngine` + اتصال | `scripts/autoload/DifficultyEngine.gd` (pure `choose_next` + `apply_level_result`)، seam فاز ۳ (`LevelLoader.next_selector`)، `LevelResultBar`، `LevelController` (`hint_timing`/`pan_snapshot`/`classify_current_error`) | «سطح بعدی بر اساس نزدیک‌ترین `difficulty_elo`، نه ترتیب فایل» | `test_difficulty_engine.gd` (۱۲ تست) + `test_adaptive_loop.gd` (۷ تست روی صحنه‌ی واقعی: اشتباه→برچسب، راهنمای ۴۵ثانیه‌ای، `score`/`final_elo_delta`ِ واقعی در payload، بعدیِ انتخاب‌شده) | ✅ |
| ۴.۵ شبیه‌سازی ۳۰ سطحی | `test_difficulty_simulation.gd` (۳ Tier × ۱۰ سطح مصنوعی، Elo ۸۲۰..۱۴۰۰) | «بازیکن ضعیف → عقب‌تر/قوی → جلوتر؛ بدون دیوار» | چهار سناریو: قوی ۳۰/۳۰ یکتا و رتبه‌ی پایانی بالاتر از ۱۰۰۰؛ ضعیف (۳ راهنما، ۵ تلاش) ۱۶ سطح تازه + ۱۴ «تمرین مجدّد» و رتبه‌ای که **بالا نمی‌رود** (۹۳۹.۸)؛ دو سطح سخت پشت‌سرهم هرگز؛ جابه‌جایی ≤ `MAX_SWAP_AHEAD`؛ Elo داخل clamp؛ ترتیب قطعی (بدون تصادف) | ✅ |

**تصمیم‌های ثبت‌شده در این فاز:** ADR-038 (موتور `level_completed` را نمی‌شنود؛ `apply_level_result`
قبل از emit صدا زده می‌شود)، ADR-039 (کلید مهارت = `concept_tags[0]` و هم‌نام‌سازی با docs/07 §۴)،
ADR-040 («ساده‌تر» یعنی **تمرینِ مجدّدِ ساده‌ترین سطحِ تمام‌شده‌ی همان Tier**، فقط یک‌بار پشت‌سرهم).

**چهار خطایی که فقط با اجرای واقعی (CI) گرفته شدند — و هیچ‌کدام با gdlint/gdparse/validator پایتون:**
۱) `LevelController` دو فلگ را مصرف می‌کرد ولی اعلام نکرده بود (`hint_timing_enabled`،
   `error_classification_enabled`) → اسکریپت کامپایل نشد و `LevelScene.tscn` بی‌اسکریپت ماند:
   ۲۸ تستِ بی‌ربطِ فاز ۲/۳ هم Nil گرفتند (خطای واقعی در یک فایل، قرمزی در ده فایل).
۲) دام‌های GUT 9.7.1: `assert_approx` وجود ندارد (helper محلی `_near` شد)، `fail()` هم نه
   (`fail_test`)، و `fired_count()` شمارنده‌ی **متن‌های متفاوت** است — تکرارِ یک پله را نمی‌شمارد،
   پس شمارش escalation باید روی `hint_triggered`ی همان نود (`watch_signals(sys)`) انجام شود.
۳) دو عددِ دست‌نویس در تست‌ها با فرمول واقعی نمی‌خواند: `delta` بردِ ۱۰۰۰→۹۰۰ برابر ۱۱.۵۱۸ است
   (نه ۷.۶۸۸ که از فاصله‌ی ۲۰۰ حساب شده بود) و «سه راهنما → رتبه منفی» در این فاصله غلط است؛
   هر دو تست حالا عدد را از خودِ `SkillRating` می‌گیرند، پس اگر منحنی انتظار عوض شود، تست
   «رابطه» را می‌سنجد نه یک عددِ یخ‌زده.
۴) «۸۰ بردِ پیاپی در سطح آسان باید رتبه را به ۲۰۰۰ برساند» یک ادعای اشتباه از من بود: منحنی
   انتظار سود را هرچه بالاتر می‌روی به صفر می‌رساند (این ویژگی Elo است، نه باگ)؛ کیسِ درستِ
   clamp، بردِ غیرمنتظره در سطحی خیلی سخت‌تر است.

**انحراف‌ها/افزوده‌هایی که سند ۰۴ نداشت (صریح):** پنجره‌ی «ضددیوار» به شکلِ قابل‌تست بازنویسی شد:
وقتی کلِ یک Tier از رتبه‌ی بازیکن بالاتر باشد، «ساده‌ترینِ همان Tier» هم سخت است، پس موتور
نمی‌تواند ادعای «حداکثر ۱ سخت در هر ۳ سطح» را عددی برآورده کند؛ ادعاهای واقعیِ کد
«هیچ‌وقت دو سطح سخت پشت‌سرهم» و «حداکثر یک پله جابه‌جایی از نردبان» تست شدند. همچنین
`GameState.level_attempts ≥ 2` تنها شرطِ struggle است (نه «شکستِ کاملِ سطح»)، چون موتور از
«تلاش‌های همین سطح» خبر دارد نه از باخت.

**بدهی به فازهای بعد:** شدتِ «تمرینِ مجدّد» (۱۴ از ۳۰ گام در شبیه‌سازیِ بازیکن ضعیف) با
`STRUGGLE_ATTEMPTS` تنظیم می‌شود و **باید با پلی‌تست واقعی (فاز ۱۱) قضاوت شود** (ADR-040)؛
`hint_shown` هنوز متن ندارد (فاز ۵، `aria_templates.json`)؛ `error_patterns` در داشبورد والدین
نمایش داده نمی‌شود (فاز ۶)؛ kill-switch تطبیق (`adaptive_selection`) در تنظیمات والدین هنوز
دکمه ندارد (فاز ۶)؛ و `DifficultyEngine` عمداً چیزی ذخیره نمی‌کند — رتبه‌ها در `PlayerModel`
زندگی می‌کنند، پس بعد از راه‌اندازی دوباره، streak صفر است (تصمیمِ باز: اگر آزاردهنده بود، ADR جدید).

### فاز ۵ — Aria ✅ (۹ کامیت، ۶ دور رفع خطا با CI)
| تسک | خروجی | DoD (سند ۰۴) | شواهد | وضعیت |
|---|---|---|---|---|
| ۵.۱ `DialogueTemplate` | `scripts/ai/DialogueTemplate.gd`: پارسرِ بدون-crash + اعتبارسنج §۴ (`from_dict`/`index_from_text`/`load_file`/`match_error`/`count_variants`) | «بارگذاری فایل نمونه، جستجو بر اساس `hint_id`» | `test_dialogue_templates.gd` (۱۲ تست: `{"hints": 3}`، `[]`، فایل ناموجود، واریانت یک‌تایی، بازه‌ی Tier، نوع ناشناخته، سقف ۲۲۰ نویسه، `hint_id` تکراری، چرخش با cursor منفی/بزرگ) | ✅ |
| ۵.۲ محتوای دیالوگ | `data/dialogue/aria_templates.json`: **۱۸ قالب × ۲ واریانت = ۳۶ متن فارسی**، پوشش کامل `error_type × tier ۱-۲` + هر پنج `hint_id` که فاز ۳ صدا می‌زند | «هیچ رشته‌ای عدد جواب را ندارد (چک خط‌به‌خط)» | چک **خودکار** در `tools/validate_levels.py` (از فاز ۳ همان‌جا بود، پس ابزار جدا لازم نشد): صفر رقم ASCII/فارسی، طول ≤ ۲۲۰، ≥ ۱۵ قالب، و مقایسه‌ی سطح‌به‌سطح با `solution/target_value`; `test_dialogue_templates.gd` هم فایل واقعی را با همان معیارها می‌سنجد | ✅ |
| ۵.۳ `AriaController` | `scripts/ai/AriaController.gd`: listener روی `hint_requested`/`error_detected`، انتخاب قالب با `match_error`، **چرخشی** با `_cursor[hint_id]`، emit `hint_shown(hint_id, level_id, text)` + `aria_state_changed` | «بازی با خطاهای عمدی: واکنش زمانی و محتوایی درست» (دستی → به فاز ۱۰/۱۱ منتقل) | `test_aria_controller.gd` (۱۰ تست): دو فراخوانی پشت‌سرهمِ یک قالب دو متن **متفاوت** می‌دهند و سوم برمی‌گردد؛ خطای تکراری بعد از `ERROR_HINT_EVERY_FAILS=2` راهنمای بعدی + متنِ خطا، و دفعه‌ی اول فقط حالت `thinking` (بی‌متن ⇒ بی‌سروصدا برای کودک)؛ `help_requested` بدون صفرکردنِ cursor؛ روتینگ شش state روی یک نود `aria_state_changed` | ✅ |
| ۵.۴ `Aria.tscn` | `scenes/characters/Aria.tscn` + `scripts/characters/{AriaAvatar,AriaCrystal,AriaCore}.gd`: چندوجهی نیمه‌شفافِ `_draw`-محور، بدونه صورت، bobbing، شش clipِ placeholderِ ساخته‌شده در کد | «هر ۶ state از کد قابل‌فراخوانی و قابل‌تفکیک» | `test_aria_avatar.gd` (۷ تست): `play_state()` برای هر شش state، **شش رنگ هسته‌ی متمایز روی نود زنده**، مدت‌های متمایز، `idle` لوپ / `celebrating` یک‌بار، پالس `encouraging` = ۱.۰→۱.۱۵→۱.۰ در ۰.۴s (§۳ عیناً)، حالت ناشناخته بی‌صدا رد، و `build_placeholder_clips=false` (شبیه‌سازی فاز ۸) که منطق را نمی‌شکند | ✅ |
| ۵.۵ `DialogueBox.tscn` | `scripts/ui/DialogueBox.gd` + صحنه: فونت ۲۴px، RTL، wrap هوشمند، سقف ۳ خط + `clip_text`، حاشیه ۲۴px، فید ۰.۲s، `mouse_filter = IGNORE` | «متن کوتاه و بلند بدون overflow» | `test_dialogue_box.gd` (۶ تست): عرض کادر ≤ عرض صفحه برای ۲۰ و ۱۶۰ نویسه (+ ادعای «بلند واقعاً می‌پیچد»)؛ واکنش به `hint_shown`؛ متن تهی ⇒ کادر خالی نمی‌ماند؛ `.tscn` به همان کلاس اینستانشیت می‌شود؛ و **تست زنجیره‌ی واقعی**: `hint_requested` → قالب فایل → کنترلر → جعبه، با ادعای «متنِ نمایش‌داده‌شده عیناً یکی از واریانت‌های فایل است و رقم ندارد» | ✅ |
| ۵.۶ `LiveAIProvider` (stub) | `scripts/ai/LiveAIProvider.gd` + `context_for()`؛ `FeatureFlags.LIVE_AI_ENABLED := false` و `live_ai_allowed()` که `with_provider()` را قفل می‌کند | «هیچ فراخوانی واقعی API؛ بازی کاملاً آفلاین» | `test_live_ai_provider.gd` (۵ تست): flag خاموش ⇒ provider هرگز وصل نمی‌شود؛ `get_dynamic_response()` تهی برمی‌گرداند؛ و **نگهبان اجرایی**: هیچ `.gd` در `game/scripts` و `game/scenes` نام یک API شبکه (`HTTPClient`/`HTTPRequest`/`WebSocketPeer`/`URIScheme`/`curl `/`fetch(`/`DuckDuckGo`) را نمی‌برد — کامنت‌ها حذف می‌شوند تا توضیحِ قانون، قانون نشود | ✅ |

**تصمیم‌های ثبت‌شده در این فاز:** ADR-041 (چرخش = cursor داخل کنترلر، نه در `HintTimingSystem`؛
payload سه‌تایی `hint_shown`)، ADR-042 (متن خطا از قالبِ `hint_id`ِ **دوم** می‌آید و بعد از هر
۳ تلاشِ ناموفق همان راهنما تکرار می‌شود؛ به همین دلیل `from_dict` نوع خطای ناشناخته را رد می‌کند)،
ADR-043 (هنر placeholder: هندسه در `_draw`، clipها در `_ready`، صحنه فقط ریشه + اسکریپت؛ `hide_now`
فوری و `hide_soft` ملایم)، ADR-044 (آفلاین‌بودن به‌شکلِ تستِ اجرایی درآمده، نه ادعا).

**شش خطایی که فقط با اجرای واقعی گرفته شدند (نه gdlint/gdparse/validator):**
۱) `JSON.parse_string` هر عددی را **float** می‌دهد؛ `mn is int` روی داده‌ی معتبر همیشه false بود،
   پس کل فایل «بازه Tier نامعتبر» می‌خورد و نمایه تهی می‌شد ⇒ پنج تستِ بی‌ربط هم افتادند.
۲) GUT هر `ERROR` موتور را «unexpected» می‌شمارد: JSON عمداً خراب (`{ this is not json`) یک
   `ERROR: Parse JSON failed` چاپ می‌کند و `Timer` با `wait_time <= 0` یک «Time should be greater
   than zero» ⇒ تست اول با JSONِ درستِ بدشکل بازنویسی شد و دومی با کفِ ۱ ثانیه (حالت «بماند»
   هرگز `start()` نمی‌کند، پس رفتار عوض نمی‌شود).
۳) دو API که در ۴.۷ وجود ندارند: `Label.ellipsis_at` (enum روی `TextServer` است) و
   `Animation.track_set_interp_mode` (درستش `track_set_interpolation_type`) — gdparse فقط پارس
   می‌کند، پس خطای «not found» فقط در load وقت می‌افتد و `DialogueBox.tscn` کامپایل نمی‌شد.
۴) `GutTest` یک Node است نه CanvasItem ⇒ `get_viewport_rect()` نداشت؛ از
   `get_tree().root.get_visible_rect().size` استفاده شد.
۵) `layout_mode`/`anchors_preset` (ویژه‌ی ویرایشگر) در `.tscn` باعث شد `load()` نودِ Nil بدهد؛
   صحنه به «ریشه + اسکریپت» کوچک شد و UI در `_ready` ساخته می‌شود (همان الگوی `LevelResultBar`).
۶) یک تستِ بد از من: رنگ هسته را **بعد از** لوپ با تک‌تک stateها می‌سنجید (یعنی رنگ آخرین حالت)
   ⇒ پنج شکست الکی. ضمناً نگهبانِ فاز ۴ که assert می‌کرد «`aria_templates.json` هنوز وجود ندارد»
   با بستن فاز باید معکوس می‌شد؛ حالا وجودش را تأیید می‌کند و همان ادعای اصلی (نردبان راهنما
   بی‌نیاز از فایل کار می‌کند) سر جایش است.

**انحراف‌ها/افزوده‌هایی که سند ۰۴ نداشت (صریح):** قانون طلایی §۴ در این فاز **سخت‌گیرانه‌تر**
شد: نه‌فقط «عدد جواب نهایی» بلکه **هر رقمی** در هر متن راهنما ممنوع است (چک خودکار در `tools/`
و در GUT)؛ شماره‌ی سطوح و Tier هم از متن‌ها بیرون ماند، چون «سطح ۳» عملاً راهنمایی ضمنی است.
متنِ راهنما دیگر از `HintTimingSystem` نمی‌آید: آن سیستتم فقط `hint_id` می‌دهد (تفکیک مسئولیت،
ADR-041). `DialogueBox` هم عمداً خودش قالب نمی‌خواند، فقط `hint_shown` را می‌شنود.

**بدهی به فازهای بعد:** هیچ صحنه‌ای هنوز `Aria.tscn` + `DialogueBox.tscn` + `AriaController` را در
HUD سطح instantiate نمی‌کند (عمداً به فاز ۶ موکول شد تا HUD با تم و چیدمان واقعی بسازد؛ منطق و
سیگنال‌ها از الان آماده‌اند)؛ clipها placeholder‌اند و فاز ۸ باید همان شش نام را در `Aria.tscn`
بگذارد (`build_placeholder_clips = false` تنها تغییر لازم است)؛ DoD دستی ۵.۳ («بازی با خطاهای
عمدی») در فاز ۱۰ با APK واقعی و در فاز ۱۱ با کودک بسته می‌شود؛ رنگ‌های هسته از `Palette`‌اند و
اگر فاز ۸ تم‌ها را عوض کرد، فقط `CORE_COLORS` ویرایش می‌شود.

### فاز ۶ — UI/UX ✅ (۱۵ کامیت؛ ۶ دور رفع خطا با CI — **CI سبز: ۳۱۵/۳۱۵ تست در ۳۷ فایل**، `a81992e`)
| تسک | خروجی | DoD (سند ۰۴) | شواهد | وضعیت |
|---|---|---|---|---|
| ۶.۱ رشته‌ها + تنظیمات + UIKit | `data/l10n/ui_strings.json` (**۹۱ کلید × ۲ زبان**، سقف ۸۰ نویسه)، `scripts/ui/Loc.gd` (۱۸ تابع ایستا: `t/digits/percent/duration_sec/alignment/text_direction/missing_keys/reset_for_tests`)، `scripts/ui/SettingsStore.gd`، `assets/audio/default_bus_layout.tres` (Master/Music/SFX)، `scripts/ui/UIKit.gd` (`MIN_TOUCH_PX=۱۴۴`، `make_button/make_label/make_raw_label/make_panel/style_button/apply_flow/retranslate/audit_touch_targets`) | «RTL درست؛ رشته‌ها از جدول؛ کفِ لمسی در کد» | `test_loc.gd` (۷)، `test_settings_store.gd` (۱۰: clamp/LRU نبودِ باور به دیسک/تفکیک فایل از مدل)، `test_ui_kit.gd` (۱۰: ممیزی لمسی روی درخت ساختگی، `style_button` که دکمهٔ بزرگ‌تر را کوچک نمی‌کند، قرارداد لرزش) + قانون تازه در `tools/validate_levels.py::check_l10n` (تقارن کلیدها، سقف طول، بی‌رقم‌بودنِ چسبیده به عدد) ⇒ خروجی محلی: «رشته UI: 91×2 ✓» | ✅ |
| ۶.۱ `MainMenu` | `scripts/ui/MainMenu.gd` + `scenes/main/MainMenu.tscn` = **صحنهٔ شروعِ بازی**؛ چهار مقصد (شروع/ادامه، نقشه، تنظیمات، داشبرد والدین، خروج) + `WorldMap.menu_requested` و `LevelLoader.goto_main_menu()` (دو طرفه) | «ورودی/خروجی از هیچ صحنه‌ای بسته نمی‌شود» | `test_main_menu.gd` (۹: برچسبِ دکمهٔ اصلی از وضعیت **واقعیِ** مدل، `continue` فقط وقتی چیزی هست، ممیزی §۷، و `test_navigation_targets_exist` که همهٔ مقصدها را `load()` می‌کند) | ✅ |
| ۶.۲ `Onboarding` | `scripts/ui/Onboarding.gd` + `scenes/main/Onboarding.tscn` + `PlayerAvatarPreview.gd` (آواتار لایه‌ای `_draw` با ۶ تُن پوست/۸ مدل مو/پالت §۴)؛ دو گام: آواتار (chipها در `GridContainer columns=4`) و ترازو = **`LevelController` واقعی** (ADR-۰۵۰) | «آموزش فقط عمل، بی‌متنِ طولانی؛ بی‌آسیب به آمار» | `test_onboarding.gd` (۹: برابری شمارنده‌های chip با `SettingsStore`/`PlayerAvatarPreview`، persist فوری، **برَدنِ آموزش بدون** `levels_completed`/`level_attempts`/`error_patterns`/`aria_transcript_log`، حرکت غلط = نه تلاش نه بازخورد منفی، `skip` فقط گام آواتار، سقف `MAX_LABEL_LEN=40`، ممیزی لمسی + بی‌overflow) | ✅ |
| ۶.۳ `SettingsStore` (فایل جدا) | `user://settings.json` + `SPEC` + چهار `apply_*` (ADR-۰۴۵)؛ `set_value` درمقاوبل/`set_and_save` برای ثبت | «هیچ تنظیمی در `PlayerModel` نمی‌نشیند» | بالا (۶.۱) + assertِ «خروجی والدین کلید `settings` ندارد» در `test_parent_dashboard.gd` | ✅ |
| ۶.۳ `PauseMenu` | `scripts/ui/PauseMenu.gd` + `scenes/ui/PauseMenu.tscn` (root: `PROCESS_MODE_ALWAYS` + `MOUSE_FILTER_STOP`، dim، چهار دکمه ≥۱۴۴) + منطق زمانِ پاز در `GameState` (ADR-۰۴۶) + `LevelController.set_drag_enabled/any_orb_draggable` | «resume از همان لحظه؛ زمان پاز شمرده نمی‌شود» | `test_pause_menu.gd` (۹: فریزِ واقعیِ درخت، کرهٔ درگ‌شونده در میانهٔ پاز رها می‌شود، **مقایسهٔ دو پنجرهٔ زمانی** با ضریب، تنظیمات به‌عنوان اورلی ⇒ هیچ `change_scene`/reload، و `allow_scene_change=false` برای هدلس) | ✅ |
| ۶.۳ `SettingsMenu` | `scripts/ui/SettingsMenu.gd` + `scenes/ui/SettingsMenu.tscn`: دو `HSlider` (+ `CheckButton` لرزش + دو دکمهٔ زبانِ disabled روی فعال)، اثر **فوری** روی `AudioServer`/`Loc`، بدون دکمهٔ «ذخیره» | «صدا و زبان زنده؛ بدون reload» | `test_settings_menu.gd` (۷: ولومِ صفر = mute روی باس، `apply_locale` و عوض‌شدن برچسب‌های **همان صحنهٔ باز**، «widgets show what is stored» = ویجت‌ها از فایل می‌خوانند نه از حدس) | ✅ |
| ۶.۴ `HUD` | `scripts/ui/HUD.gd` + `scenes/gameplay/HUD.tscn` (root `mouse_filter=IGNORE` + اندازهٔ صریح ۱۰۸۰×۱۹۲۰)؛ دکمهٔ راهنما، پیپ‌های پیشرفتِ Tier، **و بدهی فاز ۵ بسته شد**: `AriaController` + `Aria.tscn` + `DialogueBox` داخل صحنهٔ سطح؛ `LevelController.open_pause/close_pause` + `ui_cancel` | «دکمهٔ راهنما همان نردبان فاز ۴ را صدا می‌زند» | `test_hud.gd` (۹: هر پرس = یک پله بالاتر (`gentle_nudge_01` → `socratic_operation_01`) و **دقیقاً یک** `register_hint_used` در هر دو مسیر نردبان/fallback، سطحِ بی‌راهنما = نه سیگنال نه شمارنده، پیپ‌ها از `levels_for_tier` + `levels_completed`، متن راهنما **عیناً** یکی از واریانت‌های فایل و `hint_light` روی آواتار، پاز با دکمه و با `ui_cancel`، `Intro` جابه‌جا شد تا زیر نوار HUD برخورد نکند) | ✅ |
| ۶.۵ `ParentDashboard` + قفل | `scripts/ui/ParentGate.gd` (ADR-۰۴۷)، `MasteryChart.gd` (میله‌ها از `skills.keys()`)، `ParentDashboard.gd` + `scenes/ui/ParentDashboard.tscn`؛ `record_hint_shown(..., text)` به `AriaController.show_hint()` وصل شد (ADR-۰۴۸)؛ kill-switch تطبیق؛ خروجی JSON به کلیپ‌بورد | «داشبورد = دقیقاً دادهٔ `PlayerModel`» | `test_parent_gate.gd` (۷: «پاسخ روی هیچ Label/Button صفحه نیست»، ارقام فارسی/عربی، Enter خالی یک حق را نمی‌خورد، سه اشتباه = قفلِ نشست) + `test_parent_dashboard.gd` (۹: مدلِ ساختگی ۳ سطح/۳۶۶۱٫۵s/۲۳٫۴٪/۴۲٫۵s/Elo ۱۱۲۰ ⇒ متن‌ها با `Loc.duration_sec/percent/digits` برابری می‌کنند، `fill` میله = `(elo-۴۰۰)/۱۶۰۰`، **۱۲۰ ردیف لاگ کامل و قابل‌اسکرول**، `error_patterns` بزرگ‌ترین‌اول با نامِ فارسی، خاموش‌کردن تطبیق **فوراً** به موتور، JSON خروجی معتبر و بی‌`settings`، و حلقهٔ بسته: پرس دکمه ⇒ `text` در لاگ مدل) + قانون CI: هر `concept_tag` باید `skill.<tag>` را در **هر دو زبان** داشته باشد (سه tag ناقص را همان دور گرفت ⇒ ۱۶ برچسب اضافه شد) | ✅ |
| رفع خطاهای CI (۶ دور) | `4f44435`, `3cf3140`, `60d4935`, `e1aa8ef`, `49095c4`, `c2f33d4` + دو کامیت ۶.۳/۶.۴ (`81cd080`, `7ce2c32`) | — | فهرست ۱۳ خطای پایین ⇓ ⇒ **نتیجهٔ نهایی CI: `Scripts 37 / Tests 315 / Passing 315 / Failing 0`** ✓ (دو دور آخر برای `assert_watch_signals` نبودن و دامِ پارامتر چهارم GUT صرف شد؛ هر دو درس در همین جدول‌اند) | ✅ |

**DoD فاز ۶ (بسته‌شده):** کفِ لمسی ≥ ۴۸dp با ممیزیِ خودکار روی هر ۹ صحنهٔ UI ✓ RTL +
wrap + سقفِ طولِ رشته‌ها ✓ تنظیماتِ زندهٔ صدا/زبان بدون reload ✓ پازِ واقعی با کسرِ زمان ✓
و داشبورد = دقیقاً `PlayerModel` (برابریِ متن‌ها با `Loc.digits/percent/duration_sec`) ✓
پیش‌نیازِ فنیِ `test_ui_kit.gd`: خودِ ابزار ممیزی هم تست می‌شود (ADR-049).

**جمع تست:** ۳۷ فایل / **۳۱۵ تست** در CI (فاز ۵: ۲۷ فایل / ۲۲۹ ⇒ **+۸۶ تست تازه، بدون هیچ تستِ گمشده** ✓
گارد «Scripts == تعداد فایل روی دیسک» (`ADR-033`) سه بار ثابت کرد بدون آن، «سبز» یعنی هیچ‌چیز ✓).

**۱۳ خطایی که فقط با اجرای واقعی گرفته شدند (نه gdlint/gdparse/validator):**
۱) `Control.TEXT_ALIGNMENT_*` (نامِ Godot 3؛ در ۴ جهانی است) در `Loc.gd` ⇒ **یک** Parse Error در
   پایین‌ترین لایه، `UIKit` را بی‌کامپایل کرد و ۵۸ تست با پیامِ بی‌ربطِ «Nonexistent function
   'make_button' in base 'GDScript'» قرمز شد ✓ درس: زنجیره را از ریشه بخوان، نه از تعداد شکست‌ها.
۲) `NodePath.to_string()` در ۴ وجود ندارد ⇒ همان کلاس خطا، در `audit_touch_targets`.
۳) `assert_watch_signals()` در GUT نیست (درستش `watch_signals`) ⇒ **۶ فایل تست بارگذاری نشدند**
   و یک تست از آنها اجرا نشد؛ گارد کشفِ تست، صحنه را لو داد (Scripts 31 از 37).
۴) `DisplayServer.clipboard_write` در ۴ شده `clipboard_set` ⇒ یک سطر، کل `ParentDashboard.gd`
   کامپایل نشد و فایل تستش هم `Compilation failed` گرفت.
۵) `UIKit.apply_flow` به **هر** کنترلی `text_direction` می‌داد؛ `ColorRect` این عضو ندارد ⇒
   خطای زمان‌اجرا (runtime) در هر صحنه‌ای که HUD/پاز دارد (~۷۰ تست) ✗✓ قاعدهٔ تازه (ADR-۰۵۱): پیاده‌روی UI
   بر پایهٔ کلاسِ صریح، هرگز `is Control`.
۶) `retranslate()` **بعد از** ست‌کردن متن، برچسب پویا را می‌خورد ⇒ «ادامه‌ی بازی» هرگز روی دکمه
   نمی‌نشست؛ اصلاح: کلید در `meta["loc_key"]`، نه متن (ADR-۰۵۱).
۷) `needs_onboarding()` پرچم `is_first_run` را بر **رکوردِ** `onboarding_done` مقدم می‌داد ⇒
   اتمامِ ثبت‌شده بی‌اثر؛ ترتیب عمداً برعکس شد.
۸) `commit_playtime` pauseِ باز را در دو commit پشت‌سرهم کم می‌کرد ⇒ زمانِ واقعیِ بازی **صفر**
   («زمان بازی» والدین دروغ می‌شد ✓ ADR-۰۴۶) ⇒ شمارندهٔ «پازِ کسرشده» (`billed`) اضافه شد.
۹) ممیزِ لمسی، **ریشه** را گزارش می‌کرد نه متخلف را و `custom_minimum_size` را **جای** `size`
   می‌گذاشت نه `max` ⇒ در هدلس (layout=۰) هر دکمه‌ای محکوم می‌شد؛ ابزارِ DoD هم باید تست شود.
۱۰) دو تست به **ترتیب اجرا** وابسته بودند (`test_settings_menu` پرچم موتور را خاموش می‌گذاشت ⇒
   `test_settings_store` ادعای بی‌معنی) ⇒ هر دو خودکفا + ذخیره/بازگردانی در `after_each`.
۱۱) `assert_eq(str(x), "<Null>")`: در Godot ۴ مقدار `str(null)` برابر `"<null>"` است ⇒ جای
   مقایسهٔ رشته‌ای، `assert_null` (ادعای واقعی: کلید ناشناخته تهی می‌دهد نه ۰/false).
۱۲) تستِ `test_the_widgets_show_what_is_stored` برای اثبات «اسلایدر فوکوس‌ناپذیر است» خودش
   `menu.music_slider.grab_focus()` را صدا می‌زد ⇒ خطای موتورِ «This control can't grab focus»
   (که GUT شکست می‌داند) درحالی‌که **خودِ ادعا درست بود** ✗✓ قانون تازه: ادعا را بسنج، نه
   شکستِ عمدی‌اش را — `assert_eq(slider.focus_mode, FOCUS_NONE)` کافی و بی‌خطاست.
   (نکته: `ParentGate` همان فراخوانی را دارد ولی `focus_mode = FOCUS_ALL` ⇒ مجاز ✓ و
   کامنتی که آن را متهم می‌کرد اصلاح شد؛ ادعای نادرست روی کد، خودش باگ است.)
۱۳) امضای GUT ناسازگار است: `assert_signal_emit_count(..., msg)` پیام می‌گیرد ولی
   `assert_signal_emitted_with_parameters(obj, sig, params, **index**)` پیام **ندارد** ⇒ سه فراخوانیِ
   من، رشته را به‌عنوان index به `_signal_watcher` می‌دادند و **داخل خودِ GUT** با
   «Invalid operands 'String' and 'int'» + «Nonexistent function 'size' in base 'Nil'» می‌ترکید،
   بدون اشاره به فایل من ✗ (سه دور CI سوخت) ⇒ `tools/ci_annotate.py` هم اصلاح شد: جزئیاتِ بعد از
   `[Failed]` و خطِ `at: file:line` حالا در annotation می‌آیند (با لاگ ساختگی آزموده شد ✓).

**انحراف‌ها/افزوده‌هایی که سند ۰۴ نداشت (صریح):** «متنِ طولانی نداریم» به دو قانونِ قابل‌سنجش
شکست شد: هر برچسب ≤ `40` نویسه و ≤ ۵ برچسبِ نمایان در هر گام (ADR-۰۵۰؛ کپشنِ سه ردیفِ انتخاب لازم
بود)؛ تنظیمات **روی** پاز سوار می‌شود نه صحنهٔ جدا (تضمینِ resume بدون reload)؛ داشبورد هر عددی را
از مدل می‌خواند و هیچ میانگینی در UI حساب نمی‌کند؛ `MasteryChart` از `skills.keys()` می‌سازد، پس
مفهومِ تازهٔ فاز ۷ خودکار در داشبورد می‌نشیند و `skill.<tag>` اجباری است؛ `ParentGate` عمداً
امنیت نیست (ADR-۰۴۷)؛ و آواتارِ کودک در همین فاز `_draw` شد (هنر نهایی فاز ۸) تا انتخابِ §۴
زودتر از «جای‌گذارِ خاکستری» آزمون پس بدهد.

**بدهی به فازهای بعد:** (الف) `assets/fonts/` خالی است ⇒ همه‌جا `ThemeDB.fallback_font` و
`Loc` رقم‌ها را دستی تبدیل می‌کند؛ فونت بچگانه + `Theme` رسمیِ §۷ فاز ۸ (با `retranslate` هیچ
ارتباطی ندارد و نباید اشتباه گرفته شود). (ب) `assets/audio/*` فقط `default_bus_layout.tres` را دارد؛
`AudioManager` و فایل‌های واقعی فاز ۷.۶/۸ (باس‌ها از الان جدا و تست‌شوند ⇒ فقط `load` عوض می‌شود).
(ج) DoD دستی ۶.۲/۶.۳ («با کودک تست شود») به فاز ۱۱. (د) آمارِ داشبورد روی دادهٔ **محلی** است؛
`POST /api/events` (فاز ۹) هنوز هیچ فراخوانی ندارد و بازی کامل آفلاین می‌ماند ✓ (نگهبان
`test_live_ai_provider.gd`). (ه) اگر owner قفلِ واقعی (PIN) بخواهد: ADR-۰۴۷ باید با یک ADR تازه
بازبینی شود، چون بازیابیِ PIN یعنی دادهٔ شخصی ✗.

### فاز ۷ — محتوا 🟢 (در جریان)
۷.۱..۷.۴ Tier 2..5 (≈ ۸-۱۲ سطح هر Tier؛ جمع MVP ≈ ۴۰-۵۰ سطح) · ۷.۵ `story_beats.json` · ۷.۶ `AudioManager`
قاعده‌ی من: هر سطح **تولید + اعتبارسنج** می‌شود (validator)، سپس به‌صورت bot در CI تست می‌شود؛ محتوای بدون تأیید merge نمی‌شود.

**ثبت اجرا:**

| تسک | کامیت | خروجی | سنجش | وضعیت |
|---|---|---|---|---|
| ۷.۰ باتِ محتوا | `6fb51e8` | `tests/gut/test_all_content_playable.gd`: پنج تستِ کشف‌محور (Loader همهٔ فایل‌ها را می‌بیند ✓ بردِ `solution_spec.intended` در موتورِ واقعی ✓ باختهٔ `wrong_ops` ✓ قابل‌تحویل‌بودن هر `hint_id` ✓ رابطهٔ Elo بین Tierها ✓) + سه قاعدهٔ تازه در `validate_levels.py` | gdlint/parse ✓ · validator ۱۵/۱۵ ✓ | ✅ |
| ۷.۱ Tier 2 | `6fabebd` | ۱۰ سطح `data/levels/tier2/level_2_01..10.json` — mechanic «بدهی/عدد منفی»، Elo ۱۱۰۰..۱۴۶۰، بدون رقم در هیچ راهنما، یک `tolerance: 0.5/approx`، یک «فقط با بدهی حل می‌شود»، یک «یک کره کافی است» | `target_value = sum(left) − sum(right_fixed)` از حساب ساخته شد، نه از دست ⇒ `LevelData.validate()` + DPِ ابزار + باتِ GUT هر سه ✓ | ✅ |
| ۷.۱b صفحه‌بندی نقشه | `67ebcd7` | `WorldMap` صفحه‌بندی‌شده (صفحاتِ داخلِ Tier، متوازن) + `common.previous/next` + سه تستِ کهنه به استنتاج از دیسک | ADR-052: با ۱۵ سطح نودها روی هم می‌افتادند ✗✓ باگِ واقعیِ UI که فقط با رشدِ محتوا دیده می‌شد | ✅ |
| ۷.۱c قاعدهٔ «هیچ زیرمجموعه‌ای نبَرَد» | e43bdc4 | subset-check در `validate_levels.py` + چیدمانِ یکی‌یکی در بات + دادهٔ ۲_۰۱/۲_۰۷ | ADR-053: بات، دو سطح را که `wrong_ops`شان «حلِ درست + یک کره» بود رد کرد ✓✓ | ✅ |
| ۷.۲ Tier ۳ | (این کامیت) | ۱۰ سطح `data/levels/tier3/` — شبح (`ghost_orbs`) + کسر، Elo ۱۵۰۰..۱۶۸۰، یک سطح `tolerance: 0.25` | `validate_levels.py`: **۲۵/۲۵ قابل‌حل** ✓ · قاعدهٔ «مضرب ۰٫۲۵» و «شبح در سینی ممنوع» (ADR-054) | ✅ |
| ۷.۳ Tier ۴ | (این کامیت) | اسکیمای `scales` در `LevelData` + چهار قاعدهٔ تازه در ابزار + باتِ چندکفه + **۱۰ سطح Tier ۴** (دو ترازو، سینیِ مشترک) | ADR-055 · `validate_levels.py`: **۳۵/۳۵ قابل‌حل** ✓ (با پروبِ عمدی: چهار شکلِ مبهم قرمز می‌شوند ✓ «قاعده را بسنج، نه فقط سبز بودنش») | ✅ |
| ۷.۴ Tier ۵ | `c855a43` + `871add6` | `_row_values`ِ علامت‌دار در ابزار + **۱۰ سطح Tier ۵** (۷ دوکفه، ۳ تک‌کفه، همه `word_problem`) | ADR-056 · `validate_levels.py`: **۴۵/۴۵ قابل‌حل** ✓✓ · ⚠️ **CI این دور اجرا نشد**: `.git` سندباکس بازسازى شد و اتصال GitHub `401` داد ⇒ شواهد CI = ۷.۷/بازنشانیِ اتصال | ⏳ |
| ۷.۵ روایت | `b64f398` + `393c37b` | `story_beats.json` (۶ بیت / ۲۹ خط: افتتاحیه ← سه نقطهٔ عطفِ ورودِ Tier ← قله ← ترمیمِ «ترازوی بنیادین») + شش قاعده در `validate_levels.py` + `test_story_beats.gd` (۵ تست) | گریل: رقم در روایت ✗✓ · «؟» آریا در هر بیت ✓ · `ambient_art` = منطقهٔ همان Tier ✓ · لنگرِ همبستگی افتتاحیه↔پایان ✓ (پروبِ عمدی: هر شش قاعده قرمز شد ✓✓) | ✅ |
| ۷.۶ صوت | `a42f6a1` · `07d52be` · `e0aafca` | `AudioManager` (autoload) با **سنتزِ رویه‌ای** ۱۷ شناسه ✓ `audio_assets.json` (لیستِ سفارش: ۹ SFX + ۸ موزیک/استینگر با `max_sec/when/note/final_file`) ✓ دریِ باس‌ها از پروژه و سکوت از باس ✓ ۸ تست + جاروی ۱۷۰ فایل | ADR-057 · CI ✅ (۴۰ فایل / ۳۳۵ تست) ✓ یک خطای واقعیِ load در همین دور گرفته شد (`connect(_on_aria_state)` ✗) که **مینی‌چکِ self-method را گسترش داد**: حالا `connect/bind/Callable` هم سنجیده می‌شود ✓✓ | ✅ |

**جمع محتوا:** **۴۵ سطح از ≈۴۵ ✓ کامل** (Tier ۱: ۵ · ۲: ۱۰ · ۳: ۱۰ · ۴: ۱۰ · ۵: ۱۰) (Tier ۱: ۵ · Tier ۲: ۱۰ · Tier ۳: ۱۰ · Tier ۴: ۱۰) · Elo پیوسته ۹۰۰→۱۸۸۰ · `validate_levels.py`: «قابل‌حل تأییدشده: ۳۵/۳۵».
**بدهیِ تازه:** (۱) کره‌های `fixed`/شبح قابل کشیدن‌اند ⇒ تصمیمِ owner برای قفلِ جابه‌جایی (ADR-054 «پیامد الف»)، (۲) `scales` در فایل/اسکیمای `LevelData` قبل از ۷.۳، (۳) `ghost` در باتِ محتوا فعلاً از راه `target_value` سنجیده می‌شود؛ اگر Tier ۴/۵ «دو کفه» آمد، بات هم `scales` را باید بسنجد. (۴) GUT در همه‌ی دورها `Orphans 1` گزارش می‌کند ⇒ یک نودِ آزاد در مجموعهٔ تست (ریشه‌اش قبل از فاز ۷ است و با Tier ۲/۳ تغییر نکرد)؛ پاک‌سازی‌اش به فاز ۱۰ واگذار شد چون «نشت نود» در اجرای واقعیِ اندروید مهم است، نه در دادهٔ محتوا ✓.

**وضعیت CI این دور:** `gdlint + content validation` ✅ و `Godot import + GUT` ✅ روی `ea98b71` ⇒
**۳۸ فایل تست / ۳۲۰ تست، بدون شکست** (هر پنج تستِ باتِ محتوا روی دادهٔ واقعی اجرا می‌شود:
برَدِ `intended` و باختِ `wrong_ops` برای هر ۱۵ سطح ✓✓ «Annotate failures => skipped» یعنی
هیچ `[Failed to load script]` هم نمانده ✗✓ این مهم بود: در دو دورِ قبل، GUT فایل‌های
parse‌نشده را **بی‌صدا رد می‌کرد** و خلاصه هیچ «کمبودِ پوششی» نشان نمی‌داد).
DoD ۷.۱ بسته شد: هر سطح Tier ۲ هم در validator و هم در موتورِ واقعی سنجیده می‌شود، و هیچ
راهنمای عددی به کودک لو نمی‌رود (قاعدهٔ «بدون رقم» ✓) و هیچ حرکتِ «اشتباهی» برنده نیست (ADR-053 ✓).

**دو درسِ الزامی برای ۷.۲..۷.۴:** (۱) تستی که «فازِ بعدی هنوز نیامده» را فرض می‌کند، فردا
علیه ما می‌ایستد ⇒ هیچ شمارشِ محتوایی به‌صورت عددِ دست‌نویس در تست نمی‌ماند؛ (۲) محتوا UI را
هم می‌شکند ⇒ هر Tierِ تازه با `test_world_map.gd` و ممیزیِ `UIKit` سنجیده می‌شود، نه فقط validator.
**وضعیت CI ۷.۳ (پنج commit → ✅ سبز):** `a85135a` اسکیمای چندکفهٔ `LevelData` · `d5255f2` ابزار + بات · `63631d8` ده سطح Tier ۴ + ADR-055 · `eb61f87` بازگرداندن `_scene_for` · این commit ⇒ **۳۸ فایل / ۳۲۲ تست / صفر شکست** ✓✓ و `validate_levels.py`: «۳۵ سطح · ۳۵/۳۵ قابل‌حل · قالب دیالوگ ۱۸ · رشته UI ۹۳×۲» ✓ — وجهِ تازهٔ این دور: Tier ۴ در موتورِ واقعی **بَرده می‌شود** (باتِ GUT از روی JSON) با دو کفهٔ هم‌زمان و سینیِ مشترک ✗✓ کره روی **کفهٔ مقصدش** می‌نشیند (`place_on_right(..., scale_index)`) نه «هر کفه‌ای» ✓ و همان حل با **ترتیبِ معکوس** هم می‌بَرَد ✓ (اگر ترتیب، حالتِ برد را عوض کند، سطح «حدسِ ترتیب» است نه ریاضی ✗).

**دو درسِ فرآیندیِ ۷.۳ — الزامی برای ۷.۴:** (۱) بعد از **هر** جراحیِ خط‌محور، فهرست `func` را با commit والد مقایسه کن ✗✓ `_scene_for()` و `test_every_level_id_on_disk_is_discoverable_by_the_loader` داخل بلوکِ بازنویسی‌شده می‌رفتند؛ اولی CI را قرمز کرد و دومی **سبزِ بی‌صدا** ماند ✗✗ — اگر شمارش تست‌ها (۳۲۰) چک نمی‌شد، امشب «پوشش کامل» را بر پایهٔ فایلی می‌نوشتیم که یک ادعایش پریده ✓✓ (`git show <parent>:f | grep -c '^func test_'` = ۳۰ ثانیه ✓ حالا ۳۲۲). (۲) `gdparse` خطای «Function `_x()` not found in base self» را **نمی‌فهمد** ✗✓ Godot آن را در load می‌دهد و کل فایل را رد می‌کند ⇒ مینی‌چک دستی (هر `_name(` صدازده‌شده باید `func _name` داشته باشد) که این دور صفرِ باقی‌مانده داد ✓✓ اگر بارِ سوم تکرار شد، به `tools/` می‌رود ✗ فعلاً قاعدهٔ دستی.
| ۷.۷ بستنِ فاز ۷ | (این کامیت) | **DoD ۷**: ۴۵ سطح (۴۰..۶۰ ✓ `04`) · منحنی Elo پیوسته ۹۰۰→۱۹۹۰ (پرِش‌های بین‌Tier: +۴۰/+۴۰/+۲۰/+۲۰ ⇒ همه ≤ ۱۲۰ ✓ و درون‌Tier گام ۱۰-۲۰ ✓) · «آریا جواب نمی‌گوید» در **سه** لایه (قالب راهنما ✗ بیت روایت ✗ `max_sec`ِ راهنما ✗ + ممنوعیتِ رقم ✓✓) · روایتِ ۶ بیتیِ منسجم با لنگرِ ترمیم ✓ · صدایِ placeholder integrate‌شده بدونِ باینری ✓ · آفلاین در مسیرِ بازی ✓ (تنها نقطهٔ شبکه `LiveAIProvider` پشتِ `FeatureFlags.LIVE_AI_ENABLED` است ✓ و در build بسته ✓ ⇒ صفرِ ترافیکِ کودک ✓ §۹/ADR-010) | `validate_levels.py`: «۴۵ · ۴۵/۴۵ · قالب ۱۸ · UI ۹۳×۲ · بیت ۶ · صوت ۱۷ · ✔» و CI: **۴۰ فایل / ۳۳۵ تست / صفر شکست** روی `e0aafca` ✓✓ (گاردِ ADR-033 ⇒ همهٔ فایل‌ها بارگذاری شده‌اند ✗✓) | ✅ |

**بستنِ فاز ۷:** مواردِ `04` که به **محتوا** مربوط‌اند همه سبزند ✓؛ سه موردِ دیگرِ آن چک‌لیست
(«APK امضاشده روی دو گوشی»، «پلی‌تستِ واقعی»، «صفر PII در ترافیک شبکه») به‌ترتیب فاز ۱۰، ۱۱ و ۹/۱۲
هستند ✗✓ و در `docs/05` جای خود را دارند ⇒ **فاز ۷ تمام شده اعلام می‌شود** و ورود به فاز ۸
(هنرِ نهایی، SVG-first) منتظرِ تأییدِ owner است ✓ (`ادامه بده`).

### فاز ۸ — هنر نهایی (SVG-first، ADR-007)
۸.۱ Aria (ایکوساهدرون با `Polygon2D`/`CustomDraw` + shader هسته؛ ۶ حالت) · ۸.۲ آواتار لایه‌ای · ۸.۳ ۵ محیط + Hub (هر کدام ۲ حالت ویران/بازسازی) · ۸.۴ UI skin + تم · ۸.۵ آیکون کره‌ها.
DoD: چک‌لیست `02` §۸ برای هر دارایی؛ تست سیلوئت (رندر سیاه‌وسفید) خودکار؛ وزن دارایی‌ها ≤ سقف §۳.

**وضعیت فاز ۸ (۸.۱ ✅ · ۸.۲ ✅ · ۸.۳ ✅ · ۸.۴ ✅ · ۸.۵ ✅ — اثباتِ CIِ دو کامیت آخر ۸.۴ در بلوکِ ۸.۴):** ۸.۱ با همان چیزی که خودِ سطرِ برنامه گفته
بود بسته شد — «ایکوساهدرون با `Polygon2D`/`CustomDraw` + shader هسته؛ ۶ حالت» ✓✓:
`AriaCrystal` بیست‌وجهیِ واقعی شد (رأس‌ها از φ، وجه‌ها از متریک ✓ ADR-058)، هسته با
`game/assets/shaders/aria_core.gdshader` (گرادیان شعاعی از `VERTEX`، رنگ از `self_modulate`
✓§۸)، `radius` ۳۴→۲۶ تا قطر در ۴۰..۶۰ بنشیند ✓، و جدولِ `MOODS` سرعت/روشنایی/رنگِ رگه‌ها
را به §۳ تیون کرد (thinking کندتر، concerned کم‌فروغ‌تر، hint پالسِ جهت‌دار، celebrating
Teal روی رگه‌ها ✓✓). **تفسیرِ DoD برای CIِ هدلس** (و دلیلاش در ADR-058): «تست سیلوئت» =
ممیزیِ هندسه/کنتراست روی سورس ✓ نه readbackِ پیکسلی؛ رندرِ واقعی + قضاوتِ چشمیِ §۸ روی
دستگاه = فاز ۱۰ ✓✓. گیتِ `tools/validate_levels.py` هم «صفرِ PNG/JPG در `assets/art`» و
«سقفِ وزن `game/assets`» را چک می‌کند ⇒ ۸.۲..۸.۵ زیرِ همان سقف کار می‌کنند ✓.

۸.۵ هم بسته شد ✅ (`ADR-059`): سه نوع کره از **فرم** متمایز شدند (کریستالِ دوازده‌وجهیِ
پر + پرتوها / حلقه‌ی نور با سه دنباله / حبابِ بازِ پایین با حبابکِ اقماری) ✓§۶ و «تست
سیلوئت» به `signature_distance ≥ 3` + «کنتراستِ رقم/بدنه ≥ ۰٫۲» + «کفِ قطر ۶۴px» ترجمه شد
✓✓ (۱۱ تست در `test_orb_silhouettes.gd`). یک باگِ واقعیِ همین تسک را همان تست کُشت: دهانه‌ی
حباب در نسخهٔ اول به سقف می‌رفت و span از ۲π رد می‌شد ✗✓ (`bubble_arc_start/span` حالا تابع‌اند
و عددشان سنجیده می‌شود ✓✓). باقیِ فاز: ۸.۲ آواتار لایه‌ای · ۸.۳ پنج محیط با ≥۲ حالت ·
۸.۴ UI Skin (فونت + Theme + آیکون‌های SVGِ ایستا) ✓ · **۸.۲ ✅** (ADR-060):
آواتارِ لایه‌ای نهایی شد — نسبت سر:بدن دقیقاً ۱:۳ (§۴ ✗ بود: ۱:۱٫۶ ✓ اصلاح شد)، هشت مدل مو
به‌صورت **هشت دیکشنریِ هندسه** (بافت smooth/coiled/braided/wavy و طول ۰٫۰۴..۰٫۶۲) ⇒ ۴۸ ترکیب
با ریاضی سنجیده می‌شوند نه با چشم ✓✓، «دفترچهٔ مهندسی» §۴ اضافه شد (بی‌اسلحه ✓)، و
`fit_box` مقیاس را مدل‌به‌مدل تنظیم می‌کند تا هیچ مدلی به ردیفِ سواچ‌ها نخورد ✓ (همان
«گلیچِ بصری» که DoD منع می‌کند). دو فهرستِ مجازِ رنگ (`Palette.SKIN_TONES` و
`SettingsStore.HAIR_COLORS` با سه سواچِ پالتی ✓✓) تعارض §۴/§۸ را قانون کرد، نه سلیقه ✓
۱۴ تست در `test_player_avatar.gd` (۴۳ فایل / ۳۷۳ تست) ✓ و دو گیتِ تازهٔ ابزار:
`check_class_registry()` (کلاس‌های عمومی: ۳۴) و `check_text_hygiene()` (سه کاراکترِ چینیِ U+8FD0 در
`UIKit.gd`/`docs/05`/`docs/06` پیدا و «زمان‌اجرا (runtime)» شد ✓؛ اسناد ۰۰..۰۴ فقط ⚠
می‌گیرند چون سندِ مالک است — یک حاشیهٔ ترجمه در §۳ سند ۰۲ برای تأیید شما مانده ✓).

**۸.۳ ✅** (ADR-061): پنج محیط + Hub با **یک** کلاسِ برداری ✓ (`game/scripts/environments/RegionBackdrop.gd`،
`enum Region{HUB,MEADOW,CAVERNS,RUINS,OBSERVATORY,SUMMIT}` ⇔ نام‌های §۵ ✓ صفر فایلِ تصویری ✓✓).
§۵ دو چیز «با چشم» می‌خواست و هر دو به تابعِ خالصِ تست‌شدنی ترجمه شدند ✗✓ (قاعدهٔ ADR-058):
• **«هر منطقه ≥۲ حالتِ بصری»** ⇒ `signature(region, restoration)` هفت ویژگی می‌دهد و
  `signature_distance(sign(r,0), sign(r,1)) ≥ 2` برای **هر شش** منطقه سنجیده می‌شود ✓✓ و
  برای هر *جفتِ* منطقه در یک بازیابی هم ≥۲ (وگرنه «پنج محیط» فقط پنج نام بود ✗) ⇒
  جدول‌های `RUIN_BASE`/`BRIDGE_TOTAL`/`PROP_DENSITY` عمداً شش عددِ **متفاوت‌اند** ✓✓.
• **«ویرانی مستقیماً با پیشرفتِ همان Tier کم شود و پل‌ها ساخته شوند»** ⇒ تنها ورودیِ بصری
  `restoration = GameState.tier_restoration(tier) = سطح‌پوشده / کلِ سطوحِ آن Tier` است ✓ (APIِ
  تازه؛ تست: ۲ از ۵ ⇒ ۰٫۴ ⇒ دقیقاً دو پل از پنج پل ✓✓ هیچ وزن/Elo/انحرافِ پنهانی در مسیر
  هنر نیست ✓) و `bridges_built()` یکنوا با `p≥0.999 ⇒ کلِ پل‌ها` ✓؛ `world_restoration()` =
  میانگینِ پنج Tier برای Hub ✓ (تست: یک Tierِ تمام ⇒ ۰٫۲ ✓✓). `brokenness = RUIN_BASE·(1-p)` ✓.
• **خوانایی بر زیبایی**: `LAYER_ALPHA_MAX = 0.46` سقفِ **هر** آلفا (حتی `edge_alpha` خطِ پل ✓)
  ⇒ کفه/کره و عددِ روی آن خوانا می‌مانند §۷ ✓✓ و پلانِ لایه‌ها **دقیقاً** `1 sky + 3 ridge/isle +
  پل‌ها + عنصرها + 1 light` است (`assert_eq` با فرمول، نه عددِ شعاری ✓✓).
• **تک‌حقیقتِ واژگان**: `check_ambient_art_vocab()` نام‌ها را با regex از خودِ `REGION_NAMES`
  می‌خواند و به `ambient_art`های `story_beats.json` قفل می‌کند ✗✓ فهرستِ دومی وجود ندارد؛
  پروب‌های قرمز: نامِ غلط / منطقۀ بی‌روایت («هنرِ مرده») / بی‌`ambient_art` / شکلِ اعلامِ عوض‌شده ✓✓
  و در موتور هم `test_narrative_ambient_art_resolves_to_regions` همان را می‌سنجد ✓ ۵/۵ ✓.
• **پالت**: هیچ `#rrggbb` در `scripts/environments/*.gd` (تستِ regex ✓§۲ «فقط پالت رسمی») و
  تنها `Color(.)` مجازِ فایل `SHADOW_VEIL` است ✓✓؛ `_draw` هم `lerpf(/darkened(/base(/Palette.`
  ندارد ⇒ هر تصمیمِ بصری در `static` است، `_draw` فقط `match` می‌کند ✓✓ (ADR-058 بسته‌بندی‌شده).
• **سیم‌کشی**: `WorldMap` (صفحۀ ۰ = Hub و صفحۀ n = منطقۀ Tier n ✓ روی `level_completed` هم
  تازه می‌شود) و `LevelController` (بک‌گراندِ همان Tier + تویینِ ۱٫۲ ثانیه‌ای ⇒ «لحظۀ ساختن»
  دیده می‌شود ✓§۵)؛ `z_index = -20` **در خودِ کلاس** و نوع `Node2D` و نه `Control` ✗✓ (درسِ ۷.۴:
  بک‌گراندِ Control کلیک‌ها را می‌خورد)؛ `_process` با `is_visible_in_tree()` خاموش می‌شود ✓§۹؛
  `Sky`ِ ColorRectِ فاز ۳ حذف نشد، فقط `visible=false` شد ✓ تا fallback بماند (هر دو تست دارند ✓).
**سه دورِ قرمزِ ۸.۳ و درس‌هایشان (ثبت ✓✓):** (۱) سه خطایی که فقط Godot می‌بیند: عضوِ enum از
بیرونِ فایل (`RegionBackdrop.HUB` ✗✓ ⇒ `region_for_tier(0)` / `region_named("Sunlit Meadow")` — تست هم‌زمان
قفلِ واژگان شد ✓✓)، `assert_false(bd is Control)` که خودش خطای parse است ✗✓ ⇒ `get_class()`، و
و **سوم** (هر سه در یک دور، همه «فقط-Godot»): `	_ensure_backdrop()` که spliceٔ خطیِ من به انتهای `static func default_config()` ته‌نشین شده بود
⇒ «Cannot call non-static function» ⇒ ۶۲ تستِ بی‌گناه قرمز ✗✗ (ریشۀ من: الگوی `^func` که
`static func` را top-level نمی‌شناخت ✓). (۲) `Window.get_visible_viewport_rect()` — نامی که **ساختم** ✗✗
⇒ `get_visible_rect()` ✓ و گیتِ `PHANTOM_API` زاده شد تا نامِ ساختگیِ دوم بسوزد ✓ (قاعده: هر
نامی که Godot «nonexistent function» گفت، اینجا می‌نشیند ✓✓؛ هر قاعده هم یک پیام، تا صدایِ
گیت رقیق نشود ✓). (۳) پیامِ یک کامیت هم یک کاراکترِ CJK داشت ✗ (گیتِ فعلی `.gd/.md` را می‌بیند،
نه `git log` ⇒ `commit-msg` hook اگر لازِم شد فاز ۹ ✓). سه گیتِ تازهٔ ابزار از همین دورها زاده
شدند: `check_script_duplicates()` (**`gdparse --check-only` دو `func _ready()` را می‌بخشد** ✗✗ امروز
واقعاً رخ داد)، `check_static_isolation()` (با پروب قرمز/سبز ✓ و مخزن امروز صفر تخلف ✓)، و
`check_ambient_art_vocab()` ✓؛ `CLASS_REGISTRY` هم ۳۴ → ۳۵ نام ✓.

**۸.۴ ✅** (ADR-062): پوستۀ §۷ از «عددِ ثابت در `UIKit`» به «**اعمال‌شدن**» رسید ✓ — تمِ سراسری + دو وزنِ Vazirmatn + ۴ آیکون SVG + sweep روی هر ۱۲ صحنه ✓✗ (نیمی از §۷ از فاز ۶ عدد داشت: `MIN_TOUCH_PX=144`، `BUTTON_RADIUS=16`، `PRESSED_SCALE=0.95`، `TONES` ⇒ کارِ این تسک سیم‌کشی و سنجش بود، نه ساختن ✗✓)
• **تمِ یک‌منبعه**: `game/themes/Nexus.tres` از `[gui] theme/custom` ⇒ هر کنترلی که در کد ساخته می‌شود (`Button.new()`ها) هم Vazirmatn + ۲۸px می‌گیرد ✓✗ و پسوند **`.tres`** و بس: Godot 4 فایلِ `.theme` را باینری می‌خواند ⇒ تم با «Unrecognized binary resource file» **بی‌صدا** حذف می‌شد و بازی با فونتِ موتور/۱۶px می‌ماند ✗✗؛ `UIKit.THEME_PATH` تنها مرجعِ مسیر است و گیت، برابریِ آن را با `project.godot` می‌سنجد ✓✓
• فونت: `Palette.ui_font()` = Medium (بدنه) و `ui_font_bold()` = Bold (عناوین + ارقامِ اورب) ✓ و `_draw`های متنی (`MasteryChart`، `OrbVisual`) که با `ThemeDB.fallback_font` می‌نوشتند از پالت فونت می‌گیرند ✓ (فونت موتور روی Android گلیف فارسی ندارد = «جعبهٔ توپُر» ✗✓)
• **کنتراست اندازه‌گیری می‌شود**: `Palette.contrast_ratio()` (linearizeٔ WCAG) با اعدادِ مرجعِ قفل‌شده در تست — سیاه‌وسفید 21.0 · CLOUD روی INDIGO 11.2397 · `STONE_UI` روی CLOUD 5.0390 · همرنگ 1.0 ✓✗ چون `Color.get_luminance()` کنتراستِ WCAG **نیست** و اگر اشتباه می‌شد کل DoD روی کاغذ سبز می‌ماند ✗✓
• پالت: هر تُنِ `UIKit.TONES` ≥ ۴٫۵ ✓؛ `Palette.MUTED_TEXT` برای کپشن‌ها (روی پنلِ نیلی ۵٫۴۶ ✓، درحالی‌که `STONE_GREY` = ۳٫۶۸ ✗) و `Palette.STONE_UI` (=×۰٫۷۵ سنگی) برای تُنِ دکمه ✓
• §۸: ۴ آیکون SVG ایستای پالتی ≤۲KB (`hint/pause/back/done`) با `icon_texture()/attach_icon()/icon_alignment()`؛ `icon_alignment()` از `Loc.is_rtl()` ⇒ در RTL آیکون در **لبۀ بصریِ شروع** ✓؛ `game/icon.svg` نهایی شد ✓ و تیکِ «تمام» SVG است، نه گلیفِ U+2713 که در Vazirmatn نیست ✗✓
• **چهار یافتهٔ sweep که در همین تسک بسته شد**: `LevelResultBar` دکمه‌هایش را دستی می‌ساخت ✗ ⇒ `UIKit.make_button` ✓ · گره‌های `WorldMap` هیچ styleboxی نداشتند و `tooltip_text`شان جملۀ فارسیِ hard-code + گلیف چسبیده به رقم ✗✗ ⇒ سه حالتِ طلایی/ابری/سنگی + `Loc.t("map.locked_hint")` با `Loc.digits` (رشته‌ها ۹۳ ⇒ ۹۴×۲) ✓ · `SettingsMenu` دو دکمۀ زبانِ **لخت** و دو کپشنِ ۳٫۶۸ ✗✓ ⇒ `style_button("cloud")` + `pressed_feedback` + `MUTED_TEXT` ✓ · ممیزیِ سورسِ من `_add_label(` را نمی‌دید ✗✓ (blind spot خودم) ⇒ هر دو شکلِ ساختِ متن قرمز می‌شود
• **پنج گیتِ تازه/ارتقاء‌یافته** در `tools/validate_levels.py`: `check_typography()` (تم + کفِ ۲۴px با **حل‌کنندۀ عبارت** ⇒ `UIKit.TITLE_FONT_PX - 40` = ۱۶ هم گرفته می‌شود ✓ + `fallback_font` فقط در `Palette.gd`) · `check_icon_assets()` (وجود، «هنرِ مرده»، `viewBox`، بی‌`<text`، بی‌ارجاعِ بیرونی، هگز ∈ پالت، ≤۴KB، آیکونِ اپ) · `check_ui_string_i18n()` · `check_const_expressions()` · سنجشِ پسوند/محتوای تم. همۀ دامنه‌ها `game/scripts` است (تست‌ها مستثنا ✗✓) و همه با پروبِ قرمز/سبز روی فیکچر تأیید شدند ✓✓
• **تست**: `test_ui_skin.gd` (۱۸) + `test_a11y_scenes.gd` (۱۴) ⇒ sweep روی **هر** `*.tscn` با `EXPECTED_SCENES = 12` (شمارش‌محور ⇒ صحنۀ جدیدِ بی‌آزمون از ممیزی در نمی‌رود ✓✓) و ضدِ‌دروغ‌گوییِ «یافت ۰ ⇒ قرمز»؛ baselineِ پیش از ۸.۴: **۴۵ فایل / ۴۰۲ تست** ✓ و در `882af0c`: **۴۷ فایل / ۴۳۴ تست** ✓✓ (هر ۳۲ تستِ تازه اجرا شد)

**سه دورِ قرمزِ ۸.۴ و درس‌هایشان (ثبت ✓✓ — برای فاز ۹ هم لازم‌الاجرا):** (۱) `const TONES := {"stone": {"bg": Palette.STONE_GREY.darkened(0.25)}}` ✗✗ سازندۀ `Color(...)` در const مجاز است ولی **صالحِ عضو** نه ⇒ «isn't a constant expression» ⇒ کل `UIKit` کامپایل نشد و **۱۰۵** تست با پیام‌های بی‌ربط (`Nonexistent function 'make_button'/'anchor_full'/'style_button'`) قرمز شد ✗✓؛ `gdparse` محلی این را نمی‌گیرد ⇒ گیتِ `check_const_expressions` متولد شد ✓ (سومین باری که همین خانوادۀ خطا من را زد ✗✗ ⇒ قاعده: هر «عددِ ثابت» باید در `Palette`/`UIKit` constِ خالص باشد). (۲) `for name: String in …` دو بار در یک تابع ⇒ فایل تست **parse** نشد و ۱۸ تست قرمز نبودند، **غایب** بودند ✗✓ تنها سرنخ `Scripts 46` در برابر `files_on_disk=47` بود ⇒ شمارش فایل/اسکریپت در ledger ماند ✓ (و `check_script_duplicates` هم‌خانوادۀ این درس است). (۳) ابزارِ انوتیشنِ خودم (`tools/ci_annotate.py`) `✗` را الگوی «خطا» گذاشته بود ⇒ چون پیامِ هر assert ما «✗✓» دارد، ۱۰ انوتیشنِ اول (سقفِ GitHub از مسیر `::error::`) با `[Passed]` پُر شد و نامِ ۴ تستِ شکسته هیچ‌وقت دیده نشد ✗✗ (دو دور CI سوخت ✓) ⇒ `NOISE` + «جدی‌ها اول» ✓✓؛ پروب با لاگِ ساختگی: `[Failed]` + `SCRIPT ERROR` + `at:` هر سه در بخش ۱ ✓ **درس: ابزاری که برای خواناییِ شکست ساخته می‌شود، خودش هم باید قرمز/سبزِ عمدی ببیند.**

**وضعیت فاز ۸ (به‌روز):** ۸.۱ ✅ · ۸.۲ ✅ · ۸.۳ ✅ · ۸.۴ ✅ · ۸.۵ ✅ ⇒ DoD فاز ۸ بسته شد ✓✓ مسیرِ ۸.۴ از «۱۰۵ قرمز» به «۰ قرمز» در `ab34a4e` رسید ✓✓ و قیدِ «در انتظارِ پوش» که در بالا نوشته بودم حالا بی‌مورد است: اثباتِ CI در بلوکِ «اثباتِ CI (۸.۴)» همین‌جاست ✓ باقی‌ماندۀ فاز ۸ فقط چیزهایی است که در CI سنجیده نمی‌شوند (چشۀ دستگاه در فاز ۱۰) ✓

**اثباتِ CI (۸.۴):** سبز در `ab34a4e` — «GUT 4.7.2 · **Scripts 47 · Tests 434 · Passing Tests 434 · Orphans 1 · Time 27.722s** | files_on_disk=47» ✓✓ (هر ۴۷ فایلِ تست کشف و اجرا شدند ⇒ «تستِ غایبِ بی‌خبر» که یک دورِ من را زد، دیگر در این شاخه نیست ✓✓ و ۳۲ تستِ تازه‌ِ ۸.۴ همگی سبزند ✓) و «gdlint + content validation» هم سبز ✓ ⇒ پنج گیتِ تازه/ارتقاء‌یافته (`check_typography` با حل‌کنندۀ عبارت و برابری `THEME_PATH`، `check_icon_assets`، `check_ui_string_i18n`، `check_const_expressions`، سنجشِ پسوند/محتوای تم) در CI هم اجرا می‌شوند ✓. مسیرِ چهار دور: `8ca6e17` ⇒ ۱۰۵ قرمز ⇒ ۴ قرمز ⇒ ۳ قرمز ⇒ **۰** ✓✗ هر دور یک «قاعده/ابزار» به‌جای «وصله» گذاشت که در ADR-062 ثبت است ✓)

**اثباتِ CI (۸.۲ و ۸.۳):** سبز در `d027b54` — «GUT 4.7.2 · **Scripts 45 · Tests 402 · Passing Tests 402 ·
Orphans 1**» ✓✓ (پایۀ ۸.۲: ۴۳ فایل / ۳۷۳ تست ⇒ دقیقاً +۲ فایل و +۲۹ تست، **هیچ تستی حذف/خاموش
نشده** ✓✗✓ همان سنجشِ ADR-033) و دو فایلِ تست به «الف/ب» شکسته شد تا سقفِ `gdlint`
(≤۲۰ متدِ public در فایل) حفظ بماند ✓✓ · `tools/validate_levels.py` سبز با سه خطِ تازه: «تکرارِ
تعریف در .gdها: پاک ✓ · واژگانِ محیط: ۵/۵ منطقۀ روایتی با RegionBackdrop هم‌نام ✓ · استاتیک/
اینستانس: جدا ✓» + «API Godot4: پاک · کلاس‌های عمومی: ۳۵ · فایل بصری: ۱۸ (۲۴۷KB)/شیدر ۱» ✓
· `gdlint`: no problems ✓. **باقیِ فاز ۸: ۸.۴** (خانوادۀ Vazirmatn روی Theme + بدنه ≥۲۴px + دکمۀ
≥۴۸×۴۸ + گوشۀ ۱۶px + فشرده‌شدنِ ۰٫۹۵/haptic + RTL-ready ✓✗ فایل‌های فونت *از قبل* در
`game/assets/fonts`‌اند و داخلِ بودجۀ `check_art_assets` شمرده شده‌اند ⇒ کارِ ۸.۴ سیم‌کشی است،
نه دانلود ✓✓) و دیدنِ همۀ این‌ها روی دستگاه = فاز ۱۰ ✓ (این‌جا فقط فرم/کنتراست/داده سنجیده شد).

**اثباتِ CI (۸.۱ و ۸.۵):** سبز در `8a59544` — «GUT 4.7.2 · Scripts 42 · Tests 359 ·
Passing 359» ✓✓ (پایهٔ قبل از فاز ۸: ۴۰ فایل / ۳۳۵ تست ⇒ دقیقاً ۱۳ تستِ آریا + ۱۱ تستِ
سیلوئت اضافه شده و **هیچ تستی حذف/خاموش نشده** ✓✗✓ گاردِ ADR-033 همان چیزی است که این
برابری را می‌سنجد) · `tools/validate_levels.py`: ۴۵ سطح، ۱۷ صوت، ۹۳×۲ رشته، «فایل بصری:
۱۸ (۲۴۷KB)/شیدر ۱ · API Godot4: پاک · کلاس‌های عمومی: ۳۴» ✓ · `gdlint`: no problems ✓.
**سه دورِ قرمزِ همین دو تسک و درس‌هاشان (ثبت، نه فراموش ✓✓):** (۱) `Basis.xform()` و
`Color.get_h()` ⇒ گیتِ `check_godot4_api()` ساخته شد ✓ (۲) `const` با فراخوانیِ متد ⇒
الگوی «پایه + ضریب» در `CORE_COLORS`/`CORE_LIFT` ✓ (۳) `cat >` دو `class_name` را بلعید ⇒
`check_class_registry()` + قاعدهٔ «ویرایشِ خط‌محور، نه بازنویسی» ✓✓ هر سه *قبلِ* این فاز
در تاریخچه بودند (فاز ۷: `connect(_on_aria_state)`) و الگوی مشترکشان یکی است: **Godot در
`--check-only` خطای معناییِ نام/عضو را نمی‌فهمد، و هدلس `_draw()` را اجرا نمی‌کند** ⇒ پس
هر چیزی که «با چشم» سنجیده می‌شود باید به تابعِ خالصِ تست‌شدنی تبدیل شود ✓✓ (این قاعده
برای ۸.۲..۸.۵ هم لازم‌الاجراست ✓). **نوسانِ عمدیِ `Orphans 1`:** یک نودِ tests/… که در
درخت نمی‌ماند؛ از قبل شناخته‌شده و بی‌ضرر است ✓ (اگر روزی >۱ شد: نشتیِ نود ✓).

### فاز ۹ — بک‌اند
**وضعیت: ۹.۱ ✅ · ۹.۲ ✅ · ۹.۳ ✅ · ۹.۴ ✅ · ۹.۵ ✅ (ADR-063) · ۹.۶ ✅ (کد/تست محلی ✓✗ اثباتش فقط در CI ممکن است، چون سندباکس Godot ندارد ✓) · **فاز ۹ بسته شد ✓** (ADR-063/064)** — `backend/` با Node 22 + Express + zod + `pg` ساخته شد؛ ۳۵ تست `node:test` (supertest + **pg-mem**) سبز ✓✓ و `GET /health` روی سرورِ درحال‌اجرا واقعاً ۲۰۰ داد ✓ (`npm run dev` ⇒ `listening_ports` ⇒ `curl` ✓✗ DoD ۹.۱ فقط با «لاگِ موفق» ثابت نمی‌شد: دورِ اول `main()` بعد از `listen` برمی‌گشت و `.then(process.exit)` سرور را ۰٫۹ ثانیه بعد می‌کُشت ✓✓ درس: «بالا آمدن» یعنی **پورتِ در گوش** ✓)
• ۹.۲ `backend/src/db/schema.sql` = بایت‌به‌بایتِ `docs/03` §۶ ✓ + مهاجرتِ شمارشی (`nexus_migrations`) که در CI **روی Postgres 16 واقعی دوبار** اجرا می‌شود تا بی‌ضرربودن ثابت شود ✓✓ و افزودنیِ `002_player_model.sql` برای snapshot مدل (§۶ جایش را نگذاشته بود ✗✓ ADR-063)
• ۹.۳ `POST /api/player-model/:id/sync` + `GET /api/player-model/:id`: zodِ §۲ (`.strict()` ⇒ فیلدِ PIIِ قاچاقی **رد**، نه «بی‌صدا نادیده» ✓§۹)، نگاشتِ قطعیِ `p_xxxxxxxx` ⇒ UUIDv5 ✓، آینه‌شدنِ `skill_ratings` (تست ردّ‌وبدلِ بایت‌به‌بایت + شمارشِ ستون‌های نرمال ✓✓)
• ۹.۴ `POST /api/events` — فقط insert ✓؛ تک‌رویداد و دسته‌ای (۲۰۲، سقف ۲۰۰) ✓ و رویدادِ playerِ دیگر ⇒ ۴۰۳ ✓✓؛ `ensurePlayerRow` لازم شد چون flushِ صفِ آفلاین می‌تواند **پیش از** اولین sync برسد ✗✓ (FK رد می‌کرد ⇒ ۵۰۰ ✗✓ حالا placeholderِ بی‌نام `pending_sync` که syncِ بعدی proper می‌کند)
• ۹.۵ احراز هویتِ **بی‌حالت**: `device_token = b64url({p,iat,exp}).HMAC-SHA256` ⇒ نه جدولِ کاربر، نه ایمیل، نه رمز ✓§۹؛ توکن به یک player bound است ⇒ مسیرهای مدل/رویداد با ۴۰۳ از هم جدا می‌مانند ✓؛ چهار کدِ ۴۰۱ (`missing/malformed/signature/expired`) + انقضای ۴۰۰ روز + تولید از `POST /api/device` ✓ (تستِ واحد + تستِ HTTP ✓)
• **پنج قفلِ گیتِ تازه** (`check_backend_contract` + گشادشدنِ `check_text_hygiene` به `backend/**.ts`): برابریِ بایتیِ اسکیما با §۶ ✓ · شش رویداد §۵ == `EVENT_TYPES` ✓ · `path`های اعلامیِ ۹.۳/۹.۴ در `router.post/get` ✓ · هر کلیدِ §۲ در zod ✓ · فایل‌های اعلامیِ `docs/01` §۲ روی دیسک ✓ (افزودنی‌ها ⚠ نه خطا ✗✓) — پروب‌های قرمز: ستونِ اضافه، enumِ افزوده، فایلِ حذف‌شده، CJK در `.ts` ⇒ چهار خطای درست ✓✓ (همین قاعدۀ بهداشتِ متن، سه‌بار «گلیچِ چینی» خودم را در پیام/تست/سند گرفت ✓✓ (این‌جا **خودِ همین سطرِ ledger** را هم قرمز کرد ✗✓ یعنی گیت حتی روی متنِ «توضیحِ باگ» هم بیدار است ✓)
• **۹.۶ `NetworkClient.gd` (autoload ✓§۹)** ⇒ HTTP wrapper با صفِ FIFO، سقفِ `FeatureFlags.OFFLINE_QUEUE_MAX` ✓ و `stats().dropped/rejected/attempts` (سکوت در مدیریتِ حافظه ممنوع ✓)؛ DoDِ «قطعِ شبیه‌سازی‌شده ⇒ بی‌کرش، وصلِ مجدد ⇒ صف خالی» با `FakeSender` و ۱۸ تست GUT سنجیده شد ✓✗ **نه با HTTP واقعی**: `transport` تزریق‌پذیر است و `HTTPRequest` فقط با `base_urlِ` پر ساخته می‌شود ⇒ CI هرگز سوکت باز نمی‌کند ✓✓ (تست ۱۸: `assert_null(_requester)` ✓)
• دو باگی که فقط «خواندنِ قرارداد» گرفت، نه اجرای تست ✗✓ (برای همین به ADR-064 رفت): (۱) pop-before-result با آرایۀ «بازگردانی»ی پرنشده ⇒ رویداد گم می‌شد، بی‌قرمزیِ تست ⇒ قاعدۀ جدید: retry باید «شمارشِ باقی‌مانده» را ادعا کند ✓✓ (۲) `get_datetime_string_from_system(true)` بی‌`Z` بود و zodِ §۵ `.datetime({offset:true})` ⇒ هر flush با ۴۲۲ برمی‌گشت و صف تا ابد پر می‌ماند ✗✓ (fakeِ سمتِ بازی هرگز این را نمی‌دید ⇒ **قفلِ دوزبانه** گذاشته شد: `check_backend_client_contract()` = رویدادها == enumِ TS · `BATCH_LIMIT ≤ 200` · `ENDPOINT_*` در `router.*`ِ سرور وجود دارد ✓ پروب: سه خرابیِ عمدی ⇒ سه خطا ✓✓)
• allowlistِ «چه کسی حق دارد HTTP لمس کند» دو مسیرِ دقیق شد ✓ و خودِ فهرست تست می‌شود ✗✓ — و همین‌جا باگِ کهنۀ فاز ۵ بیرون آمد: exempt `live_ai_provider.gd` را می‌سنجید ولی فایل `LiveAIProvider.gd` است ⇒ exempt **مرده** بود ✓✓ (تستِ «تعداد=۲ و هر دو روی دیسک» + «NetworkClient واقعاً HTTPRequest دارد ✓»)
• بدهیِ ثبت‌شده (فاز ۱۰/۱۱): `rate-limit` روی `/api/device` · dedupِ رویداد (`event_id` + unique index = افزودنیِ ۰۰۳) · `optimistic lock` روی `updated_at` · `schema_version` فعلاً `literal(1)` ⇒ مهاجرتِ مدل در ۹.۶ باز می‌شود ✓

۹.۱ راه‌اندازی TS/Express + `GET /health` · ۹.۲ `schema.sql` + migration · ۹.۳ `POST/GET /api/player-model/:id/sync` با zod · ۹.۴ `POST /api/events` · ۹.۵ `deviceAuth` (توکن تصادفی محلی، بدون PII) · ۹.۶ `NetworkClient.gd` + صف آفلاین ✓
افزوده‌ها (A3، ADR-005/010): `device_tokens`، rate-limit، batch، حذف خودکار رویداد بعد از sync موفق.
DoD: تست یکپارچه در CI با Postgres service؛ تست `pg-mem` محلی؛ صف آفلاین با قطع شبکه در GUT.

### فاز ۱۰ — QA و build اندروید
۱۰.۱ پوشش تست (۱۰۰٪ منطق حیاتی) · ۱۰.۲ `docs/playtest-protocol.md` · ۱۰.۳ `AnalyticsManager` (۶ رویداد) · ۱۰.۴ `export_presets.cfg` (minSdk 24 → **target/compile 36**، `INTERNET` + `VIBRATE` فقط، icon، AAB) · ۱۰.۵ smoke checklist.
خروجی من: **APK/AAB امضاشده به‌عنوان artifact CI** (keystore از secrets؛ ADR-004) + گزارش سایز/مصرف.
DoD: نصب روی یک گوشی واقعی توسط تو + گزارش L3.

### فاز ۱۱ — بتا
۱۱.۱ سیاست حریم خصوصی (فارسی + انگلیسی) · ۱۱.۲ چک‌لیست انطباق Families · ۱۱.۳ Closed testing · ۱۱.۴ فرم بازخورد.

### فاز ۱۲ — انتشار (افزوده‌ی من؛ A17)
۱۲.۠ مجموعه‌ی گرافیکی فروشگاه (icon 512×512، feature graphic 1024×500، ۸ اسکرین‌شات از رندر واقعی بازی، ویدیوی ۳۰s) · ۱۲.۲ متن لیستینگ فارسی (عنوان ≤ ۳۰، کوتاه ≤ ۸۰، بلند ≤ ۴۰۰۰) + نسخه‌ی انگلیسی · ۱۲.۳ فرم‌های Play Console: Data Safety، Content rating (IARC)، Target audience، Ads=none، Pricing · ۱۲.۴ صفحه‌ی پشتیبانی/حریم‌خصوصیت میزبان (GitHub Pages از همین ریپو) · ۱۲.۵ نسخه‌بندی/CHANGELOG/rollout تدریجی ۱۰→۵۰→۱۰۰٪ · ۱۲.۶ قیمت‌گذاری و مدل درآمد (باز: §۹).

---

## ۶) گراف وابستگی و ترتیب پیشنهادی session‌ها

```
P0 ✅ → P1 → P2 ←(قلب پروژه؛ اگر P2 سست شود همه‌چیز بعدی سست است)
             ├→ P3 → P4 → P5 ─┐
             ├→ P6 (بعد P3 برای داده‌ی واقعی UI)
             ├→ P7 (محتوا؛ بعد P3، موازی با P5/P6)
             ├→ P8 (هنر؛ موازی، تحویل قبل بتا)
             └→ P9 (بک‌اند؛ موازی از هفته‌ی ۴) → P10 → P11 → P12
```

پیشنهاد من برای ادامه (هر خط = یک session کاری بعدی):
1. **P1 + P2** (هسته‌ی ترازو + تست playable) — بزرگ‌ترین گام ریسک.
2. **P3 + P4** (داده + موتور تطبیق) — بازی در این لحظه «قابل‌بازی با ۵ سطح» می‌شود.
3. **P5 + P6** (Aria + UI) — نمونه‌ی اولیه‌ی قابل‌نمایش به والدین.
4. **P9** + **P7** (بک‌اند و محتوا، موازی) .
5. **P8** (هنر نهایی) → **P10** (build) → **P11/P12** (بتا و انتشار).

---

## ۷) «قابل‌فروش» یعنی چه (تعریف Done محصول)

فنی: MVP کامل (چک‌لیست انتهای `04`) + CI سبز + APK/AAB واقعی + بودجه‌های §۱/A14 رعایت‌شده.
حقوقی/استور: بدون تبلیغ، بدون SDK شخص ثالث، privacy policy قابل‌دسترس، Data Safety صادقانه
(«ما فقط شناسه‌ی تصادفی + داده عملکرد را ذخیره می‌کنیم»)، IARC rating، target API 36،
مجوزها فقط `INTERNET`/`VIBRATE`، و «حداقل ۱۲ سال» یا «۹+» متناسب با رده‌بندی انتخابی.
بازار: لیستینگ فارسی/انگلیسی، اسکرین‌شات از رندر واقعی، یک ویدیو، ۲۰ بازخورد پلی‌تست مستند.

---

## ۸) ریسک‌ها و پلن B

| ریسک | احتمال×اثر | پلن B |
|---|---|---|
| GUT 9.7.1 با Godot 4.7 ناسازگار شود | کم×زیاد | fallback: runner سفارشی `tools/gut_min.gd` هم‌API (`assert_*`های حداقلی) — ۲۰ خط |
| GDD گمشده (A1) مسیر محتوا را عوض کند | زیاد×متوسط | سطوح در `data/` + validator؛ بازچینش Tier فقط JSON را عوض می‌کند، نه کد |
| دقیقه‌ی CI خصوصی تمام شود | متوسط×زیاد | `concurrency`+کاهش trigger به `main`/`develop`؛ اجرای manual در زمان لازم؛ در صورت لزوم public کردن ریپو یا ریپوی جدا برای build |
| ساخت APK در CI به keystore نیاز دارد | حتمی×کم | `android-export.yml` با debug signing شروع می‌شود؛ release signing بعد از قرار دادن secrets توسط تو |
| هنر AI حجیم/ناهمگون | متوسط×زیاد | SVG/پروسیجرال (ADR-007)؛ هنر AI فقط به‌عنوان مرجع رنگ در `/tmp` |
| صدای واقعی در دسترس نیست (شبکه بسته) | حتمی×کم | SFX پروسیجرال WAV (تولید با `tools/gen_audio_placeholder.py`)؛ موسیقی نهایی سفارش مالک |
| خواندن فارسی در Godot (برهم‌ریختگی ارقام/جدا نویسه‌ها) | متوسط×زیاد | تست زودهنگام: فاز ۶ یک اسکرین‌شات RTL با `Vazirmatn` را در CI تولید/بررسی می‌کند؛ در صورت نیاز `RichTextLabel` + BiDi explicit |

---

## ۹) بازِها — جلسه‌ی ۱ بسته شد (ADR-027) ✅

تصمیم‌های گرفته‌شده: **GDD ← بازسازی ایجنت در `docs/07`** · **مدل درآمد ← پولیِ یک‌باره (بدون
تبلیغ/IAP)** · **پروفایل ← تک‌پروفایل در MVP** · **بک‌اند ← کد + استقرار واقعی در MVP**.
موارد باقی‌مانده (مالک، در زمان خودش): `applicationId`/نام استودیو، اکانت Play Console،
keystore + Secrets، هاست بک‌اند، پلی‌تست با خانواده‌ها.

<details><summary>متن اصلی سؤال‌ها (برای تاریخچه)</summary>

1. **GDD اصلی** را داری؟ اگر بله اضافه‌اش کن؛ اگر نه، من `docs/07` را بازسازی می‌کنم و تو تأیید/ویرایش کن.
2. نام استودیو + `applicationId` (پیش‌فرض من: `com.nexuslearning.balance_realm`) — بعداً قابل تغییر نیست (برای آپدیت‌ها).
3. مدل درآمد: پولیِ یک‌باره / رایگان + IAP پشت parent-gate / اشتراک. (پیشنهاد: پولیِ یک‌باره یا IAP بدون تبلیغ؛ ساده‌ترین انطباق با Families.)
4. مخاطب سنی در استور: «۹-۱۲ + ۱۳-۱۵» یا فقط «۱۳-۱۵»؟ (تأثیر مستقیم روی سخت‌گیری Families و رده‌بندی.)
5. یک پروفایل در هر دستگاه، یا چند پروفایل کودک؟ (کلاس‌درس/خانواده‌های چندبچه‌ای → خواسته‌ی واقعی؛ هزینه: پیکربندی save.)
6. بک‌اند را در فاز ۹ واقعاً مستقر می‌کنیم (میزبان ارزان/Render/Fly.io) یا MVP آفلاین-محور می‌ماند و بک‌اند فقط در ریپو تست می‌شود؟
7. GitHub Actions را برای ساخت APK فعال نگه دارم و به secrets ریپو (keystore) دسترسی بدهیم؟ (برای APK امضاشده الزامی است.)
</details>


**وضعیت CI ۷.۴ و ۷.۵ (✅ سبز، با ذکرِ اتفاقِ تاریخچه):** `c855a43` (علامت‌دارکردن `_row_values`) · `871add6` (ده سطح Tier ۵) · `fc13a11` (ADR-056) ⇒ **Godot import + GUT ✅** و **gdlint + content validation ✅** ⇒ ۴۵ سطح در موتورِ واقعی بَرده می‌شوند ✓✓؛ سپس `b64f398` + `393c37b` (روایت) ⇒ دوباره ✅ روی `393c37b` با **۳۹ فایل اسکریپت / ۳۲۷ تست** (شمارشِ ایستا = همان ✓✓).
**نگهبانی که این‌بار کار کرد:** گاردِ ADR-033 در `ci.yml` «تعداد `test_*.gd` روی دیسک» را با «Scripts» در خلاصهٔ GUT مقایسه می‌کند ⇒ اگر `test_story_beats.gd` به‌دلیلِ خطای parse بارگذاری *نمی‌شد*، CI **قرمز** می‌شد (۳۸ ≠ ۳۹) ✗✓ سبزبودن یعنی فایل اجرا شده — همان چیزی که در سه دورِ قبل با `grep -a "Failed to load script"` دستی می‌گرفتیم ✓✓ (و این‌بار لاگِ `actions/jobs/<id>/logs` در این سندباکس خالی برگشت ✗ ⇒ تکیه‌گاه، همان گاردِ شماره‌ای است، نه لاگ.)
**اتفاقِ ثبت‌شده (نه پنهان‌شده):** در میانهٔ ۷.۴، `.git` سندباکس بازسازی شد و اتصال GitHub چند دقیقه `401` داد ✗✓ سه کامیتِ محلی روی ریشهٔ اشتباه (`90cdff6`) نشست و در تلاشِ بازسازی، پیامک‌ها از آبجکت‌های یتیم (GC‌شده) خوانده شد ⇒ **سه کامیت با پیامکِ خالی push شد** ✗✗ پیامک‌ها بازنویسی و با `git push --force-with-lease` (روی همین شاخهٔ سشن، PR فقط به شاخه نگاه می‌کند) جایگزین شد ✓ و قبلش `git diff --stat` بین درختِ کهنه و نو **خالی** بود ⇒ محتوا تکان نخورد ✓✓. ضمناً ۲۶ فایل `.import`ِ GUT که در بازسازیِ درخت کار افتاده بودند، از ریموت بازگردانده شدند ✓ (`git restore --source=FETCH_HEAD -- game/addons`).
**قاعدهٔ تازه:** بعد از هر `git commit`، `git log -1 --format=%s` را بخوان ✓✓ (یک کامیتِ بی‌عنوان در پروژه‌ای که کل ردیابی‌اش به `[P<phase>.<task>]` است، شکستِ خودِ قاعده است ✗) و برای بازسازیِ تاریخچه، پیامک را از **همان لحظه** بنویس، نه از object db ✗.
**بدهیِ تازه (فاز ۹/۱۰):** (۱) `story_beats.json` هنوز در UI مصرف نمی‌شود (داده + دروازه آماده ✓ پخش در جریانِ بازی = فاز ۹: `game_start` در Onboarding، `tier_start` پیش از اولین سطحِ هر Tier، `game_complete` در پایان ✓) ✗✓ (۲) انگلیسیِ روایت پس از MVP (GDD §۷) ✓ (۳) چیدمانِ **سه‌ترازو** تست‌نشده ⇒ اگر روزی خواسته شد، اول ممیزیِ لمسیِ فاز ۱۰ ✓ (۴) «خواناییِ متنِ ۹۰نویسه‌ای روی گوشی ارزان» با چشم سنجیده می‌شود (اینجا فقط جا‌شدنِ ساختاری ثابت شده ✓).محلی ناکاملاً ردیابی‌شده است ✗✓ مسیرِ صریح = قانونِ همیشگیِ این ریپو). — و از دلِ ۸.۴ دو موردِ تازه: (۲) **`commit-msg` hook**: گلایچِ CJK در پیامِ کامیت دو بار رخ داد ✗✓ و `check_text_hygiene` فقط فایل‌ها را می‌بیند (پیام را نه) ⇒ هوکِ کوچکی که `%B` را با همان `BANNED_CODEPOINTS` بسنجد ✓؛ (۳) **قاعدۀ اجرایی «هر ویرایش ⇒ بلافاصله گیت»**: سه بار در این فاز، فایلِ کهنه گیتِ سبز داد و یک بار `&&` تا کامیت رفت ✗✓ (درسِ تکراری، پس به قاعدۀ نوشتاری تبدیل شد ✓)
