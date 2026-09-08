# NEXUS — اسکیماهای داده (Data Schemas)

منبع حقیقت (Source of Truth) برای تمام ساختارهای داده‌ی پروژه. هر تغییر در این اسکیماها باید هم در Godot (`scripts/data/*.gd`) و هم در بک‌اند (`backend/src/db/schema.sql`) هم‌زمان اعمال شود.

---

## ۱. اسکیمای سطح (Level Data)

مسیر فایل نمونه: `game/data/levels/tier1/level_1_01.json`

```json
{
  "level_id": "tier1_level_01",
  "tier": 1,
  "world": "balance_realm",
  "concept_tags": ["addition", "concrete_numbers"],
  "narrative_intro": "اولین پل شکسته‌ی روستای Sunlit Meadow منتظر توست.",
  "left_side": {
    "fixed_orbs": [
      { "type": "number", "value": 3 },
      { "type": "number", "value": 5 }
    ]
  },
  "right_side": {
    "target_value": 8,
    "available_orbs": [
      { "type": "number", "value": 1, "count": 10 },
      { "type": "number", "value": 2, "count": 5 },
      { "type": "number", "value": 5, "count": 3 }
    ]
  },
  "tolerance": 0,
  "hint_sequence": [
    { "trigger": "idle_45s", "hint_id": "gentle_nudge_01" },
    { "trigger": "fail_3x", "hint_id": "socratic_operation_01" },
    { "trigger": "fail_6x", "hint_id": "socratic_specific_01" }
  ],
  "expected_solve_time_sec": 40,
  "difficulty_elo": 900
}
```

**فیلدهای کلیدی:**

| فیلد | نوع | توضیح |
|---|---|---|
| `tier` | int (1-5) | سطح دشواری مفهومی (بخش ۴ سند GDD اصلی) |
| `concept_tags` | array[string] | برای تطبیق با `skills` در Player Model |
| `tolerance` | float | خطای مجاز در تعادل (برای Tier بالاتر با اعداد اعشاری ممکن است >0 شود) |
| `hint_sequence` | array | نگاشت trigger به `hint_id` که در `aria_templates.json` تعریف می‌شود |
| `difficulty_elo` | int | برای `DifficultyEngine` جهت انتخاب سطح بعدی متناسب با رتبه‌ی بازیکن |

برای سطوح Tier 3 به بعد، یک شیء اضافه به نام `"ghost_orbs"` در `right_side` یا `left_side` اضافه می‌شود:

```json
"ghost_orbs": [
  { "id": "x1", "hidden_value": 4 }
]
```

---

## ۲. اسکیمای مدل بازیکن (Player Model)

مسیر: ذخیره‌ی محلی در `user://player_model.save` (فرمت JSON رمزنگاری‌نشده برای MVP)، همگام‌سازی با بک‌اند.

```json
{
  "schema_version": 1,
  "player_id": "p_193f2a7e",
  "created_at": "2026-09-01T10:00:00Z",
  "display_name": "کارآموز",
  "skills": {
    "addition_basic": { "elo": 1120, "confidence": 0.62, "attempts": 34, "last_seen": "2026-09-06" },
    "subtraction_negative": { "elo": 980, "confidence": 0.41, "attempts": 19, "last_seen": "2026-09-05" }
  },
  "error_patterns": [
    { "type": "sign_flip_on_subtraction", "count": 4 },
    { "type": "forgets_both_sides", "count": 2 }
  ],
  "levels_completed": ["tier1_level_01", "tier1_level_02"],
  "current_level": "tier1_level_03",
  "hint_usage_rate": 0.22,
  "avg_time_to_solve_sec": 47,
  "total_playtime_sec": 5400,
  "aria_transcript_log": [
    { "timestamp": "2026-09-06T14:02:00Z", "hint_id": "socratic_operation_01", "level_id": "tier1_level_03" }
  ]
}
```

**قوانین:**

- `schema_version` باید در هر migration افزایش یابد؛ `SaveSystem.gd` باید migration بین نسخه‌ها را پشتیبانی کند (حداقل: نسخه‌ی قدیمی را می‌خواند، فیلدهای جدید را با مقدار پیش‌فرض پر می‌کند).
- `aria_transcript_log` **کامل و بدون حذف** ذخیره می‌شود چون مبنای شفافیت برای داشبورد والدین است (بخش حریم خصوصی در GDD اصلی).
- هیچ فیلد PII (نام واقعی، ایمیل، موقعیت جغرافیایی) در این اسکیما وجود ندارد — فقط `display_name` که خودِ کاربر انتخاب می‌کند (اسم مستعار).

---

## ۳. اسکیمای رتبه‌بندی مهارت (Skill Rating — درون DifficultyEngine)

فرمول به‌روزرسانی (شبیه Elo)، در `scripts/data/SkillRating.gd`:

```gdscript
## K = ضریب یادگیری (چقدر سریع رتبه تغییر کند)
## expected_success = پیش‌بینی احتمال موفقیت بر اساس رتبه فعلی در برابر دشواری سطح
const K_FACTOR: float = 32.0

static func update_elo(current_elo: float, level_difficulty: float, did_succeed: bool) -> float:
    var expected_success: float = 1.0 / (1.0 + pow(10.0, (level_difficulty - current_elo) / 400.0))
    var actual_score: float = 1.0 if did_succeed else 0.0
    var new_elo: float = current_elo + K_FACTOR * (actual_score - expected_success)
    return clamp(new_elo, 400.0, 2000.0)
```

**نکته‌ی طراحی مهم:** موفقیت/شکست باید **وزن‌دار به تعداد راهنمای دریافتی** باشد — اگر بازیکن با ۳ راهنما حل کرد، `actual_score` باید ۱.۰ کامل نباشد (مثلاً `0.7`)، چون تسلط واقعی کمتر از حل مستقل است. این را در `ErrorClassifier.gd` محاسبه کن، نه در تابع بالا.

---

## ۴. اسکیمای قالب دیالوگ Aria (Dialogue Templates)

مسیر: `game/data/dialogue/aria_templates.json`

```json
{
  "hints": [
    {
      "hint_id": "socratic_operation_01",
      "applies_to_error_types": ["wrong_operation", "sign_flip_on_subtraction"],
      "min_tier": 1,
      "max_tier": 2,
      "text_variants": [
        "هوم... به نظرم یک طرف الان سنگین‌تره. اگه به‌جای اضافه‌کردن یه وزنه، یکی از طرف سنگین‌تر برداری چی می‌شه؟",
        "بیا با هم نگاه کنیم؛ کدوم کفه بیشتر پایین رفته؟ فکر می‌کنی چرا؟"
      ]
    },
    {
      "hint_id": "gentle_nudge_01",
      "applies_to_error_types": ["idle"],
      "min_tier": 1,
      "max_tier": 5,
      "text_variants": [
        "هر وقت آماده بودی، یه کره رو امتحان کن — می‌تونی همیشه دوباره جابه‌جاش کنی.",
        "فکر می‌کنم یه ایده داری؛ می‌خوای امتحانش کنی؟"
      ]
    }
  ]
}
```

**قانون انتخاب:** `AriaController.gd` باید از بین `text_variants` **به‌صورت چرخشی نه تصادفی محض** انتخاب کند (یعنی یک متغیر را دوبار پشت‌سرهم برای همان بازیکن در همان جلسه تکرار نکند) تا حس تکراری‌بودن ایجاد نشود.

**قانون طلایی که هیچ `text_variant`ی نباید نقض کند:** هیچ رشته‌ای در این فایل نباید مستقیماً عدد جواب نهایی را بیان کند. این باید در ریویوی محتوا (فاز ۷ در build plan) صراحتاً چک شود.

---

## ۵. اسکیمای رویداد آنالیتیکس (Events — برای بک‌اند)

```json
{
  "event_type": "level_completed",
  "player_id": "p_193f2a7e",
  "level_id": "tier1_level_03",
  "timestamp": "2026-09-06T14:10:00Z",
  "payload": {
    "time_to_solve_sec": 52,
    "hints_used": 1,
    "attempts": 4,
    "final_elo_delta": 12.5
  }
}
```

رویدادهای موردنیاز حداقلی برای MVP: `session_start`, `session_end`, `level_started`, `level_completed`, `hint_shown`, `error_occurred`.

---

## ۶. اسکیمای دیتابیس بک‌اند (PostgreSQL DDL)

مسیر: `backend/src/db/schema.sql`

```sql
CREATE TABLE players (
    player_id UUID PRIMARY KEY,
    display_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    schema_version INT NOT NULL DEFAULT 1
);

CREATE TABLE skill_ratings (
    id SERIAL PRIMARY KEY,
    player_id UUID REFERENCES players(player_id),
    skill_key TEXT NOT NULL,
    elo REAL NOT NULL,
    confidence REAL NOT NULL,
    attempts INT NOT NULL DEFAULT 0,
    last_seen TIMESTAMPTZ NOT NULL,
    UNIQUE (player_id, skill_key)
);

CREATE TABLE events (
    id BIGSERIAL PRIMARY KEY,
    player_id UUID REFERENCES players(player_id),
    event_type TEXT NOT NULL,
    level_id TEXT,
    payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_events_player_id ON events(player_id);
CREATE INDEX idx_events_type ON events(event_type);
```

**هیچ ستونی برای ایمیل، نام واقعی، یا موقعیت جغرافیایی در این اسکیما وجود ندارد — این عمدی است (بخش حریم خصوصی کودکان در GDD اصلی).**
