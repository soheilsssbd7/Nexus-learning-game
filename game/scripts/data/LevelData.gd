class_name LevelData
extends Resource
# ===========================================================================
# LevelData — پارس‌کننده‌ی دقیقاً مطابق `03-DATA-SCHEMAS.md` §۱ (تسک ۳.۱)
# ---------------------------------------------------------------------------
# سه اصل طراحی که عمداً انتخاب شده‌اند:
#  ۱) **هیچ خطایی چاپ نمی‌کند.** این کلاس داده‌ی نامطمئن را می‌خواند و نتیجه را
#     به‌صورت مقدار برمی‌گرداند (`validate()` و `{ok, level, error}`); هیچ
#     `push_error()` ندارد، چون طبق ADR-023 هر push_error در GUT یعنی تست قرمز
#     و در logcat دستگاه یعنی صدای مزاحم.
#  ۲) **منطق بازی را اجرا نمی‌کند.** «قابل‌حل بودن» کار `tools/validate_levels.py`
#     است (DP زیرمجموعه، منبع واحد). اینجا فقط ساختار/حساب ساده چک می‌شود تا داده‌ی
#     فاسد وارد صحنه نشود.
#  ۳) **قاعده‌ی علامت را از کلاس کره‌ها می‌گیرد، نه از عدد داده**: `negative` یعنی
#     منفی، هرچند `value` مثبت نوشته شده (ADR-028) → همان `orb_weight()` پایین که
#     با `WeightOrb.weight()` در تست قفل می‌شود.
# ===========================================================================

const TAG := "LevelData"
const ALLOWED_WORLD: String = "balance_realm"
const ALLOWED_ORB_TYPES: Array[String] = ["number", "ghost", "negative"]
const LEVEL_ID_PATTERN: String = "^tier[1-5]_level_[0-9]{2}$"
const TRIGGER_PATTERN: String = "^(idle_[0-9]+s|fail_[0-9]+x|help_requested|first_wrong_attempt)$"
## حداقل طول جمله‌ی روایی؛ کوتاه‌تر از این برای کودک ۹-۱۵ ساله بی‌مفهوم است (تسک ۷.x).
const MIN_INTRO_LEN: int = 10

@export_group("هویت")
@export var level_id: String = ""
@export var tier: int = 1
@export var world: String = ALLOWED_WORLD
@export var concept_tags: Array[String] = []
@export var narrative_intro: String = ""
@export var source_path: String = ""

@export_group("چپ")
@export var left_fixed_orbs: Array[Dictionary] = []
@export var left_ghost_orbs: Array[Dictionary] = []

@export_group("راست")
@export var right_fixed_orbs: Array[Dictionary] = []
@export var right_ghost_orbs: Array[Dictionary] = []
@export var target_value: float = 0.0
## false یعنی کلید `target_value` در داده نبوده (سطح «کشف مجهول» در Tier 3+).
@export var has_target: bool = false
@export var available_orbs: Array[Dictionary] = []

@export_group("چندکفه‌ای (Tier 4+)")
## آرک‌تایپ «Twin Observatory»: آرایه‌ی `scales` در فایل با **همان کلیدهای** configِ
## LevelController نوشته می‌شود (`left_orbs/right_orbs/*_ghost_orbs/target_value/id`)
## ⇒ هیچ لایه‌ی ترجمه‌ای وجود ندارد که بتواند بلغزد ✗✓ (ADR-055). خالی = تک‌کفه.
## سینی **مشترک** است: `available_orbs` همان‌جا در `right_side` می‌ماند، چون موتور
## یک سینی برای کل سطح دارد (§۲ سند ۰۱) ⇒ «قابل‌حل بودن» یعنی تقسیمِ کره‌ها بین کفه‌ها،
## و آن را باتِ GUT در موتور می‌سنجد، نه DPِ تک‌کفه‌ای (پیامد F).
@export var scales_cfg: Array[Dictionary] = []

@export_group("تنظیم")
@export var tolerance: float = 0.0
@export var tolerance_strategy: String = "exact"
@export var hint_sequence: Array[Dictionary] = []
@export var expected_solve_time_sec: float = 40.0
@export var difficulty_elo: int = 900
@export var solution_spec: Dictionary = {}


# --------------------------------------------------------------------------
# ساخت
# --------------------------------------------------------------------------
static func from_dict(data: Dictionary, p_source_path: String = "") -> LevelData:
	var lv := LevelData.new()
	lv.source_path = p_source_path
	lv.level_id = str(data.get("level_id", ""))
	lv.tier = int(data.get("tier", 1))
	lv.world = str(data.get("world", ALLOWED_WORLD))
	lv.concept_tags = _string_array(data.get("concept_tags"))
	lv.narrative_intro = str(data.get("narrative_intro", ""))

	var left: Dictionary = _dict(data.get("left_side"))
	var right: Dictionary = _dict(data.get("right_side"))
	lv.left_fixed_orbs = _orb_array(left.get("fixed_orbs"))
	lv.left_ghost_orbs = _orb_array(left.get("ghost_orbs"))
	lv.right_fixed_orbs = _orb_array(right.get("fixed_orbs"))
	lv.right_ghost_orbs = _orb_array(right.get("ghost_orbs"))
	lv.available_orbs = _orb_array(right.get("available_orbs"))
	lv.has_target = right.get("target_value") != null
	lv.target_value = float(right.get("target_value", 0.0))
	lv.tolerance = float(data.get("tolerance", 0.0))
	lv.tolerance_strategy = str(data.get("tolerance_strategy", "exact"))
	lv.expected_solve_time_sec = float(data.get("expected_solve_time_sec", 40.0))
	lv.difficulty_elo = int(data.get("difficulty_elo", 900))
	lv.scales_cfg = _dict_array(data.get("scales"))
	lv.solution_spec = _dict(data.get("solution_spec"))
	lv.hint_sequence = _dict_array(data.get("hint_sequence"))
	return lv


## تنها راه امن خواندن JSON داده‌ی غیرمطمئن (ADR-026 بند ۳): `JSON.new()` + `parse()`.
## خروجی: `{ ok: bool, level: LevelData|null, error: String }` — بدون هیچ چاپ خطا.
static func from_json_text(text: String, p_source_path: String = "") -> Dictionary:
	var json := JSON.new()
	var parse_err: int = json.parse(text)
	if parse_err != OK:
		return {
			"ok": false,
			"level": null,
			"error": "JSON نامعتبر در %s (خطای %d، سطر %d): %s"
				% [p_source_path, parse_err, json.get_error_line(), json.get_error_message()],
		}
	if not (json.data is Dictionary):
		return {"ok": false, "level": null,
			"error": "%s: ریشه‌ی فایل باید object باشد" % p_source_path}
	var level: LevelData = from_dict(json.data as Dictionary, p_source_path)
	var problems: Array[String] = level.validate()
	if not problems.is_empty():
		return {"ok": false, "level": level, "error": "; ".join(problems)}
	return {"ok": true, "level": level, "error": ""}


# --------------------------------------------------------------------------
# اعتبارسنجی درونی
# --------------------------------------------------------------------------
func validate() -> Array[String]:
	var errs: Array[String] = []
	if level_id.is_empty():
		errs.append("level_id غایب است")
	elif not _matches(level_id, LEVEL_ID_PATTERN):
		errs.append("level_id `%s` با الگوی tier<N>_level_<NN> نمی‌خواند" % level_id)
	if tier < 1 or tier > 5:
		errs.append("tier باید ۱..۵ باشد (اینجا %d)" % tier)
	if world != ALLOWED_WORLD:
		errs.append("world باید `%s` باشد (اینجا `%s`)" % [ALLOWED_WORLD, world])
	if concept_tags.is_empty():
		errs.append("concept_tags خالی است")
	if narrative_intro.length() < MIN_INTRO_LEN:
		errs.append("narrative_intro کوتاه است (حداقل %d نویسه)" % MIN_INTRO_LEN)
	if tolerance < 0.0:
		errs.append("tolerance نباید منفی باشد")
	if expected_solve_time_sec < 5.0 or expected_solve_time_sec > 600.0:
		errs.append("expected_solve_time_sec باید ۵..۶۰۰ باشد")
	if difficulty_elo < 400 or difficulty_elo > 2000:
		errs.append("difficulty_elo باید ۴۰۰..۲۰۰۰ باشد (§۳ سند داده‌ها)")

	var numbered: Array[Dictionary] = []
	numbered.append_array(left_fixed_orbs)
	numbered.append_array(right_fixed_orbs)
	numbered.append_array(available_orbs)
	for entry: Dictionary in numbered:
		if entry.get("type", "number") not in ALLOWED_ORB_TYPES:
			errs.append("نوع کره نامعتبر: %s" % str(entry.get("type")))
	if tier < 3 and (not left_ghost_orbs.is_empty() or not right_ghost_orbs.is_empty()):
		errs.append("ghost_orbs فقط برای Tier 3+ مجاز است (§۱)")
	for entry: Dictionary in available_orbs:
		if str(entry.get("type", "number")) == "ghost":
			errs.append("کره‌ی روح نباید در available_orbs باشد (مجهول قابل‌انتخاب نیست)")
		if int(entry.get("count", 0)) < 1:
			errs.append("هر ردیف available_orbs باید count ≥ 1 داشته باشد")

	var ghosts: int = left_ghost_orbs.size() + right_ghost_orbs.size()
	if not scales_cfg.is_empty():
		# تکلیف حسابِ کفه‌ها در `validate_scales()` است، نه اینجا: در سطحِ چندکفه،
		# `target_value`ِ سطح معنا ندارد و چک‌کردنش خطای ساختگی می‌داد ✗✓
		errs.append_array(validate_scales())
	elif not has_target and ghosts == 0:
		errs.append("right_side باید target_value یا ghost_orbs داشته باشد")
	if has_target and scales_cfg.is_empty() and is_equal_approx(tolerance, 0.0) and ghosts == 0:
		if not is_equal_approx(left_weight() - right_weight(), target_value):
			errs.append("ناسازگاری: نیاز راست %.3f ≠ target_value %.3f"
				% [left_weight() - right_weight(), target_value])

	if hint_sequence.is_empty():
		errs.append("hint_sequence خالی است — هر سطح حداقل یک تریگر راهنما لازم دارد")
	for step: Dictionary in hint_sequence:
		var trig: String = str(step.get("trigger", ""))
		if not _matches(trig, TRIGGER_PATTERN):
			errs.append("trigger ناشناخته `%s`" % trig)
		if str(step.get("hint_id", "")).is_empty():
			errs.append("hint_id غایب است")
	if not solution_spec.is_empty():
		var intended: Variant = _dict(solution_spec.get("intended")).get("right_orbs")
		if intended is Array:
			if scales_cfg.is_empty():
				var total: float = 0.0
				for v: Variant in (intended as Array):
					total += _orb_value(v)
				if not is_zero_approx(total) and not is_equal_approx(total, left_weight() - right_weight()):
					errs.append("solution_spec.intended با نیاز کفه‌ی راست نمی‌خواند (%.3f ≠ %.3f)"
						% [total, left_weight() - right_weight()])
			else:
				errs.append_array(_validate_intended_per_scale(intended as Array))
	return errs


## حسابِ هر کفه در سطحِ چندکفه: `target_value` داده‌شده باید با «چپ − راستِ همان کفه»
## بخواند، و کره‌های `ghost` هم مثل سطحِ تک‌کفه فقط در کلیدِ `*_ghost_orbs` می‌آیند
## (ADR-028 ⇒ وزنِ دوبل ممنوع ✗✓).
func validate_scales() -> Array[String]:
	var errs: Array[String] = []
	var seen_ids: Dictionary = {}
	for i: int in range(scales_cfg.size()):
		var sc: Dictionary = scales_cfg[i]
		var tag: String = "scales[%d]" % i
		var sid: String = str(sc.get("id", ""))
		if not sid.is_empty():
			if seen_ids.has(sid):
				errs.append("%s: `id` تکراری `%s` (ErrorClassifier با نامِ کفه کار می‌کند)" % [tag, sid])
			seen_ids[sid] = true
		for key: String in ["left_orbs", "left_ghost_orbs", "right_orbs", "right_ghost_orbs"]:
			for entry: Variant in _arr(sc.get(key)):
				var d: Dictionary = entry as Dictionary
				var type_name: String = str(d.get("type", "number"))
				if type_name not in ALLOWED_ORB_TYPES:
					errs.append("%s.%s: نوع کره نامعتبر `%s`" % [tag, key, type_name])
				if type_name == "ghost" and tier < 3:
					errs.append("%s.%s: ghost در Tier < 3 مجاز نیست (§۱)" % [tag, key])
				if type_name == "ghost" and key.ends_with("_orbs") and not key.contains("ghost"):
					errs.append("%s.%s: کره‌ی روح باید در `*_ghost_orbs` باشد نه `%s` (وزنِ دوبل ✗ ADR-028)"
						% [tag, key, key])
		var target_v: Variant = sc.get("target_value")
		if target_v is float or target_v is int:
			var need: float = side_weight(_orb_array(sc.get("left_orbs"))) \
				+ side_weight(_orb_array(sc.get("left_ghost_orbs"))) \
				- side_weight(_orb_array(sc.get("right_orbs"))) \
				- side_weight(_orb_array(sc.get("right_ghost_orbs")))
			# مثل قانونِ تک‌کفه: فقط وقتی تلورانس صفر است «دقیقاً» می‌خواهیم ✗✓
			if is_zero_approx(tolerance) and not is_equal_approx(need, float(target_v)):
				errs.append("%s: نیاز %.3f ≠ target_value %.3f" % [tag, need, float(target_v)])
		elif sc.get("left_ghost_orbs") == null and sc.get("right_ghost_orbs") == null:
			errs.append("%s: `target_value` یا کره‌ی شبح لازم است" % tag)
	return errs


## `intended.right_orbs` در سطحِ چندکفه، ورودی‌ی `{"value": 4, "scale": 1}` است ⇒ مجموعِ
## هر کفه جدا باید با نیازِ همان کفه بخواند ✗✓ (مجموعِ کل، ادعای دروغین می‌ساخت: ۴+۴ در
## کفه‌ای با نیاز ۲ و ۸ در کفه‌ای با نیاز ۱۰، «۱۶=۱۲» را سبز نشان می‌داد ✗✗).
func _validate_intended_per_scale(intended: Array) -> Array[String]:
	var errs: Array[String] = []
	var per_scale: Array[float] = []
	for entry: Variant in intended:
		var d: Dictionary = _dict(entry)
		var idx: int = int(d.get("scale", 0))
		if idx < 0 or idx >= scales_cfg.size():
			errs.append("intended: `scale` %d از تعداد کفه‌ها (%d) بیرون است" % [idx, scales_cfg.size()])
			continue
		while per_scale.size() <= idx:
			per_scale.append(0.0)
		per_scale[idx] += _orb_value(d.get("value", 0.0))
	for i: int in range(scales_cfg.size()):
		var need: float = _scale_need(i)
		var got: float = per_scale[i] if i < per_scale.size() else 0.0
		if is_zero_approx(need) and is_zero_approx(got):
			continue
		if not is_equal_approx(got, need):
			errs.append("intended برای کفه %d: %.3f ≠ نیاز %.3f" % [i, got, need])
	return errs


func _scale_need(index: int) -> float:
	if index < 0 or index >= scales_cfg.size():
		return 0.0
	var sc: Dictionary = scales_cfg[index]
	return side_weight(_orb_array(sc.get("left_orbs"))) + side_weight(_orb_array(sc.get("left_ghost_orbs"))) \
		- side_weight(_orb_array(sc.get("right_orbs"))) - side_weight(_orb_array(sc.get("right_ghost_orbs")))


static func _orb_value(v: Variant) -> float:
	if v is Dictionary:
		return float((v as Dictionary).get("value", 0.0))
	return float(v)


# --------------------------------------------------------------------------
# محاسبه‌ی وزن (قاعده‌ی علامت = همان قاعده‌ی WeightOrb)
# --------------------------------------------------------------------------
static func orb_weight(entry: Dictionary) -> float:
	var type_name: String = str(entry.get("type", "number"))
	if type_name == "ghost":
		return absf(float(entry.get("hidden_value", 0.0)))
	if type_name == "negative":
		return -absf(float(entry.get("value", 0.0)))
	return absf(float(entry.get("value", 0.0)))


static func side_weight(entries: Array[Dictionary]) -> float:
	var total: float = 0.0
	for entry: Dictionary in entries:
		total += orb_weight(entry)
	return total


func left_weight() -> float:
	return side_weight(left_fixed_orbs) + side_weight(left_ghost_orbs)


func right_weight() -> float:
	return side_weight(right_fixed_orbs) + side_weight(right_ghost_orbs)


## وزنی که بازیکن باید با کره‌های سینی روی کفه‌ی راست بسازد (target در سند §۱).
func required_right_weight() -> float:
	return left_weight() - right_weight()


func available_count() -> int:
	var n: int = 0
	for entry: Dictionary in available_orbs:
		n += int(entry.get("count", 1))
	return n


func hint_id_for(trigger_prefix: String) -> String:
	for step: Dictionary in hint_sequence:
		if str(step.get("trigger", "")).begins_with(trigger_prefix):
			return str(step.get("hint_id", ""))
	return ""


# --------------------------------------------------------------------------
# پل به موتور بازی — قرارداد ADR-028 (تغییر این شکل یعنی شکستن LevelController)
# --------------------------------------------------------------------------
func to_config_dict() -> Dictionary:
	return {
		"level_id": level_id,
		"tier": tier,
		"tolerance": tolerance,
		"narrative_intro": narrative_intro,
		"scales": scales_cfg.duplicate(true) if not scales_cfg.is_empty() else [{
			"id": "main",
			# قاعده (ADR-028): کره‌ی روح **فقط** در کلید `*_ghost_orbs` می‌آید؛ اگر در
			# `*_orbs` هم می‌آمد، LevelController دو بار روی کفه می‌گذاشتش (وزن دوبله).
			"left_orbs": left_fixed_orbs.duplicate(),
			"left_ghost_orbs": left_ghost_orbs.duplicate(),
			# آرک‌تایپ ۲ («دو طرف نیمه‌پُر»): کفه‌ی راست هم می‌تواند از قبل پر باشد
			"right_orbs": right_fixed_orbs.duplicate(),
			"right_ghost_orbs": right_ghost_orbs.duplicate(),
			"target_value": target_value,
		}],
		"available_orbs": available_orbs.duplicate(),
		# افزوده‌ها برای فازهای ۴ و ۵ (LevelController آن‌ها را نمی‌خواند):
		"world": world,
		"concept_tags": Array(concept_tags),
		"hint_sequence": hint_sequence.duplicate(),
		"expected_solve_time_sec": expected_solve_time_sec,
		"difficulty_elo": difficulty_elo,
		"solution_spec": solution_spec,
		"has_target": has_target,
	}


func summary() -> String:
	return "%s (tier %d، نیاز راست %.1f، %d کره در سینی، Elo %d)" % [
		level_id, tier, required_right_weight(), available_count(), difficulty_elo]


# --------------------------------------------------------------------------
# تبدیل‌های ایمن (درس فاز ۱: JSON هرچه بدهد take می‌کند)
# --------------------------------------------------------------------------
static func _arr(v: Variant) -> Array:
	return v as Array if v is Array else []


static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for item: Variant in (value as Array):
			out.append(str(item))
	return out


static func _dict_array(value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if value is Array:
		for item: Variant in (value as Array):
			if item is Dictionary:
				out.append(item as Dictionary)
	return out


static func _orb_array(value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = _dict_array(value)
	# همه‌ی ردیف‌ها `type` صریح می‌گیرند تا `_make_orb` روی حدس نرود
	for entry: Dictionary in out:
		if not entry.has("type"):
			entry["type"] = "number"
	return out


static func _matches(text: String, pattern: String) -> bool:
	var re := RegEx.new()
	if re.compile(pattern) != OK:
		return false
	return re.search(text) != null
