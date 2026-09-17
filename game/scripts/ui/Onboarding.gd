class_name Onboarding
extends Control
# ===========================================================================
# Onboarding — اولین اجرا: ساخت آواتار + یک مرحله‌ی عملیِ ترازو (تسک ۶.۲)
# ---------------------------------------------------------------------------
# سه قانون از سند ۰۴ §۶.۲ که این فایل حفظ می‌کند:
#   ۱) «بدون متن طولانی، فقط عمل» ⇒ هیچ پاراگرافی اینجا نیست؛ در هر گام حداکثر دو
#      برچسب و هر رشته ≤ ۴۰ نویسه (`test_onboarding.gd` می‌سنجد). راهنمایی هم با
#      انیمیشن/حالت Aria نیست: نردبان راهنما در آموزش **خاموش** است.
#   ۲) گام دوم یک `LevelController` واقعی است، نه ماکت — مکانیکِ آموزش‌دیده همان
#      مکانیکِ بازیه، پس هیچ‌وقت دو مسیر واگرا نمی‌شود. `report_progress = false`
#      تضمین می‌کند کشیدنِ کره در آموزش، آمار/رتبه/سطح‌های‌تمام‌شدهٔ کودک را بنویسد ✗
#      (یعنی بعد از آموزش، سطح ۰۱ «حل‌شده» نیست و واقعاً از اول بازی می‌کند).
#   ۳) دکمه‌ی «بریم» تا وقتی ترازو صاف نشده فعال نمی‌شود: یادگیری شرطِ پیشرفت است،
#      نه ردکردنِ یک صفحه.
# ===========================================================================

const TAG := "Onboarding"
const SCENE_PATH := "res://scenes/main/Onboarding.tscn"

const STEP_AVATAR := "avatar"
const STEP_SCALE := "scale"

## سقفِ متن آموزش (§۷ «دیوار متن ممنوع» + §۶.۲ «بدون متن طولانی»).
const MAX_LABEL_LEN := 40
## سقفِ «چند برچسب در یک گام» — آن‌چه §۶.۲ را واقعاً آموزش‌دادنگاه نگه می‌دارد
## `MAX_LABEL_LEN` است (هر رشته یک خطِ کوتاه)، نه حذفِ برچسبِ ردیف‌ها.
## سقفِ شمارنده فقط جلوی لگوبرشدن گام را می‌گیرد؛ قاعدهٔ واقعی §۶.۲ («متن طولانی
## نداریم») با `MAX_LABEL_LEN` سنجیده می‌شود. پنج = عنوان + راهنما + سه کپشنِ ردیفِ
## انتخاب («پوست/مو/رنگ») که کودک باید بداند کدام ردیف چیست؛ اگر روزی گامی ششمین
## برچسب خواست، این عدد باید آگاهانه عوض شود، نه خودش‌به‌خود.
const MAX_LABELS_PER_STEP := 5

signal finished
signal step_changed(step: String)
signal avatar_choice_made(part: String, index: int)

## false = سیگنال بده و صحنه را عوض نکن (تست‌ها ADR-035).
@export var allow_scene_change: bool = true
@export var build_tutorial: bool = true
## گامِ شروع؛ `MainMenu` وقتی آن را عوض می‌کند که کودک قبلاً ردش کرده باشد.
@export var start_step: String = STEP_AVATAR

var current_step: String = STEP_AVATAR
var preview: PlayerAvatarPreview = null
var skin_buttons: Array[Button] = []
var hair_buttons: Array[Button] = []
var color_buttons: Array[Button] = []
var done_button: Button = null
var next_button: Button = null
var skip_button: Button = null
var controller: LevelController = null
var feedback_label: Label = null

var _panels: Dictionary = {}
var _tutorial_holder: Node2D = null
var _won: bool = false


func _ready() -> void:
	if GameState.active_model == null:
		GameState.bootstrap()
	# ریشه باید viewport واقعی را بگیرد؛ minimum-size روی root در Web قاب را
	# به ۱۹۲۰ پیکسل می‌کشاند و گام آواتار را پایینِ صفحه crop می‌کند.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if size.x < 2.0 or size.y < 2.0:
		size = Vector2(1080.0, 1920.0)
	custom_minimum_size = Vector2.ZERO
	_build_background()
	_build_avatar_step()
	if build_tutorial:
		_build_scale_step()
	else:
		_panels[STEP_SCALE] = _empty_step_panel(STEP_SCALE)
	if next_button != null:
		next_button.disabled = true
	if done_button != null:
		done_button.disabled = true
	show_step(start_step if _panels.has(start_step) else STEP_AVATAR)
	UIKit.apply_flow(self)
	get_viewport().size_changed.connect(_fit_steps)
	call_deferred("_fit_steps")


func _fit_steps() -> void:
	var frame: Vector2 = get_viewport_rect().size
	var frame_height: float = maxf(frame.y, 1.0)
	for key: Variant in _panels.keys():
		var panel := _panels[key] as Control
		if panel == null or not panel.visible:
			continue
		var content_height: float = maxf(panel.get_combined_minimum_size().y, 1.0)
		var fit_scale: float = minf(1.0, maxf(frame_height - 48.0, 1.0) / content_height)
		panel.scale = Vector2.ONE * fit_scale
		panel.pivot_offset = Vector2(panel.size.x * 0.5, 0.0)
		var rendered_height: float = content_height * fit_scale
		var top: float = clampf((frame_height - rendered_height) * 0.18, 24.0, 120.0)
		panel.offset_top = top
		panel.offset_bottom = top + content_height


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Palette.DEEP_INDIGO
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.anchor_full(bg)
	add_child(bg)


func _step_box(step: String, title_key: String) -> VBoxContainer:
	var box := UIKit.make_vbox(UIKit.GAP * 0.75)
	box.name = "Step_" + step
	# این panel هم مثل MainMenu باید تمام‌عرض باشد؛ center-top همراه با
	# offsetهای چپ/راستِ صفحه، عرض منفی می‌ساخت و متن/چیپ‌ها را خارج از قاب می‌برد.
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE,
		Control.PRESET_MODE_MINSIZE, 0)
	box.offset_left = UIKit.MARGIN
	box.offset_right = -UIKit.MARGIN
	box.offset_top = 120.0
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	if not title_key.is_empty():
		var title := UIKit.make_label(title_key, UIKit.TITLE_FONT_PX - 8)
		title.name = "Title"
		box.add_child(title)
	add_child(box)
	_panels[step] = box
	return box


# --------------------------------------------------------------------------
# گام ۱ — آواتار (§۴: ۶ تُن پوست، ۸ مدل مو، رنگ مو)
# --------------------------------------------------------------------------
func _build_avatar_step() -> void:
	var box := _step_box(STEP_AVATAR, "onboarding.avatar")

	preview = PlayerAvatarPreview.new()
	preview.name = "Preview"
	preview.apply_config(SettingsStore.avatar())
	preview.unit = 1.15
	var holder := Control.new()
	holder.name = "PreviewHolder"
	holder.custom_minimum_size = Vector2(320.0, 300.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(preview)
	preview.position = Vector2(160.0, 150.0)
	# §۴/۸.۲: هشت مدل مو، هشت ارتفاع ⇒ مقیاس را خودِ آواتار با جعبه تنظیم می‌کند ✗✓
	# (عددِ ثابت ۱٫۱۵ در مدل‌های بلند به ردیفِ سواچ‌ها می‌خورد = گلیچِ DoD ✗)
	preview.fit_box = Vector2(300.0, 280.0)
	box.add_child(holder)

	skin_buttons = _add_swatch_row(box, "SkinRow", "onboarding.skin",
		PlayerAvatarPreview.skin_count(), "skin_tone")
	hair_buttons = _add_swatch_row(box, "HairRow", "onboarding.hair",
		PlayerAvatarPreview.hair_count(), "hair_style")
	color_buttons = _add_swatch_row(box, "ColorRow", "onboarding.hair_color",
		PlayerAvatarPreview.color_count(), "hair_color")

	next_button = UIKit.make_button("onboarding.next", "gold")
	next_button.name = "NextButton"
	next_button.pressed.connect(next_step)
	box.add_child(next_button)

	skip_button = UIKit.make_button("onboarding.skip", "stone")
	skip_button.name = "SkipButton"
	skip_button.pressed.connect(skip_to_end)
	box.add_child(skip_button)


## یک ردیف «چیپِ رنگی»: برچسب متنی ندارد (کودک رنگ را می‌بیند نه اسمش)، ولی
## `tooltip_text` و اندازهٔ لمسی §۷ را دارد.
func _add_swatch_row(box: VBoxContainer, row_name: String, caption_key: String,
		count: int, part: String) -> Array[Button]:
	var caption := UIKit.make_label(caption_key, UIKit.DIALOG_FONT_PX, Palette.MUTED_TEXT)
	caption.name = row_name + "_Caption"
	box.add_child(caption)
	var grid := GridContainer.new()
	grid.name = row_name
	grid.columns = mini(4, maxi(1, count))
	grid.add_theme_constant_override("h_separation", int(UIKit.GAP))
	grid.add_theme_constant_override("v_separation", int(UIKit.GAP))
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(grid)
	var made: Array[Button] = []
	for i: int in range(count):
		var chip := Button.new()
		chip.name = "%s_%02d" % [part, i]
		chip.custom_minimum_size = Vector2(UIKit.MIN_TOUCH_PX, UIKit.MIN_TOUCH_PX)
		chip.focus_mode = Control.FOCUS_NONE
		chip.text = ""
		chip.tooltip_text = "%s %s" % [Loc.t(caption_key), Loc.digits(str(i + 1))]
		chip.add_theme_stylebox_override("normal",
			UIKit.stylebox(_swatch_color(part, i), UIKit.BUTTON_RADIUS))
		chip.add_theme_stylebox_override("pressed",
			UIKit.stylebox(_swatch_color(part, i).darkened(0.15), UIKit.BUTTON_RADIUS))
		chip.add_theme_stylebox_override("hover",
			UIKit.stylebox(_swatch_color(part, i).lightened(0.06), UIKit.BUTTON_RADIUS))
		chip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		chip.pressed.connect(_choose_avatar.bind(part, i))
		grid.add_child(chip)
		made.append(chip)
	return made


static func _swatch_color(part: String, index: int) -> Color:
	match part:
		"skin_tone":
			return PlayerAvatarPreview.skin_color(index)
		"hair_style":
			# مدل مو رنگِ خودش را ندارد: طیف خاکستریِ «شکل» تا فرقشان دیدنی بماند
			return Color(0.30 + 0.08 * float(index % 4), 0.31, 0.38, 1.0)
		_:
			return PlayerAvatarPreview.hair_color_value(index)


func _choose_avatar(part: String, index: int) -> void:
	if preview == null or not preview.set_choice(part, index):
		return
	# بلافاصله ذخیره: کودک «دکمهٔ ذخیره» ندارد و نباید انتخابش با بستن بازی بپرد
	SettingsStore.set_avatar_choice(part, index)
	avatar_choice_made.emit(part, index)


# --------------------------------------------------------------------------
# گام ۲ — ترازوی واقعی، بی‌آمار
# --------------------------------------------------------------------------
func _build_scale_step() -> void:
	var box := _step_box(STEP_SCALE, "onboarding.drag")

	done_button = UIKit.make_button("onboarding.start", "gold")
	done_button.name = "DoneButton"
	done_button.disabled = true
	done_button.pressed.connect(finish)
	box.add_child(done_button)

	# «آفرین! ترازو صاف شد» فقط بعد از موفقیت؛ §۶ «تشویقِ بی‌مورد نه»
	feedback_label = UIKit.make_label("onboarding.balanced", UIKit.DIALOG_FONT_PX + 4,
		Palette.AELORIA_GOLD)
	feedback_label.name = "Feedback"
	feedback_label.visible = false
	box.add_child(feedback_label)

	controller = LevelController.new()
	controller.name = "TutorialScale"
	controller.config = tutorial_config()
	controller.report_progress = false
	controller.hint_timing_enabled = false
	controller.error_classification_enabled = false
	controller.result_bar_enabled = false
	controller.hud_enabled = false
	controller.pause_menu_enabled = false
	var holder := Node2D.new()
	holder.name = "TutorialHolder"
	holder.position = Vector2(0.0, 260.0)
	add_child(holder)
	var scales_root := Node2D.new()
	scales_root.name = "Scales"
	scales_root.position = Vector2(540.0, 700.0)
	holder.add_child(scales_root)
	var tray_root := Node2D.new()
	tray_root.name = "Tray"
	tray_root.position = Vector2(540.0, 1180.0)
	holder.add_child(tray_root)
	controller.scales_root = scales_root
	controller.tray_root = tray_root
	controller.level_won.connect(_on_tutorial_won)
	holder.add_child(controller)
	_tutorial_holder = holder


## یک‌مرحله‌ای (§۶.۲): چپ = ۵، سینی یک کرهٔ ۵ ⇒ یک کشیدن = تعادل. بی‌متن، بی‌راهنما.
static func tutorial_config() -> Dictionary:
	return {
		"level_id": "tier1_level_01",
		"tier": 1,
		"tolerance": 0.0,
		"narrative_intro": "",
		"scales": [{
			"id": "tutorial",
			"left_orbs": [{"type": "number", "value": 5.0}],
			"target_value": 5.0,
			"ghost_orbs": [],
		}],
		"available_orbs": [
			{"type": "number", "value": 5.0, "count": 1},
			{"type": "number", "value": 2.0, "count": 2},
		],
	}


func _empty_step_panel(step: String) -> Control:
	var box := UIKit.make_vbox()
	box.name = "Step_" + step
	return box


func show_step(step: String) -> void:
	if not _panels.has(step):
		Log.warn(TAG, "گام آموزش ناشناخته: " + step)
		return
	current_step = step
	for key: Variant in _panels.keys():
		var panel: Node = _panels[key]
		if is_instance_valid(panel):
			panel.visible = str(key) == step
	# Holder آموزش فرزندِ VBox نیست (جای‌گاهش روی بومِ کامل است)، پس visibility و
	# «قابل‌کلیک‌بودن» کره‌ها را دستی همگام می‌کنیم: بچه نباید از پشت صفحهٔ آواتار
	# ترازو را بکشد — و نباید فکر کند چیزی خراب شده چون «کلیکش کار نکرد».
	if _tutorial_holder != null:
		_tutorial_holder.visible = step == STEP_SCALE
	_set_tutorial_interactive(step == STEP_SCALE)
	if step == STEP_SCALE and not _won and done_button != null:
		done_button.disabled = true
	step_changed.emit(step)
	UIKit.retranslate(self)
	UIKit.apply_flow(self)
	_fit_steps()


## فقط گامِ فعالِ آموزش با کره‌ها کار می‌کند (`input_pickable` روی Area2D کره).
func _set_tutorial_interactive(on: bool) -> void:
	if controller == null or not is_instance_valid(controller):
		return
	for orb: WeightOrb in controller.tray_orbs:
		if is_instance_valid(orb):
			orb.drag_enabled = on


func is_tutorial_interactive() -> bool:
	if controller == null or not is_instance_valid(controller):
		return false
	for orb: WeightOrb in controller.tray_orbs:
		if is_instance_valid(orb) and orb.drag_enabled:
			return true
	return false


func next_step() -> void:
	show_step(STEP_SCALE if current_step == STEP_AVATAR else STEP_AVATAR)


func visible_steps() -> Array[String]:
	var out: Array[String] = []
	for key: Variant in _panels.keys():
		var panel: Node = _panels[key]
		if is_instance_valid(panel) and panel.visible:
			out.append(str(key))
	return out


func is_won() -> bool:
	return _won


func _on_tutorial_won(_stats: Dictionary) -> void:
	_won = true
	if done_button != null:
		done_button.disabled = false
	if feedback_label != null:
		feedback_label.visible = true


## «رد کن» فقط از گام آواتار: گام دوم ۳۰ ثانیه‌ی عمل است و همان جایی است که مکانیک
## یاد گرفته می‌شود؛ ردکردنِ آن یعنی آموزش دیده نشده، پس دکمه‌اش را نداریم.
func skip_to_end() -> void:
	if current_step != STEP_AVATAR:
		return
	finish()


func finish() -> void:
	SettingsStore.set_and_save("onboarding_done", true)
	GameState.is_first_run = false
	finished.emit()
	if not allow_scene_change:
		return
	if not LevelLoader.goto_map():
		Log.warn(TAG, "بعد از آموزش نقشه باز نشد: " + LevelLoader.last_error)


func is_done_recorded() -> bool:
	return bool(SettingsStore.get_value("onboarding_done"))
