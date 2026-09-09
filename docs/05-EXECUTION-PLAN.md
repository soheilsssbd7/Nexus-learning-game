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

### فاز ۶ — UI/UX
۶.۱ `MainMenu` · ۶.۲ `Onboarding` (آواتار + آموزش عملی) · ۶.۳ `PauseMenu`/`SettingsMenu` (resume کامل، اسلایدر صدا، زبان) · ۶.۴ `HUD` (دکمه‌ی راهنما + پیشرفت) · ۶.۵ `ParentDashboard` + parent-gate ریاضی (نمودار تسلط، زمان، `aria_transcript_log`).
DoD: اندازه‌ی لمسی ≥ ۴۸px با تست خودکار روی مینیاتور صحنه‌ها؛ RTL درست؛ داشبورد = دقیقاً داده‌ی `PlayerModel`.

### فاز ۷ — محتوا
۷.۱..۷.۴ Tier 2..5 (≈ ۸-۱۲ سطح هر Tier؛ جمع MVP ≈ ۴۰-۵۰ سطح) · ۷.۵ `story_beats.json` · ۷.۶ `AudioManager` + لیست دارایی صوتی.
قاعده‌ی من: هر سطح **تولید + اعتبارسنج** می‌شود (validator)، سپس به‌صورت «حل خودکار» (bot که با همان منطق کد کفه را پر می‌کند) در CI تست می‌شود؛ محتوای بدون تأیید قابل‌حل‌بودن merge نمی‌شود.

### فاز ۸ — هنر نهایی (SVG-first، ADR-007)
۸.۱ Aria (ایکوساهدرون با `Polygon2D`/`CustomDraw` + shader هسته؛ ۶ حالت) · ۸.۲ آواتار لایه‌ای · ۸.۳ ۵ محیط + Hub (هر کدام ۲ حالت ویران/بازسازی) · ۸.۴ UI skin + تم · ۸.۵ آیکون کره‌ها.
DoD: چک‌لیست `02` §۸ برای هر دارایی؛ تست سیلوئت (رندر سیاه‌وسفید) خودکار؛ وزن دارایی‌ها ≤ سقف §۳.

### فاز ۹ — بک‌اند
۹.۱ راه‌اندازی TS/Express + `GET /health` · ۹.۲ `schema.sql` + migration · ۹.۳ `POST/GET /api/player-model/:id/sync` با zod · ۹.۴ `POST /api/events` · ۹.۵ `deviceAuth` (توکن تصادفی محلی؛ بدون PII) · ۹.۶ `NetworkClient` با صف آفلاین + backoff.
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
