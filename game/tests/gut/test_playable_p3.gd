extends GutTest
# ===========================================================================
# تسک ۳.۳ — DoD سند ۰۴: «هر ۵ سطح از ابتدا تا پایان قابل‌حل و قابل‌بازی هستند»
# «پلی‌تست دستی» با ADR-013 به همین تست تبدیل شده: برای هر سطح، solution_spec
# (منبع جواب، ADR-006) خوانده می‌شود و کره‌ها با همان API درگِ فاز ۲ روی کفه
# می‌نشینند؛ اگر سطحی با جوابِ خودش نبرد، یعنی داده یا موتور خراب است.
# ===========================================================================

const PROFILE := "gut_p3_playable"
const LEVEL_SCENE := "res://scenes/gameplay/LevelScene.tscn"

var _scene: LevelController = null


func before_all() -> void:
	SaveSystem.profile_name = PROFILE
	SaveSystem.delete_all()
	GameState.bootstrap()


func after_all() -> void:
	GameState.active_model = null
	SaveSystem.bind_model(null)
	SaveSystem.delete_all()
	SaveSystem.profile_name = SaveSystem.DEFAULT_PROFILE


func before_each() -> void:
	# هر تست صحنه‌ی تازه می‌سازد؛ GameState.begin_level شمارنده‌های سطح را پاک می‌کند،
	# پس اینجا فقط باید صفِ LevelLoader را خلوت کرد (یزده‌ی تست‌های دیگر نماند).
	LevelLoader.clear_pending_config()
	_scene = null
	watch_signals(EventBus)


func _build(id: String) -> LevelController:
	var scene: LevelController = LevelLoader.create_level_scene(id) as LevelController
	assert_not_null(scene, "%s باید ساخته شود (خطا: %s)" % [id, LevelLoader.last_error])
	scene.attempt_settle_sec = 0.05
	add_child_autofree(scene)
	return scene


func _drag(orb: WeightOrb, target: Vector2) -> void:
	if orb == null:
		return
	orb.begin_drag(orb.global_position)
	orb.drag_to(target)
	orb.end_drag(target)


func _take_tray_orb(scene: LevelController, value: float) -> WeightOrb:
	for orb: WeightOrb in scene.tray_orbs:
		if orb != null and not orb.is_placed and is_equal_approx(orb.value, value):
			return orb
	return null


func _solve_from_spec(scene: LevelController, spec: Dictionary) -> void:
	var intended: Array = spec.get("right_orbs", [])
	var pan: BalancePan = scene.scales[0].right_pan
	for entry: Variant in intended:
		var value: float = float(entry)
		var orb := _take_tray_orb(scene, value)
		assert_not_null(orb, "سینی باید یک کره‌ی %.1f برای جوابِ ازپیش‌تعریف‌شده داشته باشد" % value)
		_drag(orb, pan.dish_position())


func test_each_tier1_level_is_playable_to_a_win() -> void:
	var checked: int = 0
	for id: String in LevelLoader.levels_for_tier(1):
		var lv: LevelData = LevelLoader.load_level(id)
		assert_not_null(lv)
		if lv == null:
			continue
		var spec: Dictionary = lv.solution_spec.get("intended", {})
		assert_false(spec.is_empty(), "%s باید solution_spec.intended داشته باشد (ADR-006)" % id)
		_scene = _build(id)
		watch_signals(EventBus)
		assert_eq(_scene.scales[0].left_weight(), lv.left_weight(), "%s: کفه‌ی چپ از داده" % id)
		assert_eq(_scene.scales[0].right_weight(), lv.right_weight(), "%s: ثابت‌های راست از داده" % id)
		assert_false(_scene.is_won(), "%s نباید از قبل برده باشد" % id)
		_solve_from_spec(_scene, spec as Dictionary)
		await get_tree().process_frame
		assert_true(_scene.is_won(), "%s با جواب خودش باید ببرد" % id)
		assert_signal_emitted(EventBus, "level_completed")
		assert_eq(_scene.scales[0].calculate_tilt(), 0.0)
		assert_gt(GameState.elapsed_level_sec(), 0.0)
		assert_true(GameState.active_model.levels_completed.has(id), "%s در مدل ثبت شد" % id)
		checked += 1
		_scene = null
	assert_eq(checked, 5, "پنج سطح فاز ۳")


func test_wrong_move_is_counted_and_the_level_is_still_winnable() -> void:
	_scene = _build("tier1_level_01")
	GameState.level_attempts = 0
	# حرکت غلط: یک ۲ (راست=۲ ≠ ۸) و صبر تا آستانه‌ی تلاش
	_drag(_take_tray_orb(_scene, 2.0), _scene.scales[0].right_pan.dish_position())
	await get_tree().create_timer(0.25).timeout
	assert_eq(GameState.level_attempts, 1, "چیدمان ناپایدارِ ساکن = یک تلاش، نه بیشتر")
	assert_signal_emit_count(EventBus, "attempt_failed", 1)
	assert_false(_scene.is_won())
	# همان سطح با ادامه‌ی چیدمان درست (۲+۵+۱) باید ببرد
	for value: float in [5.0, 1.0]:
		_drag(_take_tray_orb(_scene, value), _scene.scales[0].right_pan.dish_position())
	await get_tree().process_frame
	assert_true(_scene.is_won(), "اشتباه، سطح را قفل/خراب نمی‌کند")
	assert_signal_emit_count(EventBus, "level_completed", 1)


func test_level_scene_is_reconfigured_not_reinstantiated() -> void:
	_scene = _build("tier1_level_01")
	assert_eq(_scene.scales[0].left_weight(), 8.0)
	var lv: LevelData = LevelLoader.load_level("tier1_level_04")
	_scene.configure(lv.to_config_dict())
	assert_eq(_scene.level_id, "tier1_level_04")
	assert_eq(_scene.scales.size(), 1, "بازسازی، نه افزودن ترازوی دوم")
	assert_eq(_scene.scales[0].left_weight(), 11.0, "7 + 4")
	assert_eq(_scene.scales[0].right_weight(), 2.0, "تخته‌ی ۲ واحدیِ از‌قبل‌روی‌کفه (آرک‌تایپ ۲)")
	assert_eq(_scene.tray_orbs.size(), 16)
	assert_false(_scene.is_won(), "بعد از configure باید وضعیت پاک شده باشد")
	_solve_from_spec(_scene, lv.solution_spec.get("intended", {}) as Dictionary)
	await get_tree().process_frame
	assert_true(_scene.is_won())


func test_alternative_solutions_win_too() -> void:
	# GDD §۳: «چندراه‌حل» خودش دارایی آموزشی است؛ موتور باید فقط تعادل را ببیند
	_scene = _build("tier1_level_05")
	var lv: LevelData = LevelLoader.load_level("tier1_level_05")
	var pan: BalancePan = _scene.scales[0].right_pan
	# راه دومِ این سطح: سه تا ۲ و دو تا ۳؟ (داده: ۱×۱۰، ۲×۶، ۵×۴، ۷×۲ → نیاز ۱۲)
	for value: float in [2.0, 2.0, 2.0, 2.0, 2.0, 2.0]:
		_drag(_take_tray_orb(_scene, value), pan.dish_position())
	await get_tree().process_frame
	assert_true(is_equal_approx(pan.total_weight(), lv.right_weight() + lv.required_right_weight()),
		"کفه = ثابتِ راست (۳) + نیاز بازیکن (۱۲)")
	assert_true(_scene.is_won(), "جوابِ متفاوت از solution_spec هم برد است")
