# NEXUS — معماری فنی (Architecture Reference)

این سند، مرجع ثابت معماری پروژه است. تمام تسک‌های `04-BUILD-PLAN.md` باید با این سند سازگار باشند.

---

## ۱. استک فنی نهایی

| لایه | انتخاب | نسخه/جزئیات | دلیل |
|---|---|---|---|
| موتور بازی | **Godot Engine** | 4.6 یا بالاتر (Stable) | متن‌باز، بدون رویالتی، ۲D قوی، export سبک برای اندروید ارزان |
| زبان اسکریپت | **GDScript (Typed)** | — | سرعت توسعه بالا در Godot؛ از C# استفاده نمی‌کنیم مگر نیاز کارایی خاص پیش بیاید |
| کنترل نسخه | **Git + GitHub** | — | branch strategy در بخش ۴ همین سند |
| بک‌اند | **Node.js + TypeScript + Express** | Node 20 LTS+ | تیم کوچک، اکوسیستم بزرگ، توسعه‌ی سریع |
| دیتابیس | **PostgreSQL** | 15+ | مدل رابطه‌ای برای player model و skill ratings |
| کش/نشست زنده | **Redis** | 7+ | فقط اگر نیاز به session state لحظه‌ای real-time پیدا شد؛ در MVP اختیاری |
| تست موتور بازی | **GUT (Godot Unit Test)** | افزونه‌ی رسمی جامعه | استاندارد صنعت برای تست GDScript |
| CI/CD | **GitHub Actions** | — | export headless + اجرای تست‌ها روی هر PR |
| هوش مصنوعی (Aria) | **قالب‌محور (Template-based) در MVP** + هوک آماده برای LLM API در فاز بعد | — | قابلیت اطمینان، هزینه‌ی صفر، کارکرد آفلاین؛ بخش ۵ همین سند را ببین |

---

## ۲. ساختار کامل ریپازیتوری

```
nexus-game/
├── .github/
│   └── workflows/
│       └── ci.yml
├── .gitignore
├── README.md
├── docs/
│   ├── 00-START-HERE.md
│   ├── 01-ARCHITECTURE.md
│   ├── 02-ART-BIBLE.md
│   ├── 03-DATA-SCHEMAS.md
│   └── 04-BUILD-PLAN.md
├── game/                          ← پروژه‌ی Godot
│   ├── project.godot
│   ├── icon.svg
│   ├── addons/
│   │   └── gut/                   ← افزونه‌ی تست
│   ├── assets/
│   │   ├── art/
│   │   │   ├── characters/
│   │   │   │   ├── aria/
│   │   │   │   └── player/
│   │   │   ├── environments/
│   │   │   │   ├── hub_aeloria/
│   │   │   │   ├── tier1_meadow/
│   │   │   │   ├── tier2_caverns/
│   │   │   │   ├── tier3_ruins/
│   │   │   │   ├── tier4_observatory/
│   │   │   │   └── tier5_summit/
│   │   │   ├── ui/
│   │   │   └── vfx/
│   │   ├── audio/
│   │   │   ├── music/
│   │   │   └── sfx/
│   │   └── fonts/
│   ├── scenes/
│   │   ├── main/
│   │   │   ├── MainMenu.tscn
│   │   │   ├── WorldMap.tscn
│   │   │   └── Onboarding.tscn
│   │   ├── gameplay/
│   │   │   ├── LevelScene.tscn
│   │   │   ├── BalanceScale.tscn
│   │   │   ├── WeightOrb.tscn
│   │   │   └── HUD.tscn
│   │   ├── characters/
│   │   │   └── Aria.tscn
│   │   └── ui/
│   │       ├── PauseMenu.tscn
│   │       ├── SettingsMenu.tscn
│   │       ├── ParentDashboard.tscn
│   │       └── DialogueBox.tscn
│   ├── scripts/
│   │   ├── autoload/
│   │   │   ├── EventBus.gd
│   │   │   ├── GameState.gd
│   │   │   ├── SaveSystem.gd
│   │   │   ├── LevelLoader.gd
│   │   │   ├── DifficultyEngine.gd
│   │   │   ├── AnalyticsManager.gd
│   │   │   └── NetworkClient.gd
│   │   ├── gameplay/
│   │   │   ├── BalanceScale.gd
│   │   │   ├── WeightOrb.gd
│   │   │   ├── GhostOrb.gd
│   │   │   └── LevelController.gd
│   │   ├── ai/
│   │   │   ├── AriaController.gd
│   │   │   ├── ErrorClassifier.gd
│   │   │   ├── HintTimingSystem.gd
│   │   │   └── DialogueTemplate.gd
│   │   ├── data/
│   │   │   ├── LevelData.gd
│   │   │   ├── PlayerModel.gd
│   │   │   └── SkillRating.gd
│   │   └── ui/
│   │       └── (اسکریپت‌های هر UI scene)
│   ├── data/
│   │   ├── levels/
│   │   │   ├── tier1/  (level_1_01.json ... level_1_12.json)
│   │   │   ├── tier2/
│   │   │   ├── tier3/
│   │   │   ├── tier4/
│   │   │   └── tier5/
│   │   ├── dialogue/
│   │   │   └── aria_templates.json
│   │   └── narrative/
│   │       └── story_beats.json
│   └── tests/
│       └── gut/
│           ├── test_player_model.gd
│           ├── test_balance_scale.gd
│           ├── test_skill_rating.gd
│           └── test_error_classifier.gd
└── backend/                        ← سرویس بک‌اند (پروژه‌ی جدا)
    ├── package.json
    ├── tsconfig.json
    ├── src/
    │   ├── index.ts
    │   ├── routes/
    │   │   ├── playerModel.ts
    │   │   └── events.ts
    │   ├── db/
    │   │   ├── schema.sql
    │   │   └── client.ts
    │   └── middleware/
    │       └── deviceAuth.ts
    └── test/
        └── playerModel.test.ts
```

---

## ۳. معماری سیستم‌ها (نمای کلی)

```
                        ┌───────────────────────────┐
                        │       Godot Client         │
                        │                             │
   ┌─────────────┐      │  ┌─────────┐   ┌─────────┐  │
   │ BalanceScale │◄────┼──┤ Level    │   │  Aria    │  │
   │ (Gameplay)   │      │  │ Loader   │   │ Controller│  │
   └──────┬───────┘      │  └────┬────┘   └────┬────┘  │
          │               │       │              │       │
          ▼               │       ▼              ▼       │
   ┌──────────────┐       │  ┌──────────┐  ┌───────────┐ │
   │ErrorClassifier│──────┼─►│Difficulty │  │  Dialogue  │ │
   └──────┬───────┘       │  │ Engine    │  │  Template  │ │
          │               │  └────┬─────┘  └───────────┘ │
          ▼               │       │                       │
   ┌──────────────┐       │       ▼                       │
   │HintTimingSystem│◄────┼──┌──────────┐                 │
   └──────────────┘       │  │PlayerModel│                │
                           │  └────┬─────┘                 │
                           │       │                       │
                           │       ▼                       │
                           │  ┌──────────┐                 │
                           │  │SaveSystem │                 │
                           │  └────┬─────┘                 │
                           └───────┼───────────────────────┘
                                   │  (Sync هنگام آنلاین‌شدن)
                                   ▼
                        ┌───────────────────────────┐
                        │   Backend (Node/Express)   │
                        │   /api/player-model/:id     │
                        │   /api/events                │
                        └──────────────┬──────────────┘
                                       ▼
                              ┌──────────────┐
                              │  PostgreSQL   │
                              └──────────────┘
```

**اصل طراحی حیاتی:** `ErrorClassifier` و `DifficultyEngine` و `LevelLoader` **کاملاً قطعی و بدون هوش مصنوعی** هستند — منطق ساده‌ی if/else و فرمول ریاضی. `AriaController` فقط **انتخاب می‌کند کدام قالب دیالوگ از پیش‌نوشته نمایش داده شود** — در MVP هیچ فراخوانی زنده به یک مدل زبانی وجود ندارد. این یعنی بازی کاملاً آفلاین کار می‌کند و رفتار Aria همیشه قابل‌پیش‌بینی و امن است.

---

## ۴. قرارداد Git

- شاخه‌ها: `main` (پایدار، همیشه قابل build)، `develop` (کار در حال انجام)، شاخه‌ی فیچر به ازای هر تسک: `feature/<phase>-<task-id>-<short-desc>` مثلاً `feature/p2-2.3-ghost-orb`
- پیام commit: `[P<phase>.<task>] <فعل امری کوتاه>` مثلاً `[P2.3] Add GhostOrb variant with hidden weight logic`
- هر تسک = یک Pull Request جدا به `develop`، حتی اگر پروژه تک‌نفره باشد (تاریخچه‌ی قابل ریویو می‌سازد)

---

## ۵. تصمیم درباره‌ی لایه‌ی هوش مصنوعی Aria

**فاز MVP (فاز ۵ در build plan):** قالب‌محور (Template-Based). هر ترکیب `(error_type, skill_tier, attempt_count)` به یک یا چند رشته‌ی از پیش‌نوشته‌ی فارسی با جای‌خالی متغیر (مثل `{orb_name}`) نگاشت می‌شود. این در `data/dialogue/aria_templates.json` تعریف می‌شود (اسکیمای کامل در `03-DATA-SCHEMAS.md`).

**فاز بعد از MVP (خارج از scope این سند):** یک `LiveAIProvider.gd` پشت یک feature flag، که برای گفت‌وگوی آزادتر (نه هدایت اصلی حل مسئله) به یک API مدل زبانی وصل می‌شود — با همان قوانین guardrail که در سند طراحی اصلی (GDD) آمده. **این را در فاز ۵ فقط به‌صورت یک کلاس خالی/stub بساز، وصلش نکن.**
