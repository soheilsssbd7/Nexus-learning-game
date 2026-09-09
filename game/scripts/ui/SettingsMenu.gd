class_name SettingsMenu
extends Control
# ===========================================================================
# SettingsMenu — صدا، زبان، لرزش (تسک ۶.۳)
# ---------------------------------------------------------------------------
# سه تصمیم که از §۶.۳ و §۷ سند هنری می‌آید:
#   • اثرِ فوری: اسلایدر صدا همان لحظه به `AudioServer` می‌نشیند (کودک باید بشنود
#     چه اتفاقی افتاده، نه اینکه «ذخیره» بزند)؛ پس هیچ دکمهٔ «اعمال» نداریم.
#   • kill-switch تطبیق اینجا نیست: «پیشرفت خودکار» تصمیم والد است و پشت parent-gate
#     در داشبورد (تسک ۶.۵) قرار می‌گیرد — دکمهٔ کودک‌پسند نباید سختی بازی را عوض کند.
#   • زبان به‌صورت زنده عوض می‌شود و برچسب‌ها بازخوانده می‌شوند: «i18n placeholder»
#     یعنی معماری باید کار کند، نه اینکه فقط دو فایل JSON باشد.
# ===========================================================================

const TAG := "SettingsMenu"
const SCENE_PATH := "res://scenes/ui/SettingsMenu.tscn"
const SLIDER_MIN_STEP := 0.05

signal closed
signal value_changed(key: String, value: Variant)

## embedded = روی صحنهٔ دیگر سوار شده (از PauseMenu): دکمهٔ بستن queue_free نمی‌کند.
@export var embedded: bool = false
## false = فقط سیگنال/مخفی‌کردن (تست‌ها و حالت embedded؛ ADR-035).
@export var allow_scene_change: bool = true
@export var build_on_ready: bool = true
## زبان‌هایی که کاربر می‌تواند انتخاب کند؛ بقیهٔ `Loc` فقط برای مترجم است.
@export var language_buttons: bool = true

var music_slider: HSlider = null
var sfx_slider: HSlider = null
var haptics_toggle: CheckButton = null
var locale_buttons: Array[Button] = []
var labels: Array[Label] = []
var _applying: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if build_on_ready:
		_build()
	refresh()


func _build() -> void:
	# ریشه باید کل بوم را بپوشاند، وگرنه «STOP» روی یک Control صفر×صفر معنی ندارد
	UIKit.anchor_full(self)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(Palette.DEEP_INDIGO, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	UIKit.anchor_full(dim)
	add_child(dim)

	var panel := UIKit.make_panel(0.95, UIKit.MARGIN * 1.5)
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(760.0, 0.0)
	add_child(panel)
	var box := UIKit.make_vbox(UIKit.GAP)
	box.name = "Rows"
	panel.add_child(box)

	_add_label(box, "settings.title", UIKit.TITLE_FONT_PX - 6)

	music_slider = _add_slider(box, "settings.music", "music_volume")
	sfx_slider = _add_slider(box, "settings.sfx", "sfx_volume")

	_add_label(box, "settings.language", UIKit.DIALOG_FONT_PX + 4, Palette.STONE_GREY)
	var lang_row := UIKit.make_vbox(UIKit.GAP * 0.5)
	lang_row.name = "LanguageRow"
	box.add_child(lang_row)
	if language_buttons:
		for code: String in ["fa", "en"]:
			var btn := Button.new()
			btn.name = "Locale_" + code
			btn.set_meta(&"locale_code", code)
			btn.custom_minimum_size = Vector2(420.0, UIKit.MIN_TOUCH_PX)
			btn.custom_minimum_size = Vector2(UIKit.MIN_TOUCH_PX, UIKit.MIN_TOUCH_PX)
			btn.focus_mode = Control.FOCUS_NONE
			btn.pressed.connect(_choose_locale.bind(code))
			lang_row.add_child(btn)
			locale_buttons.append(btn)

	haptics_toggle = CheckButton.new()
	haptics_toggle.name = "Haptics"
	haptics_toggle.text = Loc.t("settings.haptics")
	haptics_toggle.custom_minimum_size = Vector2(360.0, UIKit.MIN_TOUCH_PX)
	haptics_toggle.focus_mode = Control.FOCUS_NONE
	haptics_toggle.toggled.connect(_choose_haptics)
	box.add_child(haptics_toggle)

	_add_label(box, "settings.adaptive_hint", UIKit.DIALOG_FONT_PX, Palette.STONE_GREY)

	var close_button: Button = UIKit.make_button("common.close", "gold")
	close_button.name = "CloseButton"
	close_button.pressed.connect(close)
	box.add_child(close_button)

	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE, 0)
	UIKit.apply_flow(self)


func _add_label(box: VBoxContainer, key: String, px: int,
		color: Color = Palette.CLOUD_WHITE) -> Label:
	var label := UIKit.make_label(key, px, color)
	box.add_child(label)
	labels.append(label)
	return label


func _add_slider(box: VBoxContainer, caption_key: String, setting_key: String) -> HSlider:
	_add_label(box, caption_key, UIKit.DIALOG_FONT_PX + 4)
	var slider := HSlider.new()
	slider.name = "Slider_" + setting_key
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = SLIDER_MIN_STEP
	slider.custom_minimum_size = Vector2(640.0, UIKit.MIN_TOUCH_PX)
	slider.focus_mode = Control.FOCUS_NONE
	slider.tick_count = 0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_choose_volume.bind(setting_key))
	box.add_child(slider)
	return slider


## فقط از دیسک به ویجت‌ها؛ `_applying` حلقهٔ «widget → save → widget» را می‌بندد.
func refresh() -> void:
	_applying = true
	var music: float = float(SettingsStore.get_value("music_volume"))
	var sfx: float = float(SettingsStore.get_value("sfx_volume"))
	if music_slider != null:
		music_slider.value = music
	if sfx_slider != null:
		sfx_slider.value = sfx
	if haptics_toggle != null:
		haptics_toggle.text = Loc.t("settings.haptics")
		haptics_toggle.set_pressed_no_signal(bool(SettingsStore.get_value("haptics_enabled")))
	for btn: Button in locale_buttons:
		var code: String = str(btn.get_meta(&"locale_code", btn.name.trim_prefix("Locale_")))
		btn.text = Loc.label_for(code)
		btn.disabled = code == Loc.locale()
	_applying = false
	UIKit.retranslate(self)
	UIKit.apply_flow(self)


func _choose_volume(value: float, setting_key: String) -> void:
	if _applying:
		return
	SettingsStore.set_and_save(setting_key, value)
	SettingsStore.apply_audio()
	value_changed.emit(setting_key, value)


func _choose_locale(code: String) -> void:
	SettingsStore.set_and_save("locale", code)
	SettingsStore.apply_locale()
	refresh()
	value_changed.emit("locale", code)


func _choose_haptics(on: bool) -> void:
	if _applying:
		return
	SettingsStore.set_and_save("haptics_enabled", on)
	value_changed.emit("haptics_enabled", on)


## «بازگردانی به پیش‌فرض» برای والد/تست؛ کودک این را نمی‌بیند؟ می‌بیند ولی بی‌ضرر است:
## فقط صدا/زبان/لرزش را برمی‌گرداند، نه پیشرفت بازی (تست همان را چک می‌کند).
func restore_defaults() -> void:
	SettingsStore.reset()
	SettingsStore.save_to()
	# apply_at_boot نه: فایل را دوباره نمی‌خوانیم (مسیرش در تست/ویرایشگر فرق می‌کند)؛
	# دقیقاً همان چیزی که ست کردیم را به موتور تحویل می‌دهیم.
	SettingsStore.apply_locale()
	SettingsStore.apply_audio()
	SettingsStore.apply_gameplay_flags()
	refresh()


func close() -> void:
	closed.emit()
	visible = false
	if embedded:
		# سوار بر PauseMenu: فقط مخفی می‌شویم؛ پاز و زمانِ بستهٔ سطح دست‌نخورده می‌مانند
		return
	if allow_scene_change:
		# از منوی اصلی باز شده ⇒ بستن یعنی برگشت به همان‌جا (DoD ۶.۱: ناوبری دوطرفه)
		if not LevelLoader.goto_main_menu():
			Log.warn(TAG, "بازگشت به منو نشد: " + LevelLoader.last_error)


func close_overlay() -> void:
	visible = false
