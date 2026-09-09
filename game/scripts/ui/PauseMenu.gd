class_name PauseMenu
extends Control
# ===========================================================================
# PauseMenu — توقف وسط گیم‌پلی (تسک ۶.۳)
# ---------------------------------------------------------------------------
# DoD سند ۰۴: «Pause وضعیت فعلی سطح را از دست نمی‌دهد؛ resume دقیقاً از همان‌جا».
# سه چیز این را تضمین می‌کند و هر سه تست دارند:
#   ۱) `get_tree().paused` + `process_mode = ALWAYS` روی همین نود: موتور می‌ایستد،
#      منو زنده می‌ماند. هیچ صحنه‌ای reload نمی‌شود ⇒ همان کره‌ها، همان کفه‌ها.
#   ۲) `mouse_filter = STOP` روی ریشه: هیچ لمسی از پس‌زمینه به سطح نمی‌رسد (پاز
#      واقعی، نه «منوی شفاف روی بازیِ در حال اجرا»).
#   ۳) `GameState.begin_pause()/end_pause()`: زمانِ پاز نه در `elapsed_level_sec`
#      (میانگین زمان حل) نه در `total_playtime_sec` (داشبورد والدین) شمرده می‌شود
#      — ADR-046.
# صحنه به‌صورت overlay هم استفاده می‌شود (HUD فاز ۶) و هم صحنه‌ی مستقل؛ برای همین
# `controller` از والد گرفته می‌شود و اگر نبود، پاز فقط زمان را می‌بندد.
# ===========================================================================

const TAG := "PauseMenu"
const SCENE_PATH := "res://scenes/ui/PauseMenu.tscn"
const SETTINGS_SCENE := "res://scenes/ui/SettingsMenu.tscn"

signal resumed
signal settings_requested
signal map_requested
signal menu_requested

@export var allow_scene_change: bool = true
## false = فقط زمان/درگ را ببند (برای صحنه‌هایی که خودشان paused را مدیریت می‌کنند).
@export var pauses_the_tree: bool = true
@export var build_on_ready: bool = true
## تنظیمات به‌جای تغییر صحنه، روی همین صحنه سوار می‌شود: «resume از همان‌جا» یعنی
# حتی یک reload هم نباید رخ دهد.
@export var embed_settings: bool = true

var buttons: Array[Button] = []
var title_label: Label = null
var settings_panel: SettingsMenu = null
var _dim: ColorRect = null
var _panel: PanelContainer = null
var _was_paused_by_us: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if build_on_ready:
		_build()
	visible = false


func _build() -> void:
	# ریشه باید کل بوم را بپوشاند تا ورودی به سطح نرسد (STOP روی Control صفر×صفر بی‌اثر است)
	UIKit.anchor_full(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(Palette.DEEP_INDIGO, 0.72)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	UIKit.anchor_full(_dim)
	add_child(_dim)

	_panel = UIKit.make_panel(0.94, UIKit.MARGIN * 1.5)
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(620.0, 0.0)
	add_child(_panel)

	var box := UIKit.make_vbox(UIKit.GAP)
	box.name = "Buttons"
	_panel.add_child(box)

	title_label = UIKit.make_label("pause.title", UIKit.TITLE_FONT_PX - 6)
	title_label.name = "Title"
	box.add_child(title_label)

	_add(box, "pause.resume", "gold", resume)
	_add(box, "pause.settings", "cloud", open_settings)
	_add(box, "pause.map", "cloud", goto_map)
	_add(box, "menu.quit", "stone", quit_to_menu)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER,
		Control.PRESET_MODE_MINSIZE, 0)
	UIKit.apply_flow(self)


func _add(box: VBoxContainer, key: String, tone: String, action: Callable) -> Button:
	var btn: Button = UIKit.make_button(key, tone)
	btn.pressed.connect(action)
	box.add_child(btn)
	buttons.append(btn)
	return btn


func is_open() -> bool:
	return visible


## بازشدن: زمان بسته می‌شود، درگ خاموش، ورودی به سطح نمی‌رسد.
func open(controller: LevelController = null) -> void:
	var target: LevelController = controller
	if target == null:
		target = get_parent() as LevelController
	if target != null and target.has_method("set_drag_enabled"):
		target.set_drag_enabled(false)
	GameState.begin_pause()
	if pauses_the_tree:
		_was_paused_by_us = not get_tree().paused
		get_tree().paused = true
	visible = true
	UIKit.apply_flow(self)


func resume() -> void:
	GameState.end_pause()
	if pauses_the_tree and _was_paused_by_us:
		get_tree().paused = false
	_was_paused_by_us = false
	var target: LevelController = get_parent() as LevelController
	if target != null and target.has_method("set_drag_enabled"):
		target.set_drag_enabled(true)
	visible = false
	if settings_panel != null and is_instance_valid(settings_panel):
		settings_panel.close_overlay()
		settings_panel = null
	resumed.emit()


func open_settings() -> void:
	settings_requested.emit()
	if not embed_settings:
		if allow_scene_change:
			var err: Error = get_tree().change_scene_to_file(SETTINGS_SCENE)
			if err != OK:
				Log.warn(TAG, "تنظیمات باز نشد (خطای %d)" % err)
		return
	if settings_panel != null and is_instance_valid(settings_panel):
		settings_panel.visible = true
		return
	var packed: PackedScene = load(SETTINGS_SCENE)
	if packed == null:
		Log.warn(TAG, "صحنهٔ تنظیمات پیدا نشد: " + SETTINGS_SCENE)
		return
	var panel: SettingsMenu = packed.instantiate() as SettingsMenu
	if panel == null:
		return
	panel.name = "SettingsOverlay"
	panel.embedded = true
	add_child(panel)
	panel.closed.connect(_on_settings_closed)
	settings_panel = panel


func _on_settings_closed() -> void:
	if settings_panel != null and is_instance_valid(settings_panel):
		settings_panel.queue_free()
	settings_panel = null


func goto_map() -> void:
	map_requested.emit()
	# خروج از سطح = زمانِ باز؛ اول resume تا شمارنده‌ها درست بسته شوند
	if not allow_scene_change:
		return
	GameState.commit_playtime()
	if not LevelLoader.goto_map():
		Log.warn(TAG, "بازگشت به نقشه نشد: " + LevelLoader.last_error)


func quit_to_menu() -> void:
	menu_requested.emit()
	if not allow_scene_change:
		return
	GameState.commit_playtime()
	if not LevelLoader.goto_main_menu():
		Log.warn(TAG, "بازگشت به منو نشد: " + LevelLoader.last_error)
