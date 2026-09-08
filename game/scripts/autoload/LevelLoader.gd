extends Node
# ===========================================================================
# LevelLoader — autoload (تسک ۳.۲)
# ---------------------------------------------------------------------------
# دو کار، و نه بیشتر:
#   ۱) `res://data/levels/tierX/level_X_NN.json` را پیدا/بخوان و به `LevelData`
#      تبدیل کند (اعتبارسنجی درونی همان‌جا انجام می‌شود).
#   ۲) `LevelScene.tscn` را با `config` پیکربندی‌شده بسازد/باز کند.
# هیچ امتیاز/راهنما/Elo این‌جا نیست (فازهای ۴ و ۵) و «قابل‌حل بودن» هم اثبات نشده —
# مرجع آن `tools/validate_levels.py` است که در CI اجرا می‌شود (ADR-028).
#
# چرا `pending_config` و نه مستندسازی روی صحنه؟ `change_scene_to_file` تا یک فریم
# بعد صحنه را نمی‌سازد؛ پس سطحِ تازه config را از همین autoload در `_ready` می‌گیرد
# (تسک ۲.۶: LevelScene با config خالی همان سطح hardcoded فاز ۲ را می‌سازد → هیچ‌وقت
# صفحه‌ی سفید نداریم).
# ===========================================================================

const TAG := "LevelLoader"
# ⚠ پوشه‌ی داده در بیلد اندروید: فایل‌های `.json` دارایی import‌شده نیستند، پس preset
# صادر کردن باید `*.json` را در «Non Resource Files» بگذارد (فاز ۱۰، تسک ۱۰.۲).
const LEVELS_ROOT := "res://data/levels"
const LEVEL_SCENE_PATH := "res://scenes/gameplay/LevelScene.tscn"
const WORLD_MAP_PATH := "res://scenes/main/WorldMap.tscn"
const TIER_DIR_PREFIX := "tier"
const ID_PATTERN := "^tier([1-5])_level_([0-9]{2})$"

signal level_loaded(level_id: String)
signal level_load_failed(level_id: String, reason: String)

## false = فقط صف/تحویل config (تست‌های GUT نباید درخت خودشان را عوض کنند)
@export var change_scene_on_start: bool = true

var current: LevelData = null
var last_error: String = ""
var pending_config: Dictionary = {}

## بازی آفلاین است و فایل‌ها ثابت؛ یک‌بار خواندن کافی است (حافظه: ≈۲KB به ازای سطح).
var _cache: Dictionary = {}


# --------------------------------------------------------------------------
# مسیرها و فهرست
# --------------------------------------------------------------------------
## "tier1_level_05" → "res://data/levels/tier1/level_1_05.json"
static func path_for(level_id: String) -> String:
	var re := RegEx.new()
	if re.compile(ID_PATTERN) != OK:
		return ""
	var m: RegExMatch = re.search(level_id)
	if m == null:
		return ""
	var tier: int = int(m.get_string(1))
	var num: String = m.get_string(2)
	return "%s/%s%d/level_%d_%s.json" % [LEVELS_ROOT, TIER_DIR_PREFIX, tier, tier, num]


static func is_valid_id_format(level_id: String) -> bool:
	return not path_for(level_id).is_empty()


## همه‌ی level_id های موجود، مرتب بر اساس Tier و شماره (منبع: فایل‌های روی دیسک).
func level_ids() -> Array[String]:
	var out: Array[String] = []
	var root := DirAccess.open(LEVELS_ROOT)
	if root == null:
		last_error = "پوشه‌ی %s پیدا نشد" % LEVELS_ROOT
		return out
	root.list_dir_begin()
	var dir_name: String = root.get_next()
	var tiers: Array[String] = []
	while not dir_name.is_empty():
		if root.current_is_dir() and dir_name.begins_with(TIER_DIR_PREFIX):
			tiers.append(dir_name)
		dir_name = root.get_next()
	root.list_dir_end()
	tiers.sort()
	for tier_dir: String in tiers:
		var d := DirAccess.open("%s/%s" % [LEVELS_ROOT, tier_dir])
		if d == null:
			continue
		d.list_dir_begin()
		var fname: String = d.get_next()
		var names: Array[String] = []
		while not fname.is_empty():
			if not d.current_is_dir() and fname.begins_with("level_") and fname.ends_with(".json"):
				names.append(fname)
			fname = d.get_next()
		d.list_dir_end()
		names.sort()
		for file: String in names:
			var tier_num: int = int(tier_dir.trim_prefix(TIER_DIR_PREFIX))
			var num: String = file.trim_prefix("level_").trim_suffix(".json").get_slice("_", 1)
			if num.is_empty() or tier_num < 1:
				continue
			out.append("%s%d_level_%s" % [TIER_DIR_PREFIX, tier_num, num])
	return out


func levels_for_tier(tier: int) -> Array[String]:
	var out: Array[String] = []
	for id: String in level_ids():
		if id.begins_with("tier%d_" % tier):
			out.append(id)
	return out


# --------------------------------------------------------------------------
# خواندن
# --------------------------------------------------------------------------
func load_level(level_id: String, use_cache: bool = true) -> LevelData:
	last_error = ""
	if use_cache and _cache.has(level_id):
		return _cache[level_id] as LevelData
	var path: String = path_for(level_id)
	if path.is_empty():
		last_error = "level_id نامعتبر: %s (انتظار tier<N>_level_<NN>)" % level_id
		level_load_failed.emit(level_id, last_error)
		return null
	# `FileAccess.file_exists` قبل از open: بازکردن فایل نبودنی در Godot خطای
	# موتوری چاپ می‌کند و طبق ADR-023 آن خطا، تست GUT را قرمز می‌کند.
	if not FileAccess.file_exists(path):
		last_error = "فایل سطح وجود ندارد: %s" % path
		level_load_failed.emit(level_id, last_error)
		return null
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		last_error = "بازکردن %s ممکن نشد (خطای %d)" % [path, FileAccess.get_open_error()]
		level_load_failed.emit(level_id, last_error)
		return null
	var text: String = f.get_as_text()
	f.close()
	var result: Dictionary = LevelData.from_json_text(text, path)
	if not bool(result.get("ok", false)):
		current = result.get("level") as LevelData
		last_error = str(result.get("error", "خطای نامشخص"))
		level_load_failed.emit(level_id, last_error)
		return null
	var level: LevelData = result["level"] as LevelData
	current = level
	_cache[level_id] = level
	level_loaded.emit(level_id)
	return level


## نسخه‌ای که LevelScene مصرف می‌کند (قرارداد ADR-028). {} یعنی «سطح را نشد خواند».
func load_config(level_id: String) -> Dictionary:
	var level: LevelData = load_level(level_id)
	if level == null:
		return {}
	return level.to_config_dict()


func clear_cache() -> void:
	_cache.clear()


# --------------------------------------------------------------------------
# پل به UI
# --------------------------------------------------------------------------
## صحنه‌ی سطح را برمی‌گرداند و **به درخت اضافه نمی‌کند** — تست‌ها و WorldMap خودشان
## تصمیم می‌گیرند (تسک ۲.۶: config قبل از add_child ست می‌شود تا `_ready` با داده
## واقعی بسازد، نه با پیش‌فرض فاز ۲).
func create_level_scene(level_id: String) -> Node2D:
	var config: Dictionary = load_config(level_id)
	if config.is_empty():
		return null
	var packed: PackedScene = load(LEVEL_SCENE_PATH)
	if packed == null:
		last_error = "صحنه‌ی %s بارگذاری نشد" % LEVEL_SCENE_PATH
		return null
	var scene := packed.instantiate() as Node2D
	if scene == null:
		last_error = "ریشه‌ی %sc باید Node2D باشد" % LEVEL_SCENE_PATH
		return null
	scene.set("config", config)
	return scene


func start_level(level_id: String) -> bool:
	pending_config = load_config(level_id)
	if pending_config.is_empty():
		return false
	if not change_scene_on_start or get_tree() == null:
		# بیرون از درخت (ویرایشگر/تست) فقط config آماده می‌ماند
		return true
	var err: Error = get_tree().change_scene_to_file(LEVEL_SCENE_PATH)
	if err != OK:
		last_error = "تغییر صحنه به %s شکست خورد (خطای %d)" % [LEVEL_SCENE_PATH, err]
		level_load_failed.emit(level_id, last_error)
		return false
	return true


## بازگشت به نقشه — تنها جایی که «مسیر صحنه‌ی نقشه» بلد است (HUD فاز ۶ هم همین را صدا می‌زند).
func goto_map() -> bool:
	last_error = ""
	if not change_scene_on_start or get_tree() == null:
		return true
	var err: Error = get_tree().change_scene_to_file(WORLD_MAP_PATH)
	if err != OK:
		last_error = "بازگشت به %s شکست خورد (خطای %d)" % [WORLD_MAP_PATH, err]
		return false
	return true


## LevelScene در `_ready` این را صدا می‌زند؛ یک‌بار مصرف است (تا F5 بعدی config خالی باشد).
func take_pending_config() -> Dictionary:
	var out: Dictionary = pending_config
	pending_config = {}
	return out


func clear_pending_config() -> void:
	pending_config = {}


## اولین سطحی که هنوز تکمیل نشده (ترتیب Tier/شماره). اگر مدل=null یعنی همه باز.
func first_unfinished_id(model: PlayerModel = null) -> String:
	for id: String in level_ids():
		if model == null or not model.is_level_completed(id):
			return id
	return ""


## سطح بعدی در ترتیب روایی (قفل روایت GDD §۵؛ تطبیق Elo واقعی فاز ۴ است).
func next_of(level_id: String) -> String:
	var ids: Array[String] = level_ids()
	var index: int = ids.find(level_id)
	if index < 0 or index + 1 >= ids.size():
		return ""
	return ids[index + 1]


func level_count() -> int:
	return level_ids().size()
