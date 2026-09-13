class_name SettingsStore
extends RefCounted
# ===========================================================================
# SettingsStore — ترجیحات دستگاه و کارآموز، در فایلِ جدا از PlayerModel
# ---------------------------------------------------------------------------
# چرا جدا؟ سند ۰۳ §۲ اسکیمای `PlayerModel` را دقیقاً تعریف کرده و همان اسکیماست که
# در فاز ۹ با بک‌اند همگام می‌شود و در داشبورد صادر می‌شود. صدا/زبان/لرزش/آواتار
# «ترجیحِ دستگاه»اند، نه «مهارتِ کودک»؛ قاطی‌کردنشان هم schema-version را بی‌دلیل
# بالا می‌برد، هم بارِ همگام‌سازی و هم سطح حمله‌ی حریم خصوصی را (ADR-045).
#
# سه قاعده:
#   ۱) تحمل‌پذیر: فایل نبود → پیش‌فرض؛ عدد خارج از بازه → clamp؛ ساختار غلط →
#      پیش‌فرضِ آن کلید. هرگز کرش، هرگز پیامِ گیج‌کننده به کودک (هم‌فلسفه با
#      `PlayerModel.from_dict`).
#   ۲) apply_* صریح‌اند: نوشتن یک مقدار، AudioServer را جلو نمی‌برد. بازی در
#      `GameState.bootstrap()` یک‌بار `apply_at_boot()` صدا می‌زند و UI بعد از هر
#      تغییر؛ پس تست‌ها می‌توانند مقدار را بدون اثر جانبی بخوانند.
#   ۳) تنها مسیر نوشتنِ user:// در UI همین کلاس است (داشبورد والدین فقط می‌خواند).
# ===========================================================================

const TAG := "Settings"
const FILE_PATH := "user://ui_settings.json"

## §۴ سند هنری: ۶ تُن پوست و ۸ مدل مو؛ رنگ مو «آزاد» است ولی کودک پالت انتخاب می‌کند.
const SKIN_TONES := 6
const HAIR_STYLES := 8
## §۴ «رنگ مو آزاد» ⇒ هشت سواچ: چهار تُنِ طبیعیِ مو + نقره‌ای (Stone Grey ✓) +
## سه رنگِ Aeloria که **مستقیماً از پالت رسمی** می‌آیند ✓✓ (تستِ ۸.۲: هر هگز باید
## یا در `Palette` باشد یا در فهرستِ مجازِ ADR-060 ⇒ هیچ رنگِ دست‌سازِ پراکنده‌ای ✗)
const HAIR_COLORS: Array[String] = [
	"3B2C2A", "6E4B3A", "A9714B", "D8A05B", "E8C39E", "8A8FA3",
	"4FD1C5", "B79CED",
]

const MIN_DB := -40.0
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

## نوع و بازه‌ی هر کلید — همین جدول هم sanitize می‌کند هم پیش‌فرض می‌دهد.
const SPEC := {
	"music_volume": {"kind": "float", "min": 0.0, "max": 1.0, "default": 0.8},
	"sfx_volume": {"kind": "float", "min": 0.0, "max": 1.0, "default": 1.0},
	"locale": {"kind": "locale", "default": Loc.FA},
	"haptics_enabled": {"kind": "bool", "default": true},
	# تسک ۹.۶ | دروازۀ والد برای همگام‌سازی ابری ✓§۹. پیش‌فرض از `FeatureFlags.CLOUD_SYNC_ENABLED`
	# کپی شده (صریح، نه تابعی ✗✓: مقدارِ const باید ثابت باشد — همان درسِ `const TONES` فاز ۸ ✓✓)
	"cloud_sync_enabled": {"kind": "bool", "default": true},
	"adaptive_selection": {"kind": "bool", "default": true},
	"onboarding_done": {"kind": "bool", "default": false},
	"avatar": {"kind": "avatar", "default": {}},
}

static var _values: Dictionary = {}
static var _source_path: String = ""


static func defaults() -> Dictionary:
	var out := {}
	for key: String in SPEC.keys():
		out[key] = SPEC[key].get("default", null)
	out["avatar"] = default_avatar()
	return out


static func default_avatar() -> Dictionary:
	return {"skin_tone": 0, "hair_style": 0, "hair_color": 0}


## یک مقدار را به نوع/بازه‌ی مجازِ همان کلید می‌رساند (تهی = پیش‌فرض).
static func clamp_value(key: String, value: Variant) -> Variant:
	var spec: Dictionary = SPEC.get(key, {}) as Dictionary
	match str(spec.get("kind", "")):
		"float":
			var f: Variant = value
			if f is String:
				f = float(str(f)) if (str(f) as String).is_valid_float() else null
			if not (f is float or f is int):
				return spec.get("default", 0.0)
			return clampf(float(f), float(spec.get("min", 0.0)), float(spec.get("max", 1.0)))
		"bool":
			if value is bool:
				return value
			if value is int or value is float:
				return float(value) > 0.5
			if value is String:
				var s: String = (str(value) as String).to_lower()
				if s == "true" or s == "1" or s == "yes":
					return true
				if s == "false" or s == "0" or s == "no":
					return false
			return spec.get("default", false)
		"locale":
			var code: String = str(value)
			return code if Loc.is_known_locale(code) else str(spec.get("default", Loc.FA))
		"avatar":
			return _clamp_avatar(value)
		_:
			# کلید ناشناخته: نگهش نداریم — ولی تهی هم برنمی‌گردانیم تا فراخوان
			# اشتباه بی‌سروصدا «مقدار درست» به نظر نرسد.
			return null


static func _clamp_avatar(value: Variant) -> Dictionary:
	var out := default_avatar()
	if not (value is Dictionary):
		return out
	var raw: Dictionary = value
	for key: String in out.keys():
		var n: Variant = raw.get(key, out[key])
		var limit: int = SKIN_TONES if key == "skin_tone" else (
			HAIR_STYLES if key == "hair_style" else HAIR_COLORS.size())
		if n is int or n is float or (n is String and str(n).is_valid_int()):
			out[key] = clampi(int(n), 0, maxi(0, limit - 1))
	return out


static func sanitize(raw: Variant) -> Dictionary:
	var out := defaults()
	if not (raw is Dictionary):
		return out
	var data: Dictionary = raw
	for key: String in SPEC.keys():
		if not data.has(key):
			continue
		var value: Variant = clamp_value(key, data[key])
		if value != null:
			out[key] = value
	return out


## false یعنی «فایل نبود یا خونده نشد» و `_values` روی پیش‌فرض می‌نشیند (کرش نه).
static func load_from(path: String = FILE_PATH) -> bool:
	_source_path = path
	if not FileAccess.file_exists(path):
		_values = defaults()
		return false
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		_values = defaults()
		return false
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	_values = sanitize(parsed)
	return parsed is Dictionary


static func ensure_loaded() -> void:
	if _values.is_empty():
		load_from()


static func save_to(path: String = "") -> bool:
	var target: String = path if not path.is_empty() else _source_path
	if target.is_empty():
		target = FILE_PATH
	var f: FileAccess = FileAccess.open(target, FileAccess.WRITE)
	if f == null:
		Log.warn(TAG, "نوشتن تنظیمات ممکن نشد: " + target)
		return false
	f.store_string(JSON.stringify(_values, "\t"))
	f.close()
	_source_path = target
	return true


static func all() -> Dictionary:
	ensure_loaded()
	return _values.duplicate(true)


static func get_value(key: String) -> Variant:
	ensure_loaded()
	if not _values.has(key):
		return clamp_value(key, null)
	return _values[key]


## نوشتن با تایید شکل: false یعنی کلید را نمی‌شناسیم (اشتباهِ برنامه‌نویس لو می‌رود).
static func set_value(key: String, value: Variant) -> bool:
	if not SPEC.has(key):
		Log.warn(TAG, "کلید تنظیمات ناشناخته: " + key)
		return false
	ensure_loaded()
	_values[key] = clamp_value(key, value)
	return true


static func set_and_save(key: String, value: Variant) -> bool:
	if not set_value(key, value):
		return false
	return save_to()


static func toggle(key: String) -> bool:
	var current: Variant = get_value(key)
	if not (current is bool):
		return false
	return set_and_save(key, not bool(current))


static func avatar() -> Dictionary:
	ensure_loaded()
	return _clamp_avatar(_values.get("avatar", {}))


static func limit_for(part: String) -> int:
	if part == "skin_tone":
		return SKIN_TONES
	if part == "hair_style":
		return HAIR_STYLES
	if part == "hair_color":
		return HAIR_COLORS.size()
	return 0


static func set_avatar_choice(part: String, index: int) -> bool:
	if part != "skin_tone" and part != "hair_style" and part != "hair_color":
		return false
	ensure_loaded()
	var next := avatar()
	next[part] = clampi(index, 0, maxi(0, limit_for(part) - 1))
	_values["avatar"] = next
	return save_to()


static func reset() -> Dictionary:
	_values = defaults()
	return _values.duplicate(true)


static func reset_for_tests() -> void:
	_values = {}
	_source_path = ""


# --------------------------------------------------------------------------
# apply_* — تنها جایی که تنظیمات به موتور تبدیل می‌شود
# --------------------------------------------------------------------------
static func bus_index(bus_name: String) -> int:
	return AudioServer.get_bus_index(bus_name)


## ۰..۱ روی اسلایدر → dB خطی‌نمای + mute کامل در صفر (کودک «خاموش» را صفر می‌خواهد، نه «خیلی آرام»).
static func apply_volume(bus_name: String, level: float) -> void:
	var idx: int = bus_index(bus_name)
	if idx < 0:
		Log.debug(TAG, "باس «%s» وجود ندارد (چیدمان باس تنظیم نشده؟)" % bus_name)
		return
	var v: float = clampf(level, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))


static func apply_audio() -> void:
	apply_volume(BUS_MUSIC, float(get_value("music_volume")))
	apply_volume(BUS_SFX, float(get_value("sfx_volume")))


static func apply_locale() -> void:
	var code: String = str(get_value("locale"))
	if not Loc.set_locale(code):
		Loc.set_locale(Loc.default_locale())


static func apply_gameplay_flags() -> void:
	# kill-switch والدین (تسک ۶.۵): موتور دشواری را مستقیم خاموش/روشن می‌کند —
	# «پیشرفت خودکار» یک انتخاب والد است، نه یک ثابت برنامه‌نویسی.
	DifficultyEngine.adaptive_selection = bool(get_value("adaptive_selection"))


static func apply_at_boot() -> void:
	load_from()
	apply_locale()
	apply_audio()
	apply_gameplay_flags()


static func describe() -> String:
	return "locale=%s music=%.2f sfx=%.2f haptics=%s adaptive=%s" % [
		str(get_value("locale")), float(get_value("music_volume")),
		float(get_value("sfx_volume")), str(get_value("haptics_enabled")),
		str(get_value("adaptive_selection")),
	]
