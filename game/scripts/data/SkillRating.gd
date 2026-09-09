class_name SkillRating
extends Resource
# ===========================================================================
# SkillRating — رتبه‌ی یک مهارت (تسک ۴.۱؛ docs/03-DATA-SCHEMAS.md §3)
# ---------------------------------------------------------------------------
# فرمول دقیقاً همان قطعه‌کد §3 است؛ دو چیز افزوده شده:
#  1) `actual_score` وزن‌دار: §3 می‌گوید اگر با راهنما حل شد امتیاز کامل ندهیم.
#     آن وزن در ErrorClassifier/DifficultyEngine محاسبه و **به این تابع تزریق**
#     می‌شود (اینجا فقط clamp).
#  2) `confidence` — در §2 فیلد هست ولی فرمول ندارد؛ ADR-015: attempts/(attempts+12).
# ===========================================================================

const ELO_MIN: float = 400.0
const ELO_MAX: float = 2000.0
const ELO_START: float = 1000.0
## K = ضریب یادگیری (چقدر سریع رتبه تغییر کند) — §3
const K_FACTOR: float = 32.0
## ADR-015: با ۱۲ تلاش، confidence به ۰.۵ می‌رسد.
const CONFIDENCE_HALF_ATTEMPTS: float = 12.0

@export var elo: float = ELO_START
@export var confidence: float = 0.0
@export var attempts: int = 0
## تاریخ ISO (YYYY-MM-DD). در اسکیما رشته است، نه timestamp — همان را نگه می‌داریم.
@export var last_seen: String = ""


## احتمال موفقیتِ پیش‌بینی‌شده (منطقه‌ی ۰..۱) — §3
static func expected_success(current_elo: float, level_difficulty: float) -> float:
	return 1.0 / (1.0 + pow(10.0, (level_difficulty - current_elo) / 400.0))


## §3 — `update_elo` با یک پارامتر اختیاری برای امتیاز وزن‌دار.
## did_succeed: آیا سطح در نهایت حل شد.
## weighted_score: اگر >= 0 داده شود، جای 1.0/0.0 را می‌گیرد (کاهش به‌خاطر راهنما).
static func update_elo(
		current_elo: float,
		level_difficulty: float,
		did_succeed: bool,
		weighted_score: float = -1.0) -> float:
	var expected: float = expected_success(current_elo, level_difficulty)
	var actual_score: float = 1.0 if did_succeed else 0.0
	if weighted_score >= 0.0:
		actual_score = clampf(weighted_score, 0.0, 1.0)
	var new_elo: float = current_elo + K_FACTOR * (actual_score - expected)
	return clampf(new_elo, ELO_MIN, ELO_MAX)


## ADR-015
static func compute_confidence(attempt_count: int) -> float:
	return clampf(float(attempt_count) / (float(attempt_count) + CONFIDENCE_HALF_ATTEMPTS), 0.0, 1.0)


## یک نتیجه‌ی تلاش را اعمال می‌کند و **delta** رتبه را برمی‌گرداند
## (AnalyticsManager آن را در payload رویداد `level_completed` می‌گذارد: final_elo_delta).
func apply_result(level_difficulty: float, did_succeed: bool, weighted_score: float = -1.0) -> float:
	var before: float = elo
	elo = update_elo(elo, level_difficulty, did_succeed, weighted_score)
	attempts += 1
	confidence = compute_confidence(attempts)
	last_seen = Time.get_date_string_from_system(true)  # UTC، سازگار با §2
	return elo - before


const FLOAT_PRECISION := 0.000001


## round به ۶ رقم اعشار: JSON.stringify  دقت کامل double را چاپ نمی‌کند؛ بدون این کار
## یک دور «ذخیره → بارگذاری» می‌تواند عدد را عوض‌شده نشان دهد (و تست‌های برابری را می‌شکند).
static func quantize(v: float) -> float:
	return snappedf(v, FLOAT_PRECISION)


func to_dict() -> Dictionary:
	return {
		"elo": SkillRating.quantize(elo),
		"confidence": SkillRating.quantize(confidence),
		"attempts": attempts,
		"last_seen": last_seen,
	}


static func from_dict(d: Dictionary) -> SkillRating:
	var r := SkillRating.new()
	r.elo = clampf(float(d.get("elo", ELO_START)), ELO_MIN, ELO_MAX)
	r.confidence = clampf(float(d.get("confidence", 0.0)), 0.0, 1.0)
	r.attempts = maxi(0, int(d.get("attempts", 0)))  # شمارنده‌ی منفی از دیسک = 0
	r.last_seen = str(d.get("last_seen", ""))
	return r
