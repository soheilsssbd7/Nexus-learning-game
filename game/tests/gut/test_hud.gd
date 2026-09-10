extends GutTest
# ===========================================================================
# تسک ۶.۴ — HUD: دکمهٔ راهنما همان نردبان است، نه مسیر دوم
# ---------------------------------------------------------------------------
# DoD: «دکمهٔ راهنما، همان مسیر AriaController را با یک سطح راهنمایی بالاتر trigger
# می‌کند». یعنی باید ثابت کنیم:
#   الف) یک پله از نردبانِ `HintTimingSystem` بالا می‌رود (پرس دوم ≠ پرس اول)؛
#   ب) متن از AriaController و قالب‌های واقعی می‌آید و در جعبه می‌نشیند (زنجیرهٔ فاز ۵)؛
#   ج) «راهنمای دستی» هم شمرده می‌شود (یک‌بار، نه دو بار) وگرنه `hint_usage_rate`
#      دروغ می‌گوید؛
#   د) HUD هرگز جلوی درگ را نمی‌گیرد (ریشه IGNORE) و §۷ را روی صحنه نقض نمی‌کند.
# ===========================================================================

const HUD_SCENE := "res://scenes/gameplay/HUD.tscn"


func before_each() -> void:
	LevelLoader.clear_pending_config()
	get_tree().paused = false
	GameState.end_pause()
	GameState.is_paused = false
	DifficultyEngine.reset_state()


func after_each() -> void:
	get_tree().paused = false
	GameState.end_pause()
	GameState.is_paused = false


func _level(hud_on: bool = true) -> LevelController:
	var scene: LevelController = LevelLoader.create_level_scene("tier1_level_01") as LevelController
	assert_not_null(scene, "سطح ۰۱ باید ساخته شود (%s)" % LevelLoader.last_error)
	scene.hud_enabled = hud_on
	scene.attempt_settle_sec = 0.05
	add_child_autofree(scene)
	return scene


func test_the_level_scene_gains_a_hud_and_a_pause_menu() -> void:
	var scene := _level()
	assert_not_null(scene.hud, "§۶.۴: HUD فرزندِ صحنهٔ سطح است")
	assert_not_null(scene.pause_menu, "§۶.۳+۶.۴: پاز از همان صحنه باز می‌شود")
	if scene.hud == null:
		return
	assert_eq(scene.hud.controller, scene, "HUD موتور سطح را می‌شناسد، نه اینکه حدس بزند")
	assert_eq(scene.hud.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"ریشهٔ HUD نباید درگ کره را قاپد (درسِ input فاز ۲)")
	var off_scene := _level(false)
	assert_null(off_scene.hud, "آموزش/صحنه‌های دیباگ HUD نمی‌خواهند")


func test_the_aria_and_dialogue_from_phase_5_are_live_in_the_level() -> void:
	var scene := _level()
	var hud: HUD = scene.hud
	assert_not_null(hud.aria, "AriaController داخل صحنهٔ سطح زنده است (بدهی فاز ۵)")
	assert_not_null(hud.dialogue_box, "جعبهٔ گفت‌وگو سوار شده")
	assert_not_null(hud.avatar, "آواتاک Aria در HUD است")
	if hud.dialogue_box == null:
		return
	assert_false(hud.dialogue_box.visible, "بدون راهنما، کادر خالی روی صحنه نباشد")
	assert_true(hud.dialogue_box.listen_to_event_bus, "جعبه به EventBus وصل است، نه به HUD")


func test_hint_button_walks_the_ladder_one_rung_per_press() -> void:
	var scene := _level()
	var hud: HUD = scene.hud
	assert_not_null(hud)
	if hud == null:
		return
	GameState.level_attempts = 0
	GameState.hints_used_this_level = 0
	watch_signals(EventBus)
	hud.hint_button.pressed.emit()
	# پرس اول = اولین پلهٔ نردبانِ همین سطح.  دامِ GUT ۹: پارامتر چهارمِ این assert
	# «شمارهٔ فراخوانی» است نه پیام؛ متن آنجا = `String == int` داخل خودِ GUT ✗✗
	# (و GUT هر خطای موتور را شکست می‌داند) ⇒ پیام را اینجا کامنت می‌کنیم.
	assert_signal_emitted_with_parameters(EventBus, "hint_requested", ["gentle_nudge_01"])
	assert_eq(GameState.hints_used_this_level, 1,
		"راهنمای دستی هم شمرده می‌شود، وگرنه نرخ راهنمای والدین دروغ می‌گوید")
	hud.hint_button.pressed.emit()
	# پرس دوم باید یک پله بالاتر باشد، نه تکرارِ همان متن
	assert_signal_emitted_with_parameters(EventBus, "hint_requested", ["socratic_operation_01"])
	assert_eq(GameState.hints_used_this_level, 2)
	assert_eq(scene.hint_timing.fired_count(), 2)


func test_the_hint_text_travels_through_the_phase_5_chain() -> void:
	var scene := _level()
	var hud: HUD = scene.hud
	if hud == null or hud.dialogue_box == null:
		return
	await get_tree().process_frame
	hud.hint_button.pressed.emit()
	await get_tree().process_frame
	var shown: String = hud.dialogue_box.visible_text()
	assert_false(shown.is_empty(), "متن راهنما باید در جعبه نشسته باشد")
	var tpl: DialogueTemplate = hud.aria.by_id.get("gentle_nudge_01", null)
	assert_not_null(tpl)
	if tpl == null:
		return
	assert_true(tpl.text_variants.has(shown),
		"متنِ HUD باید عیناً یکی از واریانت‌های فایل باشد: " + shown)
	assert_eq(hud.avatar.current_state, "hint_light",
		"§۳: راهنمای سطح ۱ = حالت hint_light، نه فلش و نه صدای بلند")


func test_the_fallback_path_is_used_when_no_ladder_exists() -> void:
	var scene: LevelController = LevelLoader.create_level_scene("tier1_level_01") as LevelController
	scene.hint_timing_enabled = false
	scene.pause_menu_enabled = false
	add_child_autofree(scene)
	var hud: HUD = scene.hud
	assert_not_null(hud)
	if hud == null:
		return
	assert_eq(hud.manual_hint_id(), "gentle_nudge_01",
		"fallback از همان `hint_sequence` سطح می‌خواند")
	GameState.hints_used_this_level = 0
	watch_signals(EventBus)
	hud.hint_button.pressed.emit()
	assert_signal_emitted_with_parameters(EventBus, "hint_requested", ["gentle_nudge_01"])
	assert_eq(GameState.hints_used_this_level, 1, "در fallback هم باید یک‌بار شمرده شود")


func test_a_level_without_hints_does_no_harm() -> void:
	var scene := _level()
	var hud: HUD = scene.hud
	if hud == null:
		return
	# نردبان را برمی‌داریم تا مسیر **fallback** سنجیده شود؛ اگر نردبان بماند،
	# `request_help()` از داده‌ی اصلیِ ساخته‌شده در `build()` شلیک می‌کند و تست
	# دارد رفتارِ درستِ نردبان را به‌عنوان «نباید» حساب می‌کند.
	scene.hint_timing = null
	hud.controller.hint_timing = null
	scene.config = {"level_id": "tier1_level_09", "tier": 1, "scales": []}
	hud.refresh_progress()
	GameState.hints_used_this_level = 0
	watch_signals(EventBus)
	hud.request_hint()
	assert_signal_not_emitted(EventBus, "hint_requested")
	assert_eq(GameState.hints_used_this_level, 0,
		"راهنمای نبود ⇒ شمارنده هم نباید جلو برود (تستِ بی‌crash برای محتوای فاز ۷)")


func test_progress_pips_follow_the_tier_and_the_model() -> void:
	var model := PlayerModel.create_new("آزمون")
	var saved: PlayerModel = GameState.active_model
	GameState.active_model = model
	var scene := _level()
	var hud: HUD = scene.hud
	if hud == null:
		GameState.active_model = saved
		return
	var tier_ids: Array[String] = LevelLoader.levels_for_tier(1)
	assert_eq(hud.pips.size(), tier_ids.size(), "یک پیپ به ازای هر سطحِ همین Tier")
	assert_eq(hud.current_pip_index(), 0)
	assert_eq(hud.filled_pips(), 0, "هیچ سطوحی تمام نشده ⇒ هیچ پیپ طلایی نیست")
	assert_eq(hud.current_pip_color(), Palette.SOFT_TEAL, "پیپِ «همین‌جا» فیروزه‌ای است")
	model.mark_level_completed("tier1_level_01", 30.0, 0)
	hud.refresh_progress()
	assert_eq(hud.filled_pips(), 1)
	assert_true(hud.progress_label.text.contains(Loc.digits("1")),
		"شماره‌ها فارسی‌اند: " + hud.progress_label.text)
	GameState.active_model = saved


func test_the_pause_button_opens_the_real_pause_of_the_level() -> void:
	var scene := _level()
	var hud: HUD = scene.hud
	if hud == null:
		return
	assert_true(scene.any_orb_draggable())
	hud.pause_button.pressed.emit()
	assert_true(get_tree().paused, "پاز از HUD باید همان پاز واقعی صحنه باشد")
	assert_true(GameState.is_paused)
	assert_false(scene.any_orb_draggable(), "پاز = درگ خاموش")
	assert_true(scene.pause_menu.is_open())
	scene.pause_menu.resume()
	assert_false(get_tree().paused)
	assert_true(scene.any_orb_draggable())


func test_the_hud_scene_file_instantiates_and_stays_inside_the_canvas() -> void:
	var packed: PackedScene = load(HUD_SCENE)
	assert_not_null(packed)
	if packed == null:
		return
	var node: Node = packed.instantiate()
	add_child_autofree(node)
	assert_true(node is HUD, "صحنهٔ HUD باید همان کلاس باشد")
	assert_true(UIKit.audit_touch_targets(node).is_empty(),
		str(UIKit.audit_touch_targets(node)))
	var hud := node as HUD
	hud.refresh_progress()
	var slot: Control = hud.get_node_or_null("DialogueSlot") as Control
	assert_not_null(slot, "جعبهٔ گفت‌وگو جای مشخصی دارد (نه روی سینی/نوار نتیجه)")
	if slot != null:
		assert_gt(slot.position.y, 1200.0, "زیرِ ناحیهٔ ترازو، بالای نوار نتیجه")
		assert_lt(slot.position.y + slot.size.y, 1920.0)
