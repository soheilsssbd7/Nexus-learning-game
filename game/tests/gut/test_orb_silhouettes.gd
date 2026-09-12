extends GutTest
# ===========================================================================
# NEXUS — تست‌های تسک ۸.۵ (آیکون سه نوع کره §۶ + «تست سیلوئت» §۸)
# --------------------------------------------------------------------------
# DoD ۸.۵: «هر سه نوع از فاصله‌ی بازی معمولی قابل‌تشخیص فوری‌اند (تست سیلوئت)» ✓
# و §۱: سیلوئت باید در سیاه‌وسفیدِ کامل خوانا باشد ✓✗✓ در CIِ هدلس `_draw()` اجرا
# نمی‌شود ⇒ رندرِ پیکسلی ممکن نیست؛ جایش **امضایِ هندسه/کنتراست** را می‌نشانیم ✓✓:
# همان عدد‌هایی که `_draw()` مصرف می‌کند (پوششِ مساحت، دانه‌های چندوجهی، پرتوها،
# دنباله‌ها، دهانه، آلفا) — پس اگر کسی روزی فرم‌ها را یکی کند، این تست قرمز می‌شود ✓
# (تفسیر در ADR-059؛ رندرِ واقعی و قضاوتِ چشمی = فاز ۱۰ روی دستگاه ✓)
# ===========================================================================

const VISUAL := preload("res://scripts/gameplay/OrbVisual.gd")


func _orb(kind: int) -> OrbVisual:
	var v: OrbVisual = OrbVisual.new()
	v.radius = 44.0
	v.kind = kind
	v.glyph = "3"  # رقمِ نمونه: تستِ «عدد در مرکز» بی‌محتزا نباشد ✓
	add_child_autofree(v)
	return v


func _sig(kind: int) -> Dictionary:
	return _orb(kind).silhouette_signature()


func _placed_orb(cls: Script) -> WeightOrb:
	var o: WeightOrb = cls.new() as WeightOrb
	add_child_autofree(o)
	o.refresh_visual()
	return o


# ------------------------------------------------------------------ تمایز سه‌گانه
func test_the_three_kinds_are_three_different_forms() -> void:
	var n := _sig(OrbVisual.Kind.NUMBER)
	var g := _sig(OrbVisual.Kind.GHOST)
	var b := _sig(OrbVisual.Kind.BUBBLE)
	assert_true(VISUAL.signature_distance(n, g) >= 3, "عدد ↔ روح: حداقل سه ویژگی فرق کند")
	assert_true(VISUAL.signature_distance(g, b) >= 3, "روح ↔ حباب")
	assert_true(VISUAL.signature_distance(n, b) >= 3, "عدد ↔ حباب")
	assert_ne(str(n), str(g), "امضاها یکسان نیستند (وگرنه DoD ۸.۵ یعنی صفر ✗)")


func test_number_orb_reads_as_a_solid_crystal() -> void:
	# §۶ «کره‌ی شفاف با عدد در مرکز» + «ملموس» ⇒ بدنه‌ی پرِ چندوجهی با پرتوهای شکست ✓
	var s := _sig(OrbVisual.Kind.NUMBER)
	assert_eq(int(s.facets), 12, "کریستالِ دوازده‌وجهی (نه دایره‌ی صاف ✗)")
	assert_eq(int(s.spokes), 6, "پرتوهای داخلی ⇒ حسِ حجم ✓")
	assert_true(float(s.coverage) >= 0.90, "بدنه تقریباً پر است ⇒ %s" % str(s.coverage))
	assert_true(float(s.body_alpha) >= 0.55, "«شفاف» یعنی نور رد کند، نه نامرئی بودن")
	assert_false(bool(s.glyph_empty), "عدد در مرکز نشسته (§۶)")


func test_ghost_orb_is_a_translucent_ring_with_trailing_light() -> void:
	# §۶ «همیشه Ghost Violet، نیمه‌شفاف، «؟» نورِ کم‌سو» ⇒ حلقه + دیسکِ نرم + دنباله ✓
	var s := _sig(OrbVisual.Kind.GHOST)
	assert_eq(int(s.wisps), 3, "سه دنباله‌ی نور ⇒ «مجهول» حتی در سیاه‌وسفید ✓")
	assert_eq(int(s.spokes), 0, "روح پرتو ندارد؛ پرتو مالِ شیءِ سخت است ✓")
	assert_true(float(s.body_alpha) <= 0.62 + 0.001, "نیمه‌شفاف (§۶) ⇒ %s" % str(s.body_alpha))
	assert_true(float(s.coverage) < 0.90, "دیسکِ نرم، بدنه‌ی پر نیست")
	assert_true(float(s.highlight_alpha) < 0.4, "نورِ کم‌سو (§۶)، نه هایلایتِ جیغ ✗")


func test_negative_orb_is_an_open_bubble_not_a_sphere() -> void:
	# §۶ «حباب‌های کوچک شفاف با حرکت روبه‌بالا» ⇒ پوسته‌ی باز در پایین + حبابک ✓
	var s := _sig(OrbVisual.Kind.BUBBLE)
	assert_eq(int(s.facets), 0, "بدنه‌ی بسته نداریم ⇒ پوششِ صفر ✓")
	assert_true(float(s.coverage) <= 0.001, "داخلِ حباب خالی است (§۶ «شفاف») ✗ کره نباشد")
	assert_true(float(s.gap_deg) >= 20.0, "دهانه‌ی پایین: نشانه‌ی «رها شدن/بالا رفتن» ✓")
	assert_true(float(s.satellite) > 0.0, "حبابکِ اقماری ⇒ تمایزِ یک‌نگاه ✓")
	assert_true(float(s.body_alpha) <= 0.22 + 0.001, "حباب هرگز پر نمی‌شود")


func test_bubble_arc_is_exactly_a_circle_minus_the_gap() -> void:
	# باگِ نسخهٔ نخستِ ۸.۵: دهانه با `-PI/2` شروع می‌شد ⇒ هم سقف باز می‌شد و هم span
	# از ۲π رد می‌گشت (یک دورِ همپوش ⇒ «حباب» همان کره ✓✗). هدلس هیچ‌کدام را
	# نمی‌بیند ✗✓ پس span/start تابع‌اند و تست عددشان را می‌سنجد ✓✓
	var gap: float = VISUAL.gap_degrees_for(OrbVisual.Kind.BUBBLE)
	var span: float = VISUAL.bubble_arc_span(OrbVisual.Kind.BUBBLE)
	var start: float = VISUAL.bubble_arc_start(OrbVisual.Kind.BUBBLE)
	assert_true(absf(span + deg_to_rad(gap) - TAU) < 0.0001,
		"کمان + دهانه = یک دورِ کامل ⇒ نه بیشتر، نه کمتر")
	assert_true(absf(start - (PI * 0.5 + deg_to_rad(gap) * 0.5)) < 0.0001,
		"دهانه در **پایینِ** صفحه است (§۶ بالا رفتن ⇒ پایین باز ✓)")
	assert_true(absf(VISUAL.bubble_arc_span(OrbVisual.Kind.NUMBER) - TAU) < 0.0001,
		"کره‌ی عدد دهانه ندارد")


# --------------------------------------------------------------- رنگ‌ها: §۶ + §۸
func test_thermal_scale_only_encodes_magnitude_not_kind() -> void:
	var light := _placed_orb(WeightOrb)
	light.value = 1.0
	light.refresh_visual()
	var heavy := _placed_orb(WeightOrb)
	heavy.value = Palette.THERMAL_MAX_VALUE
	heavy.refresh_visual()
	assert_true(light.fill_color().is_equal_approx(Palette.SOFT_TEAL),
		"عددِ کوچک = Soft Teal (مقیاس گرمایی §۶)")
	assert_true(heavy.fill_color().is_equal_approx(Palette.AELORIA_GOLD),
		"عددِ بزرگ = Aeloria Gold")
	assert_eq(int(light.get("_visual").kind), int(OrbVisual.Kind.NUMBER),
		"فرم از نوعِ کره می‌آید، نه از اندازه ⇒ %s" % str(light.get("_visual").kind))


func test_ghost_is_always_ghost_violet_revealed_or_not() -> void:
	var g := _placed_orb(GhostOrb)
	assert_true(absf(g.fill_color().h - Palette.GHOST_VIOLET.h) < 0.001,
		"§۶: رنگ روح **ثابت** است (هیچ‌وقت با وزن عوض نمی‌شود)")
	assert_eq(str(g.display_text()), "?", "مجهول، عددِ مخفی را لو نمی‌دهد (ADR فاز ۲)")
	g.set_hidden_value(7.0)
	g.reveal()
	var v: OrbVisual = g.get("_visual") as OrbVisual
	assert_true(absf(v.fill_color.h - Palette.GHOST_VIOLET.h) < 0.001,
		"حالتِ کشف‌شده هم violet می‌ماند (§۶)")
	assert_true(v.fill_color.a < 1.0, "حتی پس از reveal نیمه‌شفاف می‌ماند ✓")
	assert_eq(str(v.glyph), "7", "پس از حل، عدد نشان داده می‌شود (نه پاسخِ زودهنگام ✗)")


func test_negative_bubble_rises_and_uses_the_bubble_kind() -> void:
	var n := _placed_orb(NegativeOrb)
	n.value = -3.0
	n.refresh_visual()
	var v: OrbVisual = n.get("_visual") as OrbVisual
	assert_eq(int(v.kind), int(OrbVisual.Kind.BUBBLE), "منفی ⇒ حباب، نه کره (§۶)")
	assert_true(str(v.glyph).begins_with("-"), "علامتِ منفی روی خودِ حباب هم هست ✓")
	# فازِ معلوم، نه «منتظرِ فریم» ✗✓ هدلس بی‌vsync ممکن است delta های ریزِ ۱۰µs بدهد و
	# آنگاه جابه‌جایی زیرِ آستانه می‌ماند ⇒ نوسانِ تست ✗ (flake = سمّ CI ✓). یک `_process`
	# دستی با deltaِ معلوم، همان مسیرِ کد را دقیقاً می‌سنجد ✓✓
	n._process(0.12)
	assert_true(v.position.y < -0.5,
		"§۶ «حرکت روبه‌بالا»: حباب شناور است (drift روی Visual، نه ریشه ✓)")
	n._process(1.0)
	assert_true(v.position.y <= 0.0, "حباب هرگز زیرِ جای خود پایین‌تر نمی‌رود ✓")
	n.is_placed = true
	n._process(0.12)
	assert_true(absf(v.position.y) < 0.001, "روی کفه که شد، drift باید صفر شود ✓")


func test_glyph_contrast_survives_black_and_white() -> void:
	# §۸ «در تست سیلوئت سیاه‌وسفید قابل‌تشخیص است» ⇒ عدد باید از بدنه جدا بماند؛
	# جداسازیِ رنگِ رقم/بدنه با luminance سنجیده می‌شود (در B&W همین تنها معیار است ✓)
	for c: Color in [Palette.SOFT_TEAL, Palette.AELORIA_GOLD, Palette.ghost_fill(0.62),
			Palette.negative_bubble(2.0), Palette.ghost_fill(0.85).lightened(0.2)]:
		var glyph: Color = Palette.text_on(c)
		var d: float = absf(glyph.get_luminance() - c.get_luminance())
		assert_true(d >= 0.2, "کنتراستِ رقم/بدنه ≥ ۰٫۲ ⇒ %s روی %s" % [str(glyph), str(c)])


func test_no_aggressive_red_in_any_orb_color() -> void:
	# §۸ «هیچ قرمز تهاجمی برای خطا استفاده نشده» ✓ روی کل طیفِ گرمایی سنجیده می‌شود
	for i: int in range(0, 13):
		var c: Color = Palette.thermal(float(i) * 0.9)
		assert_true(not (c.r > 0.85 and c.g < 0.45 and c.b < 0.45),
			"مقیاس گرمایی نباید به قرمزِ تهاجمی برسد (§۸)")
	for c: Color in [Palette.ghost_fill(0.62), Palette.negative_bubble(4.0)]:
		assert_true(not (c.r > 0.85 and c.g < 0.45 and c.b < 0.45), "رنگِ فرعی هم قرمز نیست")


func test_orb_is_big_enough_to_read_at_play_distance() -> void:
	# §۱/§۸: «از فاصله‌ی بازی معمولی» ⇒ کره نباید زیر ~۶۴px بیفتد ✗✓ (تستِ عددی،
	# نه سلیقه‌ای: شعاعِ پیش‌فرض وکفِ clampِ هر دو کنترل می‌شوند ✓)
	var v := _orb(OrbVisual.Kind.NUMBER)
	assert_true(v.radius * 2.0 >= 64.0, "قطرِ پیش‌فرض ≥ ۶۴px ⇒ %f" % (v.radius * 2.0))
	v.radius = 3.0
	assert_true(v.radius >= 8.0, "clampِ شعاع: حباب‌سازیِ تصادفیِ اندازه ممنوع ✓")
	var o := _placed_orb(WeightOrb)
	assert_true(o.radius * 2.0 >= 64.0, "کره‌های سطح‌ساز هم از همان سقف پایین‌تر نمی‌روند")
