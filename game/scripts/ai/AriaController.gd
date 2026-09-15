class_name AriaController
extends Node
# ===========================================================================
# تسک ۵.۳ — AriaController: از «کی/چه شد» تا «چه بگوید و چه شکلی باشد»
# --------------------------------------------------------------------------
# ورودی‌ها فقط سیگنال‌های EventBus‌اند (هیچ نودی او را صدا نمی‌زند، پس صحنه‌ها
# مستقل‌اند): `hint_requested` (نردبان HintTimingSystem یا دکمه‌ی راهنمای HUD)،
# `error_detected` (کلاس‌بندی خطا) و سه رویداد عمرِ سطح.
# خروجی‌ها: `EventBus.hint_shown(hint_id, level_id, text)` برای DialogueBox و
# `EventBus.aria_state_changed(state)` برای آواتار (docs/02 §۳).
#
# دو قانون که اینجا کد شده‌اند:
#  ۱) چرخشی، نه تصادفی (§۴ سند داده‌ها): هر `hint_id` شمارنده‌ی خودش را دارد و
#     واریانتِ بعدی را برمی‌دارد؛ پس «دو بار پشت‌سرهم همان متن» ساختاراً ناممکن است.
#  ۲) قانون مزاحمت: آواتار روی هر `error_detected` «concerned» می‌شود، اما **متن**
#     فقط از خطای دوم و بعد هر ۳ خطا release می‌شود (ADR-042) — وگرنه Aria به صدای
#     پس‌زمینه‌ی آزاردهنده تبدیل می‌شود و بچه یاد می‌گیرد صدایش را قطع کند.
# ===========================================================================

const TAG := "Aria"

## شش حالت Art Bible §۳ — هر چیز دیگری بی‌معنی است و به `idle` برمی‌گردد
const STATE_IDLE := "idle"
const STATE_NAMES := ["idle", "thinking", "hint_light", "encouraging",
	"celebrating", "concerned"]

## از چندمین خطا متن بدهیم و بعد هر چندتا (ADR-042)
const FIRST_ERROR_HINT := 2
const EVERY_ERROR_HINT := 3
## «تلاش درست جزئی» (Art Bible §۳): فاصله‌ی کفه‌ها چقدر کم شود که تشویق کنیم
const ENCOURAGE_RATIO := 0.35
const ENCOURAGE_EPS := 0.05

@export var templates_path: String = DialogueTemplate.DEFAULT_PATH
@export var auto_load_templates: bool = true
## اگر false شود هیچ `hint_shown` publish نمی‌شود (برای تست/حالت بی‌صدا)
@export var emits_hint_shown: bool = true

var by_id: Dictionary = {}
var order: PackedStringArray = PackedStringArray()
var last_text: String = ""
var last_hint_id: String = ""
var last_state: String = "idle"

var _cursors: Dictionary = {}
var _errors_this_level: int = 0
var _last_gap: float = 0.0


func _ready() -> void:
	if auto_load_templates:
		load_templates(templates_path)
	EventBus.hint_requested.connect(_on_hint_requested)
	EventBus.error_detected.connect(_on_error_detected)
	EventBus.level_started.connect(_on_level_started)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.balance_changed.connect(_on_balance_changed)
	EventBus.orb_placed.connect(_on_orb_moved)


## بارگذاری قالب‌ها؛ false یعنی فایل نخوانده شد (بازی با بی‌صدا ادامه می‌دهد، نه crash).
func load_templates(path: String = "") -> bool:
	var target: String = path if not path.is_empty() else templates_path
	var res: Dictionary = DialogueTemplate.load_file(target)
	if not bool(res["ok"]):
		Log.warn(TAG, "قالب‌های دیالوگ بارگذاری نشد: " + str(res.get("error", "")))
		by_id = {}
		order = PackedStringArray()
		return false
	by_id = res["by_id"] as Dictionary
	order = res["order"] as PackedStringArray
	return true


func template_count() -> int:
	return by_id.size()


## متن بعدیِ یک قالب (و جلو بردن شمارنده‌ی همان قالب). بی‌id = رشته‌ی تهی.
func text_for_hint(hint_id: String) -> String:
	if hint_id.is_empty() or not by_id.has(hint_id):
		return ""
	var tpl: DialogueTemplate = by_id[hint_id]
	if tpl == null:
		return ""
	var cursor: int = int(_cursors.get(hint_id, 0))
	_cursors[hint_id] = cursor + 1
	return tpl.text_for(cursor)


func set_state(state: String) -> void:
	var known: bool = state in STATE_NAMES
	last_state = state if known else STATE_IDLE
	if known:
		EventBus.aria_state_changed.emit(last_state)


func reset_session() -> void:
	_cursors.clear()
	_errors_this_level = 0
	_last_gap = 0.0
	last_text = ""
	last_hint_id = ""
	set_state(STATE_IDLE)


# --------------------------------------------------------------------------
# مسیرهای ورودی
# --------------------------------------------------------------------------
func _on_hint_requested(hint_id: String) -> void:
	show_hint(hint_id)


func show_hint(hint_id: String) -> void:
	var text: String = text_for_hint(hint_id)
	if text.is_empty():
		# قالب نداریم: سکوت بهتر از جمله‌ی بی‌ربط (§۴ «هیچ‌وقت جواب نده» را UI نمی‌شکند)
		Log.debug(TAG, "بدون قالب برای `%s` — بی‌صدا" % hint_id)
		return
	last_text = text
	last_hint_id = hint_id
	set_state("hint_light")
	# §۴ سند ۰۳: `aria_transcript_log` مبنای شفافیت برای والد است ⇒ همین‌جا نوشته
	# می‌شود (نه در UI): هر متنی که کودک دید، در مدل هم ثبت شده باشد.
	if GameState.active_model != null:
		GameState.active_model.record_hint_shown(hint_id, GameState.current_level_id, text)
	if emits_hint_shown:
		EventBus.hint_shown.emit(hint_id, GameState.current_level_id, text)


func _on_error_detected(error_type: String) -> void:
	_errors_this_level += 1
	set_state("concerned")
	var due: bool = _errors_this_level == FIRST_ERROR_HINT \
		or (_errors_this_level > FIRST_ERROR_HINT \
			and (_errors_this_level - FIRST_ERROR_HINT) % EVERY_ERROR_HINT == 0)
	if not due:
		return
	var matched: String = DialogueTemplate.match_error(by_id, order, error_type,
		GameState.current_tier)
	if matched.is_empty():
		matched = "gentle_nudge_01"  # fallback بی‌ضرر: تشویق به حرکت، نه جواب
	show_hint(matched)


func _on_level_started(_level_id: String, _tier: int) -> void:
	_errors_this_level = 0
	_last_gap = 0.0
	set_state(STATE_IDLE)


func _on_level_completed(_level_id: String, _stats: Dictionary) -> void:
	set_state("celebrating")


func _on_orb_moved(_orb_data: Dictionary) -> void:
	set_state("thinking")


## «تلاش درست جزئی»: فاصله‌ی دو کفه ناگهان کم شده باشد → تشویق (هیچ عددی هم نمی‌گوییم)
func _on_balance_changed(left_weight: float, right_weight: float) -> void:
	var gap: float = absf(left_weight - right_weight)
	var closed: bool = _last_gap > ENCOURAGE_EPS and gap <= _last_gap * ENCOURAGE_RATIO \
		and gap > ENCOURAGE_EPS
	_last_gap = gap
	if closed:
		set_state("encouraging")
