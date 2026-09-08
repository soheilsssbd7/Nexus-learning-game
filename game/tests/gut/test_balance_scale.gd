extends GutTest
# ===========================================================================
# تسک ۲.۲ — BalanceScale: DoD = «تست GUT برای calculate_tilt() با چند سناریوی وزن»
# اعداد انتظار دقیقاً از فرمول سند مشتق شده‌اند: clamp(diff/20, -1, 1) * 14
# ===========================================================================

const BalanceScaleScene := preload("res://scenes/gameplay/BalanceScale.tscn")
const MAX_TILT: float = 14.0

var _scale: BalanceScale = null


func before_each() -> void:
	_scale = BalanceScaleScene.instantiate() as BalanceScale
	add_child_autofree(_scale)
	watch_signals(EventBus)


func _orb(p_value: float) -> WeightOrb:
	var o := WeightOrb.new()
	autofree(o)
	o.value = p_value
	return o


func _put(pan: BalancePan, values: Array) -> void:
	for v: Variant in values:
		pan.add_orb(_orb(float(v)))


func test_scene_builds_beam_and_two_pans() -> void:
	assert_not_null(_scale.beam, "بازو باید وجود داشته باشد (صحنه یا build_children)")
	assert_not_null(_scale.left_pan)
	assert_not_null(_scale.right_pan)
	assert_true(_scale.left_pan is Area2D, "کفه‌ها Area2D هستند (تسک ۲.۲)")
	assert_ne(_scale.left_pan.side, _scale.right_pan.side, "یک کفه چپ و یک کفه راست")


func test_tilt_is_zero_when_both_sides_empty() -> void:
	assert_eq(_scale.calculate_tilt(), 0.0)


func test_tilt_matches_doc_formula() -> void:
	_put(_scale.left_pan, [8.0])
	# diff = 0 - 8 = -8 → clamp(-0.4) * 14 = -5.6
	assert_almost_eq(_scale.calculate_tilt(), -5.6, 0.0001)
	_put(_scale.right_pan, [20.0])
	# diff = 20 - 8 = 12 → 0.6 * 14 = 8.4
	assert_almost_eq(_scale.calculate_tilt(), 8.4, 0.0001)


func test_tilt_is_clamped_to_max_angle() -> void:
	_put(_scale.right_pan, [100.0, 200.0])
	assert_eq(_scale.calculate_tilt(), MAX_TILT)
	_put(_scale.left_pan, [500.0])
	assert_eq(_scale.calculate_tilt(), -MAX_TILT)


func test_equal_weights_are_balanced() -> void:
	_put(_scale.left_pan, [3.0, 5.0])
	_put(_scale.right_pan, [5.0, 2.0, 1.0])
	assert_eq(_scale.calculate_tilt(), 0.0)
	assert_true(_scale.is_balanced(0.0), "tolerance=0 با مجموع برابر باید balanced باشد")
	assert_eq(_scale.left_weight(), 8.0)
	assert_eq(_scale.right_weight(), 8.0)


func test_tolerance_opens_the_win_window() -> void:
	_put(_scale.left_pan, [8.0])
	_put(_scale.right_pan, [8.4])
	assert_false(_scale.is_balanced(0.0))
	assert_true(_scale.is_balanced(0.5), "سطوح اعشاری Tier بالا tolerance > 0 دارند (§۱ سند داده‌ها)")


func test_sum_weights_is_static_and_pure() -> void:
	var orbs: Array[WeightOrb] = []
	for v: float in [1.0, 2.0, 5.0]:
		orbs.append(_orb(v))
	assert_eq(BalanceScale._sum_weights(orbs), 8.0)
	assert_eq(BalanceScale._sum_weights([] as Array[WeightOrb]), 0.0)


func test_heavier_side_flag_drives_colors() -> void:
	_put(_scale.right_pan, [9.0])
	assert_true(_scale.is_side_heavier(BalancePan.SIDE_RIGHT))
	assert_false(_scale.is_side_heavier(BalancePan.SIDE_LEFT))
	_put(_scale.left_pan, [9.0])
	assert_false(_scale.is_side_heavier(BalancePan.SIDE_LEFT), "تراز = هیچ کفه‌ای سنگین‌تر نیست")


func test_refresh_emits_balance_and_scale_state() -> void:
	_put(_scale.left_pan, [8.0])
	_scale.scale_id = "twin_a"
	_scale.refresh(false)
	assert_signal_emitted_with_parameters(EventBus, "balance_changed", [8.0, 0.0])
	assert_signal_emitted_with_parameters(EventBus, "scale_state_changed", ["twin_a", 8.0, 0.0])
	assert_signal_emitted(_scale, "weights_changed")


func test_beam_animates_instead_of_jumping_and_pans_stay_level() -> void:
	_scale.left_pan.add_orb(_orb(9.0))
	await get_tree().create_timer(0.5).timeout  # tilt_seconds = 0.35
	var tilt: float = _scale.calculate_tilt()
	assert_almost_eq(_scale.beam.rotation_degrees, tilt, 0.01, "بازو باید به زاویه‌ی هدف رسیده باشد")
	assert_almost_eq(_scale.left_pan.rotation_degrees, -tilt, 0.01, "کفه باید افقی بماند")
	assert_almost_eq(_scale.right_pan.rotation_degrees, -tilt, 0.01)


func test_clear_pans_resets_weights() -> void:
	_put(_scale.left_pan, [4.0])
	_put(_scale.right_pan, [2.0, 2.0])
	assert_eq(_scale.placed_count(), 3)
	_scale.clear_pans()
	assert_eq(_scale.placed_count(), 0)
	assert_eq(_scale.calculate_tilt(), 0.0)


func test_removed_orb_unbalances_immediately() -> void:
	_put(_scale.left_pan, [8.0])
	_put(_scale.right_pan, [8.0])
	assert_true(_scale.is_balanced(0.0))
	var taken: WeightOrb = _scale.right_pan.orbs[0]
	_scale.right_pan.remove_orb(taken)
	assert_false(_scale.is_balanced(0.0))
	assert_eq(_scale.right_weight(), 0.0)
