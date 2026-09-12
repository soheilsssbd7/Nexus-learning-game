extends GutTest
# ===========================================================================
# NEXUS — تست‌های تسک ۸.۱ (Aria: ایکوساهدرون + هسته‌ی شیدری + تیونینگ §۳)
# --------------------------------------------------------------------------
# چرا اصلاً این شکل؟ در CIِ **هدلس** `_draw()` اجرا نمی‌شود ✗✓ پس هر «قانونِ سند
# هنری» یا باید در توابعِ خالص/پراپرتی‌ها زندگی کند (اینجا همین کار کردیم ✓) یا
# در CI سبزِ توخالی می‌ماند ✗✗. پس: هندسه از `AriaCrystal` ایستا، رنگ‌ها از
# `AriaAvatar`، و رفتارِ شیدر از روی `material` + متنِ سورسِ شیدر ✓
# ===========================================================================

const ARIA_SCENE := "res://scenes/characters/Aria.tscn"
const CRYSTAL := preload("res://scripts/characters/AriaCrystal.gd")
const CORE := preload("res://scripts/characters/AriaCore.gd")
const SHADER_PATH := "res://assets/shaders/aria_core.gdshader"


func _make() -> AriaAvatar:
	var scene: AriaAvatar = load(ARIA_SCENE).instantiate() as AriaAvatar
	assert_not_null(scene, "صحنه‌ی Aria لود می‌شود")
	add_child_autofree(scene)
	return scene


# ------------------------------------------------------------------ §۳ هندسه
func test_body_is_a_real_icosahedron() -> void:
	assert_eq(CRYSTAL.vertex_count(), 12, "ایکوساهدرون دوازده رأس دارد (§۳ «بیست‌وجهی»)")
	assert_eq(CRYSTAL.face_count(), 20, "بیست وجه ✓، نه شش‌وجهیِ فاز ۵")
	assert_eq(CRYSTAL.edge_count(), 30, "سی لبه = مؤلفهٔ صحتِ توپولوژی ✓")


func test_all_vertices_lie_on_the_unit_sphere() -> void:
	var v: PackedVector3Array = CRYSTAL.icosahedron_vertices()
	assert_eq(v.size(), 12, "دوازده رأس")
	for i: int in v.size():
		assert_true(absf(v[i].length() - 1.0) < 0.0001, "رأس %d روی کرانهٔ واحد است" % i)
	# رأس‌های مقابلِ هم ⇒ قرینگی ✓ (اگر یک علامتِ φ اشتباه شود، همینجا می‌شکند ✗✓)
	var seen := {}
	for i: int in v.size():
		seen[str(v[i].normalized())] = true
	assert_eq(seen.size(), 12, "رأس‌ها یکتا هستند")


func test_faces_are_twenty_distinct_triangles() -> void:
	var f: PackedInt32Array = CRYSTAL.icosahedron_faces()
	assert_eq(f.size(), 60, "۲۰ وجه × ۳ رأس")
	var uniq := {}
	for i: int in range(0, f.size(), 3):
		var tri: Array[int] = [f[i], f[i + 1], f[i + 2]]
		tri.sort()
		assert_false(tri[0] == tri[1] or tri[1] == tri[2], "مثلثِ دَژَه نداریم")
		uniq[str(tri)] = true
	assert_eq(uniq.size(), 20, "بیست وجهِ یکتا (بدونِ تکرارِ رویه‌ای)")


func test_diameter_matches_the_bible_window() -> void:
	var aria := _make()
	var body: AriaCrystal = aria.get_node("Body") as AriaCrystal
	var d: float = body.diameter_px()
	assert_true(d >= 40.0 and d <= 60.0, "§۳: قطر تقریبی ۴۰ تا ۶۰ پیکسل ⇒ %f" % d)
	assert_true(body.radius >= 20.0 and body.radius <= 30.0, "شعاع در همان بازه")


# ----------------------------------------------------- §۳ بدنه همیشه طلایی می‌ماند
func test_state_never_repaints_the_body_only_the_core() -> void:
	var aria := _make()
	var anim: AnimationPlayer = aria.get_node("Anim") as AnimationPlayer
	var lib: AnimationLibrary = anim.get_animation_library("") as AnimationLibrary
	var forbidden := PackedStringArray(
		["Body:self_modulate", "Body:modulate", "Body:color", "Body:material"])
	for state: String in AriaAvatar.STATES:
		assert_true(aria.play_state(state), "%s قابل‌پخش است" % state)
		var clip: Animation = lib.get_animation(state)
		assert_not_null(clip, state + " clip دارد")
		for ti: int in clip.get_track_count():
			var path: String = str(clip.track_get_path(ti))
			for bad: String in forbidden:
				assert_ne(path, bad,
					"§۳: بدنه طلایی می‌ماند؛ تنها `Core` رنگ عوض می‌کند (%s)" % state)


func test_body_gold_to_white_gradient_and_alpha_window() -> void:
	# §۳: «گرادیان از طلایی در مرکز به سفید در لبه‌ها با شفافیت ۷۰ تا ۸۵٪» ✓
	var center: Color = CRYSTAL.face_fill_color(0.0, 1.0)
	var edge: Color = CRYSTAL.face_fill_color(1.0, 0.0)
	# آلفا عمداً outside است ✓§۳ ⇒ مقایسه فقط روی rgb (وگرنه ۰٫۸۵ در برابر ۱٫۰ ✗)
	var center_rgb := Color(center.r, center.g, center.b, 1.0)
	assert_true(center_rgb.is_equal_approx(Palette.AELORIA_GOLD), "مرکز = Aeloria Gold")
	assert_true(edge.r > center.r and edge.g > center.g and edge.b > center.b,
		"لبه به Cloud White نزدیک‌تر است (روشن‌تر در هر سه مؤلفه)")
	for front: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var a: float = CRYSTAL.face_fill_color(0.5, front).a
		assert_true(a >= 0.70 - 0.0001 and a <= 0.85 + 0.0001,
			"آلفای وجه در بازهٔ §۳ است ⇒ %f" % a)
	assert_true(CRYSTAL.edge_line_alpha(1.0, 0.55) <= 0.95 + 0.0001,
		"لبه‌ی ممتد به دوناتِ پرنور تبدیل نمی‌شود ✓")


func test_energy_lines_never_go_completely_dark() -> void:
	# §۳ «به‌جای چشم/دهان، خطوطِ نور» ⇒ اگر آلفا صفر شود، آریا بی‌صورتِ سیاه می‌شود ✗✓
	for i: int in range(5):
		var a: float = CRYSTAL.streak_alpha_for(i, 5, 1.37, 0.35, 0.55)
		assert_gt(a, 0.0, "رگه %d هرگز خاموشِ کامل نیست" % i)
		assert_true(a <= 1.0, "آلفای معتبر")
	var quiet: float = CRYSTAL.streak_alpha_for(0, 5, 0.0, 0.0, 0.55)
	assert_gt(quiet, 0.0, "با rate=0 هم نور می‌ماند (حالتِ بی‌حرکت ≠ بی‌نوری)")


# ------------------------------------------------------------- §۳ هسته + شیدر
func test_core_uses_the_radial_shader_with_the_live_radius() -> void:
	var aria := _make()
	var core: AriaCore = aria.get_node("Body/Core") as AriaCore
	assert_true(core.is_using_shader(), "§۱ «گرادیان نرم» با shader روی دیسک می‌آید")
	var mat: ShaderMaterial = core.material as ShaderMaterial
	assert_not_null(mat, "متریالِ شیدری به نود وصل است")
	assert_true(str(mat.shader.resource_path).ends_with("aria_core.gdshader"),
		"شیدر از assets/shaders بارگذاری می‌شود (نه از کجا ✗)")
	# همگامیِ شعاع: اگر یونیفورم فراموش شود، گرادیان با هندسه نمی‌خواند ✗
	assert_true(absf(float(mat.get_shader_parameter("radius")) - core.radius) < 0.0001,
		"یونیفورمِ radius با پراپرتی زنده یکی است")
	core.radius = core.radius * 0.5
	assert_true(absf(float(mat.get_shader_parameter("radius")) - core.radius) < 0.0001,
		"با تغییرِ شعاع هم یونیفورم تازه می‌شود ✓")


func test_shader_takes_its_color_from_modulate_not_from_itself() -> void:
	# §۸: «فقط پالت رسمی» ⇒ شیدر حقّ ندارد رنگِ اختراعی داشته باشد ✓✓
	var f: FileAccess = FileAccess.open(SHADER_PATH, FileAccess.READ)
	assert_not_null(f, "سورسِ شیدر در مخزن است (بدونِ باینری ✓)")
	if f == null:
		return
	var src: String = f.get_as_text()
	f.close()
	assert_true(src.contains("shader_type canvas_item"), "canvas_item چون روی Node2D است")
	var re_lit := RegEx.create_from_string(r"vec3\s*\(\s*0?\.\d")
	var hits := re_lit.search_all(src)
	assert_eq(hits.size(), 0, "رنگِ هاردکد در شیدر ممنوع ✓ (رنگ = self_modulate)")
	assert_true(src.contains("COLOR.rgb"), "خروجی از COLOR (یعنی modulate) ساخته می‌شود")


func test_core_state_colors_are_official_palette_derivations() -> void:
	# جدول §۳؛ رنگ‌ها باید **مشتقِ** پالت باشند نه هگزِ دست‌نویس ✓
	var bases := [Palette.AELORIA_GOLD, Palette.SOFT_TEAL, Palette.WARM_CORAL,
		Palette.CLOUD_WHITE]
	for state: String in AriaAvatar.STATES:
		var c: Color = AriaAvatar.core_color_for(state)
		var near := 1.0
		for b: Color in bases:
			near = minf(near, absf(c.get_h() - b.get_h()))
		assert_true(near < 0.06, "%s: هویّت با یکی از چهار رنگِ رسمی یکی است ⇒ %s" % [state, str(c)])
	var concerned: Color = AriaAvatar.core_color_for(AriaAvatar.STATE_CONCERNED)
	assert_true(concerned.get_saturation() < Palette.WARM_CORAL.get_saturation(),
		"§۳: Warm Coral «کم‌رنگ» (هرگز قرمز کامل ✗)")
	assert_true(not (concerned.r > 0.85 and concerned.g < 0.45 and concerned.b < 0.45),
		"§۸: هیچ قرمزِ تهاجمی در هیچ حالتی نیست")
	assert_true(AriaAvatar.core_color_for(AriaAvatar.STATE_IDLE)
		.is_equal_approx(Palette.AELORIA_GOLD), "idle = طلاییِ خالص (§۳)")


func test_each_state_carries_its_own_light_mood() -> void:
	var aria := _make()
	var body: AriaCrystal = aria.get_node("Body") as AriaCrystal
	assert_eq(AriaAvatar.MOODS.size(), AriaAvatar.STATES.size(), "برای هر حالت یک حس هست")
	for state: String in AriaAvatar.STATES:
		assert_true(AriaAvatar.MOODS.has(state), state + " در جدولِ MOODS هست")
		assert_true(aria.play_state(state), state)
		var m: Array = AriaAvatar.mood_for(state)
		assert_true(absf(body.streak_rate - float(m[1])) < 0.0001,
			"سرعتِ رگه‌ها از §۳ می‌آید نه از حدس ✓")
		assert_true(absf(body.streak_alpha - float(m[2])) < 0.0001, "روشناییِ رگه‌ها")
	var idle: Array = AriaAvatar.mood_for(AriaAvatar.STATE_IDLE)
	var think: Array = AriaAvatar.mood_for(AriaAvatar.STATE_THINKING)
	var hint: Array = AriaAvatar.mood_for(AriaAvatar.STATE_HINT)
	var worr: Array = AriaAvatar.mood_for(AriaAvatar.STATE_CONCERNED)
	assert_true(float(think[1]) < float(idle[1]), "§۳ thinking: کندتر و دورانی")
	assert_true(float(worr[2]) < float(idle[2]), "§۳ concerned: کم‌فروغ‌تر")
	assert_true(float(hint[2]) > float(idle[2]), "§۳ hint: پالسِ روشن")
	var cele: Color = AriaAvatar.mood_for(AriaAvatar.STATE_CELEBRATING)[3] as Color
	assert_true(cele.is_equal_approx(Palette.SOFT_TEAL),
		"§۳ «ترکیب Gold + Teal»: Teal را رگه‌ها حمل می‌کنند ✓")


func test_hint_emits_a_directional_pulse() -> void:
	var aria := _make()
	var body: AriaCrystal = aria.get_node("Body") as AriaCrystal
	assert_lt(body.pulse_level(), 0.001, "آغاز: بی‌پالس")
	aria.hint_target = Vector2(-240.0, 0.0)
	assert_true(aria.play_state(AriaAvatar.STATE_HINT), "hint پخش می‌شود")
	assert_gt(body.pulse_level(), 0.5, "پالسِ §۳ شلیک شد (و در ۰٫۴ ثانیه خاموش می‌شود)")
	assert_true(body.pulse_direction().x < 0.0, "جهت = سمتِ هدفی که صحنه داده")
	body.pulse_toward(Vector2.ZERO)
	assert_gt(body.pulse_level(), 0.5, "پالسِ شعاعی وقتی جهت نداریم ✓")


func test_missing_shader_falls_back_but_says_so() -> void:
	var aria := _make()
	var core: AriaCore = aria.get_node("Body/Core") as AriaCore
	core.use_shader = false
	core._build_material()
	assert_false(core.is_using_shader(), "مسیرِ پشتیبان فعال می‌شود")
	assert_null(core.material, "بی‌شیدر ⇒ متریالی نصب نیست")
	assert_true(CORE.SHADER_PATH.ends_with("aria_core.gdshader"),
		"آدرسِ شیدر در کد و روی دیسک یکی است")
