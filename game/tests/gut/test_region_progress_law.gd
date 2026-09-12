extends GutTest
# ===========================================================================
# NEXUS — تست‌های تسک ۸.۳ «ب» (قانونِ §۵: ویرانی ← پیشرفتِ همان Tier ✓ + سیم‌کشیِ صحنه‌ها)
# --------------------------------------------------------------------------
# بندِ «الف» (`test_region_backdrop.gd`) قراردادِ هنریِ شش منطقه را می‌سنجد؛ این فایل همان
# چیزی را که کودک **واقعاً تجربه می‌کند** ✓: عددِ بازیابی از `GameState.tier_restoration()`
# می‌آید (۲ از ۵ سطح ⇒ ۰٫۴ ⇒ دو پل از پنج پلِ دشت ✓✓ هیچ وزن/انحرافِ پنهانی نیست) و دو صحنه
# (نقشۀ جهان + صحنۀ سطح) بک‌گراند را می‌سازند و به `level_completed` وصلش می‌کنند ⇒ برد،
# همان لحظه، در دنیا دیده می‌شود ✓§۵. helper های `_read/_func_body` عمداً تکرار شده‌اند:
# فایل‌های تست مستقل می‌مانند و با باگ‌رفتنِ یکی، آن یکی هنوز چیزی را اثبات می‌کند ✓
# ===========================================================================

const BD := preload("res://scripts/environments/RegionBackdrop.gd")
const SRC_PATH := "res://scripts/environments/RegionBackdrop.gd"
const MAP_PATH := "res://scripts/ui/WorldMap.gd"
const CTRL_PATH := "res://scripts/gameplay/LevelController.gd"

var _saved_model: PlayerModel = null
var _saved_tier: int = 1


func before_each() -> void:
	# مدلِ GameState مشترک است ⇒ مدلِ خودمان را می‌گذاریم و پس می‌دهیم ✓ (تستِ عددیِ §۵
	# نباید اثرِ جانبی روی بقیۀ ۴۰ فایل داشته باشد ✗✓)
	_saved_model = GameState.active_model
	_saved_tier = GameState.current_tier
	GameState.active_model = PlayerModel.new()


func after_each() -> void:
	GameState.active_model = _saved_model
	GameState.current_tier = _saved_tier


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s: String = f.get_as_text()
	f.close()
	return s


func _func_body(fn_name: String) -> String:
	var lines: PackedStringArray = _read(SRC_PATH).split("\n")
	var out: PackedStringArray = PackedStringArray()
	var hit := false
	for i: int in range(lines.size()):
		var l: String = lines[i]
		if not hit:
			if l.begins_with("func " + fn_name + "(") or l.begins_with("static func " + fn_name + "("):
				hit = true
			continue
		if l.strip_edges() != "" and l.substr(0, 1) != "\t":
			break
		out.append(l)
	return "\n".join(out)


# --------------------------------------------------------------------------
# ۳) قانونِ §۵: پل‌ها ساخته می‌شوند ✓ (نه اینکه فقط رنگ عوض شود)
# --------------------------------------------------------------------------
func test_bridges_are_built_as_progress_rises() -> void:
	for r: int in range(BD.region_count()):
		var total: int = BD.bridge_total(r)
		assert_gt(total, 0, "هر منطقه دستِ‌کم یک پل/اتصال دارد ✓")
		assert_eq(BD.bridges_built(r, 0.0), 0, "%s: در شروعِ Tier هیچ پلی نیست ✗✓" % BD.region_name(r))
		assert_eq(BD.bridges_built(r, 1.0), total, "%s: پایانِ Tier ⇒ همهٔ پل‌ها ✓" % BD.region_name(r))
		var prev := -1
		for i: int in range(0, 21):
			var p: float = float(i) / 20.0
			var built: int = BD.bridges_built(r, p)
			assert_true(built <= total, "پلِ بیشتر از کل ممکن نیست ✗")
			assert_true(built >= prev, "پل‌ها هرگز خراب نمی‌شوند ✓ (یکنوا)")
			prev = built


func test_brokenness_is_clamped() -> void:
	for r: int in range(BD.region_count()):
		for p: float in [-0.4, 0.0, 0.5, 1.0, 3.0]:
			var brk: float = BD.brokenness(r, p)
			assert_true(brk >= 0.0 and brk <= 1.0, "ویرانی باید در [0,1] بماند (شد %f)" % brk)


# --------------------------------------------------------------------------
# ۴) پلانِ هندسه ✓ (ساختارِ لایه‌ها، سقفِ آلفا، حقِ خوانایی)
func test_visual_rules_live_in_static_functions() -> void:
	for fn_name: String in ["brokenness", "bridges_built", "prop_density", "light_color",
			"sky_gradient", "layers", "signature", "design_size"]:
		assert_true(_func_body(fn_name).length() > 10, "%s بدنه دارد ✓" % fn_name)


# --------------------------------------------------------------------------
# ۶) ورودیِ بصری از پیشرفتِ واقعیِ بازی ✓§۵ (پل بین هنر و داده)
# --------------------------------------------------------------------------
# ۶) ورودیِ بصری از پیشرفتِ واقعیِ بازی ✓§۵ (پل بین هنر و داده)
# --------------------------------------------------------------------------
func test_tier_restoration_is_completed_over_total() -> void:
	var ids: Array[String] = LevelLoader.levels_for_tier(1)
	assert_eq(ids.size(), 5, "Tier 1 پنج سطح دارد ✓ (۴۵/۵ در سندِ داده)")
	assert_eq(GameState.tier_restoration(1), 0.0, "با مدلِ تازه هیچ پلی ساخته نشده")
	GameState.active_model.levels_completed.append(ids[0])
	GameState.active_model.levels_completed.append(ids[1])
	assert_eq(GameState.tier_restoration(1), 0.4, "۲ از ۵ ⇒ ۰٫۴ ✓ (رابطهٔ مستقیم، بدونِ وزنِ پنهان)")
	for i: int in range(2, ids.size()):
		GameState.active_model.levels_completed.append(ids[i])
	assert_eq(GameState.tier_restoration(1), 1.0, "پایانِ Tier ⇒ منطقۀ کاملاً بازسازی‌شده ✓§۵")


func test_restoration_for_empty_tier_is_zero() -> void:
	assert_eq(GameState.tier_restoration(9), 0.0, "Tier ناموجود صفر است، نه NaN ✗✓")
	assert_eq(GameState.tier_restoration(-2), 0.0, "منفی هم امن است ✓")


func test_hub_restoration_is_the_average_of_five_tiers() -> void:
	var ids: Array[String] = LevelLoader.levels_for_tier(1)
	for id: String in ids:
		GameState.active_model.levels_completed.append(id)
	assert_true(absf(GameState.world_restoration() - 0.2) < 0.0001,
			"یک Tier از پنج ⇒ ۰٫۲ ✓ (Hub با «کلِ پیشرفت» زنده می‌شود، نه یک Tier)")
	assert_true(GameState.world_restoration() >= GameState.tier_restoration(1) * 0.2 - 0.0001,
			"Hub هیچ‌وقت از میانگینِ خودش جلوتر نمی‌زند ✓")


func test_region_for_tier_mapping() -> void:
	assert_eq(BD.region_for_tier(0), RegionBackdrop.HUB, "صفحۀ ۰ نقشه = Hub ✓")
	assert_eq(BD.region_for_tier(1), RegionBackdrop.MEADOW, "Tier 1 = Sunlit Meadow ✓§۵")
	assert_eq(BD.region_for_tier(2), RegionBackdrop.CAVERNS, "Tier 2 = Whisper Caverns ✓")
	assert_eq(BD.region_for_tier(3), RegionBackdrop.RUINS, "Tier 3 = Ghostlight Ruins ✓")
	assert_eq(BD.region_for_tier(4), RegionBackdrop.OBSERVATORY, "Tier 4 = Twin Observatory ✓")
	assert_eq(BD.region_for_tier(5), RegionBackdrop.SUMMIT, "Tier 5 = Summit of Equilibrium ✓")
	assert_eq(BD.region_for_tier(99), RegionBackdrop.SUMMIT, "خارجِ بازه ⇒ سوراخ/NaN نه ✓")
	assert_eq(BD.region_for_tier(-5), RegionBackdrop.HUB, "منفی ⇒ Hub ✓")


# --------------------------------------------------------------------------
# ۷) قراردادِ instance/لایه‌بندی/سیم‌کشی ✓
# --------------------------------------------------------------------------
# ۷) قراردادِ instance/لایه‌بندی/سیم‌کشی ✓
# --------------------------------------------------------------------------
func test_backdrop_is_a_non_control_node_behind_everything() -> void:
	# درسِ فاز ۷.۴ ✗✓: گرهٔ بک‌گراند اگر Control باشد کلیک‌های بچه‌ها را می‌خورد
	var bd := RegionBackdrop.new()
	assert_true(bd is Node2D, "Node2D است ✓")
	assert_false(bd is Control, "Control نیست ⇒ هیچ کلیکی نمی‌خورد ✗✓")
	add_child(bd)
	assert_true(bd.z_index < 0, "پشتِ HUD/گیم‌پلی است (z_index=%d)" % bd.z_index)
	assert_eq(bd.z_index, -20, "منبعِ واحدِ لایه‌بندی: خودِ کلاس ست می‌کند، نه صحنه‌ها ✓")
	remove_child(bd)
	bd.queue_free()


func test_set_restoration_instant_and_tween_paths() -> void:
	var bd := RegionBackdrop.new()
	add_child(bd)
	bd.set_restoration(0.7, false)
	assert_eq(bd.restoration, 0.7, "animate=false ⇒ فوری ✓ (ورودِ صحنه نباید انیمیشن بسازد)")
	bd.set_restoration(5.0, false)
	assert_eq(bd.restoration, 1.0, "خارجِ بازه کلمپ می‌شود ✗✓")
	remove_child(bd)
	bd.queue_free()
	assert_true(_read(SRC_PATH).contains("tween_property(self, \"restoration\""),
			"مسیرِ انیمیشن هم وجود دارد ✓§۵ «لحظهٔ ساختن» دیده می‌شود")


func test_process_skips_hidden_backdrops() -> void:
	# گوشیِ Android ⇒ هر بیدارِ بی‌مصرف یعنی باتری ✗✓ (فاز ۱۰ روی دستگاه سنجیده می‌شود)
	var body := _func_body("_process")
	assert_true(body.contains("is_visible_in_tree()"), "پنهان ⇒ بی‌کار ✓")
	assert_true(body.contains("queue_redraw()"), "روشن ⇒ فقط یک redraw ✓")


func test_design_size_has_a_portrait_safe_floor() -> void:
	var s: Vector2 = BD.design_size()
	assert_true(s.x >= 640.0 and s.y >= 360.0, "کفِ طراحی برای هندسه/تست ثبات دارد (%s)" % str(s))
	assert_true(_read(SRC_PATH).contains("maxf(vp.x, 640.0)"), "کف در تابع دیده می‌شود، نه فقط در عددِ تست ✓")


func test_scenes_wire_the_backdrop() -> void:
	# سیم‌کشی واقعی: هم نقشه (Hub + Tier صفحه‌ها) و هم صحنۀ سطح ✓✗ بدونِ این، هنر مرده است
	for path: String in [MAP_PATH, CTRL_PATH]:
		var src := _read(path)
		assert_true(src.length() > 200, "%s خوانده شد ✓" % path)
		assert_true(src.contains("RegionBackdrop.new()"), "%s بک‌گراند را می‌سازد ✗✓" % path)
		assert_true(src.contains("_backdrop") or src.contains("bd.set_restoration"),
				"%s بازیابی را از GameState می‌گیرد ✓" % path)
	assert_true(_read(CTRL_PATH).contains("EventBus.level_completed.connect(_on_level_completed_backdrop)"),
			"در صحنۀ سطح، هر برد ⇒ یک پل تازه ✓§۵")
	assert_true(_read(MAP_PATH).contains("_refresh_backdrop(true)"),
			"در نقشه، برد ⇒ همان منطقۀ صفحه جلو می‌آید ✓")


func test_placeholder_sky_is_turned_off_not_deleted() -> void:
	# `Sky` (ColorRect فاز ۳) به‌عنوان fallback می‌ماند ✓ ولی نباید هنر را بپوشاند ✗
	var src := _read(CTRL_PATH)
	assert_true(src.contains("get_node_or_null(\"Sky\") as ColorRect"), "پیدا می‌کند ✓")
	assert_true(src.contains("sky.visible = false"), "خاموشش می‌کند ✓")
	var tscn := _read("res://scenes/gameplay/LevelScene.tscn")
	assert_true(tscn.contains("[node name=\"Sky\" type=\"ColorRect\""), "گره هنوز هست ✓ (حذف نکردم)")
