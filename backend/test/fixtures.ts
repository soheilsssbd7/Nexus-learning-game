/**
 * NEXUS — بک‌اند | نمونه‌های آزمون
 * ===============================
 * مدلِ زیر **همان نمونهٔ `docs/03` §۲ است** ✓ (نه یک مدلِ دست‌سازِ تست ⇒ اگر قرارداد عوض
 * شد، این فایل و گیتِ `check_backend_schema_contract` با هم می‌گویند ✓✓).
 */
import type { PlayerModel } from "../src/schemas/playerModel.js";
import type { AnalyticsEvent } from "../src/schemas/events.js";

export const SAMPLE_MODEL: PlayerModel = {
  schema_version: 1,
  player_id: "p_193f2a7e",
  created_at: "2026-09-01T10:00:00Z",
  display_name: "کارآموز",
  skills: {
    addition_basic: { elo: 1120, confidence: 0.62, attempts: 34, last_seen: "2026-09-06" },
    subtraction_negative: { elo: 980, confidence: 0.41, attempts: 19, last_seen: "2026-09-05" },
  },
  error_patterns: [
    { type: "sign_flip_on_subtraction", count: 4 },
    { type: "forgets_both_sides", count: 2 },
  ],
  levels_completed: ["tier1_level_01", "tier1_level_02"],
  current_level: "tier1_level_03",
  hint_usage_rate: 0.22,
  avg_time_to_solve_sec: 47,
  total_playtime_sec: 5400,
  aria_transcript_log: [
    {
      timestamp: "2026-09-06T14:02:00Z",
      hint_id: "socratic_operation_01",
      level_id: "tier1_level_03",
    },
  ],
};

export const SAMPLE_EVENT: AnalyticsEvent = {
  event_type: "level_completed",
  player_id: "p_193f2a7e",
  level_id: "tier1_level_03",
  timestamp: "2026-09-06T14:10:00Z",
  payload: { time_to_solve_sec: 52, hints_used: 1, attempts: 4, final_elo_delta: 12.5 },
};

export const OTHER_PLAYER_ID = "p_deadbeef";
