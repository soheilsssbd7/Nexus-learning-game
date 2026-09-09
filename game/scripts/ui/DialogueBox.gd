class_name DialogueBox
extends Control
# ===========================================================================
# تسک ۵.۵ — DialogueBox: پیام Aria پایین صفحه
# --------------------------------------------------------------------------
# مشخصات Art Bible §۷ که اینجا کد شده‌اند:
#  • فونت گفت‌وگو ≥ ۲۴px (روی موبایل خوانا باشد) — `MIN_FONT_SIZE` زیرِ این نمی‌رود؛
#  • فارسی راست‌به‌چپ: `TEXT_DIRECTION_RTL` + ترازوی FILL (سطح‌بندیِ منطقی، نه هندسی)؛
#  • بدون سرریز: `AUTOWRAP_WORD_SMART` + سقف خط + پد داخل کادر؛
#  • ورود/خروج «ملایم»: فید ۰.۲ ثانیه، بدون هیچ bounce یا صدای بلند.
# جعبه فقط `EventBus.hint_shown` را می‌شنود؛ تصمیم‌گیری با AriaController است (۵.۳).
# ===========================================================================

const TAG := "DialogueBox"

## §۷: حداقل اندازه‌ی متن گفت‌وگو (px)
const MIN_FONT_SIZE := 24
const MAX_LINES := 3
const SIDE_MARGIN := 24.0
const FADE_SEC := 0.2

@export var listen_to_event_bus: bool = true
## بعد از چند ثانیه محو شود (0 = تا وقتی کاربر کاری نکند بماند)
@export var auto_hide_sec: float = 6.0
@export var panel_color: Color = Color(0.10, 0.11, 0.28, 0.82)

var label: Label = null
var panel: PanelContainer = null

var _timer: Timer = null
var _fade: Tween = null


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE,
		Control.PRESET_MODE_MINSIZE, int(SIDE_MARGIN))
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = panel_color
	style.set_corner_radius_all(16)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	label = Label.new()
	label.name = "Text"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.max_lines_visible = MAX_LINES
	# «…» را Label خودش با `clip_text` + سقف خط می‌زند؛ Godot 4 روی Label هیچ enum
	# ellipsis ندارد (این روی TextServer/RichTextLabel است) — پس عمداً چیزی ست نمی‌کنیم.
	label.clip_text = true
	label.add_theme_font_size_override("font_size", MIN_FONT_SIZE)
	label.add_theme_color_override("font_color", Palette.CLOUD_WHITE)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(label)

	_timer = Timer.new()
	_timer.name = "AutoHide"
	_timer.one_shot = true
	_timer.wait_time = maxf(0.0, auto_hide_sec)
	_timer.timeout.connect(hide_soft)
	add_child(_timer)

	modulate.a = 0.0
	visible = false
	if listen_to_event_bus:
		EventBus.hint_shown.connect(_on_hint_shown)


func visible_text() -> String:
	return label.text if label != null else ""


## نمایش یک پیام؛ متن خالی = مخفی‌کردن (جعبه‌ی خالی روی صفحه نگذار).
func show_text(text: String) -> void:
	if label == null:
		return
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		hide_now()
		return
	label.text = trimmed
	visible = true
	_animate_to(1.0)
	if auto_hide_sec > 0.0:
		_timer.wait_time = auto_hide_sec
		_timer.start()


## مخفی‌کردن فوری (حالتِ «متن تهی» و تست): تصمیمِ state باید همان لحظه گرفته شود،
## وگرنه یک کادر نیمه‌شفافِ خالی روی صحنه می‌ماند.
func hide_now() -> void:
	if _timer != null:
		_timer.stop()
	if _fade != null and _fade.is_valid():
		_fade.kill()
	visible = false
	modulate.a = 0.0


## خروج «ملایم» §۷: فید و بعد مخفی‌شدن — همین را تایمر خودکار صدا می‌زند.
func hide_soft() -> void:
	if _timer != null:
		_timer.stop()
	if not visible:
		return
	_animate_to(0.0)


## برای تست/دیباگ: آیا تایمر محوشدنِ خودکار در حال شمارش است؟
func auto_hide_running() -> bool:
	return _timer != null and not _timer.is_stopped()


func is_showing() -> bool:
	return visible and label != null and not label.text.strip_edges().is_empty()


func _animate_to(alpha: float) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", alpha, FADE_SEC)
	if alpha <= 0.0:
		_fade.tween_callback(_set_hidden)


func _set_hidden() -> void:
	visible = false


func _on_hint_shown(_hint_id: String, _level_id: String, text: String) -> void:
	show_text(text)
