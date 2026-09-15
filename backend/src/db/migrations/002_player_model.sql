-- NEXUS — مهاجرتِ ۰۰۲ | تسک ۹.۳ (docs/04 §۹)
-- ===========================================================
-- **چرا این فایل هست؟** §۶ سند Data Schemas سه جدول می‌دهد (`players`, `skill_ratings`,
-- `events`) و §۲ «مدل بازیکن» چیزی است که endpointِ ۹.۳ باید *ذخیره و بازیابی* کند —
-- شامل `levels_completed`, `current_level`, `hint_usage_rate`, `avg_time_to_solve_sec`,
-- `total_playtime_sec`, `error_patterns`, `aria_transcript_log` ✗ هیچ‌کدام در آن سه جدول
-- جایی ندارند ✓⇒ «دقیقاً طبق §۶» با «DoDِ ۹.۳ (ارسال ⇒ دریافتِ همان مدل)» تنها با
-- یک افزودنیِ **بدونِ تغییرِ** §۶ شدنی است ✓✓ (ADR-063: اسکیما را نمی‌شکنیم، افزون می‌کنیم).
--
-- قیدهای آگاهانه:
--  • فقط یک ردیف به‌ازای هر بازیکن (snapshotِ آخر) ✓ — تاریخچۀ رویدادها در `events` است ✓§۶
--  • `model JSONB` همان `player_model.save` است ✓ (بدونِ ستون‌های PII ✗§۹؛ نامِ نمایشی را
--    همان `players.display_name` نگه می‌دارد که §۶ تعیین کرده ✓)
--  • `updated_at` برای «آخرین همگام‌سازی» و رفعِ نبردِ نسخه در کلاینت (۹.۶) مصرف می‌شود ✓

CREATE TABLE player_models (
    player_id UUID PRIMARY KEY REFERENCES players(player_id),
    schema_version INT NOT NULL,
    model JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_player_models_updated_at ON player_models(updated_at);
