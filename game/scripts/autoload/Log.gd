extends Node
# ===========================================================================
# Log — لاگ سطح‌دار با پیشوند ماژول (قاعده‌ی سبک AGENTS.md §۵)
# ---------------------------------------------------------------------------
# هیچ داده‌ی بازیکنی هرگز لاگ نمی‌شود (نه اسم، نه مدل، نه transcript) —
# در اندروید logcat برای بقیه‌ی اپ‌ها خواندنی است. برای همین `debug()` تنها در
# build دیباگ چاپ می‌کند و `info/warn/error` بدون داده‌ی کاربر.
# `last_errors` یک حلقه‌ی کوچک در حافظه است که Parent Dashboard نشان می‌دهد
# (ADR-019: crash log محلی، بدون ارسال).
# ===========================================================================

enum Level { DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3 }

const TAG := "NEXUS"
const MAX_KEPT_ERRORS := 64

var min_level: int = Level.INFO
var last_errors: Array[String] = []


func _ready() -> void:
	if OS.is_debug_build():
		min_level = Level.DEBUG
	set_process(false)


func debug(module: String, message: String) -> void:
	if min_level <= Level.DEBUG:
		print("[%s/%s] %s" % [TAG, module, message])


func info(module: String, message: String) -> void:
	if min_level <= Level.INFO:
		print("[INFO %s/%s] %s" % [TAG, module, message])


func warn(module: String, message: String) -> void:
	if min_level <= Level.WARN:
		push_warning("[WARN %s/%s] %s" % [TAG, module, message])


func error(module: String, message: String) -> void:
	# فقط در حافظه‌ی محله؛ هیچ‌جا ارسال نمی‌شود (ADR-010).
	var line := "[ERROR %s/%s] %s" % [TAG, module, message]
	last_errors.append(line)
	if last_errors.size() > MAX_KEPT_ERRORS:
		last_errors.pop_front()
	push_error(line)
