extends GutTest
# ===========================================================================
# تسک ۲.۱ — WeightOrb: درگ لمسی با SignalTap
# DoD: «تست شبیه‌سازی لمس: یک کره برداشته و روی کفه رها می‌شود».
# روتینگ واقعیِ ورودی هدلس قابل‌اطمینان نیست، پس اینجا API عمومی درگ تست می‌شود؛
# اتصال `_input_event` → همان API در test_level_controller پوشش داده شده است.
# ===========================================================================

const BalanceScaleScene := preload("res://scenes/gameplay/BalanceScale.tscn")

var _scale: BalanceScale = null


func before_each() -> void:
	_scale = BalanceScaleScene.instantiate() as BalanceScale
	add_child_autofree(_scale)


func _orb(p_value: float) -> WeightOrb:
	var o := WeightOrb.new()
	autofree(o)
	o.set_value(p_value)
	add_child_autofree(o)
	return o


func test_orb_carries_weight_and_label() -> void:
	var o := _orb(3.0)
	assert_eq(o.weight(), 3.0)
	assert_eq(o.display_text(), "3")
	assert_eq(o.orb_type, WeightOrb.OrbType.NUMBER)
	assert_eq(o.radius, 44.0)
	assert_not_null(o._visual, "نود Visual از صحنه/کد باید پیدا شود")
	assert_eq(o._visual.glyph, "3")
	assert_eq(o._visual.fill, Palette.thermal(3.0), "رنگ از توابع thermal (§۶ سند هنری)")


func test_decimal_weight_shows_one_decimal() -> void:
	assert_eq(_orb(0.5).display_text(), "0.5")


func test_collision_shape_matches_radius() -> void:
	var o := _orb(2.0)
	assert_true(o._body != null and o._body.shape is CircleShape2D)
	assert_eq((o._body.shape as CircleShape2D).radius, o.radius)


func test_drag_lifts_the_orb_and_release_drops_it() -> void:
	var o := _orb(5.0)
	watch_signals(o)
	var from := Vector2(200.0, 900.0)
	o.global_position = from
	o.begin_drag(from)
	assert_true(o.is_dragging())
	assert_eq(o.z_index, 100, "کره‌ی در حال درگ باید روی همه باشد")
	assert_true(o._visual.lifted)
	assert_signal_emitted(o, "drag_began")
	o.drag_to(from + Vector2(120.0, -60.0))
	assert_eq(o.global_position, from + Vector2(120.0, -60.0) + o._grab_offset)
	o.end_drag(o.global_position)
	assert_false(o.is_dragging())
	assert_eq(o.z_index, 0)
	assert_false(o._visual.lifted)
	assert_signal_emitted(o, "drag_ended")


func test_grab_offset_keeps_the_touch_point_relative() -> void:
	var o := _orb(1.0)
	var center := Vector2(500.0, 500.0)
	o.global_position = center
	o.begin_drag(center + Vector2(10.0, 8.0))
	assert_eq(o._grab_offset, Vector2(-10.0, -8.0))
	o.drag_to(Vector2(700.0, 300.0))
	assert_eq(o.global_position, Vector2(690.0, 292.0), "کره نباید به مرکز انگشت بچسبد (پرش بصری ممنوع)")


func test_input_event_routes_touch_press_and_release() -> void:
	var o := _orb(2.0)
	watch_signals(o)
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = o.global_position
	o._input_event(null, press, 0)
	assert_true(o.is_dragging(), "لمس روی Area2D باید درگ را شروع کند")
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = o.global_position + Vector2(40.0, 0.0)
	o._input_event(null, release, 0)
	assert_false(o.is_dragging())
	assert_signal_emitted(o, "drag_ended")


func test_mouse_events_are_accepted_too() -> void:
	var o := _orb(2.0)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = o.global_position
	o._input_event(null, press, 0)
	assert_true(o.is_dragging())
	o.end_drag(o.global_position)


func test_drag_disabled_ignores_input() -> void:
	var o := _orb(2.0)
	o.drag_enabled = false
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = o.global_position
	o._input_event(null, press, 0)
	assert_false(o.is_dragging(), "کره‌های قفل/غیرقابل‌استفاده نباید درگ شوند")


func test_second_press_is_ignored_while_dragging() -> void:
	var o := _orb(2.0)
	watch_signals(o)
	var start := o.global_position
	o.begin_drag(start)
	o.begin_drag(start + Vector2(50.0, 50.0))
	assert_signal_emit_count(o, "drag_began", 1, "درگ دوتایی = کره‌ی گم‌شده روی صفحه")


func test_touching_a_pan_does_not_place_by_itself() -> void:
	var o := _orb(2.0)
	o.global_position = _scale.right_pan.dish_position()
	assert_false(o.is_placed, "قرارگرفتن فقط با رهاکردن (end_drag) رخ می‌دهد — هندسی، نه overlap فیزیکی")


func test_pan_accepts_and_rejects() -> void:
	var o := _orb(2.0)
	assert_true(_scale.right_pan.add_orb(o))
	assert_true(o.is_placed)
	assert_eq(o.pan, _scale.right_pan)
	assert_false(_scale.right_pan.add_orb(o), "یک کره نمی‌تواند دو بار روی کفه باشد")
	var from_tray := WeightOrb.new()
	autofree(from_tray)
	from_tray.set_value(1.0)
	assert_true(_scale.right_pan.add_orb(from_tray))
	assert_true(_scale.left_pan.is_empty(), "کفه‌ی چپ خالی می‌ماند")
	assert_eq(_scale.right_weight(), 3.0)
