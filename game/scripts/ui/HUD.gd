class_name HUD
extends Control
# ===========================================================================
# HUD — لایه‌ی داخل سطح (تسک ۶.۴): دکمهٔ راهنما، پیشرفت Tier، pause، Aria و جعبه
# ---------------------------------------------------------------------------
# سه قانون این فایل را شکل می‌دهد:
#   ۱) DoD ۶.۴: «دکمهٔ راهنما همان مسیر AriaController را با یک سطح بالاتر trigger
#      می‌کند» ⇒ ما متن نمی‌سازیم و نردبان را دور نمی‌زنیم: `request_help()` صدا زده
#      می‌شود (فاز ۴) و `hint_requested` (فاز ۵) همان مسیر همیشگی است.
#      اگر نردبان نبود (آموزش/فلگ خاموش)، fallback هم همان سیگنال را با اولین
#      `hint_id` سطح می‌فرستد — و در هر دو حالت دقیقاً یک‌بار `register_hint_used()`.
#   ۲) ریشه `mouse_filter = IGNORE` است: یک HUD تمام‌صفحه که درگِ کره را بَقاپد،
#      همان دامی است که فاز ۲ با input ثبت کرد؛ فقط دکمه‌ها ورودی می‌گیرند.
#   ۳) Aria/جعبهٔ گفت‌وگو از فاز ۵ این‌جا سوار می‌شوند (بدهیِ آن فاز): صحنهٔ سطح
#      نباید منتظر HUD بماند تا «شخصیت» به بازی برسد.
# ===========================================================================

const TAG := "HUD"
const SCENE_PATH := "res://scenes/gameplay/HUD.tscn"
const ARIA_SCENE := "res://scenes/characters/Aria.tscn"
const DIALOGUE_SCENE := "res://scenes/ui/DialogueBox.tscn"

## چیدمان دستی چون والدِ HUD یک Node2D است (LevelController) ⇒ anchor معنا ندارد
## (همان دلیلی که `LevelResultBar` هم موقعیت صریح دارد).
const CANVAS := Vector2(1080.0, 1920.0)
const HINT_AT := Vector2(60.0, 40.0)
const HINT_SIZE := Vector2(300.0, 148.0)
const PAUSE_AT := Vector2(876.0, 40.0)
const PAUSE_SIZE := Vector2(148.0, 148.0)
const PROGRESS_AT := Vector2(372.0, 40.0)
const PROGRESS_SIZE := Vector2(336.0, 148.0)
const OBJECTIVE_AT := Vector2(60.0, 430.0)
const OBJECTIVE_SIZE := Vector2(960.0, 188.0)
const ARIA_AT := Vector2(940.0, 1240.0)
const DIALOGUE_SLOT := Rect2(24.0, 1400.0, 1032.0, 260.0)
const PIP_SIZE := Vector2(44.0, 44.0)

signal hint_pressed
signal pause_pressed

@export var controller: LevelController = null
## false = HUD چیزی را به صحنه اضافه نمی‌کند (تست‌ها خودشان صحنه را می‌سازند).
@export var embed_aria: bool = true
@export var build_on_ready: bool = true

var hint_button: Button = null
var pause_button: Button = null
var progress_label: Label = null
var concept_label: Label = null
var pips: Array[ColorRect] = []
var _pip_row: HBoxContainer = null
var _tier_ids: Array[String] = []
var _current_index: int = -1
var aria: AriaController = null
var dialogue_box: DialogueBox = null
var avatar: AriaAvatar = null


func _ready() -> void:
	if controller == null:
		controller = get_parent() as LevelController
	position = Vector2.ZERO
	size = CANVAS
	custom_minimum_size = CANVAS
	# لایه‌ی عبوری: خودِ HUD هیچ لمسی را نمی‌گیرد؛ فرزندانش می‌گیرند.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if build_on_ready:
		_build()
		_build_aria()
	EventBus.level_started.connect(_on_level_started)
	EventBus.level_completed.connect(_on_level_completed)
	refresh_progress()


func _build() -> void:
	# §۸ | آیکونِ ایستا در کنارِ متن (نه به‌جایش): کودکِ کم‌خوان با واژه هم ادامه می‌دهد ✓
	# و جهتِ آیکون از `Loc` می‌آید ⇒ در فارسی سمتِ شروع می‌نشیند ✓✓ (تستِ ۸.۴)
	hint_button = UIKit.make_button("hud.hint", "teal", HINT_SIZE, "hint")
	hint_button.name = "HintButton"
	hint_button.position = HINT_AT
	hint_button.pressed.connect(request_hint)
	add_child(hint_button)

	pause_button = UIKit.make_button("hud.pause", "cloud", PAUSE_SIZE, "pause")
	pause_button.name = "PauseButton"
	pause_button.position = PAUSE_AT
	pause_button.pressed.connect(pause_level)
	add_child(pause_button)

	var panel := UIKit.make_panel(0.72, 12.0)
	panel.name = "ProgressPanel"
	panel.position = PROGRESS_AT
	panel.size = PROGRESS_SIZE
	add_child(panel)
	var row := UIKit.make_vbox(6.0)
	row.name = "Progress"
	panel.add_child(row)
	progress_label = UIKit.make_label("hud.level", UIKit.DIALOG_FONT_PX + 2)
	progress_label.name = "ProgressLabel"
	row.add_child(progress_label)
	var pip_row := HBoxContainer.new()
	pip_row.name = "Pips"
	pip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip_row.add_theme_constant_override("separation", 10)
	row.add_child(pip_row)
	_pip_row = pip_row

	# کارتِ هدف، حلقه‌ی آموزشی را روی خودِ بازی نگه می‌دارد: کودک می‌داند
	# الان چه مفهومی را تمرین می‌کند، نه اینکه فقط «یک معما» جلوی او باشد.
	var objective := UIKit.make_panel(0.74, 22.0)
	objective.name = "ObjectiveCard"
	objective.position = OBJECTIVE_AT
	objective.size = OBJECTIVE_SIZE
	var objective_flow := UIKit.make_vbox(6.0)
	var mission := UIKit.make_label("hud.mission", 24, Palette.AELORIA_GOLD, true)
	mission.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_flow.add_child(mission)
	concept_label = UIKit.make_raw_label(Loc.t("hud.concept"), 31, Palette.CLOUD_WHITE)
	concept_label.name = "ConceptLabel"
	concept_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_flow.add_child(concept_label)
	var loop := UIKit.make_label("hud.learning_loop", 24, Palette.MUTED_TEXT)
	loop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_flow.add_child(loop)
	objective.add_child(objective_flow)
	add_child(objective)


func _build_aria() -> void:
	if not embed_aria:
		return
	aria = AriaController.new()
	aria.name = "Aria"
	add_child(aria)

	var packed: PackedScene = load(ARIA_SCENE)
	if packed != null:
		var node: Node = packed.instantiate()
		avatar = node as AriaAvatar
		if node != null:
			node.name = "AriaAvatar"
			add_child(node)
			if node is Node2D:
				(node as Node2D).position = ARIA_AT
	else:
		Log.warn(TAG, "صحنهٔ Aria بارگذاری نشد — راهنما بی‌آواتار کار می‌کند")

	var box_packed: PackedScene = load(DIALOGUE_SCENE)
	if box_packed == null:
		Log.warn(TAG, "صحنهٔ DialogueBox بارگذاری نشد")
		return
	var slot := Control.new()
	slot.name = "DialogueSlot"
	slot.position = DIALOGUE_SLOT.position
	slot.size = DIALOGUE_SLOT.size
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slot)
	var box: DialogueBox = box_packed.instantiate() as DialogueBox
	if box == null:
		return
	box.name = "DialogueBox"
	box.auto_hide_sec = 8.0
	slot.add_child(box)
	dialogue_box = box


# --------------------------------------------------------------------------
# اکشن‌ها
# --------------------------------------------------------------------------
## DoD ۶.۴: یک پله بالاتر روی همان نردبانی که زمان‌بندی راهنما می‌سازد.
func request_hint() -> void:
	hint_pressed.emit()
	var timing: HintTimingSystem = null
	if controller != null:
		timing = controller.hint_timing
	if timing != null and timing.is_armed():
		# `_fire` خودش `GameState.register_hint_used()` را صدا می‌زند ⇒ یک‌بار
		timing.request_help()
		return
	var id: String = manual_hint_id()
	if id.is_empty():
		Log.debug(TAG, "سطح راهنمای دستی ندارد — فقط حالت Aria عوض می‌شود")
		if aria != null:
			aria.set_state(AriaController.STATE_IDLE)
		return
	GameState.register_hint_used()
	EventBus.hint_requested.emit(id)


## اولین `hint_id`ِ همان سطح؛ fallbackِ واقعی وقتی نردبان خاموش است.
func manual_hint_id() -> String:
	if controller == null or controller.config.is_empty():
		return ""
	var seq: Variant = controller.config.get("hint_sequence", [])
	if seq is Array and not (seq as Array).is_empty():
		var first: Variant = (seq as Array)[0]
		if first is Dictionary:
			return str((first as Dictionary).get("hint_id", ""))
	return ""


## پاز را خودِ PauseMenu انجام می‌دهد (فریزِ واقعی + شمارش زمان، ADR-046)؛ HUD فقط
## درخواست می‌دهد — اگر منطق پاز دو جا باشد، یکی‌شان حتماً فراموش می‌کند.
func pause_level() -> void:
	pause_pressed.emit()
	if controller != null and controller.has_method("open_pause"):
		controller.open_pause()
		return
	if controller != null and controller.has_method("set_drag_enabled"):
		controller.set_drag_enabled(false)
	GameState.begin_pause()
	get_tree().paused = true


## نوار پیشرفتِ «داخل Tier» (§۶.۴): یک پیپ به ازای هر سطحِ همین Tier؛ طلایی = تمام‌شده،
## فیروزه‌ای = همین‌جاییم، کم‌رنگ = قفل/نرفته. (هیچ رقمی روی پیپ نیست: §۷.)
func refresh_progress() -> void:
	if progress_label == null:
		return
	var tier: int = controller.tier if controller != null else GameState.current_tier
	# `Array[String]` برگردانده می‌شود (نه Variant): `_tier_ids` همان‌جا مقدار اولیه‌ی
	# تهی دارد و Tierِ بدون سطح فقط صفر پیپ می‌دهد، نه خطا.
	var ids: Array[String] = LevelLoader.levels_for_tier(tier)
	_tier_ids = ids
	var level_id: String = controller.level_id if controller != null else GameState.current_level_id
	_current_index = _tier_ids.find(level_id)
	var total: int = maxi(_tier_ids.size(), 1)
	progress_label.text = "%s %s" % [Loc.t("hud.level"),
		Loc.digits("%d/%d" % [maxi(_current_index + 1, 1), total])]
	_pips_for()
	_refresh_objective()


func _refresh_objective() -> void:
	if concept_label == null:
		return
	var tags_raw: Variant = controller.config.get("concept_tags", []) if controller != null else []
	if not (tags_raw is Array) or (tags_raw as Array).is_empty():
		concept_label.text = Loc.t("hud.concept")
		return
	var tags: Array = tags_raw as Array
	var names: Array[String] = []
	for tag: Variant in tags.slice(0, 2):
		var translated: String = Loc.t("skill." + str(tag))
		if translated != "skill." + str(tag):
			names.append(translated)
	concept_label.text = " · ".join(names) if not names.is_empty() else Loc.t("hud.concept")


func _pips_for() -> void:
	if _pip_row == null:
		return
	for pip: ColorRect in pips:
		if is_instance_valid(pip):
			pip.queue_free()
	pips.clear()
	var model: PlayerModel = GameState.active_model
	var total: int = clampi(_tier_ids.size(), 0, 24)
	for i: int in range(total):
		var id: String = _tier_ids[i]
		var pip := ColorRect.new()
		pip.name = "Pip_%02d" % (i + 1)
		pip.custom_minimum_size = PIP_SIZE
		pip.size = PIP_SIZE
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var done: bool = model != null and model.is_level_completed(id)
		pip.color = Palette.AELORIA_GOLD if done else (
			Palette.SOFT_TEAL if i == _current_index else Color(Palette.CLOUD_WHITE, 0.25))
		_pip_row.add_child(pip)
		pips.append(pip)


func current_pip_index() -> int:
	return _current_index


func filled_pips() -> int:
	var count: int = 0
	for pip: ColorRect in pips:
		if is_instance_valid(pip) and pip.color == Palette.AELORIA_GOLD:
			count += 1
	return count


func current_pip_color() -> Color:
	if _current_index >= 0 and _current_index < pips.size() and is_instance_valid(pips[_current_index]):
		return pips[_current_index].color
	return Color.TRANSPARENT


func _on_level_started(_level_id: String, _tier: int) -> void:
	refresh_progress()


func _on_level_completed(_level_id: String, _stats: Dictionary) -> void:
	refresh_progress()
	if avatar != null and is_instance_valid(avatar):
		avatar.play_state(AriaAvatar.STATE_CELEBRATING)
