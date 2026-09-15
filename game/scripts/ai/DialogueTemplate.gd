class_name DialogueTemplate
extends RefCounted
# ===========================================================================
# تسک ۵.۱ — پارسر `data/dialogue/aria_templates.json` (اسکیمای docs/03 §۴)
# --------------------------------------------------------------------------
# دو کار می‌کند: داده را **بدون crash** به نمایه‌ی `hint_id → قالب` تبدیل می‌کند و
# همان‌جا قوانین §۴ را سخت‌گیرانه اعمال می‌کند (هر قالب ≥۲ واریانت، بازه Tier معتبر، نوع خطای شناخته‌شده).
# منطق «کدام واریانت؟» اینجا نیست — آن حالتِ نشستِ AriaController است (چرخشی، ADR-041).
#
# چرا خروجی `Dictionary` است و نه `Array`؟ چون `hint_requested` یک `hint_id` می‌دهد
# و جست‌وجو باید O(1) باشد؛ ترتیب فایل هم در `order` نگه داشته می‌شود تا انتخابِ
# «نخستین قالبِ منطبق برای این خطا» پایدار و قابل‌تست بماند.
# ===========================================================================

const TAG := "DialogueTemplate"
const DEFAULT_PATH := "res://data/dialogue/aria_templates.json"
## §۴ DoD: برای هر id حداقل دو واریانت — وگرنه «چرخشی» بی‌معنی است
const MIN_VARIANTS := 2
## Art Bible §۷: متن گفت‌وگو روی موبایل با فونت ۲۴px؛ درازتر از این = ریسک سرریز
const MAX_TEXT_LEN := 220
## `timeout` و `help_requested` در §۴ مجازند ولی خودِ خطای محاسباتی نیستند
const ALLOWED_ERROR_TYPES := [
	"wrong_operation", "sign_flip_on_subtraction", "forgets_both_sides",
	"computation_error", "idle", "timeout", "help_requested",
]

var hint_id: String = ""
var applies_to_error_types: Array[String] = []
var min_tier: int = 1
var max_tier: int = 5
var text_variants: Array[String] = []


func variant_count() -> int:
	return text_variants.size()


## انتخاب چرخشی: `cursor` شمارنده‌ی همان id در نشستِ بازیکن است (نه تصادفی).
func text_for(cursor: int) -> String:
	if text_variants.is_empty():
		return ""
	return text_variants[absi(cursor) % text_variants.size()]


func applies_to(error_type: String) -> bool:
	return applies_to_error_types.has(error_type)


func covers_tier(tier: int) -> bool:
	return tier >= min_tier and tier <= max_tier


func to_dict() -> Dictionary:
	return {
		"hint_id": hint_id,
		"applies_to_error_types": Array(applies_to_error_types),
		"min_tier": min_tier,
		"max_tier": max_tier,
		"text_variants": Array(text_variants),
	}


# --------------------------------------------------------------------------
# پارس / اعتبارسنجی
# --------------------------------------------------------------------------
static func errors_for(raw: Variant, where: String) -> Array[String]:
	var out: Array[String] = []
	if not (raw is Dictionary):
		out.append("%s: قالب باید object باشد" % where)
		return out
	var d: Dictionary = raw as Dictionary
	var id: Variant = d.get("hint_id", "")
	if not (id is String) or str(id).is_empty():
		out.append("%s: `hint_id` غایب یا خالی است" % where)
	var types: Variant = d.get("applies_to_error_types", [])
	if not (types is Array) or (types as Array).is_empty():
		out.append("%s: `applies_to_error_types` خالی است" % str(id))
	else:
		for e: Variant in (types as Array):
			if not ALLOWED_ERROR_TYPES.has(str(e)):
				out.append("%s: نوع خطای ناشناخته `%s`" % [str(id), str(e)])
	# دام: `JSON.parse_string` هر عددی را float می‌دهد (حتی ۱ و ۵)، پس `is int` روی
	# داده‌ی واقعی همیشه false است — تشخیص باید روی typeof و مقدار انجام شود.
	var mn: Variant = d.get("min_tier", 1)
	var mx: Variant = d.get("max_tier", 5)
	var numeric: bool = (mn is int or mn is float) and (mx is int or mx is float)
	if not numeric or int(mn) < 1 or int(mx) > 5 or int(mn) > int(mx) \
			or float(mn) != float(int(mn)) or float(mx) != float(int(mx)):
		out.append("%s: `min_tier`/`max_tier` باید عددِ صحیح ۱..۵ و mn<=mx باشند" % str(id))
	var variants: Variant = d.get("text_variants", [])
	if not (variants is Array) or (variants as Array).size() < MIN_VARIANTS:
		out.append("%s: حداقل %d `text_variant` لازم است (§۴)" % [str(id), MIN_VARIANTS])
	else:
		for j: int in range((variants as Array).size()):
			var text: Variant = (variants as Array)[j]
			if not (text is String) or str(text).strip_edges().is_empty():
				out.append("%s: text_variants[%d] خالی است" % [str(id), j])
			elif str(text).length() > MAX_TEXT_LEN:
				out.append("%s: text_variants[%d] از %d نویسه بلندتر است"
					% [str(id), j, MAX_TEXT_LEN])
	return out


static func from_dict(raw: Variant) -> DialogueTemplate:
	if not (raw is Dictionary):
		return null
	var d: Dictionary = raw as Dictionary
	var tpl := DialogueTemplate.new()
	tpl.hint_id = str(d.get("hint_id", ""))
	var types: Variant = d.get("applies_to_error_types", [])
	if types is Array:
		for e: Variant in (types as Array):
			var s: String = str(e)
			if not s.is_empty() and not tpl.applies_to_error_types.has(s):
				tpl.applies_to_error_types.append(s)
	tpl.min_tier = int(d.get("min_tier", 1))
	tpl.max_tier = int(d.get("max_tier", 5))
	var variants: Variant = d.get("text_variants", [])
	if variants is Array:
		for v: Variant in (variants as Array):
			var text: String = str(v).strip_edges()
			if not text.is_empty():
				tpl.text_variants.append(text)
	return tpl


## خروجی: {ok: bool, error: String, by_id: Dictionary, order: Array[String],
##         errors: Array[String]} — `error` یعنی فایل نشد خوانده/پارس شود.
static func index_from_text(text: String) -> Dictionary:
	var out := {
		"ok": false, "error": "", "by_id": {}, "order": PackedStringArray(),
		"errors": [],
	}
	if text.strip_edges().is_empty():
		out["error"] = "متن خالی است"
		return out
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		out["error"] = "ریشه‌ی JSON باید object باشد"
		return out
	var raw: Variant = (parsed as Dictionary).get("hints", [])
	if not (raw is Array) or (raw as Array).is_empty():
		out["error"] = "`hints` خالی یا غایب است (§۴)"
		return out
	var by_id: Dictionary = {}
	var order := PackedStringArray()
	var errs: Array[String] = []
	for i: int in range((raw as Array).size()):
		var item: Variant = (raw as Array)[i]
		var where: String = "hints[%d]" % i
		errs.append_array(errors_for(item, where))
		var tpl := DialogueTemplate.from_dict(item)
		if tpl == null or tpl.hint_id.is_empty() or by_id.has(tpl.hint_id):
			continue
		by_id[tpl.hint_id] = tpl
		order.append(tpl.hint_id)
	out["by_id"] = by_id
	out["order"] = order
	out["errors"] = errs
	out["ok"] = errs.is_empty()
	if not errs.is_empty():
		out["error"] = "; ".join(errs)
	return out


static func load_file(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "فایل پیدا نشد: " + path, "by_id": {},
			"order": PackedStringArray(), "errors": []}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "باز کردن فایل ناموفق بود", "by_id": {},
			"order": PackedStringArray(), "errors": []}
	var text: String = f.get_as_text()
	f.close()
	return index_from_text(text)


# --------------------------------------------------------------------------
# انتخاب
# --------------------------------------------------------------------------
## نخستین قالبی (به ترتیب فایل) که این خطا را برای این Tier پوشش می‌دهد.
## خروجی: hint_id، یا "" اگر هیچ قالبی نخورد — که AriaController را بی‌صدا می‌گذارد.
static func match_error(by_id: Dictionary, order: PackedStringArray,
		error_type: String, tier: int) -> String:
	for id: String in order:
		var tpl: DialogueTemplate = by_id.get(id, null)
		if tpl != null and tpl.applies_to(error_type) and tpl.covers_tier(tier):
			return id
	return ""


static func count_variants(by_id: Dictionary) -> int:
	var n: int = 0
	for id: Variant in by_id.keys():
		var tpl: DialogueTemplate = by_id[id]
		if tpl != null:
			n += tpl.variant_count()
	return n
