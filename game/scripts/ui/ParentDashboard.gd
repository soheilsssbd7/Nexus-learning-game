class_name ParentDashboard
extends Control
# ===========================================================================
# ParentDashboard — آنچه والد می‌بیند = دقیقاً همان چیزی که در مدل است (تسک ۶.۵)
# ---------------------------------------------------------------------------
# چهار اصل که این فایل را از «یک صفحهٔ آمار» جدا می‌کند:
#   ۱) قفل همین‌جاست، نه در منو: `gate_enabled` داخل خود صحنه باز می‌شود، پس ساختن
#      یک صحنهٔ دیگر که این را فراخوانی می‌کند هم قفل را رد نمی‌کند (به همان دلیل
#      MainMenu فقط مسیر می‌فرستد). تنها راه دیدن محتوا: `passed` از ParentGate.
#   ۲) هیچ عددی اینجا محاسبه نمی‌شود: زمان، نرخ راهنما، میانهٔ زمان حل، رتبه‌ی
#      مهارت‌ها و الگوهای خطا همه از `PlayerModel` خوانده و فقط **قالب** می‌شوند
#      (DoD ۶.۵: «داده‌ها دقیقاً با مقادیر واقعی PlayerModel می‌خورند»).
#   ۳) `aria_transcript_log` کامل و قابل‌اسکرول است — §۲ سند داده‌ها آن را «مبنای
#      شفافیت» می‌داند، پس خلاصه/برش نمی‌خورند.
#   ۴) کنترل‌های والد (kill-switch تطبیق، خروجی JSON) همین‌جاین و در منوی کودک نه.
# ===========================================================================

const TAG := "ParentDashboard"
const SCENE_PATH := "res://scenes/ui/ParentDashboard.tscn"
const CANVAS := Vector2(1080.0, 1920.0)
const ROW_FONT := 26

signal content_revealed
signal export_requested
signal left

@export var gate_enabled: bool = true
## false = ناوبری را به بیرون واگذار کن (تست‌ها و HUD؛ ADR-035).
@export var allow_scene_change: bool = true
## محتوای تازه بعد از هر سطح/ذخیره (برای وقتی داشبورد وسط اجرا باز می‌ماند).
@export var auto_refresh: bool = true
## فقط برای دیباگ/تست: بدون قفل. پیش‌فرض در بازی **true** است.
@export var reveal_without_gate_for_debug: bool = false
## فقط برای تست/دیباگ: سؤال قفل با seed قطعی می‌شود (پیش‌فرض = تصادفی).
@export var gate_seed: int = -1

var gate: ParentGate = null
var content: VBoxContainer = null
var chart: MasteryChart = null
var stats: Dictionary = {}
var error_box: VBoxContainer = null
var transcript_box: VBoxContainer = null
var adaptive_toggle: CheckButton = null
var adaptive_status: Label = null
var export_button: Button = null
var export_label: Label = null
var empty_label: Label = null

var _revealed: bool = false


func _ready() -> void:
	position = Vector2.ZERO
	size = CANVAS
	custom_minimum_size = CANVAS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	if gate_enabled and not reveal_without_gate_for_debug:
		gate.visible = true
		content.visible = false
	else:
		_unlock()
	if auto_refresh:
		EventBus.level_completed.connect(_on_needs_refresh)
		EventBus.save_requested.connect(_on_needs_refresh)


func _build() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Palette.DEEP_INDIGO
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.anchor_full(bg)
	add_child(bg)

	content = VBoxContainer.new()
	content.name = "Content"
	content.position = Vector2(UIKit.MARGIN, UIKit.MARGIN)
	content.size = Vector2(CANVAS.x - UIKit.MARGIN * 2.0, CANVAS.y - UIKit.MARGIN * 2.0)
	content.custom_minimum_size = content.size
	content.add_theme_constant_override("separation", int(UIKit.GAP))
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)

	var box := UIKit.make_vbox(UIKit.GAP)
	box.name = "Rows"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	box.add_child(UIKit.make_label("dashboard.title", UIKit.TITLE_FONT_PX - 6))
	empty_label = UIKit.make_label("dashboard.no_data", UIKit.DIALOG_FONT_PX + 2,
		Palette.STONE_GREY)
	empty_label.name = "EmptyNote"
	empty_label.visible = false
	box.add_child(empty_label)

	chart = MasteryChart.new()
	chart.name = "MasteryChart"
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(chart)

	box.add_child(_section("dashboard.levels", "levels"))
	box.add_child(_section("dashboard.time", "time"))
	box.add_child(_section("dashboard.hint_rate", "hint_rate"))
	box.add_child(_section("dashboard.avg_time", "avg_time"))
	box.add_child(_section("dashboard.transcript", "transcript_count"))

	box.add_child(_caption("dashboard.errors"))
	error_box = UIKit.make_vbox(8.0)
	error_box.name = "ErrorRows"
	box.add_child(error_box)

	box.add_child(_caption("dashboard.transcript"))
	transcript_box = UIKit.make_vbox(8.0)
	transcript_box.name = "TranscriptRows"
	box.add_child(transcript_box)

	# --- کنترل‌های والد ---
	adaptive_toggle = CheckButton.new()
	adaptive_toggle.name = "AdaptiveToggle"
	adaptive_toggle.text = Loc.t("settings.adaptive")
	adaptive_toggle.custom_minimum_size = Vector2(560.0, UIKit.MIN_TOUCH_PX)
	adaptive_toggle.focus_mode = Control.FOCUS_NONE
	adaptive_toggle.toggled.connect(_on_adaptive_toggled)
	box.add_child(adaptive_toggle)
	adaptive_status = UIKit.make_label("dashboard.adaptive_on", UIKit.DIALOG_FONT_PX,
		Palette.SOFT_TEAL)
	adaptive_status.name = "AdaptiveStatus"
	box.add_child(adaptive_status)
	box.add_child(_caption("settings.adaptive_hint"))

	var row := UIKit.make_vbox(UIKit.GAP * 0.5)
	row.name = "ParentActions"
	box.add_child(row)
	export_button = UIKit.make_button("dashboard.export", "cloud")
	export_button.name = "ExportButton"
	export_button.pressed.connect(export_for_review)
	row.add_child(export_button)
	export_label = UIKit.make_label("common.ok", UIKit.DIALOG_FONT_PX, Palette.STONE_GREY)
	export_label.name = "ExportNote"
	export_label.visible = false
	row.add_child(export_label)

	var back: Button = UIKit.make_button("common.back", "stone")
	back.name = "BackButton"
	back.pressed.connect(leave)
	row.add_child(back)

	gate = ParentGate.new()
	gate.name = "Gate"
	gate.question_seed = gate_seed
	gate.passed.connect(_on_gate_passed)
	gate.rejected.connect(_on_gate_rejected)
	gate.left.connect(leave)
	add_child(gate)
	UIKit.apply_flow(self)


func _caption(key: String) -> Label:
	return UIKit.make_label(key, UIKit.DIALOG_FONT_PX + 2, Palette.STONE_GREY)


## یک ردیف «برچسب: مقدار» — مقدار را `refresh()` از مدل پر می‌کند.
func _section(caption_key: String, stat_key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Stat_" + stat_key
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_caption(caption_key))
	var value := Label.new()
	value.name = "Value"
	value.text = "—"
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.text_direction = Loc.text_direction()
	value.horizontal_alignment = Loc.alignment()
	value.add_theme_font_size_override("font_size", UIKit.DIALOG_FONT_PX + 2)
	value.add_theme_color_override("font_color", Palette.CLOUD_WHITE)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value)
	stats[stat_key] = value
	return row


func _on_gate_passed() -> void:
	_unlock()


func _on_gate_rejected() -> void:
	leave()


func _unlock() -> void:
	_revealed = true
	if gate != null:
		gate.visible = false
	content.visible = true
	refresh()
	content_revealed.emit()


func is_revealed() -> bool:
	return _revealed


func set_stat(key: String, text_value: String) -> void:
	var label: Label = stats.get(key, null) as Label
	if label != null:
		label.text = text_value


func stat_text(key: String) -> String:
	var label: Label = stats.get(key, null) as Label
	return label.text if label != null else ""


## تنها منبع داده‌ها: `GameState.active_model`. هیچ میانگین/رتبه‌ای اینجا ساخته نمی‌شود.
func refresh() -> void:
	var model: PlayerModel = GameState.active_model
	if chart != null:
		chart.refresh(model)
	if model == null:
		empty_label.visible = true
		for key: String in stats.keys():
			set_stat(key, "—")
		return
	empty_label.visible = false
	set_stat("levels", Loc.digits(str(model.levels_completed.size())))
	set_stat("time", Loc.duration_sec(model.total_playtime_sec))
	set_stat("hint_rate", Loc.percent(model.hint_usage_rate))
	set_stat("avg_time", "%s %s" % [Loc.digits("%.1f" % model.avg_time_to_solve_sec),
		Loc.t("dashboard.sec")])
	set_stat("transcript_count", Loc.digits(str(model.aria_transcript_log.size())))
	_refresh_errors(model)
	_refresh_transcript(model)
	_refresh_adaptive()
	UIKit.retranslate(self)
	UIKit.apply_flow(self)


func _clear(box: VBoxContainer) -> void:
	# `remove_child` بعد از `queue_free` یعنی شماره‌ی ردیف‌ها در همان فریم درست است
	# (وگرنه `transcript_row_count()` ردیف‌های مرده را هم می‌شمرد و تست گول می‌خورد).
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _data_row(row_name: String, text_value: String, color: Color) -> Label:
	var label: Label = UIKit.make_raw_label(text_value, ROW_FONT, color)
	label.name = row_name
	return label


func _refresh_errors(model: PlayerModel) -> void:
	_clear(error_box)
	var entries: Array = model.error_patterns.duplicate()
	entries.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.get("count", 0)) > int(y.get("count", 0)))
	if entries.is_empty():
		error_box.add_child(_data_row("ErrorEmpty", Loc.t("dashboard.no_data"),
			Palette.STONE_GREY))
		return
	for entry: Variant in entries:
		var d: Dictionary = entry as Dictionary
		var row_text := "%s — %s" % [Loc.t("error." + str(d.get("type", ""))),
			Loc.digits(str(int(d.get("count", 0))))]
		error_box.add_child(_data_row("Error_%s" % str(d.get("type", "")), row_text,
			Palette.CLOUD_WHITE))


func _refresh_transcript(model: PlayerModel) -> void:
	_clear(transcript_box)
	if model.aria_transcript_log.is_empty():
		transcript_box.add_child(_data_row("TranscriptEmpty",
			Loc.t("dashboard.no_data"), Palette.STONE_GREY))
		return
	# §۲ سند داده‌ها: «کامل و بدون حذف» ⇒ هیچ slice[-N:] نمی‌زنیم؛ فقط یک ScrollContainer.
	for entry: Variant in model.aria_transcript_log:
		var d: Dictionary = entry as Dictionary
		var ts: String = str(d.get("timestamp", ""))
		var clock: String = ts.substr(11, 5) if ts.length() >= 16 else ts
		var line := "%s · %s · %s" % [Loc.digits(clock), str(d.get("hint_id", "?")),
			str(d.get("level_id", "—"))]
		var text_value: String = str(d.get("text", ""))
		if not text_value.is_empty():
			line += "\n" + text_value
		transcript_box.add_child(_data_row("Transcript_%03d" % transcript_row_count(),
			line, Palette.CLOUD_WHITE))


func transcript_row_count() -> int:
	return transcript_box.get_child_count()


func error_row_count() -> int:
	return error_box.get_child_count()


func _refresh_adaptive() -> void:
	if adaptive_toggle == null:
		return
	var on: bool = bool(DifficultyEngine.adaptive_selection)
	adaptive_toggle.set_pressed_no_signal(on)
	if adaptive_status != null:
		adaptive_status.text = Loc.t("dashboard.adaptive_on" if on
			else "dashboard.adaptive_off")


## kill-switch فاز ۴: نوشته می‌شود **و** فوراً به موتور داده می‌شود (ADR-045).
func _on_adaptive_toggled(on: bool) -> void:
	SettingsStore.set_and_save("adaptive_selection", on)
	SettingsStore.apply_gameplay_flags()
	_refresh_adaptive()


## خروجی برای بازبینی: فقط کلیپ‌بوردِ دستگاه — هیچ شبکه‌ای، هیچ فایلی بیرون از
## `user://` (§۵ سند ۰۰: آفلاین؛ ADR-010: بدون PII).
func export_for_review() -> void:
	export_requested.emit()
	var json_text: String = SaveSystem.export_json_for_parent()
	DisplayServer.clipboard_set(json_text)
	if export_label != null:
		export_label.text = Loc.t("dashboard.exported")
		export_label.visible = true
	Log.info(TAG, "خروجی بازبینی آماده شد (%d نویسه)" % json_text.length())


func _on_needs_refresh() -> void:
	if _revealed:
		refresh()


func leave() -> void:
	left.emit()
	if not allow_scene_change:
		return
	if not LevelLoader.goto_main_menu():
		Log.warn(TAG, "بازگشت به منو نشد: " + LevelLoader.last_error)
