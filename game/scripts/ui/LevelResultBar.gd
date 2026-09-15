class_name LevelResultBar
extends Control
# ===========================================================================
# LevelResultBar — «بعدی / نقشه» بعد از برد (تسک ۳.۴؛ حلقه‌ی کاملِ جریان)
# ---------------------------------------------------------------------------
# عمداً کوچک است: HUD/پاز/تنظیمات واقعی فاز ۶ این نود را می‌بلعد. اینجا فقط دو
# دکمه‌ی لمسی ≥ ۴۸dp هست تا DoD فاز ۳ («منو → انتخاب سطح → بازی → برگشت به
# نقشه با سطح بعدی باز شده») قابل‌اثبات باشد.
# ===========================================================================

const TAG := "LevelResultBar"
const BAR_SIZE := Vector2(760.0, 150.0)
const BUTTON_SIZE := Vector2(340.0, 148.0)  # ارتفاع ≥ کفِ لمسی ۱۴۴px (§۷، ADR-049)

signal next_requested(level_id: String)
signal map_requested

@export var controller: LevelController = null
## false = فقط سیگنال/ناوبریِ سطحی (تست‌ها درخت GUT را دست نمی‌زنند)
@export var allow_scene_change: bool = true

var _next_button: Button = null
var _map_button: Button = null


func _ready() -> void:
	if controller == null:
		controller = get_parent() as LevelController
	custom_minimum_size = BAR_SIZE
	_next_button = _make_button("Next", Vector2(20.0, 19.0))
	_map_button = _make_button("Map", Vector2(400.0, 19.0))
	_next_button.pressed.connect(advance)
	_map_button.pressed.connect(goto_map)
	visible = false
	if controller != null and not controller.level_won.is_connected(_on_level_won):
		controller.level_won.connect(_on_level_won)
	# والد یک Node2D است (نه Control) ⇒ anchor بی‌معنی؛ موقعیت صریح و قابل‌تست
	position = Vector2((1080.0 - BAR_SIZE.x) * 0.5, 1700.0)
	size = BAR_SIZE


## تسک ۸.۴ | قبلاً این‌جا `Button.new()` دستی بود ✗✓ یعنی §۷ (گوشۀ ۱۶px، RTL،
## کوچک‌شدنِ ۰٫۹۵ + لرزش، کفِ لمسی) فقط در `UIKit` نوشته شده بود و این دو دکمه از آن
## می‌گریختند ⇒ sweepِ `test_a11y_scenes.gd` همین را گرفت ✓✓ حالا همه از یک مسیرند ✓
func _make_button(label: String, at: Vector2) -> Button:
	var btn := Button.new()
	btn.name = label
	btn.text = label
	btn.position = at
	btn.size = BUTTON_SIZE
	btn.custom_minimum_size = BUTTON_SIZE
	UIKit.style_button(btn, "gold")
	add_child(btn)
	return btn


## نشستن روی کفه‌ی آخر = برد → نوار نتیجه ظاهر می‌شود (بدون شمارش معکوس، §۶ سند هنری
## «جشنِ بی‌مورد نه؛ بازخورد آرام» و §۳ GDD «هیچ دکمه‌ی بررسی جواب»).
func _on_level_won(_stats: Dictionary) -> void:
	visible = true
	if _next_button != null:
		var next_id: String = LevelLoader.pick_next_from(controller.level_id) if controller != null else ""
		_next_button.visible = not next_id.is_empty()


## سطح بعدی را `LevelLoader` می‌پرسد — از فاز ۴ به بعد `DifficultyEngine`
## پاسخ می‌دهد (Elo + قوانین §۵)؛ اگر چیزی نمانده باشد به نقشه برمی‌گردد.
func advance() -> void:
	if controller == null:
		return
	var next_id: String = LevelLoader.pick_next_from(controller.level_id)
	if next_id.is_empty():
		goto_map()
		return
	next_requested.emit(next_id)
	if not allow_scene_change:
		LevelLoader.pending_config = LevelLoader.load_config(next_id)
		return
	if not LevelLoader.start_level(next_id):
		Log.warn(TAG, "سطح بعدی %s باز نشد: %s" % [next_id, LevelLoader.last_error])


func goto_map() -> void:
	map_requested.emit("res://scenes/main/WorldMap.tscn")
	if not allow_scene_change:
		return
	if not LevelLoader.goto_map():
		Log.warn(TAG, "بازگشت به نقشه ممکن نشد: %s" % LevelLoader.last_error)
