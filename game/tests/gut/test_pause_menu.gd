extends GutTest
# ===========================================================================
# تسک ۶.۳ — PauseMenu: «resume دقیقاً از همان‌جا» + زمانی که پاز شده شمرده نمی‌شود
# ---------------------------------------------------------------------------
# ادعاهایی که فقط با هم‌اجرای `LevelController` و پاز سنجیده می‌شوند:
#   الف) درِ پاز روی صحنه باز است ولی **مکانیک خوابیده**: settleِ «تلاش ناموفق» وسط
#      پاز شلیک نمی‌کند و بعد از resume از همان نقطه ادامه می‌دهد.
#   ب) زمان پاز نه به `elapsed_level_sec` (⇒ میانگین زمان حل در مدل) نه به
#      `total_playtime_sec` (⇒ داشبورد والدین) اضافه می‌شود (ADR-046).
#   ج) ورودی بچه به سطح نمی‌رسد: ریشهٔ پاز `STOP` است و کره‌ها `drag_enabled = false`.
# ===========================================================================

const PAUSE_SCENE := "res://scenes/ui/PauseMenu.tscn"


func before_each() -> void:
	LevelLoader.clear_pending_config()
	get_tree().paused = false
	GameState.end_pause()
	GameState.is_paused = false


func after_each() -> void:
	get_tree().paused = false
	GameState.end_pause()
	GameState.is_paused = false


func _level() -> LevelController:
	var scene: LevelController = LevelLoader.create_level_scene("tier1_level_01") as LevelController
	assert_not_null(scene, "صحنهٔ سطح باید ساخته شود (خطا: %s)" % LevelLoader.last_error)
	scene.attempt_settle_sec = 0.06
	add_child_autofree(scene)
	return scene


func _pause(controller: LevelController) -> PauseMenu:
	var packed: PackedScene = load(PAUSE_SCENE)
	assert_not_null(packed, "PauseMenu.tscn باید بارگذاری شود")
	var menu: PauseMenu = packed.instantiate() as PauseMenu
	assert_not_null(menu, "ریشه باید PauseMenu باشد")
	menu.allow_scene_change = false
	if controller != null:
		controller.add_child(menu)
	else:
		add_child_autofree(menu)
	return menu


func test_the_scene_instantiates_and_starts_closed() -> void:
	var menu := _pause(null)
	assert_false(menu.is_open(), "پاز با صحنه باز نمی‌آید")
	assert_eq(menu.buttons.size(), 4, "ادامه/تنظیمات/نقشه/منو (§۶.۳)")
	assert_eq(menu.process_mode, Node.PROCESS_MODE_ALWAYS,
		"با in-tree pause، منو باید زنده بماند وگرنه قفل می‌شود")


func test_open_freezes_the_tree_and_resume_unfreezes_it() -> void:
	var controller := _level()
	var menu := _pause(controller)
	watch_signals(menu)
	menu.open(controller)
	assert_true(get_tree().paused, "pause واقعی، نه فقط منوی روی صحنه")
	assert_true(GameState.is_paused)
	assert_true(menu.is_open())
	menu.resume()
	assert_false(get_tree().paused)
	assert_false(GameState.is_paused)
	assert_signal_emitted(menu, "resumed")


func test_the_level_state_survives_a_pause_and_finishes_after_resume() -> void:
	var controller := _level()
	var wrong: WeightOrb = null
	for orb: WeightOrb in controller.tray_orbs:
		if orb != null and is_equal_approx(orb.value, 2.0):
			wrong = orb
	assert_not_null(wrong, "سینی سطح ۰۱ کرهٔ ۲ دارد")
	GameState.begin_level("tier1_level_01", 1)
	GameState.level_attempts = 0
	# یک حرکتِ غلط، و **بلافاصله** پاز: settle (۰.۰۶s) نباید فرصت شلیک پیدا کند
	controller.place_on_right([wrong])
	assert_false(controller.is_won(), "۲ در کفهٔ راست تعادل نیست")
	var before: Dictionary = controller.pan_snapshot(0)

	var menu := _pause(controller)
	menu.open(controller)
	# settle (0.06s) باید در پاز **شلیک نکند**: `_process` ایستاده است
	await get_tree().create_timer(0.3).timeout
	assert_eq(GameState.level_attempts, 0, "وسط پاز هیچ تلاشی شمرده نمی‌شود")
	assert_eq(controller.pan_snapshot(0), before, "کره سر جایش است — resume از همان‌جا")

	menu.resume()
	await get_tree().create_timer(0.25).timeout
	assert_eq(GameState.level_attempts, 1,
		"بعد از resume، همان تلاشِ نیمه‌کاره تمام می‌شود (نه دوباره‌سازی، نه گم‌شدن)")


func test_orbs_cannot_be_dragged_behind_the_pause_menu() -> void:
	var controller := _level()
	var menu := _pause(controller)
	assert_true(controller.any_orb_draggable())
	menu.open(controller)
	assert_false(controller.any_orb_draggable(),
		"§۶.۳: پاز یعنی ورودی به سطح نمی‌رسد (کره‌ها قفل‌اند)")
	menu.resume()
	assert_true(controller.any_orb_draggable(), "resume همان کره‌ها را آزاد می‌کند")


func test_input_does_not_pass_through_the_pause_overlay() -> void:
	var menu := _pause(null)
	menu.open(null)
	assert_eq(menu.mouse_filter, Control.MOUSE_FILTER_STOP)
	var dim: ColorRect = menu.get_node("Dim") as ColorRect
	assert_not_null(dim)
	if dim != null:
		assert_eq(dim.mouse_filter, Control.MOUSE_FILTER_STOP)
		assert_lt(dim.color.a, 1.0, "صحنهٔ پشت باید دیده شود (بی‌ترس‌کنندگی §۶)")


func test_paused_time_is_not_billed_to_the_level() -> void:
	GameState.begin_level("tier1_level_01", 1)
	await get_tree().create_timer(0.12).timeout
	var running: float = GameState.elapsed_level_sec()
	GameState.begin_pause()
	await get_tree().create_timer(0.4).timeout
	var during_pause: float = GameState.elapsed_level_sec()
	assert_lt(during_pause - running, 0.2,
		"پاز نباید داخل «زمان حل» شمرده شود (avg_time_to_solve_sec در مدل می‌نشیند)")
	assert_gt(GameState.paused_level_sec(), 0.3, "ولی خودش ثبت می‌شود")
	GameState.end_pause()
	assert_false(GameState.is_pause_open())
	await get_tree().create_timer(0.12).timeout
	assert_gt(GameState.elapsed_level_sec(), during_pause, "و بعد از resume ساعت دوباره راه می‌افتد")


func test_paused_time_is_not_billed_to_the_parent_dashboard() -> void:
	var model := PlayerModel.create_new("آزمون")
	var saved: PlayerModel = GameState.active_model
	GameState.active_model = model
	GameState.reset_time_windows_for_tests()
	model.total_playtime_sec = 0.0
	GameState.begin_pause()
	await get_tree().create_timer(0.45).timeout
	GameState.commit_playtime()
	assert_lt(model.total_playtime_sec, 0.2, "داشبورد نباید خوابِ کودک را «زمان بازی» بزند")
	GameState.end_pause()
	await get_tree().create_timer(0.12).timeout
	GameState.commit_playtime()
	assert_gt(model.total_playtime_sec, 0.0, "زمان واقعیِ بازی ثبت می‌شود")
	GameState.active_model = saved


func test_settings_open_over_the_pause_and_keep_time_frozen() -> void:
	var menu := _pause(null)
	watch_signals(menu)
	menu.open(null)
	menu.open_settings()
	assert_signal_emitted(menu, "settings_requested")
	assert_true(menu.get_node_or_null("SettingsOverlay") is SettingsMenu,
		"تنظیمات سوار می‌شود نه reload: «resume از همان‌جا» با یک تغییر صحنه می‌شکست")
	assert_true(get_tree().paused, "پاز باید پشت تنظیمات هم بماند")
	assert_true(GameState.is_pause_open())
	menu.resume()
	assert_false(get_tree().paused)
	assert_false(GameState.is_paused)


func test_navigation_buttons_signal_and_do_not_break_the_tree() -> void:
	var menu := _pause(null)
	watch_signals(menu)
	menu.goto_map()
	menu.quit_to_menu()
	assert_signal_emitted(menu, "map_requested")
	assert_signal_emitted(menu, "menu_requested")
	assert_false(get_tree().root.is_queued_for_deletion())
	assert_true(UIKit.audit_touch_targets(menu).is_empty(),
		str(UIKit.audit_touch_targets(menu)))
