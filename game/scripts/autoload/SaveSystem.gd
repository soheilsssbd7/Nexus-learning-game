extends Node
# ===========================================================================
# SaveSystem — خواندن/نوشتن مدل بازیکن روی دیسک (تسک ۱.۳)
# ---------------------------------------------------------------------------
# مسیر پیش‌فرض دقیقاً `user://player_model.save` است (docs/03-DATA-SCHEMAS.md §۲).
# برای پشتیبانی از چند پروفایل (ADR-012) مسیر پارامتریک است:
#   profile_name == "default"  →  user://player_model.save
#   profile_name == "sara"     →  user://profiles/sara/player_model.save
#
# نکات ایمنی/حریم‌خصوصی:
#   * نوشتن اتمیک: `.tmp` سپس rename — اگر باتری وسط نوشت بچکد، save قبلی نمی‌سوزد.
#   * فایل JSON رمزنگاری‌نشده است (تصمیم آگاهانه در §۲ و ADR-019): هیچ PII در آن نیست.
#   * `schema_version` مهاجرت را تعیین می‌کند؛ فیلد غایب = مقدار پیش‌فرض.
# ===========================================================================

const TAG := "SaveSystem"
const FILE_NAME := "player_model.save"
const PROFILES_ROOT := "user://profiles"
## تک‌پروفایل MVP (تصمیم مالک، docs/06 ADR-027): مسیر پارامتریک است ولی پیش‌فرض «default».
const DEFAULT_PROFILE := "default"
## فاصله‌ی بین «dirty شدن» و نوشتن واقعی — درگ‌ها زیاد write تولید می‌کنند.
const DEBOUNCE_SEC := 1.0

var profile_name: String = DEFAULT_PROFILE
var had_save_on_load: bool = false

## مدلی که آخرین بار بارگذاری/ساخته شد؛ Write‌های debounced از همین خوانده می‌شود تا
## SaveSystem به ترتیب آزاد شدن autoloadها وابسته نباشد (فقط داده، بدون logic).
var _bound_model: PlayerModel = null

var _dirty: bool = false
var _since_last_change: float = DEBOUNCE_SEC


func _ready() -> void:
	EventBus.save_requested.connect(_on_save_requested)


func _process(delta: float) -> void:
	if not _dirty:
		return
	_since_last_change += delta
	if _since_last_change >= DEBOUNCE_SEC:
		flush()


func path_for(profile: String = "") -> String:
	var p: String = profile if not profile.is_empty() else profile_name
	if p.is_empty() or p == "default":
		return "user://" + FILE_NAME
	return "%s/%s/%s" % [PROFILES_ROOT, p, FILE_NAME]


## پوشه‌ی حاوی مسیر داده را می‌سازد. (تست‌ها و مسیر مهاجرت هم همین را صدا می‌زنند تا
## `FileAccess.open` هرگز null برنگرداند.)
func ensure_dir(path: String) -> Error:
	var dir_abs: String = ProjectSettings.globalize_path(path.get_base_dir())
	if DirAccess.dir_exists_absolute(dir_abs):
		return OK
	return DirAccess.make_dir_recursive_absolute(dir_abs)


func has_save(profile: String = "") -> bool:
	return FileAccess.file_exists(path_for(profile))


# --------------------------------------------------------------------------
# API اصلی
# --------------------------------------------------------------------------
func bind_model(model: PlayerModel) -> void:
	_bound_model = model


func bound_model() -> PlayerModel:
	return _bound_model if (model_ok()) else null


func model_ok() -> bool:
	return _bound_model != null and is_instance_valid(_bound_model)
func save_player_model(model: PlayerModel) -> Error:
	if model == null:
		Log.warn(TAG, "save خواسته شد ولی مدل فعالی وجود ندارد")
		return ERR_INVALID_DATA
	model.schema_version = PlayerModel.SCHEMA_VERSION
	var path: String = path_for()
	var tmp_path: String = path + ".tmp"

	var dir_err: Error = ensure_dir(path)
	if dir_err != OK:
		Log.error(TAG, "پوشه‌ی save ساخته نشد: %s" % error_string(dir_err))
		return dir_err

	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		Log.error(TAG, "باز کردن فایل موقت ناموفق: %s" % tmp_path)
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(model.to_dict(), "  "))
	f.close()

	# rename = جای‌گزینی اتمیک روی لینوکس/اندروید؛ اگر نشد، کپی+حذف (نه اتمیک ولی بهتر از هیچ).
	if FileAccess.file_exists(path):
		if DirAccess.rename_absolute(tmp_path, path) != OK:
			var cp: Error = DirAccess.copy_absolute(tmp_path, path)
			if cp != OK:
				Log.error(TAG, "جای‌گزینی فایل save ناموفق: %s" % error_string(cp))
				return cp
			DirAccess.remove_absolute(tmp_path)
	else:
		if DirAccess.rename_absolute(tmp_path, path) != OK:
			var cp2: Error = DirAccess.copy_absolute(tmp_path, path)
			if cp2 != OK:
				return cp2
			DirAccess.remove_absolute(tmp_path)
	_dirty = false
	Log.debug(TAG, "save نوشته شد → %s" % path)
	return OK


## همیشه یک مدل معتبر برمی‌گرداند. اگر save نبود، مدل تازه (با player_id تازه) ساخته می‌شود
## و `had_save_on_load` برابر false می‌ماند (MainMenu بر همین اساس Onboarding را باز می‌کند).
func load_player_model(create_if_missing: bool = true) -> PlayerModel:
	var path: String = path_for()
	had_save_on_load = false
	if not FileAccess.file_exists(path):
		if create_if_missing:
			var fresh := PlayerModel.create_new()
			Log.info(TAG, "save یافت نشد → پروفایل تازه ساخته شد")
			return fresh
		return null
	var text: String = FileAccess.get_file_as_string(path)
	# چرا JSON.parse_string نه؟ نسخه‌ی static موقع خطا ERR_PRINT می‌کند؛ ما خودمان
	# مدیریت می‌کنیم (ADR-023: هیچ engine error مدیریت‌شده‌ای در لاگ/تست‌ها نماند).
	var parser := JSON.new()
	var parse_err: Error = parser.parse(text)
	var parsed: Variant = parser.data if parse_err == OK else null
	if not (parsed is Dictionary):
		Log.warn(TAG, "فایل save خراب است (%s) → پشتیبان‌گیری و شروع تازه"
			% (parser.get_error_message() if parse_err != OK else "ریشه‌ی JSON آبجکت نیست"))
		DirAccess.copy_absolute(path, path + ".corrupt")
		return PlayerModel.create_new() if create_if_missing else null
	var migrated: Dictionary = _migrate(parsed)
	var model := PlayerModel.from_dict(migrated)
	had_save_on_load = true
	Log.debug(TAG, "save بارگذاری شد (schema v%d، %d سطح)" % [model.schema_version, model.levels_completed.size()])
	return model


# --------------------------------------------------------------------------
# مهاجرت نسخه‌ها (§۲: «نسخه‌ی قدیمی را می‌خواند، فیلدهای جدید را با پیش‌فرض پر می‌کند»)
# --------------------------------------------------------------------------
func _migrate(raw: Dictionary) -> Dictionary:
	var data: Dictionary = raw.duplicate(true)
	var from_version: int = int(data.get("schema_version", 0))
	if from_version > PlayerModel.SCHEMA_VERSION:
		# save جدیدتر از این بیلد (ریزا/داون‌گرید) — داده را دور نمی‌ریزیم، فقط هشدار می‌دهیم.
		Log.error(TAG, "save با schema v%d از این بیلد (%d) جدیدتر است — با احتیاط بارگذاری شد"
			% [from_version, PlayerModel.SCHEMA_VERSION])
	if from_version < PlayerModel.SCHEMA_VERSION:
		data = _migrate_to_v1(data)
	data["schema_version"] = PlayerModel.SCHEMA_VERSION
	return data


## v0 (فیلدهای ناقص/اولیه) → v1: هر کلید لازم که نیست، پیش‌فرض می‌گیرد.
func _migrate_to_v1(data: Dictionary) -> Dictionary:
	var defaults := PlayerModel.create_new().to_dict()
	defaults.erase("player_id")
	defaults.erase("created_at")
	for key: String in defaults.keys():
		if not data.has(key):
			data[key] = defaults[key]
	# تغییرات نام فیلد در نسخه‌های آزمایشی (نگاشت سازگارکننده) — فعلاً خالی:
	# data["x"] = data.get("x", data.get("old_x", 0))
	return data


# --------------------------------------------------------------------------
# API کمکی: debounce، حذف، خروجی برای والد
# --------------------------------------------------------------------------
func _on_save_requested() -> void:
	_dirty = true
	_since_last_change = 0.0


func request_save() -> void:
	_on_save_requested()


## نوشتن فوری (خروج از بازی، پایان سطح، قبل از sync).
func flush() -> void:
	if _dirty and model_ok():
		save_player_model(_bound_model)
	_dirty = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and model_ok():
		save_player_model(_bound_model)


func save_now(model: PlayerModel) -> void:
	save_player_model(model)
	_dirty = false


func delete_all() -> void:
	for candidate: String in [path_for(), path_for() + ".tmp", path_for() + ".corrupt"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)
	Log.info(TAG, "save حذف شد (درخواست والد)")


## متن JSON برای نمایش/ذخیره توسط والد (تسک ۶.۵) — بدون هیچ فیلد اضافه.
func export_json_for_parent() -> String:
	if not model_ok():
		return "{}"
	return JSON.stringify(_bound_model.to_dict(), "  ")
