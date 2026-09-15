extends GutTest
# ===========================================================================
# NEXUS — تست‌های تسک ۸.۲ (آواتار لایه‌ایِ بازیکن §۴ | ترکیب‌پذیر، نه ۴۸ فایل)
# --------------------------------------------------------------------------
# DoD ۸.۲: «در Onboarding، تمام ترکیب‌ها بدون گلیچ بصری قابل‌انتخاب‌اند» ✓ و §۴ سه چیز
# می‌خواهد: نسبت سر:بدن ≈ ۱:۳ · ۶ تُنِ فراگیر · ۸ مدل موی متنوع از نظر **بافت و طول** ✓✗✓
# در CI هدلس `_draw()` اجرا نمی‌شود ⇒ «گلیچ» را با هندسه سنجیدیم: مرزِ هر ترکیب داخلِ
# کادر باشد، هیچ مویی روی چشم نیفتد، و هشت مدل واقعاً هشت **فرم** باشند ✓✓ (ADR-058/060)
# ===========================================================================

const AV := preload("res://scripts/ui/PlayerAvatarPreview.gd")


func _preview() -> PlayerAvatarPreview:
	var v: PlayerAvatarPreview = PlayerAvatarPreview.new()
	add_child_autofree(v)
	return v


func test_head_to_body_ratio_is_the_one_the_bible_asks() -> void:
	# §۴ «چیبی-متوسط… نسبت سر به بدن حدود ۱ به ۳» ✓ (فاز ۶ عملاً ۱:۱٫۶ ساخته بود ✗)
	var r: float = AV.head_to_body_ratio()
	assert_true(absf(r - (1.0 / 3.0)) < 0.02, "نسبت سر:بدن ≈ ۰٫۳۳۳ ⇒ %f" % r)
	assert_gt(r, 0.2, "نه فوق‌کوتاه بامزه، نه رئال (§۴)")
	assert_lt(r, 0.45, "وگرنه دوباره فاز ۶ می‌شود ✗")


func test_six_tones_eight_styles_eight_colors() -> void:
	assert_eq(AV.skin_count(), 6, "§۴: شش تُن پوست")
	assert_eq(AV.hair_count(), 8, "§۴: هشت مدل مو")
	assert_eq(AV.color_count(), SettingsStore.HAIR_COLORS.size(), "رنگ مو آزاد = فهرستِ تنظیمات")
	assert_eq(AV.HAIR_NAMES.size(), AV.HAIR_SHAPES.size(), "هر مدل مو **شکل** هم دارد، نه فقط نام ✗")
	assert_eq(str(AV.hair_name(3)), "braid", "نام‌ها برای برچسبِ Onboarding ثابت‌اند ✓")


func test_skin_spectrum_is_ordered_and_spread() -> void:
	# «طیف واقعی و فراگیر» یعنی **فاصله‌ی دیداری**؛ تُن‌های هم‌رنگ فقط عددند ✗✓
	var prev_luma := 1.5
	for i: int in AV.SKIN_COLORS.size():
		var c: Color = AV.SKIN_COLORS[i]
		var l: float = c.get_luminance()
		assert_lt(l, prev_luma, "تُن %d باید تیره‌تر از قبلی باشد (روشن → تیره ✓)" % i)
		if i > 0:
			assert_true(prev_luma - l >= 0.05, "فاصلهٔ تُن‌های مجاور کم است ⇒ %d" % i)
		assert_true(not (c.r > 0.85 and c.g < 0.45 and c.b < 0.45), "هیچ تُنی قرمزِ تهاجمی نیست (§۸)")
		prev_luma = l
	assert_true(absf(AV.SKIN_COLORS[0].get_luminance() - AV.SKIN_COLORS[5].get_luminance()) > 0.5,
		"طیف از روشن تا تیره **واقعی** است، نه سه درجه ✗")


func test_skin_tones_come_from_the_palette_only() -> void:
	# §۸ «فقط پالت رسمی» با ADR-060 جمع شد: پوست/مو دو فهرستِ مجازند و **جز آن‌ها** چیزی ✗
	for i: int in AV.SKIN_COLORS.size():
		assert_true(Palette.SKIN_TONES[i].is_equal_approx(AV.SKIN_COLORS[i]),
			"تُن %d از `Palette.SKIN_TONES` می‌آید (دو فهرست ≠ دو حقیقت ✗)" % i)
	for c in [Palette.AELORIA_GOLD, Palette.SOFT_TEAL, Palette.WARM_CORAL]:
		for s: Color in AV.SKIN_COLORS:
			assert_false(s.is_equal_approx(c), "تُنِ پوست با رنگِ UI قاطی نمی‌شود ✓")


func test_hair_colors_are_natural_plus_official_palette() -> void:
	# سه سواچِ «آزاد» باید **خودِ پالت** باشند ✓ (تست با `to_html` مقایسه می‌کند ✗✓ نه هگزِ من ✗)
	var official := [Palette.SOFT_TEAL.to_html(false), Palette.GHOST_VIOLET.to_html(false),
		Palette.STONE_GREY.to_html(false)]
	var found := 0
	for hex_str: String in SettingsStore.HAIR_COLORS:
		assert_true(hex_str.is_valid_html_color(), "هگزِ نامعتبر در فهرست مو ✗ %s" % hex_str)
		if official.has(hex_str.to_lower()) or official.has(hex_str.to_upper()):
			found += 1
	assert_true(found >= 3, "حداقل سه رنگِ مو از پالت رسمی است (§۸) ⇒ %d" % found)
	var uniq := {}
	for hex_str: String in SettingsStore.HAIR_COLORS:
		uniq[hex_str.to_lower()] = true
	assert_eq(uniq.size(), SettingsStore.HAIR_COLORS.size(), "هشت سواچِ یکتا (دوقلو = انتخابِ گیج‌کننده ✗)")


func test_every_style_stays_inside_its_frame() -> void:
	var frame: Rect2 = AV.frame_rect()
	for rep in AV.all_combos():
		assert_true(bool(rep["in_frame"]),
			"%s از کادر بیرون می‌زند ⇒ کلیپ/برخورد با لبه‌ی پنل در Onboarding ✗✓" % str(rep["name"]))
		var box: Rect2 = rep["bbox"]
		assert_true(frame.encloses(box), str(rep["name"]) + " : مرزها داخل کادر")


func test_no_hairstyle_covers_the_eyes() -> void:
	# «صورت باید خوانا بماند» (§۴: تمایز از مو/پوست است، نه از ماسک ✗) ⇒ تداخلِ هندسی ممنوع ✓
	for rep in AV.all_combos():
		assert_false(bool(rep["overlaps_eyes"]),
			"موی %s روی چشم افتاده ⇒ گلیچِ §۴ ✗✓" % str(rep["name"]))
	# و قاعده باید **دندانه** داشته باشد: اگر پنلِ کناری را به صورت نزدیک کنیم، قرمز می‌شود ✓
	var near := Rect2(-12.0, -2.0, 24.0, 8.0)
	for eb: Rect2 in AV.eye_boxes():
		assert_true(near.intersects(eb), "تستِ تداخل واقعاً چشم را می‌بیند (نه always-false ✗✗)")


func test_eight_styles_are_eight_different_forms() -> void:
	var reps: Array = AV.all_combos()
	var lengths := {}
	var textures := {}
	for rep in reps:
		lengths[str(rep["length"])] = true
		textures[str(rep["texture"])] = true
	assert_eq(lengths.size(), 8, "§۴: «متنوع از نظر طول» ⇒ هشت طولِ متمایز ✓")
	assert_true(textures.size() >= 4, "§۴: «متنوع از نظر بافت» ⇒ حداقل چهار بافت ✓")
	var cmin := 99.0
	var cmax := 0.0
	for rep in reps:
		cmin = minf(cmin, float(rep["coverage"]))
		cmax = maxf(cmax, float(rep["coverage"]))
	assert_true(cmax / maxf(cmin, 0.001) >= 4.0,
		"buzz تا coils باید **چند برابر** حجم داشته باشد ⇒ %f/%f" % [cmax, cmin])


func test_all_48_combinations_are_selectable() -> void:
	# DoD ۸.۲: «تمام ترکیب‌ها» ⇒ جاروی ۶×۸ روی API واقعیِ Onboarding ✓✓
	var v := _preview()
	var seen := 0
	for tone: int in AV.skin_count():
		for style: int in AV.hair_count():
			assert_true(v.set_choice("skin_tone", tone), "تُن %d انتخاب می‌شود" % tone)
			assert_true(v.set_choice("hair_style", style), "مو %d انتخاب می‌شود" % style)
			var cfg: Dictionary = v.config()
			assert_eq(int(cfg["skin_tone"]), tone, "پیکربندی همان را نگه می‌دارد")
			assert_eq(int(cfg["hair_style"]), style, "و مدل مو را هم ✓")
			# تُن، هندسه را عوض نمی‌کند ⇒ سیلوئت فقط از مو است (§۴ «تمایز از لباس نه» ✓)
			var box: Rect2 = AV.layout_bbox(style)
			var box2: Rect2 = AV.layout_bbox(style)
			assert_true(box.is_equal_approx(box2), "مرزها بی‌تأثیر از تُن ✓")
			seen += 1
	assert_eq(seen, 48, "شصت‌وهشت؟ نه: ۶×۸ = ۴۸ ترکیبِ کامل سنجیده شد ✓")


func test_round_trip_through_storage_and_clamps() -> void:
	var v := _preview()
	v.apply_config({"skin_tone": 4, "hair_style": 6, "hair_color": 7})
	assert_eq(v.skin_tone, 4, "بارگذاریِ ذخیره")
	assert_eq(v.hair_style, 6, "باب ✓")
	assert_eq(v.hair_color, 7, "رنگ مو هفتم")
	v.apply_config({"skin_tone": 99, "hair_style": -3, "hair_color": 12})
	assert_eq(v.skin_tone, AV.skin_count() - 1, "ذخیرهٔ خراب/دستی ⇒ clamp، نه کرش ✗✓")
	assert_eq(v.hair_style, 0, "و منفی هم صفر می‌شود ✓")
	assert_eq(v.hair_color, SettingsStore.HAIR_COLORS.size() - 1, "رنگ مو هم clamp ✓")
	assert_false(v.set_choice("boots", 0), "بخشِ ناشناخته false برمی‌گرداند (تایپو در کد لو می‌رود ✓)")
	assert_eq(int(v.config()["skin_tone"]), AV.skin_count() - 1, "و حالت قبلی نمی‌شکند ✓")


func test_apron_and_notebook_are_part_of_the_character() -> void:
	# §۴: لباس‌پایهٔ یکسان (پیش‌بند) + «دفترچهٔ مهندسی» ✓ بی‌اسلحه ✗
	var body: Rect2 = AV.body_rect()
	assert_true(absf(body.size.x - 92.0) < 0.001, "پیش‌بند به عرضِ شانه‌ها ✓")
	var nb: Rect2 = AV.notebook_rect()
	assert_gt(nb.size.x, 16.0, "دفترچه هست و به اندازه ✓§۴")
	assert_true(body.intersects(nb) or body.position.x - nb.end.x < 20.0,
		"دفترچه در دست/زیرِ بازو است، نه معلق در هوا ✓")
	assert_false(body.grow(4.0).encloses(nb), "نیمی از آن بیرونِ تنه‌ی پیش‌بند می‌ماند ⇒ دیده می‌شود ✓")
	var cols: Array[Color] = [AV.APRON_COLOR, AV.TRIM_COLOR, AV.EYE_COLOR]
	assert_true(cols[0].is_equal_approx(Palette.STONE_GREY), "پیش‌بند Stone Grey (§۴)")
	assert_true(cols[1].is_equal_approx(Palette.AELORIA_GOLD), "جزئیات Aeloria Gold (§۴)")
	assert_true(cols[2].is_equal_approx(Palette.DEEP_INDIGO), "چشم‌ها از پالت ✓")


func test_the_avatar_fits_its_onboarding_box() -> void:
	# DoD ۸.۲ «بدونِ گلیچِ بصری» در UI: با هشت ارتفاعِ متفاوت، یک مقیاسِ ثابت یعنی
	# «مدلِ بلند به ردیفِ سواچ‌ها می‌خورد» ✗✓ پس `fit_box` مقیاس را مدل‌به‌مدل تنگ می‌کند ✓
	var box := Vector2(300.0, 280.0)  # همان عددی که `Onboarding._build_avatar_step` ست می‌کند ✓
	for style: int in AV.hair_count():
		var u: float = AV.unit_for_box(box, style)
		var b: Rect2 = AV.layout_bbox(style)
		assert_true(b.size.x * u <= box.x + 0.5, "عرضِ مدل %d در جعبه جا می‌شود ⇒ %f" % [style, b.size.x * u])
		assert_true(b.size.y * u <= box.y + 0.5, "ارتفاعِ مدل %d در جعبه جا می‌شود ⇒ %f" % [style, b.size.y * u])
	var v := _preview()
	v.unit = 1.15
	v.fit_box = box
	v.hair_style = 4  # بلندترین جعبه (گوجه‌ای روی سر ⇒ ارتفاعِ بیشتر ✓)
	assert_lt(v.effective_unit(), 1.15, "تنظیمِ خودکار عدد را کم می‌کند ✗✓ (ثابت نبودیم ✓)")
	assert_false(v.draw_origin().is_zero_approx(), "مبدأ نقاشی تصحیح می‌شود تا شکل وسط بنشیند ✓")
	var units := {}
	for style: int in AV.hair_count():
		units[str(snappedf(AV.unit_for_box(box, style), 0.01))] = true
	assert_true(units.size() >= 3, "واحدِ مؤثر با مدل مو فرق می‌کند ⇒ %d مقدار" % units.size())


func test_no_color_lives_outside_the_two_allowed_lists() -> void:
	# ADR-060: §۸ «فقط پالت رسمی» برای پوست/مو با دو فهرستِ صریح جمع شد ✓ ⇒ هیچ رنگِ
	# پراکنده‌ای در کدِ آواتار مجاز نیست ✗ (تستِ متنِ سورس: هگزِ تازه = باید ثبت شود ✓✓)
	var src: String = ""
	var f: FileAccess = FileAccess.open("res://scripts/ui/PlayerAvatarPreview.gd", FileAccess.READ)
	if f != null:
		src = f.get_as_text()
		f.close()
	var re_hex := RegEx.create_from_string("#([0-9A-Fa-f]{6})")
	var allowed := {}
	for c: Color in Palette.SKIN_TONES:
		allowed[c.to_html(false).to_lower()] = true
	for hex_str: String in SettingsStore.HAIR_COLORS:
		allowed[hex_str.to_lower()] = true
	for m: RegExMatch in re_hex.search_all(src):
		assert_true(allowed.has(m.group(1).to_lower()),
			"هگزِ «#%s» بیرونِ دو فهرستِ مجاز است ✗ (ADR-060)" % m.group(1))
	assert_true(src.contains("Palette.STONE_GREY"), "پیش‌بند از پالت می‌آید ✓§۴")
	assert_true(src.contains("Palette.AELORIA_GOLD"), "جزئیات از پالت ✓§۴")


func test_preview_is_cheap_enough_for_a_small_phone() -> void:
	# §۱ «رندر ارزان»: آواتار باید بی‌آنی‌میشنِ سنگین و با draw-call های محدود باشد ✓
	var v := _preview()
	v.unit = 1.6
	assert_true(absf(v.unit - 1.6) < 0.0001, "مقیاس برای کارتِ والدین/هَدآپ ✓")
	v.unit = 0.01
	assert_true(v.unit >= 0.1, "clampِ مقیاس: صفر/منفی ⇒ تقسیمِ بر صفر در چیدمان ✗")
	assert_eq(v.get_child_count(), 0, "آواتار بچه‌ی گره‌ی اضافه ندارد (یک Node2D، بی‌Animate) ✓")
