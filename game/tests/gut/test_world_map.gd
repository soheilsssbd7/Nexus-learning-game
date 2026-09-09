extends GutTest
# ===========================================================================
# تسک ۳.۴ — DoD: «جریان کامل: منو → انتخاب سطح → بازی → برگشت به نقشه با
# سطح بعدی باز شده». ناوبری صحنه با `LevelLoader.change_scene_on_start=false`
# خاموش است تا درخت GUT دست‌نخورده بماند؛ بقیه‌ی مسیر واقعی تست می‌شود.
# ===========================================================================

const PROFILE := "gut_p3_map"
const MAP_SCENE_PATH := "res://scenes/main/WorldMap.tscn"
const LEVEL_SCENE_PATH := "res://scenes/gameplay/LevelScene.tscn"
const MIN_TOUCH_PX: float = 48.0

var _map: WorldMap = null


func before_all() -> void:
	LevelLoader.change_scene_on_start = false
	SaveSystem.profile_name = PROFILE
	SaveSystem.delete_all()
	GameState.bootstrap()


func after_all() -> void:
	LevelLoader.change_scene_on_start = true
	GameState.active_model = null
	SaveSystem.bind_model(null)
	SaveSystem.delete_all()
	SaveSystem.profile_name = SaveSystem.DEFAULT_PROFILE


func before_each() -> void:
	LevelLoader.clear_pending_config()
	# هر تست از صفر شروع می‌کند (مدل تازه؛ وگرنه قفل‌ها به تست قبلی وابسته می‌شوند)
	var fresh := PlayerModel.new()
	GameState.active_model = fresh
	SaveSystem.bind_model(fresh)
	watch_signals(EventBus)


func _build_map(override: Array[String] = []) -> WorldMap:
	var map: WorldMap = load(MAP_SCENE_PATH).instantiate() as WorldMap
	assert_not_null(map, "WorldMap.tscn باید ریشه‌ی WorldMap باشد")
	map.allow_scene_change = false
	map.level_ids_override = override
	add_child_autofree(map)
	return map


func _drag(orb: WeightOrb, target: Vector2) -> void:
	orb.begin_drag(orb.global_position)
	orb.drag_to(target)
	orb.end_drag(target)


func test_scene_exists_and_builds_one_node_per_level() -> void:
	_map = _build_map()
	assert_eq(_map.level_count(), 5)
	assert_eq(_map.buttons.size(), 5)
	assert_eq(_map.buttons[0].name, "Level_01")
	assert_eq(_map.buttons[0].text, "1")


func test_touch_targets_and_on_screen_bounds() -> void:
	_map = _build_map()
	for btn: Button in _map.buttons:
		assert_true(btn.size.x >= MIN_TOUCH_PX and btn.size.y >= MIN_TOUCH_PX,
			"هدف لمسی باید ≥ %.0fpx باشد (§۲ سند هنری)" % MIN_TOUCH_PX)
		assert_gt(btn.position.x, 0.0)
		assert_lt(btn.position.x + btn.size.x, 1080.0)
		assert_gt(btn.position.y, 0.0)
		assert_lt(btn.position.y + btn.size.y, 1920.0, "نقشه نباید از پایین صفحه بیرون بزند")
	# هیچ دو گره‌ای روی هم نیفتند (کودک ۹ ساله با انگشت اشتباه نکند)
	for i: int in range(_map.buttons.size()):
		for j: int in range(i + 1, _map.buttons.size()):
			assert_false(_map.buttons[i].get_global_rect().intersects(_map.buttons[j].get_global_rect()),
				"دکمه‌های %d و %d روی هم‌اند" % [i + 1, j + 1])


func test_only_the_next_level_is_unlocked() -> void:
	_map = _build_map()
	assert_false(_map.buttons[0].disabled, "اولین سطح همیشه باز است")
	assert_true(_map.buttons[1].disabled)
	assert_true(_map.buttons[4].disabled)
	assert_true(_map.buttons[1].tooltip_text.contains("قفل"))


func test_locks_open_in_order_as_progress_is_recorded() -> void:
	_map = _build_map()
	GameState.active_model.mark_level_completed("tier1_level_01", 20.0, 0)
	_map.refresh_locks()
	assert_false(_map.buttons[1].disabled, "۲ باز شد")
	assert_true(_map.buttons[2].disabled, "۳ هنوز قفل است")
	assert_true(_map.buttons[0].text.contains("✓"), "سطح تمام‌شده علامت می‌گیرد")


func test_completed_level_unlocks_the_next_one_through_eventbus() -> void:
	_map = _build_map()
	assert_true(_map.buttons[1].disabled)
	# برد = اول مدل ثبت می‌شود، بعد `level_completed` منتشر می‌شود؛ نقشه به رویداد
	# وصل است (نه به polling) پس با همان یک سیگنال باز می‌شود.
	GameState.active_model.mark_level_completed("tier1_level_01", 18.0, 0)
	assert_true(_map.buttons[1].disabled, "بدون خبر، نقشه نباید خودش حدس بزند")
	EventBus.level_completed.emit("tier1_level_01", {"attempts": 0})
	await get_tree().process_frame
	assert_false(_map.buttons[1].disabled, "نقشه بدون reload باز می‌شود")


func test_requesting_an_unlocked_level_primes_the_config() -> void:
	_map = _build_map()
	watch_signals(_map)
	_map.request_level(0)
	assert_signal_emitted_with_parameters(_map, "level_requested", ["tier1_level_01"])
	assert_eq(LevelLoader.pending_config.get("level_id"), "tier1_level_01")
	assert_signal_not_emitted(EventBus, "level_completed")


func test_locked_level_cannot_be_requested() -> void:
	_map = _build_map()
	watch_signals(_map)
	_map.request_level(3)
	assert_signal_emitted(_map, "level_blocked")
	assert_eq(LevelLoader.pending_config, {}, "درخواستِ سطحِ قفل نباید config بچیند")


func test_unknown_level_is_reported_not_crashed() -> void:
	_map = _build_map(["tier9_level_99"])
	assert_eq(_map.buttons.size(), 1)
	_map.request_level(0)
	assert_true(LevelLoader.pending_config.is_empty(), "داده‌ی ناموجود = بی‌عمل، نه کرش")


func test_full_flow_map_to_win_to_next_level() -> void:
	_map = _build_map()
	_map.request_level(0)
	# ۱) صحنه‌ی سطح، config را از صف برمی‌دارد (همان کاری که F5/تغییر صحنه می‌کند)
	var scene: LevelController = load(LEVEL_SCENE_PATH).instantiate() as LevelController
	scene.attempt_settle_sec = 0.05
	add_child_autofree(scene)
	assert_eq(scene.level_id, "tier1_level_01")
	assert_not_null(scene.result_bar, "نوار نتیجه در _ready ساخته می‌شود (تسک ۳.۴)")
	assert_false(scene.result_bar.visible, "قبل از برد پنهان است")
	# ۲) بازی با جوابِ خودِ سطح
	var lv: LevelData = LevelLoader.load_level("tier1_level_01")
	for entry: Variant in (lv.solution_spec.get("intended") as Dictionary).get("right_orbs", []):
		var value: float = float(entry)
		var picked: WeightOrb = null
		for orb: WeightOrb in scene.tray_orbs:
			if orb != null and not orb.is_placed and is_equal_approx(orb.value, value):
				picked = orb
				break
		assert_not_null(picked)
		_drag(picked, scene.scales[0].right_pan.dish_position())
	await get_tree().process_frame
	assert_true(scene.is_won())
	assert_true(scene.result_bar.visible, "نوار نتیجه بعد از برد ظاهر می‌شود")
	# ۳) «بعدی» → سطح ۲ در صف است و نقشه قفلش را باز کرده
	scene.result_bar.advance()
	assert_eq(LevelLoader.pending_config.get("level_id"), "tier1_level_02")
	await get_tree().process_frame
	assert_false(_map.buttons[1].disabled, "برگشت به نقشه = سطح بعدی باز")
	# ۴) «نقشه»
	watch_signals(scene.result_bar)
	scene.result_bar.goto_map()
	assert_signal_emitted(scene.result_bar, "map_requested")


func test_last_level_of_the_tier_sends_the_player_to_the_map() -> void:
	var lv: LevelData = LevelLoader.load_level("tier1_level_05")
	var scene: LevelController = load(LEVEL_SCENE_PATH).instantiate() as LevelController
	scene.config = lv.to_config_dict()
	scene.attempt_settle_sec = 0.05
	add_child_autofree(scene)
	await get_tree().process_frame
	assert_eq(LevelLoader.next_of(scene.level_id), "", "پنج‌ام آخرین سطح نوشته‌شده است")
	# تسک ۴.۴: «بعدی» را موتور انتخاب می‌کند، پس برای سنجیدنِ «دیگر چیزی نمانده»
	# باید وضعیت واقعیِ پایانِ Tier را بسازیم (۰۱..۰۵ تمام‌شده)، نه مدلِ خالی.
	for done_id: String in LevelLoader.levels_for_tier(1):
		GameState.active_model.mark_level_completed(done_id, 25.0, 0)
	watch_signals(scene.result_bar)
	scene.result_bar.advance()
	# آخرین سطحِ Tier = بازگشت به نقشه، نه صفحه‌ی سفید
	assert_signal_emitted(scene.result_bar, "map_requested")
