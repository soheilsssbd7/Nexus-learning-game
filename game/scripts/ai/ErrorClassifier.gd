class_name ErrorClassifier
# ===========================================================================
# ErrorClassifier — طبقه‌بندی rule-based خطای بازیکن (تسک ۴.۲ | docs/04)
# --------------------------------------------------------------------------
# ورودی: `config` سطح (قرارداد ADR-028) + state فعلی دو کفه. **هیچ** فراخوانی
# هوش مصنوعی/شبکه اینجا نیست (docs/04 §۴.۲ و FeatureFlags.LIVE_AI_ENABLED=false).
#
# چهار نوع خطا (تعریف سند ساخت):
#   wrong_operation          جهت را اشتباه گرفته (کم کرده به‌جای اضافه کردن / برعکس)
#   sign_flip_on_subtraction علامت اشتباه در استفاده از NegativeOrb
#   forgets_both_sides       وقتی باید هر دو کفه تغییر کند، فقط یکی را تغییر داده
#   computation_error        جهت درست، مقدار عددی اشتباه
# و یک مقدار غیرخطا:
#   idle                     بی‌حرکتی؛ از HintTimingSystem می‌آید، نه از این کلاس
#
# چرا «قضاوت روی وزن» و نه روی حرکت‌به‌حرکت؟ چون داده‌ی سطح خودش **هم** جوابِ
# موردنظر (`solution_spec.intended`) و هم خطای منتظره‌ی نویسنده
# (`solution_spec.wrong_ops`) را دارد (رفع ابهام A2 در ممیزی)؛ پس می‌توان دقیق و
# قابل‌تست تصمیم گرفت بدون هیچ مدل زبانی.
# ===========================================================================

const TAG := "ErrorClassifier"

const WRONG_OPERATION := "wrong_operation"
const SIGN_FLIP_ON_SUBTRACTION := "sign_flip_on_subtraction"
const FORGETS_BOTH_SIDES := "forgets_both_sides"
const COMPUTATION_ERROR := "computation_error"
## از HintTimingSystem؛ اینجا فقط تعریف شده تا فهرست انواع، یک‌جا و واحد باشد.
const IDLE := "idle"

## انواعِ خطای واقعی (idle عمداً بیرون است: بی‌حرکتی، خطای محاسباتی نیست)
const ERROR_TYPES: Array[String] = [
	WRONG_OPERATION, SIGN_FLIP_ON_SUBTRACTION, FORGETS_BOTH_SIDES, COMPUTATION_ERROR,
]

## آستانه‌های عددی (مقایسه‌ی شبه‌ای وزن‌ها)
const WEIGHT_EPS := 0.0001

## امتیاز وزن‌دارِ §۳ سند داده‌ها / docs/07 §۵ (ADR-015):
## score = 1 - 0.15*min(hints,2) - 0.05*min(extra_attempts,4)
## سقف‌ها عمداً کوتاه‌شده‌اند: راهنمای بیشتر از ۲ و تلاشِ بیشتر از ۴، تنبیه را
## بی‌نهایت نمی‌کند (کودک ۹ ساله نباید «صفر» بگیرد؛ کف طبیعی این فرمول ۰.۵ است).
const HINT_PENALTY := 0.15
const HINT_PENALTY_MAX := 2
const ATTEMPT_PENALTY := 0.05
const ATTEMPT_PENALTY_MAX := 4


## امتیازی که `SkillRating.update_elo` به‌جای ۱.۰ می‌گیرد.
## attempts = شمارنده‌ی کل تلاش‌ها؛ «تلاش‌های اضافه» = attempts-1 (آخری موفق است).
static func success_score(hints_used: int, attempts: int) -> float:
	var extra: int = maxi(0, attempts - 1)
	var score: float = 1.0 \
		- HINT_PENALTY * minf(float(hints_used), float(HINT_PENALTY_MAX)) \
		- ATTEMPT_PENALTY * minf(float(extra), float(ATTEMPT_PENALTY_MAX))
	return clampf(score, 0.0, 1.0)


# --------------------------------------------------------------------------
# ورودی‌خوانی
# --------------------------------------------------------------------------
static func _scale_at(level_config: Dictionary, scale_index: int) -> Dictionary:
	var scales: Variant = level_config.get("scales", [])
	if not (scales is Array) or (scales as Array).is_empty():
		return {}
	var i: int = clampi(scale_index, 0, (scales as Array).size() - 1)
	var scale: Variant = (scales as Array)[i]
	return scale as Dictionary if scale is Dictionary else {}


static func _sum(orbs: Array) -> float:
	var total: float = 0.0
	for entry: Variant in orbs:
		if entry is Dictionary:
			total += _weight_of(entry as Dictionary)
	return total


## وزن یک کره. `weight` اگر داده شده باشد همان است (نمای صریحِ snapshot)، وگرنه از
#  type/value/hidden_value ساخته می‌شود — همان قاعده‌ی LevelData.orb_weight.
static func _weight_of(entry: Dictionary) -> float:
	if entry.has("weight"):
		return float(entry.get("weight", 0.0))
	return LevelData.orb_weight(entry)


static func _entries_of(scale: Dictionary, key: String) -> Array:
	var raw: Variant = scale.get(key, [])
	var out: Array = []
	if raw is Array:
		for entry: Variant in (raw as Array):
			if entry is Dictionary:
				out.append(entry)
	return out


## جمع وزن‌های یک فهرست از ورودی‌های `solution_spec.intended` — عددهای خام، نه dict:
## `right_orbs: [4, 4, 1]` → ۹ و `removed_orbs: [6]` → ۶ (همیشه قدرمطلق؛ علامتِ
## معنادار را از نام کلید می‌فهمیم، نه از علامت عدد).
static func _sum_numbers(value: Variant) -> float:
	if not (value is Array):
		return 0.0
	var total: float = 0.0
	for item: Variant in (value as Array):
		if item is int or item is float:
			total += float(item)  # علامت‌دار: `right_orbs: [10, -2]` یعنی ۸
		elif item is Dictionary:
			total += _weight_of(item)
	return total


# --------------------------------------------------------------------------
# تحلیل کمّی state (خروجی‌اش برای لاگ/داشبورد والدین هم به‌درد می‌خورد)
# --------------------------------------------------------------------------
## {left_base,left_now,left_delta,right_base,right_now,right_delta,
##  need_right,intended_left_removed,tolerance,balanced}
static func state_of(level_config: Dictionary, left_now: Array, right_now: Array,
		scale_index: int = 0) -> Dictionary:
	var scale := _scale_at(level_config, scale_index)
	var left_base: float = _sum(_entries_of(scale, "left_orbs")) \
		+ _sum(_entries_of(scale, "left_ghost_orbs"))
	var right_base: float = _sum(_entries_of(scale, "right_orbs")) \
		+ _sum(_entries_of(scale, "right_ghost_orbs"))
	var left_now_weight: float = _sum(left_now)
	var right_now_weight: float = _sum(right_now)
	var spec: Dictionary = _as_dict(level_config.get("solution_spec"))
	var intended: Dictionary = _as_dict(spec.get("intended"))
	var intended_right: float = _sum_numbers(intended.get("right_orbs"))
	var need_right: float = intended_right
	# فقط وقتی spec چیزی نمی‌گوید میانگین‌گیری را از خود معادله بساز (need منفی یعنی
	# «از راست بردار» — آرک‌تایپ ۳ — پس نباید با fallback بازنویسی شود)
	if absf(intended_right) <= WEIGHT_EPS:
		# سطح بدون solution_spec (داده‌ی فاز ۲/۳ِ حداقلی): نیاز از خود معادله (§۱)
		var target: float = float(scale.get("target_value", 0.0))
		need_right = target if target > WEIGHT_EPS else maxf(0.0, left_base - right_base)
	var tolerance: float = float(level_config.get("tolerance", 0.0))
	return {
		"left_base": left_base,
		"left_now": left_now_weight,
		"left_delta": left_now_weight - left_base,
		"right_base": right_base,
		"right_now": right_now_weight,
		"right_delta": right_now_weight - right_base,
		"need_right": need_right,
		"intended_left_removed": absf(_sum_numbers(intended.get("removed_orbs"))),
		"tolerance": tolerance,
		"balanced": absf(left_now_weight - right_now_weight) <= maxf(tolerance, WEIGHT_EPS),
	}


static func _as_dict(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


# --------------------------------------------------------------------------
# طبقه‌بندی
# --------------------------------------------------------------------------
## "" یعنی خطایی برای طبقه‌بندی نیست (تعادل برقرار است یا هنوز کاری نکرده).
static func classify(level_config: Dictionary, left_now: Array, right_now: Array,
		scale_index: int = 0) -> String:
	if level_config.is_empty():
		return ""
	var s := state_of(level_config, left_now, right_now, scale_index)
	var d_left: float = float(s["left_delta"])
	var d_right: float = float(s["right_delta"])
	if bool(s["balanced"]):
		return ""
	if absf(d_left) <= WEIGHT_EPS and absf(d_right) <= WEIGHT_EPS:
		return ""  # هنوز چیزی جابه‌جا نشده؛ «بی‌حرکتی» کار HintTimingSystem است

	# ۱) علامت اشتباه: با وارونه‌کردن علامتِ دقیقاً یک کره، حساب می‌بندد
	if _is_sign_flip(s, left_now, right_now, level_config):
		return SIGN_FLIP_ON_SUBTRACTION
	# ۲) جهت اشتباه: خلافِ جهتِ `solution_spec.intended` (یا همان wrong_ops نویسنده)
	if _is_wrong_direction(s, d_left, d_right, level_config):
		return WRONG_OPERATION
	# ۳) سطحی که «هر دو کفه» را می‌خواهد و بازیکن فقط یکی را دست زده
	if _forgets_a_side(s, d_left, d_right):
		return FORGETS_BOTH_SIDES
	# ۴) جهت درست، مقدار نزدیک ولی نه دقیق
	return COMPUTATION_ERROR


## معیارِ تشخیص: اگر علامتِ **یک** کره‌ی روی کفه‌ها را وارون کنیم ترازو متعادل می‌شد،
## خطا از نوع «علامت» است (＋v جایی که −v لازم بود دو واحد جابه‌جا می‌کند، نه یک واحد).
## کره فقط وقتی کاندید است که اندازه‌اش در سینیِ همین سطح باشد (کره‌ی از‌قبل‌روی‌کفه
## انتخاب بازیکن نیست، پس «وارونگی علامت» توضیحِ کار او نیست).
static func _is_sign_flip(s: Dictionary, left_now: Array, right_now: Array,
		level_config: Dictionary) -> bool:
	var tol: float = maxf(float(s["tolerance"]), WEIGHT_EPS)
	var left_total: float = float(s["left_now"])
	var right_total: float = float(s["right_now"])
	var level_has_negative: bool = _level_has_negative(level_config)
	for orb: Variant in right_now:
		if not (orb is Dictionary):
			continue
		var w: float = _weight_of(orb as Dictionary)
		if not _is_flip_candidate(level_config, orb as Dictionary, level_has_negative):
			continue
		if absf(left_total - (right_total - 2.0 * w)) <= tol:
			return true
	for orb: Variant in left_now:
		if not (orb is Dictionary):
			continue
		var wl: float = _weight_of(orb as Dictionary)
		if not _is_flip_candidate(level_config, orb as Dictionary, level_has_negative):
			continue
		if absf((left_total - 2.0 * wl) - right_total) <= tol:
			return true
	return false


## کاندیدِ وارونگی: اندازه‌اش در سینی همین سطح باشد (کره‌ی از‌قبل‌روی‌کفه، انتخاب بازیکن
## نیست) **و** این سطح یا حباب ضد-وزن دارد یا خودِ کره حباب است — بی‌ضدوزن، برچسبِ
## «علامت» معنایی ندارد (§۴.۲: خطای استفاده از NegativeOrb).
static func _is_flip_candidate(level_config: Dictionary, orb: Dictionary,
		level_has_negative: bool) -> bool:
	var magnitude: float = absf(_weight_of(orb))
	if magnitude <= WEIGHT_EPS:
		return false
	if not _is_available_magnitude(level_config, magnitude):
		return false
	return level_has_negative or str(orb.get("type", "number")) == "negative"


## آیا در سینیِ این سطح `negative` وجود دارد?
static func _level_has_negative(level_config: Dictionary) -> bool:
	for entry: Variant in _entries_of(level_config, "available_orbs"):
		if str((entry as Dictionary).get("type", "number")) == "negative":
			return true
	return false


static func _is_available_magnitude(level_config: Dictionary, magnitude: float) -> bool:
	for entry: Variant in _entries_of(level_config, "available_orbs"):
		if absf(absf(_weight_of(entry as Dictionary)) - magnitude) <= WEIGHT_EPS:
			return true
	return false


## «اضافه کرده به‌جای کم‌کردن» — و برعکس.
static func _is_wrong_direction(s: Dictionary, d_left: float, d_right: float,
		level_config: Dictionary) -> bool:
	var need: float = float(s["need_right"])
	var remove_left: float = float(s["intended_left_removed"])
	# جهتِ راست: نیاز مثبت یعنی «اضافه کن»؛ بازیکن کم کرده
	if need > WEIGHT_EPS and d_right < -WEIGHT_EPS:
		return true
	# نیاز منفی یعنی «از راست بردار»؛ بازیکن اضافه کرده
	if need < -WEIGHT_EPS and d_right > WEIGHT_EPS:
		return true
	# چپ: اگر قرار بوده از چپ برداشته شود ولی بازیکن به چپ اضافه کرده
	if remove_left > WEIGHT_EPS and d_left > WEIGHT_EPS:
		return true
	# و اگر نباید چپ دست‌بخوردگی ولی بازیکن از چپ کم کرده تا راست را پر کند
	if remove_left <= WEIGHT_EPS and d_left < -WEIGHT_EPS and need > WEIGHT_EPS:
		return true
	# خطای منتظره‌ی نویسنده (`solution_spec.wrong_ops`) دقیقاً همین‌جاست
	var spec: Dictionary = _as_dict(level_config.get("solution_spec"))
	var wrong_ops: Dictionary = _as_dict(spec.get("wrong_ops"))
	for key: Variant in wrong_ops.keys():
		var name: String = str(key)
		if name.contains("left") and absf(d_left) > WEIGHT_EPS \
				and ((name.begins_with("remove") and d_left < 0.0) or (name.begins_with("add") and d_left > 0.0)):
			return true
		if name.contains("right") and absf(d_right) > WEIGHT_EPS \
				and ((name.begins_with("remove") and d_right < 0.0) or (name.begins_with("add") and d_right > 0.0)):
			return true
	return false


## آرک‌تایپ «هر دو طرف»: intended روی هر دو کفه تغییر می‌خواهد و یکی دست‌نخورده است.
static func _forgets_a_side(s: Dictionary, d_left: float, d_right: float) -> bool:
	var need: float = float(s["need_right"])
	var remove_left: float = float(s["intended_left_removed"])
	if absf(need) <= WEIGHT_EPS or absf(remove_left) <= WEIGHT_EPS:
		return false
	return absf(d_left) <= WEIGHT_EPS or absf(d_right) <= WEIGHT_EPS


static func is_error_type(error_type: String) -> bool:
	return ERROR_TYPES.has(error_type)
