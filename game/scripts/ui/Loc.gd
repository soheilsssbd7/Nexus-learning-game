class_name Loc
extends RefCounted
# ===========================================================================
# Loc — رشته‌های UI از یک فایل، نه از دل صحنه (تسک ۶.۳ «i18n placeholder»)
# ---------------------------------------------------------------------------
# چرا یک RefCounted استاتیک و نه autoload: هیچ وضعیت اجرایی ندارد جز یک کشِ
# خواندنی، و autoload تازه یعنی تغییر ترتیب بارگذاری در project.godot (ADR-016).
# فایل `data/l10n/ui_strings.json` تنها منبع رشته‌هاست:
#   • `default_locale` = fa، و `rtl_locales` جهت را تعریف می‌کند — پس RTL یک
#     داده است نه یک `set(...)` پراکنده در صحنه‌ها؛ افزودن زبان جدید فقط این فایل است.
#   • رشته‌ی گمشده = خودِ کلید نمایش داده می‌شود (crash نه، و در تست هم لو می‌رود).
#   • `tools/validate_levels.py` برابری کلیدهای همه‌ی localeها و سقف طول را می‌سنجد.
# ===========================================================================

const TAG := "Loc"
const PATH := "res://data/l10n/ui_strings.json"
const FA := "fa"

static var _data: Dictionary = {}
static var _locale: String = ""
static var _loaded: bool = false


## خواندن فایل؛ اگر نشد، دیکشنری خالی ⇒ هر `t(key)` خودش را برمی‌گرداند (بی‌crash).
static func load_file(path: String = PATH) -> bool:
	_loaded = true
	if not FileAccess.file_exists(path):
		_data = {}
		Log.warn(TAG, "فایل رشته‌ها پیدا نشد: " + path)
		return false
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		_data = {}
		return false
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_data = {}
		Log.error(TAG, "ساختار فایل رشته‌ها غلط است (باید object با `strings` باشد)")
		return false
	_data = parsed
	if _locale.is_empty():
		_locale = default_locale()
	return true


static func ensure_loaded() -> void:
	if not _loaded:
		load_file()


static func default_locale() -> String:
	ensure_loaded()
	var code: String = str(_data.get("default_locale", FA))
	return code if not code.is_empty() else FA


static func locale() -> String:
	ensure_loaded()
	return _locale if not _locale.is_empty() else default_locale()


## تنها کلیدهایی که `set_locale` می‌پذیرد؛ زبان ناشناخته = بی‌اثر (نه کرش، نه Englishِ ناخواسته).
static func available_locales() -> Array:
	ensure_loaded()
	var raw: Variant = _data.get("locales", {})
	return (raw as Dictionary).keys() if raw is Dictionary else [default_locale()]


## نامِ قابل‌نمایش یک زبان (برای دکمهٔ «زبان» در تنظیمات): از خودِ فایل، نه hardcode.
static func label_for(code: String) -> String:
	ensure_loaded()
	var raw: Variant = _data.get("locales", {})
	if raw is Dictionary and (raw as Dictionary).has(code):
		return str((raw as Dictionary)[code])
	return code


static func is_known_locale(code: String) -> bool:
	return available_locales().has(code)


static func set_locale(code: String) -> bool:
	ensure_loaded()
	if not is_known_locale(code):
		Log.warn(TAG, "زبان ناشناخته: " + code)
		return false
	_locale = code
	return true


static func strings(code: String = "") -> Dictionary:
	ensure_loaded()
	var all: Variant = _data.get("strings", {})
	if not (all is Dictionary):
		return {}
	var want: String = code if not code.is_empty() else locale()
	var table: Variant = (all as Dictionary).get(want, {})
	return table if table is Dictionary else {}


## متن یک کلید؛ fallback: زبان فعلی → `default_locale` → خودِ کلید.
static func t(key: String) -> String:
	ensure_loaded()
	var direct: Variant = strings().get(key, null)
	if direct is String and not (direct as String).is_empty():
		return direct
	var fallback: Variant = strings(default_locale()).get(key, null)
	if fallback is String and not (fallback as String).is_empty():
		return fallback
	return key


## جهت متن از داده می‌آید، نه از hardcode: هر چیزی که `fa` است RTL می‌شود.
static func is_rtl(code: String = "") -> bool:
	ensure_loaded()
	var want: String = code if not code.is_empty() else locale()
	var raw: Variant = _data.get("rtl_locales", [FA])
	return (raw as Array).has(want) if raw is Array else want == FA


static func text_direction() -> int:
	return Control.TEXT_DIRECTION_RTL if is_rtl() else Control.TEXT_DIRECTION_LTR


static func alignment() -> int:
	return Control.TEXT_ALIGNMENT_RIGHT if is_rtl() else Control.TEXT_ALIGNMENT_LEFT


## رقم‌های ASCII درون یک متن را به رقم فارسی می‌برود (در هر زبان RTL).
## UI اعداد را با همین نمایش می‌دهد؛ متن راهنما (فاز ۵) اصلاً رقم ندارد، پس دست‌نخورده می‌ماند.
static func digits(text: String) -> String:
	if not is_rtl():
		return text
	var out := ""
	for i: int in range(text.length()):
		var c: String = text[i]
		var o: int = c.unicode_at(0)
		if o >= 48 and o <= 57:
			out += String.chr(1776 + (o - 48))
		else:
			out += c
	return out


static func percent(value: float) -> String:
	var out: String = digits("%d%%" % int(round(clampf(value, 0.0, 1.0) * 100.0)))
	return out.replace("%", "٪") if is_rtl() else out


## زمان را خوانا می‌کند: «۱ ساعت ۵ دقیقه»، «۴۲ دقیقه»، «۳۵ ثانیه».
static func duration_sec(value: float) -> String:
	var total: int = int(round(maxf(0.0, value)))
	if total < 60:
		return "%s %s" % [digits(str(total)), t("dashboard.sec")]
	var minutes: int = int(floor(float(total) / 60.0))
	var hours: int = int(floor(float(minutes) / 60.0))
	if hours > 0:
		return "%s %s و %s %s" % [digits(str(hours)), t("dashboard.hour"),
			digits(str(minutes % 60)), t("dashboard.minute")]
	return "%s %s" % [digits(str(minutes)), t("dashboard.minute")]


## برای تست و برای `tools/validate_levels.py`: هر locale چه کلیدهایی را کم دارد.
static func missing_keys() -> Dictionary:
	ensure_loaded()
	var out := {}
	var reference: Array = strings(default_locale()).keys()
	var all: Variant = _data.get("strings", {})
	if not (all is Dictionary):
		return {"*": reference}
	for code: Variant in (all as Dictionary).keys():
		var table: Dictionary = (all as Dictionary)[code] as Dictionary
		var absent: Array[String] = []
		for key: String in reference:
			if not table.has(key):
				absent.append(key)
		if not absent.is_empty():
			out[str(code)] = absent
	return out


static func reset_for_tests() -> void:
	_data = {}
	_locale = ""
	_loaded = false
