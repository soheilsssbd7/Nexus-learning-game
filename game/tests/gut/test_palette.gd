extends GutTest
# ===========================================================================
# قانون سند هنری §۲: «هیچ قرمز تند (#FF0000) در کل بازی ممنوع» — اینجا قفل می‌شود
# تا هر افزودن رنگ بعدی (فاز ۸) نتواند قانون را بشکند.
# ===========================================================================

const ALL_COLORS: Array[Color] = [
	Palette.AELORIA_GOLD, Palette.SOFT_TEAL, Palette.WARM_CORAL, Palette.GHOST_VIOLET,
	Palette.MINT, Palette.LAVENDER, Palette.SUNYELLOW, Palette.CLOUD_WHITE,
	Palette.STONE_GREY, Palette.PALE_PEACH,
]


func test_no_aggressive_red_anywhere() -> void:
	for c: Color in ALL_COLORS:
		var is_hot_red: bool = c.r > 0.85 and c.g < 0.45 and c.b < 0.45
		assert_false(is_hot_red, "رنگ %s قرمز تند است — ممنوع (§۲ سند هنری)" % str(c))
	assert_false(Palette.error_hint() == Color(1, 0, 0), "اشتباه = مرجان گرم، نه قرمز هشدار")


func test_palette_names_match_art_bible() -> void:
	assert_eq(Palette.SOFT_TEAL.to_html(false), "4ecdc4")
	assert_eq(Palette.WARM_CORAL.to_html(false), "ff8b7b")
	assert_eq(Palette.GHOST_VIOLET.to_html(false), "a67fe8")
	assert_eq(Palette.AELORIA_GOLD.to_html(false), "ffd166")
	assert_eq(Palette.STONE_GREY.to_html(false), "b8b3c9")
	assert_eq(Palette.CLOUD_WHITE.to_html(false), "f7f4ef")


func test_ghost_color_is_constant_across_thermal_range() -> void:
	var small := GhostOrb.new()
	autofree(small)
	small.set_hidden_value(1.0)
	var big := GhostOrb.new()
	autofree(big)
	big.set_hidden_value(50.0)
	assert_eq(small.fill_color(), big.fill_color(), "Ghost Violet نباید با مقدار تغییر کند")


func test_thermal_maps_small_to_teal_and_large_to_gold() -> void:
	assert_eq(Palette.thermal(0.0), Palette.SOFT_TEAL)
	assert_eq(Palette.thermal(12.0), Palette.AELORIA_GOLD)
	var mid: Color = Palette.thermal(6.0)
	assert_true(mid.r > Palette.SOFT_TEAL.r and mid.g > Palette.SOFT_TEAL.g,
		"بینابین باید به سمت طلایی برود نه به سمت قرمز")
	assert_lt(mid.b, Palette.SOFT_TEAL.b)


func test_ui_font_is_never_null_in_headless() -> void:
	assert_not_null(Palette.ui_font(), "فونت پیش‌فرض پروژه باید همیشه resolve شود (ADR-030)")
	assert_true(Palette.ui_font().get_height(48) > 0)
