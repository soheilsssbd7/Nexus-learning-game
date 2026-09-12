extends GutTest
# ===========================================================================
# NEXUS — تست‌های تسک ۸.۳ (پنج محیط + Hub، هر منطقه ≥۲ حالتِ بصری | §۵)
# --------------------------------------------------------------------------
# §۵ دو چیز می‌خواهد که «با چشم» سنجیده می‌شوند ✗✓ ولی CI هدلس `_draw()` را اجرا نمی‌کند،
# پس همان دو چیز را به هندسه/داده ترجمه کرده‌ایم (قراردادِ ADR-058، سه‌مین بار ✓✓):
#  ۱) «هر منطقه حداقل دو حالتِ بصری دارد» ⇒ امضایِ هفت‌ویژگیِ (منطقه، بازیابیِ ۰ و ۱)
#     باید در **دو** ویژگی یا بیشتر فرق کند ⇒ `signature_distance ≥ 2` ✓
#  ۲) «ویرانی مستقیماً با پیشرفتِ همان Tier کم می‌شود و پل‌ها ساخته می‌شوند» ⇒ تنها
#     ورودیِ بصری `restoration` است و آن را از `GameState.tier_restoration()` می‌گیریم ⇒
#     عددش را تست می‌کنیم (۰ → ۰٫۵ → ۱ برای ۵ سطح ✓ و Hub = میانگینِ پنج Tier ✓)
# (بند «ب» این تسک در `test_region_progress_law.gd` است ✓ قانونِ پیشرفت و سیم‌کشیِ صحنه‌ها)
# همچنین دو دروازۀ بهداشتِ هنر: پالت (ممنوعیتِ `#rrggbb` و تک‌`Color(` بودنِ شیدرِ سایه ✓)
# و «`_draw` فقط مصرف‌کنندۀ پلان است، تصمیم‌ساز نیست» ✓✓ (ADR-061)
# ===========================================================================

const BD := preload("res://scripts/environments/RegionBackdrop.gd")
const SRC_PATH := "res://scripts/environments/RegionBackdrop.gd"
const BEATS_PATH := "res://data/narrative/story_beats.json"

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
# ۱) واژگان: شش منطقه، نام‌های §۵، قفل‌شدن با روایت ✓✓
# --------------------------------------------------------------------------
func test_six_regions_with_named_identity() -> void:
	assert_eq(BD.region_count(), 6, "Hub + پنج منطقۀ §۵ ✓")
	for r: int in range(BD.region_count()):
		var n: String = BD.region_name(r)
		assert_true(n.length() > 3, "منطقۀ %d نامِ معنادار دارد: %s" % [r, n])
	assert_eq(BD.region_name(0), "Aeloria Hub", "ایندکسِ ۰ = Hub ✓ (خارج این ترتیب = باگِ لایه‌بندی)")


func test_names_match_the_contract_in_art_bible() -> void:
	var expected: Array[String] = [
		"Aeloria Hub", "Sunlit Meadow", "Whisper Caverns",
		"Ghostlight Ruins", "Twin Observatory", "Summit of Equilibrium",
	]
	for i: int in range(expected.size()):
		assert_eq(BD.region_name(i), expected[i], "نامِ §۵ باید کلمه‌به‌کلمه همان باشد ✓")


func test_narrative_ambient_art_resolves_to_regions() -> void:
	# هر `ambient_art` در روایت باید یک منطقۀ شناخته‌شده باشد ✓✗ در غیر این صورت صحنه‌ای
	# با نامی می‌خوانیم که هیچ هنری پشتش نیست (گیتِ پایتون هم همین را می‌گیرد ✓ ولی این‌جا
	# در موتور هم سنجیده می‌شود تا بازیِ واقعی نه فقط CI تضمین داشته باشد ✓✓)
	var raw: Variant = JSON.parse_string(_read(BEATS_PATH))
	assert_true(raw is Dictionary, "story_beats.json قابل‌پارس است")
	var beats: Array = (raw as Dictionary).get("beats", [])
	assert_gt(beats.size(), 0, "بیتِ روایت داریم")
	var seen: Dictionary = {}
	for b: Variant in beats:
		if not (b is Dictionary):
			continue
		var art: String = String((b as Dictionary).get("ambient_art", ""))
		if art == "":
			continue
		var idx: int = BD.region_named(art)
		assert_ne(idx, -1, "«%s» باید منطقۀ RegionBackdrop باشد ✗✓" % art)
		seen[idx] = true
	assert_eq(seen.size(), 5, "پنج منطقۀ روایتیِ §۵ (Hub صحنۀ روایت نیست، منطقۀ نقشه است ✓)")


func test_region_named_rejects_strangers() -> void:
	assert_eq(BD.region_named("Meadow of Sun"), -1, "نامِ ساختگی ⇒ -1 ✓ (گیتِ واژگان به همین تکیه می‌کند)")
	assert_eq(BD.region_named(""), -1, "رشتهٔ خالی هم نباید منطقه بسازد")


# --------------------------------------------------------------------------
# ۲) «هر منطقه ≥۲ حالتِ بصری» ✓§۵ — ادعای اصلیِ ۸.۳
# --------------------------------------------------------------------------
# ۲) «هر منطقه ≥۲ حالتِ بصری» ✓§۵ — ادعای اصلیِ ۸.۳
# --------------------------------------------------------------------------
func test_every_region_has_two_distinct_visual_states() -> void:
	for r: int in range(BD.region_count()):
		var d: int = BD.signature_distance(BD.signature(r, 0.0), BD.signature(r, 1.0))
		assert_true(d >= 2,
				"%s: شروعِ Tier و پایانِ Tier باید در ≥۲ ویژگی فرق کنند (شد %d) ✗✓"
				% [BD.region_name(r), d])


func test_start_state_is_the_ruined_one() -> void:
	for r: int in range(BD.region_count()):
		assert_gt(BD.brokenness(r, 0.0), BD.brokenness(r, 1.0),
				"ویرانی با پیشرفت **کم** می‌شود ✓§۵ (سراشیبیِ مستقیم، نه تصادفی)")
		assert_true(BD.brokenness(r, 0.0) > 0.0, "شروعِ هر منطقه واقعاً ویران است ✓")


func test_regions_are_not_clones_of_each_other() -> void:
	# اگر دو منطقه در همان بازیابی یکی بودند، «پنج محیط» فقط پنج نام بود ✗✓
	for a: int in range(BD.region_count()):
		for b: int in range(a + 1, BD.region_count()):
			var d: int = BD.signature_distance(BD.signature(a, 0.5), BD.signature(b, 0.5))
			assert_true(d >= 2, "%s با %s حداقل در دو ویژگی فرق دارد (شد %d)"
					% [BD.region_name(a), BD.region_name(b), d])


func test_prop_densities_are_all_different() -> void:
	# دلیلِ شمارهٔ بالا: چگالیِ عنصر محیطی نباید کپی‌شده باشد ✓§۵ «هر منطقه هویت دارد»
	var seen: Dictionary = {}
	for r: int in range(BD.region_count()):
		var d: int = BD.prop_density(r)
		assert_true(d >= 4, "چگالی %s باید ≥۴ باشد تا سیلوئت پر باشد" % BD.region_name(r))
		assert_eq(seen.get(d, -1), -1, "چگالیِ تکراری ⇒ دو منطقه هم‌شکل می‌شوند ✗")
		seen[d] = r


func test_signature_is_deterministic() -> void:
	# قطعی‌بودن لازمهٔ «اسکرین‌شاتِ مقایسه‌ای» در فاز ۱۰ است ✓ (هر تصادفِ seedless یعنی
	# دو اجرا دو دنیا ✗✓) — همه‌چیز از جدول‌های const می‌آید، نه `randf()`
	var a: Dictionary = BD.signature(RegionBackdrop.RUINS, 0.37)
	var b: Dictionary = BD.signature(RegionBackdrop.RUINS, 0.37)
	assert_eq(str(a), str(b), "دو بار فراخوانی ⇒ یک امضا ✓")
	assert_false(_read(SRC_PATH).contains("randf("), "هیچ تصادفی در محیط نیست ✓")


# --------------------------------------------------------------------------
# ۳) قانونِ §۵: پل‌ها ساخته می‌شوند ✓ (نه اینکه فقط رنگ عوض شود)
# --------------------------------------------------------------------------
# ۴) پلانِ هندسه ✓ (ساختارِ لایه‌ها، سقفِ آلفا، حقِ خوانایی)
# --------------------------------------------------------------------------
func test_layer_plan_covers_every_required_kind() -> void:
	var kinds: Dictionary = {}
	for r: int in range(BD.region_count()):
		kinds.clear()
		for l: Dictionary in BD.layers(r, 0.5):
			kinds[String(l.kind)] = int(kinds.get(String(l.kind), 0)) + 1
		for want: String in ["sky", "ridge", "isle", "bridge", "prop", "light"]:
			assert_true(kinds.has(want), "%s لایۀ «%s» ندارد ✗ (پلانِ ناقص = محیطِ مرده)"
					% [BD.region_name(r), want])
		# شمارشِ لایه باید **دقیقاً** پلان باشد: آسمان + سه رشته‌کوه/جزیره + کلِ پل‌ها +
		# عنصرها + هاله ✓✓ (نه «حداقل ۱۲» ✗ عددِ شعاری؛ این فرمول هر لایۀ گم‌شده/اضافی را
		# می‌گیرد و با تغییرِ جدول‌ها خودش هم عوض می‌شود ✓)
		var want: int = 1 + 3 + BD.bridge_total(r) + BD.prop_density(r) + 1
		assert_eq(BD.layers(r, 0.5).size(), want, "%s: پلانِ کامل ✓§۵" % BD.region_name(r))


func test_bridge_layer_count_equals_total() -> void:
	for r: int in range(BD.region_count()):
		var bridges := 0
		for l: Dictionary in BD.layers(r, 0.4):
			if String(l.kind) == "bridge":
				bridges += 1
		assert_eq(bridges, BD.bridge_total(r), "پل‌های شکسته هم در پلان‌اند (خطِ نور) ✓ تا «ساخته شدن» دیده شود")


func test_alpha_never_exceeds_readability_cap() -> void:
	# سقفِ آلفا دلیلِ فنی دارد: کفه/کره و عددِ روی آن باید خوانا بماند ✓§۷ (نه سلیقه ✗)
	var cap: float = BD.layer_max_alpha()
	assert_true(cap > 0.0 and cap <= 0.6, "سقفِ آلفا منطقی است: %f" % cap)
	for r: int in range(BD.region_count()):
		for p: float in [0.0, 0.33, 0.66, 1.0]:
			for l: Dictionary in BD.layers(r, p):
				for key: String in l.keys():
					if not key.ends_with("alpha"):
						continue
					var a: float = float(l[key])
					assert_true(a >= 0.0 and a <= cap,
							"%s/%s.%s = %f، سقف %f ✗ (خوانایی کفه/کره §۷)"
							% [BD.region_name(r), String(l.kind), key, a, cap])


func test_built_bridges_are_more_visible_than_gaps() -> void:
	for r: int in range(BD.region_count()):
		var built_min := 1.0
		var gap_max := 0.0
		for l: Dictionary in BD.layers(r, 0.6):
			if String(l.kind) != "bridge":
				continue
			if bool(l.built):
				built_min = minf(built_min, float(l.alpha))
			else:
				gap_max = maxf(gap_max, float(l.alpha))
		if BD.bridges_built(r, 0.6) > 0:
			assert_gt(built_min, gap_max, "پلِ ساخته‌شده از شکافِ باز پررنگ‌تر است ✓ (بازخوردِ بصری)")


# --------------------------------------------------------------------------
# ۵) بهداشتِ پالت و «`_draw` تصمیم نمی‌گیرد» ✓✓ (ADR-058/060/061)
# --------------------------------------------------------------------------
# ۵) بهداشتِ پالت و «`_draw` تصمیم نمی‌گیرد» ✓✓ (ADR-058/060/061)
# --------------------------------------------------------------------------
func test_no_hardcoded_hex_colors_in_environment() -> void:
	# §۲ «پالت رسمیِ Aeloria» ⇒ هیچ `#rrggbb` در سورسِ محیط ✗✓ همه از `Palette` ✓
	var rx := RegEx.create_from_string("#[0-9a-fA-F]{6}")
	assert_null(rx.search(_read(SRC_PATH)), "هیچ رنگِ هگزِ محلی در RegionBackdrop نیست ✓")
	var dir := DirAccess.open("res://scripts/environments")
	assert_not_null(dir, "پوشۀ محیط‌ها هست")
	dir.list_dir_begin()
	var f: String = dir.get_next()
	while f != "":
		if f.ends_with(".gd"):
			var t: String = _read("res://scripts/environments/" + f)
			assert_null(rx.search(t), "%s رنگِ هگز ندارد ✓" % f)
		f = dir.get_next()


func test_only_one_literal_color_is_allowed() -> void:
	# تنها استثنا: «پردهٔ سایه» که سیاهِ خالصِ بی‌بافت است و باید توضیح داشته باشد ✓
	var src := _read(SRC_PATH)
	var n := 0
	for l: String in src.split("\n"):
		if l.contains("Color(") and not l.contains("Array[Color]"):
			n += 1
			assert_true(l.contains("SHADOW_VEIL"), "تک‌رنگِ مجاز: %s" % l.strip_edges())
	assert_eq(n, 1, "یک Color(.) در کل فایل — بقیه از Palette ✓§۲")


func test_draw_only_consumes_the_plan() -> void:
	var body := _func_body("_draw")
	assert_gt(body.length(), 20, "بدنۀ _draw خوانده شد (وگرنه این تست دروغگو است ✗✓)")
	assert_true(body.contains("layers("), "_draw از پلانِ استاتیک می‌خواند ✓")
	assert_true(body.contains("match String(l.kind)"), "توزیعِ نوع در همان یک نقطه ✓")
	for banned: String in ["lerpf(", "darkened(", "lightened(", "brokenness(", "prop_density(",
			"bridges_built(", "light_color(", "sky_gradient(", "signature(", "base(", "Palette."]:
		assert_false(body.contains(banned),
				"`%s` در _draw ممنوع: تصمیمِ بصری باید در تابعِ استاتیک باشد (ADR-058) ✗✓" % banned)
