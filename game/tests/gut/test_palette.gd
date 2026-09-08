extends GutTest
# ===========================================================================
# قفل قانون §۲ سند هنری (docs/02) — «هیچ قرمز تهاجمی در کل بازی»
# هر رنگی که فاز ۸ اضافه کند از همین لیست عبور می‌کند؛ پالت مرجعِ کد است نه PNGها.
# ===========================================================================

const ALL_COLORS: Array[Color] = [
	Palette.AELORIA_GOLD, Palette.DEEP_INDIGO, Palette.WARM_CORAL, Palette.SOFT_TEAL,
	Palette.CLOUD_WHITE, Palette.STONE_GREY, Palette.GHOST_VIOLET,
]


func test_no_aggressive_red_in_master_palette() -> void:
	for c: Color in ALL_COLORS:
		var is_hot_red: bool = c.r > 0.85 and c.g < 0.45 and c.b < 0.45
		assert_false(is_hot_red, "رنگ %s قرمز تهاجمی است — §۲ سند هنری ممنوع کرده" % str(c))
	assert_ne(Palette.WARM_CORAL, Color("FF0000"), "خطا = مرجان گرم، نه قرمز هشدار")


func test_palette_matches_art_bible_hexes() -> void:
	assert_eq(Palette.AELORIA_GOLD.to_html(false), "f4c95d")
	assert_eq(Palette.DEEP_INDIGO.to_html(false), "2b2f77")
	assert_eq(Palette.WARM_CORAL.to_html(false), "ff7a5c")
	assert_eq(Palette.SOFT_TEAL.to_html(false), "4fd1c5")
	assert_eq(Palette.CLOUD_WHITE.to_html(false), "fbf9f4")
	assert_eq(Palette.STONE_GREY.to_html(false), "8a8fa3")
	assert_eq(Palette.GHOST_VIOLET.to_html(false), "b79ced")


static func _hex(c: Color) -> String:
	return c.to_html(false)


func test_ghost_violet_is_constant_across_the_thermal_range() -> void:
	var small := GhostOrb.new()
	autofree(small)
	small.set_hidden_value(1.0)
	var big := GhostOrb.new()
	autofree(big)
	big.set_hidden_value(50.0)
	assert_eq(small.fill_color(), big.fill_color(), "Ghost Violet نباید با مقدار عوض شود (§۲)")


func test_thermal_maps_small_to_teal_and_large_to_gold() -> void:
	# مقایسه با hex ۸بیتی: lerp روی float دقیقاً برابر نمی‌شود و assert_eq روی Color شکننده است
	assert_eq(_hex(Palette.thermal(Palette.THERMAL_MIN_VALUE)), _hex(Palette.SOFT_TEAL))
	assert_eq(_hex(Palette.thermal(Palette.THERMAL_MAX_VALUE)), _hex(Palette.AELORIA_GOLD))
	assert_eq(_hex(Palette.thermal(99.0)), _hex(Palette.AELORIA_GOLD), "خارج از بازه باید clamp شود")
	var mid: Color = Palette.thermal(5.0)
	assert_true(mid.r > Palette.SOFT_TEAL.r and mid.b < Palette.SOFT_TEAL.b,
		"بینابین به سمت طلایی می‌رود، نه قرمز")


func test_negative_bubble_never_turns_red() -> void:
	for v: float in [0.5, 2.0, 6.0, 40.0]:
		var c: Color = Palette.negative_bubble(v)
		assert_true(c.g > 0.5 and c.b > 0.5, "حباب ضد-وزن فیروزه‌ای-سفید می‌ماند (§۶ سند هنری)")


func test_imbalance_color_is_warning_not_error() -> void:
	assert_eq(Palette.imbalance_color(1.0), Palette.WARM_CORAL, "بیشترین اختلاف = مرجان")
	assert_eq(Palette.imbalance_color(0.0), Palette.STONE_GREY, "اختلاف صفر = خاکستری/بی‌اثر")
	assert_true(Palette.imbalance_color(0.5).g > 0.4, "هیچ‌وقت به قرمز خالص نزدیک نمی‌شود")


func test_text_color_rule_for_ui_surfaces() -> void:
	assert_eq(Palette.text_on(Palette.DEEP_INDIGO), Palette.CLOUD_WHITE, "روی آسمان نیلی = سفید ابری")
	assert_eq(Palette.text_on(Palette.CLOUD_WHITE), Palette.DEEP_INDIGO, "روی پنل روشن = نیلی")
	assert_eq(Palette.text_on(Palette.AELORIA_GOLD), Palette.DEEP_INDIGO)
	# سطوح واقعی UI باید WCAG AA را رد کنند. پرِ کره‌ها رنگ میان‌روشنایی دارند و
	# متن روی آن‌ها در فاز ۸ با plate خوانا می‌شود (ADR-030) → آن‌ها را فقط
	# «متن نیلی یا سفید» می‌سنجیم، نه کنتراست ۴.۵.
	for surface: Color in [Palette.DEEP_INDIGO, Palette.CLOUD_WHITE]:
		assert_gt(_contrast(surface, Palette.text_on(surface)), 4.5,
			"کنتراست متن روی %s باید ≥ ۴.۵ باشد (§۲ سند هنری)" % str(surface))
	for c: Color in ALL_COLORS:
		assert_true(Palette.CLOUD_WHITE == Palette.text_on(c) or Palette.DEEP_INDIGO == Palette.text_on(c),
			"متن فقط یکی از دو رنگ رسمی است")


## کنتراست WCAG با فرمول luminance (همان وزن‌ها؛ مستقل از داخلی‌جات Godot)
static func _luma(c: Color) -> float:
	# WCAG روی luminance خطی تعریف شده، نه مقدار sRAW → to_linear() لازم است
	var lin: Color = c.to_linear()
	return lin.r * 0.2126 + lin.g * 0.7152 + lin.b * 0.0722


static func _contrast(a: Color, b: Color) -> float:
	var la: float = _luma(a)
	var lb: float = _luma(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
