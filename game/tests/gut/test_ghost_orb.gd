extends GutTest
# ===========================================================================
# تسک ۲.۳ — GhostOrb: وزن واقعی در محاسبه لحاظ شود، عدد هیچ‌جا نمایش داده نشود.
# ===========================================================================

const BalanceScaleScene: PackedScene = preload("res://scenes/gameplay/BalanceScale.tscn")

var _scale: BalanceScale = null


func before_each() -> void:
	_scale = BalanceScaleScene.instantiate() as BalanceScale
	add_child_autofree(_scale)


func _ghost(p_hidden: float) -> GhostOrb:
	var g := GhostOrb.new()
	autofree(g)
	g.set_hidden_value(p_hidden)
	return g


func test_hidden_value_counts_in_balance() -> void:
	_scale.left_pan.add_orb(_ghost(4.0))
	assert_eq(_scale.left_weight(), 4.0, "وزن مخفی باید در محاسبه لحاظ شود (DoD ۲.۳)")


func test_display_never_reveals_the_number() -> void:
	var g := _ghost(4.0)
	assert_eq(g.display_text(), "?")
	assert_eq(str(g.value), "0.0", "value برای مجهول معنایی ندارد")
	_scale.left_pan.add_orb(g)
	assert_eq(g._visual.glyph, "?", "متن روی کره هم باید «؟» بماند")
	assert_false(str(g._visual.glyph).contains("4"), "عدد مخفی نباید به UI نشت کند")


func test_color_is_always_ghost_violet() -> void:
	var g := _ghost(7.0)
	assert_eq(g.fill_color().to_html(false), Palette.GHOST_VIOLET.to_html(false),
		"Ghost Violet در کل بازی ثابت است (§۲ سند هنری)")
	assert_eq(g.orb_type, WeightOrb.OrbType.GHOST)
	assert_true(g.is_ghost())


func test_pulsing_visual_and_reveal_api() -> void:
	var g := _ghost(6.0)
	_scale.left_pan.add_orb(g)
	await get_tree().process_frame
	assert_true(g._visual.pulsing, "«؟» باید نفس بکشد (§۶ سند هنری)")
	g.reveal()
	assert_false(g._visual.pulsing)
	assert_eq(g._visual.glyph, "6", "فقط بعد از reveal عدد نشان داده می‌شود")


func test_ghost_on_right_pans_balances_ghost_on_left() -> void:
	_scale.left_pan.add_orb(_ghost(5.0))
	_scale.right_pan.add_orb(_ghost(5.0))
	assert_true(_scale.is_balanced(0.0))
	assert_eq(_scale.calculate_tilt(), 0.0)


func test_ghost_weight_survives_value_tampering() -> void:
	var g := _ghost(3.0)
	g.value = 99.0
	assert_eq(g.weight(), 3.0, "وزن مجهول فقط از hidden_value می‌آید")
