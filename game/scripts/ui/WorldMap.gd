class_name WorldMap
extends Node2D
# ===========================================================================
# WorldMap — انتخاب سطح (تسک ۳.۴؛ placeholder تا HUD/منوی واقعی فاز ۶)
# ---------------------------------------------------------------------------
# قانون قفل (از سند ۰۴): سطح i باز است اگر i==0 یا سطح قبلی در PlayerModel
# تکمیل شده باشد. یعنی «ترتیب روایی» حفظ می‌شود و هیچ سطحی از Tier باز نشده
# ظاهر نمی‌شود (GDD §۵). فهرست سطوح از فایل‌ها می‌آید، نه از const — پس فاز ۷
# فقط JSON اضافه می‌کند و این صحنه دست‌نخورده می‌ماند.
#
# درخت در کد ساخته می‌شود (ADR-032) تا ادیتور و هدلس یک رفتار داشته باشند؛
# صحنه‌ی .tscn فقط ریشه + اسکریپت است.
# ===========================================================================

const TAG := "WorldMap"
## قانون دست‌رسپذیری §۲ سند هنری: حداقل ۴۸dp؛ روی بوم ۱۰۸۰×۱۹۲۰ این یعنی ~۱۲۸px.
const NODE_SIZE := Vector2(136.0, 136.0)
const TOP_Y: float = 300.0
const BOTTOM_Y: float = 1560.0
const MEANDER_X: float = 190.0

signal level_requested(level_id: String)
signal level_blocked(level_id: String, reason: String)

@export var build_on_ready: bool = true
## برای تست/ویرایشگر: اگر خالی باشد از LevelLoader خوانده می‌شود.
@export var level_ids_override: Array[String] = []
## false = فقط درخواست بفرست (تست‌ها صحنه را خودشان می‌سازند تا درخت GUT به‌هم نریزد).
@export var allow_scene_change: bool = true

var buttons: Array[Button] = []
var level_ids: Array[String] = []


func _ready() -> void:
	if build_on_ready:
		rebuild()
	# برد در LevelController با `level_completed` اعلام می‌شود → همین‌جا قفل‌ها باز می‌شوند
	EventBus.level_completed.connect(_on_level_completed)


func rebuild() -> void:
	for b: Button in buttons:
		if is_instance_valid(b):
			b.queue_free()
	buttons.clear()
	level_ids = level_ids_override.duplicate()
	if level_ids.is_empty():
		level_ids = LevelLoader.level_ids()
	if level_ids.is_empty():
		Log.warn(TAG, "هیچ سطحی در data/levels پیدا نشد — نقشه خالی است (فاز ۳/۷)")
		return
	var count: int = level_ids.size()
	var span: float = BOTTOM_Y - TOP_Y
	var step: float = span / float(maxi(1, count - 1)) if count > 1 else 0.0
	for i: int in range(count):
		var center := Vector2(540.0 + MEANDER_X * sin(float(i) * 1.05), TOP_Y + step * float(i))
		var btn := Button.new()
		btn.name = "Level_%02d" % (i + 1)
		btn.custom_minimum_size = NODE_SIZE
		btn.position = center - NODE_SIZE * 0.5
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 40)
		btn.pressed.connect(request_level.bind(i))
		add_child(btn)
		buttons.append(btn)
	refresh_locks()


func is_unlocked(index: int) -> bool:
	if index <= 0:
		return true
	if index >= level_ids.size():
		return false
	var model: PlayerModel = GameState.active_model
	if model == null:
		return true
	return model.is_level_completed(level_ids[index - 1])


## متن/قفل دکمه‌ها را از PlayerModel بازسازی می‌کند (دکمه‌ی غیرفعال = قفل، نه پنهان).
func refresh_locks() -> void:
	var model: PlayerModel = GameState.active_model
	for i: int in range(buttons.size()):
		var btn: Button = buttons[i]
		if not is_instance_valid(btn):
			continue
		var id: String = level_ids[i]
		var done: bool = model != null and model.is_level_completed(id)
		var open: bool = is_unlocked(i)
		btn.disabled = not open
		btn.text = str(i + 1) + (" ✓" if done else "")
		btn.tooltip_text = id if open else "%s — قفل (اول سطح %d را تمام کن)" % [id, i]
		btn.add_theme_color_override("font_color", Palette.CLOUD_WHITE if open else Palette.STONE_GREY)
		btn.add_theme_color_override("font_disabled_color", Palette.STONE_GREY)


func level_count() -> int:
	return level_ids.size()


## ورودی عمومی «این سطح را باز کن» — هم کلیک، هم تست (بدون تزریق InputEvent).
func request_level(index: int) -> void:
	if index < 0 or index >= level_ids.size():
		return
	var id: String = level_ids[index]
	if not is_unlocked(index):
		level_blocked.emit(id, "locked")
		Log.info(TAG, "سطح %s قفل است" % id)
		return
	level_requested.emit(id)
	if not allow_scene_change:
		# تست/پیش‌نمایش: ناوبری با صحنه را مسئول بیرونی می‌گذاریم
		LevelLoader.pending_config = LevelLoader.load_config(id)
		return
	if not LevelLoader.start_level(id):
		Log.warn(TAG, "بازکردن سطح %s ممکن نشد: %s" % [id, LevelLoader.last_error])


func _on_level_completed(_level_id: String, _stats: Dictionary) -> void:
	refresh_locks()
