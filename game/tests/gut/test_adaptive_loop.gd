extends GutTest
# ===========================================================================
# تسک ۴.۲ تا ۴.۴ — حلقه‌ی زنده: اشتباه → طبقه‌بندی → راهنما → رتبه → سطح بعدی
# --------------------------------------------------------------------------
# تست‌های فاز ۴ هر کدام یک تکه را تنها می‌سنجند؛ این فایل همان‌ها را روی **یک صحنه‌ی
# واقعی** به هم وصل می‌کند (اتصال، جایی که باگ‌های فاز ۳ زندگی می‌کردند).
# ===========================================================================

const PROFILE := "gut_p4_loop"
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
	LevelLoader.clear_pending_config()
	LevelLoader.change_scene_on_start = false
	DifficultyEngine.reset_state()
	GameState.active_model = PlayerModel.create_new("حلقه")
	SaveSystem.bind_model(GameState.active_model)
	GameState.begin_level("tier1_level_01", 1)
	watch_signals(EventBus)
	_scene = null


func after_each() -> void:
	GameState.end_level()
	DifficultyEngine.reset_state()


func _build(id: String) -> LevelController:
	var scene: LevelController = LevelLoader.create_level_scene(id) as LevelController
	assert_not_null(scene, "%s باید ساخته شود (خطا: %s)" % [id, LevelLoader.last_error])
	if scene == null:
		return null
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


func _solve(scene: LevelController) -> void:
	var lv: LevelData = LevelLoader.load_level(scene.level_id)
	var spec: Dictionary = lv.solution_spec if lv != null else {}
	var intended: Array = (spec.get("intended", {}) as Dictionary).get("right_orbs", [])
	var pan: BalancePan = scene.scales[0].right_pan
	for entry: Variant in intended:
		_drag(_take_tray_orb(scene, float(entry)), pan.dish_position())


# --------------------------------------------------------------------------
func test_a_wrong_layout_is_classified_and_counted_in_the_model() -> void:
	_scene = _build("tier1_level_01")
	if _scene == null:
		return
	var model: PlayerModel = GameState.active_model
	# یک ۱۰ روی راست (نیاز ۸ است): جهت درست، مقدار نه → computation_error
	_drag(_take_tray_orb(_scene, 10.0), _scene.scales[0].right_pan.dish_position())
	await get_tree().create_timer(0.3).timeout
	assert_signal_emit_count(EventBus, "error_detected", 1)
	var args: Variant = get_signal_parameters(EventBus, "error_detected", 0)
	assert_true(args is Array, "payload باید آرایه‌ی پارامتر باشد")
	if args is Array:
		assert_eq(str((args as Array)[0]), ErrorClassifier.COMPUTATION_ERROR)
	assert_eq(model.count_error_pattern(ErrorClassifier.COMPUTATION_ERROR), 1,
		"§۲: `error_patterns` مبنای داشبورد والدین است، پس باید از همین‌جا پر شود")
	assert_eq(GameState.level_attempts, 1)


func test_classification_can_be_switched_off() -> void:
	_scene = _build("tier1_level_01")
	if _scene == null:
		return
	_scene.error_classification_enabled = false
	_drag(_take_tray_orb(_scene, 10.0), _scene.scales[0].right_pan.dish_position())
	await get_tree().create_timer(0.3).timeout
	assert_signal_emit_count(EventBus, "error_detected", 0)
	assert_eq(GameState.level_attempts, 1, "شمارش تلاش مستقل از طبقه‌بندی است")


func test_hint_ladder_is_part_of_the_scene_and_uses_the_authored_trigger() -> void:
	_scene = _build("tier1_level_01")
	if _scene == null:
		return
	assert_not_null(_scene.hint_timing, "تسک ۴.۳: صحنه باید تایمر راهنما داشته باشد")
	if _scene.hint_timing == null:
		return
	_scene.hint_timing.auto_idle_timer = false  # زمان را دستی جلو می‌بریم
	_scene.hint_timing.tick(44.0)
	assert_signal_emit_count(EventBus, "hint_requested", 0, "زودتر از ۴۵ ثانیه (§۴.۳) نه")
	_scene.hint_timing.tick(1.5)
	assert_signal_emitted_with_parameters(EventBus, "hint_requested", ["gentle_nudge_01"])
	assert_eq(GameState.hints_used_this_level, 1,
		"راهنما باید در شمارنده بنشیند تا `success_score` آن را ببیند")


func test_win_payload_carries_the_weighted_score_and_the_real_elo_delta() -> void:
	_scene = _build("tier1_level_01")
	if _scene == null:
		return
	var model: PlayerModel = GameState.active_model
	var before: float = model.skill_elo("addition_basic")
	_solve(_scene)
	await get_tree().process_frame
	assert_true(_scene.is_won(), "جوابِ خودش باید ببرد")
	var args: Variant = get_signal_parameters(EventBus, "level_completed", 0)
	assert_true(args is Array and (args as Array).size() == 2, "payload سطح")
	if not (args is Array) or (args as Array).size() < 2:
		return
	var stats: Dictionary = (args as Array)[1] as Dictionary
	assert_eq(float(stats.get("score", 0.0)), 1.0, "بدون راهنما و بدون تلاشِ اضافه = ۱.۰")
	var delta: float = float(stats.get("final_elo_delta", 0.0))
	assert_gt(delta, 5.0, "رتبه باید واقعاً به‌روز شده باشد (قبلاً صفر بود)")
	assert_lt(delta, SkillRating.K_FACTOR, "بردِ یک سطح آسان هرگز به سقف K نمی‌رسد")
	assert_gt(model.skill_elo("addition_basic"), before)
	assert_eq(DifficultyEngine.results_size(), 1, "یک برد = یک اعمال (ADR-038)")


func test_hints_lower_the_score_of_the_same_win() -> void:
	_scene = _build("tier1_level_01")
	if _scene == null:
		return
	if _scene.hint_timing != null:
		_scene.hint_timing.auto_idle_timer = false
		_scene.hint_timing.tick(46.0)  # یک راهنما
		var stats_a: Dictionary = {}
		_solve(_scene)
		await get_tree().process_frame
		var args: Variant = get_signal_parameters(EventBus, "level_completed", 0)
		if args is Array and (args as Array).size() == 2:
			stats_a = (args as Array)[1] as Dictionary
		assert_eq(float(stats_a.get("hints_used", -1.0)), 1.0)
		assert_lt(float(stats_a.get("score", 1.0)), 1.0, "§۳ نکته: راهنما امتیاز را می‌خورد")
		# مقایسه با تلورانس (نه assert_eq): 1 - 0.15 در double برابرِ 0.85ِ دقیق نیست
		assert_true(absf(float(stats_a.get("score", 0.0)) - 0.85) < 0.0001,
			"یک راهنما = 1 - 0.15 (docs/07 §۵)")
	else:
		fail("تایمر راهنما ساخته نشد")


func test_the_next_level_after_a_win_comes_from_the_engine() -> void:
	_scene = _build("tier1_level_01")
	if _scene == null:
		return
	_solve(_scene)
	await get_tree().process_frame
	assert_true(_scene.result_bar != null, "نوار نتیجه فاز ۳ باید باشد")
	_scene.result_bar.advance()
	assert_eq(str(LevelLoader.pending_config.get("level_id", "")), "tier1_level_02",
		"بازیکن تازه = همان پله‌ی نردبان؛ موتور بی‌دلیل جابه‌جا نمی‌کند")
	assert_eq(DifficultyEngine.last_reason(), "ladder_order")


func test_no_more_hints_after_the_level_is_won() -> void:
	_scene = _build("tier1_level_01")
	if _scene == null:
		return
	_solve(_scene)
	await get_tree().process_frame
	assert_false(_scene.hint_timing.is_armed(), "بعد از برد نردبان خاموش است")
	_scene.hint_timing.auto_idle_timer = false
	_scene.hint_timing.tick(120.0)
	assert_signal_emit_count(EventBus, "hint_requested", 0)
