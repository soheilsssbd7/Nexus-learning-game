extends GutTest
# ===========================================================================
# تعریف «قابل‌اجرا بودن» (تسک ۲.۶ + DoD ۲.۵) — مهم‌ترین تست فاز ۲
# ---------------------------------------------------------------------------
# این فایل LevelScene.tscn را واقعاً instantiate می‌کند (نه کپی منطق) و همان
# API عمومیِ درگ را صدا می‌زند که `_input_event` در دستگاه واقعی صدا می‌زند؛
# پس در هدلس CI قطعی است و در دستگاه همان مسیر را پوشش می‌دهد.
# ===========================================================================

const PROFILE := "gut_p2_playable"
const LevelSceneResource := preload("res://scenes/gameplay/LevelScene.tscn")
const REQUIRED_STAT_KEYS: Array[String] = [
	"time_to_solve_sec", "attempts", "hints_used", "error_count",
	"error_type", "score", "elo_delta",
]

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
	watch_signals(EventBus)
	_scene = LevelSceneResource.instantiate() as LevelController
	_scene.attempt_settle_sec = 0.05
	add_child_autofree(_scene)


func _right_pan(index: int = 0) -> BalancePan:
	return _scene.scales[index].right_pan


func _tray_orb(value: float) -> WeightOrb:
	for orb: WeightOrb in _scene.tray_orbs:
		if orb != null and not orb.is_placed and is_equal_approx(orb.value, value):
			return orb
	return null


func _drag(orb: WeightOrb, target: Vector2) -> void:
	if orb == null:
		return
	orb.begin_drag(orb.global_position)
	orb.drag_to(target)
	orb.end_drag(target)


# --------------------------------------------------------------------------
# ساخت صحنه
# --------------------------------------------------------------------------
func test_level_scene_builds_the_doc_example() -> void:
	assert_not_null(_scene, "LevelScene.tscn باید ریشه‌ی LevelController باشد")
	assert_not_null(_scene.scales_root)
	assert_not_null(_scene.tray_root)
	assert_eq(_scene.level_id, "tier1_level_01")
	assert_eq(_scene.scales.size(), 1)
	assert_eq(_scene.scales[0].left_weight(), 8.0, "کفه‌ی چپ «3 + 5» است")
	assert_eq(_scene.scales[0].right_weight(), 0.0)
	assert_eq(_scene.tray_orbs.size(), 18, "سینی: ده تا ۱، پنج تا ۲، سه تا ۵")
	assert_ne(_scene.intro_label.text, "", "نریشن ورودی (§۶ سند GDD) باید روی پرده باشد")


func test_tray_layout_stays_inside_the_viewport() -> void:
	for orb: WeightOrb in _scene.tray_orbs:
		var global: Vector2 = orb.global_position
		assert_gt(global.x, 40.0, "کره نباید از لبه‌ی چپ 1080 بیرون بزند")
		assert_lt(global.x, 1040.0)
		assert_gt(global.y, 1000.0, "سینی باید زیر ترازو باشد")
		assert_lt(global.y, 1900.0, "و نباید از پایین صفحه بیرون بزند")


# --------------------------------------------------------------------------
# درگ‌واندراپ تا برد
# --------------------------------------------------------------------------
func test_drag_and_drop_places_an_orb_on_the_pan() -> void:
	var orb := _tray_orb(5.0)
	_drag(orb, _right_pan().dish_position())
	await get_tree().process_frame
	assert_true(orb.is_placed)
	assert_eq(orb.pan, _right_pan())
	assert_eq(_scene.scales[0].right_weight(), 5.0)
	assert_false(_scene.is_won(), "۵ ≠ ۸ هنوز حل نشده")
	assert_signal_emitted(EventBus, "orb_placed")
	var payload: Dictionary = get_signal_parameters(EventBus, "orb_placed", 0)[0]
	assert_eq(payload["side"], BalancePan.SIDE_RIGHT)
	assert_eq(payload["scale_id"], "main")
	assert_eq(payload["value"], 5.0)


func test_orb_dropped_in_empty_space_returns_to_the_tray() -> void:
	var before: int = _scene.tray_unplaced_count()
	var orb := _tray_orb(2.0)
	_drag(orb, Vector2(80.0, 1800.0))
	await get_tree().create_timer(0.3).timeout
	assert_false(orb.is_placed, "رهاکردن بیرون کفه = برگشت به سینی")
	assert_eq(_scene.scales[0].right_weight(), 0.0)
	assert_eq(_scene.tray_unplaced_count(), before)
	assert_almost_eq(orb.global_position.distance_to(orb.home_position + _scene.tray_root.global_position),
		0.0, 0.5, "کره با Tween به خانه‌اش در سینی برمی‌گردد")


func test_removing_from_a_pan_rebalances_at_once() -> void:
	var orb := _tray_orb(5.0)
	_drag(orb, _right_pan().dish_position())
	await get_tree().process_frame
	_drag(orb, _scene.tray_root.global_position)
	assert_false(orb.is_placed)
	assert_eq(_scene.scales[0].right_weight(), 0.0)


func test_unstable_layout_counts_exactly_one_attempt_after_settling() -> void:
	assert_eq(GameState.level_attempts, 0)
	_drag(_tray_orb(5.0), _right_pan().dish_position())
	await get_tree().create_timer(0.3).timeout
	assert_eq(GameState.level_attempts, 1, "۰.۸ ثانیه (اینجا ۰.۰۵) بی‌حرکتیِ نامتعادل = یک تلاش")
	assert_signal_emit_count(EventBus, "attempt_failed", 1)
	assert_eq(GameState.active_model.attempts_total, 1)


func test_fast_consecutive_placements_are_not_each_an_attempt() -> void:
	for v: float in [5.0, 2.0]:
		_drag(_tray_orb(v), _right_pan().dish_position())
	assert_eq(GameState.level_attempts, 0, "حالت میانیِ درگ «تلاش ناموفق» نیست (§۳ GDD)")


func test_balancing_the_scale_wins_the_level() -> void:
	for v: float in [5.0, 2.0, 1.0]:
		_drag(_tray_orb(v), _right_pan().dish_position())
	await get_tree().process_frame
	assert_true(_scene.is_won())
	assert_eq(_scene.scales[0].calculate_tilt(), 0.0)
	assert_signal_emit_count(EventBus, "level_completed", 1)
	var params: Array = get_signal_parameters(EventBus, "level_completed", 0)
	assert_eq(params[0], "tier1_level_01")
	var stats: Dictionary = params[1]
	for key: String in REQUIRED_STAT_KEYS:
		assert_true(stats.has(key), "level_completed باید stats کامل بدهد: %s" % key)
	assert_eq(stats["attempts"], 0)
	assert_true(GameState.active_model.levels_completed.has("tier1_level_01"))


func test_any_correct_combination_wins() -> void:
	for i: int in range(8):
		_drag(_tray_orb(1.0), _right_pan().dish_position())
	await get_tree().process_frame
	assert_true(_scene.is_won(), "هشت تا ۱ هم پاسخ درست است (GDD §۱.۳: چندراه‌حل)")


func test_win_is_reported_once_only() -> void:
	for v: float in [5.0, 2.0, 1.0]:
		_drag(_tray_orb(v), _right_pan().dish_position())
	await get_tree().process_frame
	assert_signal_emit_count(EventBus, "level_completed", 1)
	_drag(_tray_orb(1.0), _right_pan().dish_position())
	_drag(_scene.scales[0].right_pan.orbs[0], _scene.tray_root.global_position)
	await get_tree().process_frame
	assert_signal_emit_count(EventBus, "level_completed", 1, "بعد از برد، سطح نباید دوباره «برده» شود")


# --------------------------------------------------------------------------
# آمادگی برای فاز ۳/۴: config-محوری، کره‌ی روح، چندترازویی
# --------------------------------------------------------------------------
func _fresh_scene(cfg: Dictionary) -> LevelController:
	var scene: LevelController = LevelSceneResource.instantiate() as LevelController
	scene.config = cfg
	scene.attempt_settle_sec = 0.05
	add_child_autofree(scene)
	return scene


func test_ghost_orb_weight_counts_but_stays_hidden_in_scene() -> void:
	var scene := _fresh_scene({
		"level_id": "tier3_ghost_probe",
		"tier": 3,
		"tolerance": 0.0,
		"scales": [{
			"id": "main",
			"left_orbs": [{"type": "number", "value": 2.0}],
			"left_ghost_orbs": [{"type": "ghost", "hidden_value": 4.0}],
		}],
		"available_orbs": [{"type": "ghost", "hidden_value": 6.0, "count": 1}],
	})
	var ghost: GhostOrb = scene.scales[0].left_pan.orbs[1] as GhostOrb
	assert_not_null(ghost, "کره‌ی روح باید روی کفه باشد")
	assert_eq(scene.scales[0].left_weight(), 6.0, "وزن مخفی در محاسبه لحاظ می‌شود")
	assert_eq(ghost.display_text(), "?")
	assert_eq(ghost._visual.glyph, "?", "عدد هیچ‌جا در UI نمایش داده نمی‌شود")
	assert_signal_not_emitted(EventBus, "level_completed")


func test_negative_orb_can_solve_a_level() -> void:
	var scene := _fresh_scene({
		"level_id": "tier4_negative_probe",
		"tier": 4,
		"tolerance": 0.0,
		"scales": [{
			"id": "main",
			"left_orbs": [{"type": "number", "value": 3.0}],
		}],
		"available_orbs": [
			{"type": "number", "value": 5.0, "count": 1},
			{"type": "negative", "value": 2.0, "count": 1},
		],
	})
	_drag(scene.tray_orbs[0], scene.scales[0].right_pan.dish_position())
	assert_false(scene.is_won(), "۳ ≠ ۵")
	_drag(scene.tray_orbs[1], scene.scales[0].right_pan.dish_position())
	await get_tree().process_frame
	assert_true(scene.is_won(), "۵ − ۲ = ۳ → حباب ضد-وزن بخشی از پازل است")


func test_two_linked_scales_are_supported() -> void:
	var scene := _fresh_scene({
		"level_id": "tier4_twin_probe",
		"tier": 4,
		"tolerance": 0.0,
		"scales": [
			{"id": "a", "left_orbs": [{"type": "number", "value": 3.0}]},
			{"id": "b", "left_orbs": [{"type": "number", "value": 4.0}]},
		],
		"available_orbs": [
			{"type": "number", "value": 3.0, "count": 1},
			{"type": "number", "value": 4.0, "count": 1},
		],
	})
	assert_eq(scene.scales.size(), 2, "Tier 4 دو ترازو دارد (GDD §۳ + ADR-029)")
	_drag(scene.tray_orbs[0], scene.scales[1].right_pan.dish_position())
	await get_tree().process_frame
	assert_false(scene.is_won(), "تا هر دو ترازو متعادل نشده‌اند برد نیست")
	assert_eq(scene.scales[1].calculate_tilt(), 0.0)
	assert_ne(scene.scales[0].calculate_tilt(), 0.0)
	_drag(scene.tray_orbs[1], scene.scales[0].right_pan.dish_position())
	await get_tree().process_frame
	assert_true(scene.is_won(), "برد فقط وقتی هر دو ترازو متعادل باشد")
	assert_eq(scene.scales[0].left_weight() + scene.scales[0].right_weight(), 6.0)
