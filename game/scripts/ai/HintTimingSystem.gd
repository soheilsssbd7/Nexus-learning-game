class_name HintTimingSystem
extends Node
# ===========================================================================
# HintTimingSystem — «کی» Aria حرف بزند (تسک ۴.۳ | docs/04 §۴.۳، docs/07 §۵-الف)
# --------------------------------------------------------------------------
# دو ورودی دارد و یک خروجی:
#   ورودی: بی‌حرکتی (idle) و شمارنده‌ی تلاش‌های ناموفقِ همین سطح
#   خروجی: `EventBus.hint_requested(hint_id)` — همان `hint_id` که در
#          `level.hint_sequence` برای آن تریگر نوشته شده است.
# خودش هیچ متنی نمی‌سازد و هیچ تصمیمی درباره‌ی «چه بگوییم» نمی‌گیرد؛ آن کار
# AriaController است (فاز ۵). نمایشِ واقعیِ پیام = `hint_shown` (فاز ۵) و
# آمار `hints_used` از همین‌جا به GameState اضافه می‌شود تا در `level_completed`
# و در `success_score` (فشارِ راهنما → امتیاز کمتر) دیده شود.
#
# نردبان کمک (docs/07 §۵-الف): L1 اشاره‌ی غیرکلامی → L2 سؤال سقراطی جهت‌دار →
# L3 سؤال عددی-جزئی → L4 «یک حرکتِ من». ترتیبِ `hint_sequence` در داده‌ی سطح،
# همان نردبان است؛ پس سیستم **به ترتیب آرایه** شلیک می‌کند و هر ردیف حداکثر یک‌بار
# (ردیف آخر با هر `ESCALATION_FAILS` تلاشِ اضافه تکرار می‌شود تا بازیکن گیر نکند).
# ===========================================================================

const TAG := "HintTiming"

## پیش‌فرض §۴.۳: «۴۵ ثانیه بدون حرکت»
const DEFAULT_IDLE_SEC := 45.0
## اگر آستانه‌های `hint_sequence` تمام شد و بازیکن هنوز گیر است، هر چند تلاشِ
## ناموفقِ دیگر یک پله‌ی تکراری (فقط از ردیف آخر نردبان).
const ESCALATION_FAILS := 2

signal hint_triggered(hint_id: String, trigger: String)

## اگر false شود، زمان فقط با `tick()` جلو می‌رود (حالت تست — بدون خوابِ واقعی).
@export var auto_idle_timer: bool = true
@export var idle_sec: float = DEFAULT_IDLE_SEC
## آستانه‌ی پیش‌فرض تلاش؛ ردیف‌های `fail_<n>x` در داده بر آن اولویت دارند.
@export var fail_threshold: int = 3

var _steps: Array[Dictionary] = []
var _idle_elapsed: float = 0.0
var _fails: int = 0
var _fired_count: Dictionary = {}
var _armed: bool = false


func _ready() -> void:
	EventBus.attempt_failed.connect(_on_attempt_failed)
	EventBus.orb_placed.connect(_on_orb_moved)
	EventBus.orb_removed.connect(_on_orb_moved)
	EventBus.level_started.connect(_on_level_started)
	EventBus.level_completed.connect(_on_level_completed)


# --------------------------------------------------------------------------
# پارس `hint_sequence`
# --------------------------------------------------------------------------
## [{trigger, hint_id, kind: idle|fail|first_wrong|help, threshold: float}]
static func parse_steps(config: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw: Variant = config.get("hint_sequence", [])
	if not (raw is Array):
		return out
	for entry: Variant in (raw as Array):
		if not (entry is Dictionary):
			continue
		var step: Dictionary = entry as Dictionary
		var trigger: String = str(step.get("trigger", ""))
		var hint_id: String = str(step.get("hint_id", ""))
		if hint_id.is_empty():
			continue
		var parsed := {"trigger": trigger, "hint_id": hint_id, "kind": "", "threshold": 0.0}
		if trigger.begins_with("idle_"):
			parsed["kind"] = "idle"
			parsed["threshold"] = float(_digits(trigger))
		elif trigger.begins_with("fail_"):
			parsed["kind"] = "fail"
			parsed["threshold"] = float(_digits(trigger))
		elif trigger == "first_wrong_attempt":
			parsed["kind"] = "first_wrong"
		elif trigger == "help_requested":
			parsed["kind"] = "help"
		else:
			continue  # تریگر ناشناخته: بی‌صدا رد (LevelData.validate آن را خطا می‌داند)
		out.append(parsed)
	return out


static func _digits(text: String) -> String:
	var out: String = ""
	for i: int in range(text.length()):
		var c: String = text[i]
		if c >= "0" and c <= "9":
			out += c
	return out


# --------------------------------------------------------------------------
# چرخه‌ی عمر
# --------------------------------------------------------------------------
## LevelController بعد از ساخت سطح صدا می‌زند (`config` همان ADR-028 است).
func configure(config: Dictionary) -> void:
	_steps = parse_steps(config)
	reset()


func reset() -> void:
	_idle_elapsed = 0.0
	_fails = 0
	_fired_count.clear()
	_armed = true


func stop() -> void:
	_armed = false


func is_armed() -> bool:
	return _armed


func fails() -> int:
	return _fails


func fired_count() -> int:
	return _fired_count.size()


## موتور زمان. `_process` فقط این را با delta صدا می‌زند؛ تست‌ها همین را دستی
## جلو می‌برند (در CI هیچ ۴۵ ثانیه‌ای خواب نمی‌کنیم).
func tick(seconds: float) -> void:
	if not _armed or seconds <= 0.0:
		return
	_idle_elapsed += seconds
	_try_fire()


## هر حرکتِ کره، بی‌حرکتی را صفر می‌کند (بازیکن مشغول است؛ سکوت کن).
func on_movement() -> void:
	_idle_elapsed = 0.0


func _process(delta: float) -> void:
	if auto_idle_timer:
		tick(delta)


## دکمه‌ی «راهنما» در HUD (تسک ۶.۴) همین را صدا می‌زند.
# نوبتِ اول: ردیف `help_requested` (اگر سطح دارد). بعد از آن هر فشار، یک پله از
# نردبان بالاتر می‌رود و در ردیف آخر می‌ماند — «همان راهنما را تکرار کردن» بدترین
# تجربه‌ی این بازی است (docs/07 §۵-الف).
func request_help() -> void:
	if not _armed or _steps.is_empty():
		return
	var help_step := _find_kind("help")
	if not help_step.is_empty() and not _is_fired(help_step):
		_fire(help_step)
		return
	var next_step := _first_unfired_step()
	_fire(next_step if not next_step.is_empty() else _last_ladder_step())


# --------------------------------------------------------------------------
# شلیک
# --------------------------------------------------------------------------
func _on_attempt_failed(_attempt_index: int) -> void:
	if not _armed:
		return
	_fails += 1
	_try_fire()


func _on_orb_moved(_orb_data: Dictionary) -> void:
	on_movement()


func _on_level_started(_level_id: String, _tier: int) -> void:
	reset()


func _on_level_completed(_level_id: String, _stats: Dictionary) -> void:
	# بعد از برد، سکوت مطلق: نردبان راهنما در صفحه‌ی نتیجه جایی ندارد
	stop()


func _idle_limit(step: Dictionary) -> float:
	var t: float = float(step.get("threshold", 0.0))
	return t if t > 0.0 else idle_sec


func _fail_limit(step: Dictionary, index: int) -> int:
	var t: int = int(step.get("threshold", 0.0))
	var base: int = t if t > 0 else maxi(1, fail_threshold)
	# پله‌ی escalation: هر ESCALATION_FAILS تلاشِ اضافه، بعد از آخرین ردیف
	if index == _steps.size() - 1:
		return base + ESCALATION_FAILS * int(_fired_count.get(str(step.get("hint_id", "")), 0))
	return base


## ردیفِ «تکرارِ ناامیدکننده» نباید خودِ `help_requested` باشد (یک متنِ ثابتِ تکراری
## بدترین تجربه است)؛ پس از آخر به اول اولین ردیفِ غیرکمکی را برمی‌داریم.
func _last_ladder_step() -> Dictionary:
	for i: int in range(_steps.size() - 1, -1, -1):
		if str((_steps[i] as Dictionary).get("kind", "")) != "help":
			return _steps[i]
	return {}


func _find_kind(kind: String) -> Dictionary:
	for step: Dictionary in _steps:
		if str(step.get("kind", "")) == kind:
			return step
	return {}


func _first_unfired_step() -> Dictionary:
	for step: Dictionary in _steps:
		if str(step.get("kind", "")) == "help":
			continue
		if not _is_fired(step):
			return step
	return {}


func _is_fired(step: Dictionary) -> bool:
	return int(_fired_count.get(str(step.get("hint_id", "")), 0)) > 0


func _try_fire() -> void:
	if not _armed or _steps.is_empty():
		return
	for i: int in range(_steps.size()):
		var step: Dictionary = _steps[i]
		var kind: String = str(step.get("kind", ""))
		var is_last: bool = i == _steps.size() - 1
		if _is_fired(step) and not (is_last and kind == "fail"):
			continue  # هر ردیف یک‌بار؛ فقط ردیفِ آخرِ «تلاش» برای escalation تکرار می‌شود
		match kind:
			"idle":
				if _idle_elapsed >= _idle_limit(step):
					_fire(step)
					return
			"first_wrong":
				if _fails >= 1 and not _is_fired(step):
					_fire(step)
					return
			"fail":
				if _fails >= _fail_limit(step, i):
					_fire(step)
					return
			"help":
				continue  # فقط از request_help()


func _fire(step: Dictionary) -> void:
	if step.is_empty():
		return
	var hint_id: String = str(step.get("hint_id", ""))
	if hint_id.is_empty():
		return
	var key: String = hint_id
	_fired_count[key] = int(_fired_count.get(key, 0)) + 1
	GameState.register_hint_used()
	if _idle_elapsed > 0.0:
		_idle_elapsed = 0.0
	hint_triggered.emit(hint_id, str(step.get("trigger", "")))
	EventBus.hint_requested.emit(hint_id)
	Log.debug(TAG, "راهنمای `%s` (تریگر %s) درخواست شد" % [hint_id, str(step.get("trigger", ""))])
