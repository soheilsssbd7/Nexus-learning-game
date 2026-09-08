extends Resource
class_name PlayerModel
# ===========================================================================
# PlayerModel — تنها منبع حقیقتِ «چقدر بلَد شده» (تسک ۱.۲)
# ---------------------------------------------------------------------------
# اسکیمای داده: docs/03-DATA-SCHEMAS.md §۲ — فیلدها و نام‌ها دقیقاً همان‌اند.
# اینجا **فقط** نگهداری/تبدیل داده انجام می‌شود؛ هیچ تصمیم آموزشی گرفته نمی‌شود:
#   - محاسبه‌ی Elo  → SkillRating.gd (تسک ۴.۱)
#   - وزن‌دهی راهنما → ErrorClassifier.gd (تسک ۴.۲ / نکته‌ی §۳ سند داده‌ها)
#   - انتخاب سطح بعدی → DifficultyEngine.gd (تسک ۴.۴)
#   - نوشتن روی دیسک → SaveSystem.gd (تسک ۱.۳)
#
# حریم خصوصی (§۲ و §۶ سند داده‌ها): هیچ فیلد PII نه اینجا، نه در JSON، نه در لاگ.
# `display_name` یک نام مستعار است که خود کاربر انتخاب می‌کند.
# ===========================================================================

## با هر migration افزایش می‌یابد؛ SaveSystem بر اساس همین مقدار مهاجرت می‌کند.
const SCHEMA_VERSION: int = 1
## ADR-019: transcript چرخشی است («بدون حذف» یعنی تا وقتی والد نگاه می‌کند).
const MAX_TRANSCRIPT_ENTRIES: int = 500
## ADR-015: EMA برای آمار زمان/راهنما.
const EMA_ALPHA: float = 0.3

@export var schema_version: int = SCHEMA_VERSION
@export var player_id: String = ""
@export var created_at: String = ""
@export var display_name: String = "کارآموز"
## skill_key (از concept_tags) → SkillRating
@export var skills: Dictionary = {}
## [{ "type": String, "count": int }]
@export var error_patterns: Array[Dictionary] = []
@export var levels_completed: Array[String] = []
@export var current_level: String = ""
@export var hint_usage_rate: float = 0.0
@export var avg_time_to_solve_sec: float = 0.0
@export var total_playtime_sec: float = 0.0
## [{ "timestamp": ISO8601, "hint_id": String, "level_id": String }]
@export var aria_transcript_log: Array[Dictionary] = []


# --------------------------------------------------------------------------
# ساخت
# --------------------------------------------------------------------------
static func create_new(display: String = "کارآموز") -> PlayerModel:
	var m := PlayerModel.new()
	m.schema_version = SCHEMA_VERSION
	m.player_id = generate_player_id()
	m.created_at = Time.get_datetime_string_from_system(true)
	m.display_name = display
	m.current_level = ""
	return m


## قالب `p_<12 hex>` (ADR-005). از UUID.v4 گرفته می‌شود تا کلاش نباشد.
static func generate_player_id() -> String:
	var raw: String = UUID.v4().replace("-", "")
	if raw.length() < 12:
		# هرگز نباید رخ دهد؛ fallback تا بازی هیچ‌وقت به خاطر id نشکند.
		raw = "%012x" % (randi() * randi())
	return "p_" + raw.substr(0, 12)


# --------------------------------------------------------------------------
# مهارت‌ها
# --------------------------------------------------------------------------
## SkillRating را می‌دهد؛ اگر skill ثبت نشده باشد، با مقادیر شروع ساخته می‌شود.
func ensure_skill(skill_key: String) -> SkillRating:
	if skill_key.is_empty():
		skill_key = "general"
	if not skills.has(skill_key):
		skills[skill_key] = SkillRating.new()
	var rating: SkillRating = skills[skill_key]
	if rating.last_seen.is_empty():
		rating.confidence = SkillRating.compute_confidence(rating.attempts)
	return rating


func skill_elo(skill_key: String) -> float:
	if not skills.has(skill_key):
		return SkillRating.ELO_START
	var rating: SkillRating = skills[skill_key]
	return rating.elo if rating != null else SkillRating.ELO_START


## میانگین رتبه‌ی مهارت‌های یک سطح — ورودی «رتبه‌ی فعلی بازیکن» برای DifficultyEngine.
func average_skill_elo(skill_keys: PackedStringArray) -> float:
	var relevant: Array[String] = []
	for k: String in skill_keys:
		if skills.has(k):
			relevant.append(k)
	if relevant.is_empty():
		return SkillRating.ELO_START
	var total: float = 0.0
	for k: String in relevant:
		total += skill_elo(k)
	return total / float(relevant.size())


# --------------------------------------------------------------------------
# به‌روزرسانی‌های اتمیک (از DifficultyEngine / AriaController صدا زده می‌شوند)
# --------------------------------------------------------------------------
## آمار یک سطحِ حل‌شده. `stats` همان payload سیگنال level_completed است.
func mark_level_completed(level_id: String, time_sec: float, hints_used: int) -> void:
	if not levels_completed.has(level_id):
		levels_completed.append(level_id)
	current_level = level_id
	# EMA — ADR-015
	avg_time_to_solve_sec = _ema(avg_time_to_solve_sec, time_sec)
	hint_usage_rate = _ema(hint_usage_rate, 1.0 if hints_used > 0 else 0.0)


func _ema(old_value: float, sample: float) -> float:
	if is_equal_approx(old_value, 0.0):
		return sample
	return lerpf(old_value, sample, EMA_ALPHA)


func bump_error_pattern(error_type: String) -> void:
	for entry: Dictionary in error_patterns:
		if entry.get("type", "") == error_type:
			entry["count"] = int(entry.get("count", 0)) + 1
			return
	error_patterns.append({"type": error_type, "count": 1})


func count_error_pattern(error_type: String) -> int:
	for entry: Dictionary in error_patterns:
		if entry.get("type", "") == error_type:
			return int(entry.get("count", 0))
	return 0


## §۲: این ورودی‌ها مبنای شفافیتِ داشبورد والدین‌اند → حذف خودکار نداریم (فقط سقف چرخشی).
func record_hint_shown(hint_id: String, level_id: String) -> void:
	aria_transcript_log.append({
		"timestamp": Time.get_datetime_string_from_system(true),
		"hint_id": hint_id,
		"level_id": level_id,
	})
	while aria_transcript_log.size() > MAX_TRANSCRIPT_ENTRIES:
		aria_transcript_log.pop_front()


func add_playtime(sec: float) -> void:
	if sec > 0.0:
		total_playtime_sec += sec


func is_level_completed(level_id: String) -> bool:
	return levels_completed.has(level_id)


# --------------------------------------------------------------------------
# سریال‌سازی (JSON روی دیسک / REST به بک‌اند)
# --------------------------------------------------------------------------
func to_dict() -> Dictionary:
	var skills_out := {}
	for key: String in skills.keys():
		var rating: SkillRating = skills[key]
		if rating != null:
			skills_out[key] = rating.to_dict()
	return {
		"schema_version": schema_version,
		"player_id": player_id,
		"created_at": created_at,
		"display_name": display_name,
		"skills": skills_out,
		"error_patterns": error_patterns.duplicate(true),
		"levels_completed": Array(levels_completed),
		"current_level": current_level,
		"hint_usage_rate": SkillRating.quantize(hint_usage_rate),
		"avg_time_to_solve_sec": SkillRating.quantize(avg_time_to_solve_sec),
		"total_playtime_sec": SkillRating.quantize(total_playtime_sec),
		"aria_transcript_log": aria_transcript_log.duplicate(true),
	}


## تلورنس کامل: هر فیلد غایب = مقدار پیش‌فرض (این همان پایه‌ی migration در SaveSystem است).
static func from_dict(d: Dictionary) -> PlayerModel:
	var m := PlayerModel.new()
	m.schema_version = int(d.get("schema_version", SCHEMA_VERSION))
	m.player_id = str(d.get("player_id", ""))
	if m.player_id.is_empty():
		m.player_id = generate_player_id()
	m.created_at = str(d.get("created_at", Time.get_datetime_string_from_system(true)))
	m.display_name = str(d.get("display_name", "کارآموز"))

	var raw_skills: Variant = d.get("skills", {})
	if raw_skills is Dictionary:
		for key: Variant in raw_skills.keys():
			var value: Variant = raw_skills[key]
			if value is Dictionary:
				m.skills[str(key)] = SkillRating.from_dict(value)

	var raw_patterns: Variant = d.get("error_patterns", [])
	if raw_patterns is Array:
		for entry: Variant in raw_patterns:
			if entry is Dictionary and entry.has("type"):
				m.error_patterns.append({
					"type": str(entry["type"]),
					"count": int(entry.get("count", 0)),
				})

	var raw_done: Variant = d.get("levels_completed", [])
	if raw_done is Array:
		for id: Variant in raw_done:
			m.levels_completed.append(str(id))

	m.current_level = str(d.get("current_level", ""))
	m.hint_usage_rate = float(d.get("hint_usage_rate", 0.0))
	m.avg_time_to_solve_sec = float(d.get("avg_time_to_solve_sec", 0.0))
	m.total_playtime_sec = float(d.get("total_playtime_sec", 0.0))

	var raw_log: Variant = d.get("aria_transcript_log", [])
	if raw_log is Array:
		for entry: Variant in raw_log:
			if entry is Dictionary:
				m.aria_transcript_log.append(entry)
	return m


func summary_for_parent() -> Dictionary:
	return {
		"player_id": player_id,
		"display_name": display_name,
		"levels_completed": levels_completed.size(),
		"total_playtime_sec": total_playtime_sec,
			"hint_usage_rate": hint_usage_rate,
		"avg_time_to_solve_sec": avg_time_to_solve_sec,
		"skills": skills.keys(),
		"transcript_entries": aria_transcript_log.size(),
	}
