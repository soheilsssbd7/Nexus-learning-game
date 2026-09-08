extends GutTest
# ===========================================================================
# تسک ۲.۴ — NegativeOrb: وزن منفی + بالا کشیدن (DoD: «کم کردن از وزن کفه در تست»)
# ===========================================================================

const BalanceScaleScene: PackedScene = preload("res://scenes/gameplay/BalanceScale.tscn")

var _scale: BalanceScale = null


func before_each() -> void:
	_scale = BalanceScaleScene.instantiate() as BalanceScale
	add_child_autofree(_scale)


func _neg(p_value: float) -> NegativeOrb:
	var n := NegativeOrb.new()
	autofree(n)
	n.set_value(p_value)
	return n


func _num(p_value: float) -> WeightOrb:
	var o := WeightOrb.new()
	autofree(o)
	o.set_value(p_value)
	return o


func test_weight_is_negative() -> void:
	var n := _neg(2.0)
	assert_eq(n.weight(), -2.0)
	assert_eq(n.orb_type, WeightOrb.OrbType.NEGATIVE)
	assert_false(n.is_ghost())


func test_negative_reduces_pan_total() -> void:
	_scale.right_pan.add_orb(_num(5.0))
	assert_eq(_scale.right_weight(), 5.0)
	_scale.right_pan.add_orb(_neg(2.0))
	assert_eq(_scale.right_weight(), 3.0, "Additive stacking: وزن منفی از کفه کم می‌کند (GDD §۱.۳)")


func test_negative_can_win_by_taking_weight_off() -> void:
	_scale.left_pan.add_orb(_num(3.0))
	_scale.right_pan.add_orb(_num(5.0))
	_scale.right_pan.add_orb(_neg(2.0))
	assert_true(_scale.is_balanced(0.0))
	assert_eq(_scale.calculate_tilt(), 0.0)


func test_display_shows_minus_and_absolute_value() -> void:
	assert_eq(_neg(2.0).display_text(), "-2")
	assert_eq(_neg(1.5).display_text(), "-1.5")


func test_value_sign_is_normalized_by_type() -> void:
	var n := NegativeOrb.new()
	autofree(n)
	n.value = 4.0
	assert_eq(n.weight(), -4.0, "علامت را نوع تعیین می‌کند، نه داده (ADR-028)")


func test_unplaced_negative_drifts_upward_not_down() -> void:
	var n := _neg(1.0)
	add_child_autofree(n)
	await get_tree().process_frame
	var ys: Array[float] = []
	for i: int in range(8):
		n._process(0.2)
		ys.append(n._visual.position.y)
		if n._visual.position.y <= -12.0:
			break
	assert_lt(ys.max(), 0.0, "حباب ضد-وزن به سمت بالا می‌کشد (§۶ سند هنری)")
	assert_gt(ys.min(), -(NegativeOrb.DRIFT_RANGE + 0.01), "دامنه‌ی drift محدود است")


func test_placed_negative_does_not_float_off_the_pan() -> void:
	var n := _neg(1.0)
	_scale.left_pan.add_orb(n)
	for i: int in range(10):
		n._process(0.2)
	assert_eq(n._visual.position, Vector2.ZERO, "روی کفه باید سر جای خودش بماند")
