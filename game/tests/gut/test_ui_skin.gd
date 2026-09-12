extends GutTest
# ===========================================================================
# NEXUS — تست‌های تسک ۸.۴ «الف» (UI Skin | §۷: فونت، کفِ اندازه، کنتراست، آیکون)
# --------------------------------------------------------------------------
# DoD ۸.۴ سند ۰۴: «تست دسترس‌پذیری: تمام دکمه‌ها حداقل ۴۸×۴۸px، کنتراست متن/پس‌زمینه
# قابل‌قبول» ✓✗ بندِ «قابل‌قبول» بدونِ عدد بی‌معنی است ⇒ آن را به **WCAG 2.2 AA (1.4.3)**
# قفل کردیم (۴٫۵ برای متن، عددی که از بیرون می‌آید نه از سلیقۀ من ✓✓) و تابعش در
# `Palette.contrast_ratio()` است؛ این‌جا اول خودِ ریاضی را با مقادیرِ مرجع می‌سنجیم ✗✓
# (اگر فرمول غلط باشد، همه‌ی assertهای کنتراست دروغ می‌گویند ✓✓) بعد تم/فونت/آیکون.
# بخش «ب» (ممیزیِ همهٔ صحنه‌ها) در `test_a11y_scenes.gd` است ✓
# ===========================================================================

const SKIN_DIR := "res://scripts/ui"
const ICONS_DIR := "res://assets/art/icons"


func after_each() -> void:
	Loc.set_locale(Loc.default_locale())


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s: String = f.get_as_text()
	f.close()
	return s


# --------------------------------------------------------------------------
# ۱) خودِ سنجش ✓ (فرمول، نه ادعا)
# --------------------------------------------------------------------------
func test_contrast_formula_matches_wcag_reference_values() -> void:
	assert_true(absf(Palette.contrast_ratio(Color.WHITE, Color.BLACK) - 21.0) < 0.01,
			"سفید/سیاه باید دقیقاً ۲۱٫۰ باشد ✓ (اگر این گرفت، خطی‌سازی sRGB غلط است ✗)")
	var grey := Color(0.5019608, 0.5019608, 0.5019608)
	assert_true(absf(Palette.contrast_ratio(grey, Color.BLACK) - 5.3172) < 0.02,
			"خاکستری ۵۰٪ روی سیاه = ۵٫۳۱ ✓ (مقدارِ مرجعِ WCAG)")
	assert_true(absf(Palette.contrast_ratio(grey, grey) - 1.0) < 0.0001, "هم‌رنگ ⇒ ۱٫۰ ✓")
	assert_true(absf(Palette.contrast_ratio(Palette.CLOUD_WHITE, Palette.DEEP_INDIGO) - 11.2397) < 0.02,
			"متنِ اصلی روی ایندیگو ✓§۲")


func test_relative_luminance_is_ordered() -> void:
	assert_gt(Palette.relative_luminance(Palette.CLOUD_WHITE),
			Palette.relative_luminance(Palette.AELORIA_GOLD))
	assert_gt(Palette.relative_luminance(Palette.AELORIA_GOLD),
			Palette.relative_luminance(Palette.DEEP_INDIGO))
	assert_lt(Palette.relative_luminance(Palette.DEEP_INDIGO), 0.06, "ایندیگو واقعاً تیره است ✓")


func test_text_on_picks_by_measured_ratio() -> void:
	# نسخهٔ قبلی با آستانۀ لومینانس (`> 0.55`) کار می‌کرد ✗ روی خاکستریِ سنگی می‌سوخت ✓✓
	assert_eq(Palette.text_on(Palette.DEEP_INDIGO), Palette.CLOUD_WHITE, "روی تیره ⇒ ابری ✓")
	assert_eq(Palette.text_on(Palette.AELORIA_GOLD), Palette.DEEP_INDIGO, "روی طلایی ⇒ ایندیگو ✓")
	# (الف) تعهدِ واقعیِ تابع: **بهترینِ دو جوهر** را انتخاب کند ✗✓ نه «همیشه AA» — چون برای
	# یک رنگِ میانی هیچ‌کدام از دو جوهرِ §۲ به ۴٫۵ نمی‌رسد و ادعایِ «همیشه» دروغ بود ✓✓
	for c: Color in [Palette.CLOUD_WHITE, Palette.AELORIA_GOLD, Palette.SOFT_TEAL,
			Palette.WARM_CORAL, Palette.STONE_GREY, Palette.GHOST_VIOLET, Palette.MUTED_TEXT,
			Palette.STONE_UI, Palette.DEEP_INDIGO]:
		var picked: Color = Palette.text_on(c)
		var best: float = maxf(Palette.contrast_ratio(Palette.CLOUD_WHITE, c),
				Palette.contrast_ratio(Palette.DEEP_INDIGO, c))
		assert_true(Palette.contrast_ratio(picked, c) >= best - 0.001,
				"«%s»: جوهرِ %s بهترین نیست (%f < %f) ✗" % [c.to_html(), picked.to_html(),
				Palette.contrast_ratio(picked, c), best])
	# (ب) و روی **هر پس‌زمینۀ واقعیِ UI** (تُن‌های دکمه) کفِ AA برقرار است ✓§۷ DoD
	for tone: String in UIKit.TONES.keys():
		var bg: Color = (UIKit.TONES[tone] as Dictionary)["bg"] as Color
		assert_true(Palette.contrast_ratio(Palette.text_on(bg), bg) >= Palette.AA_TEXT_RATIO,
				"تُن «%s» با جوهرِ انتخابی AA نیست (شد %f) ✗✓" % [tone,
				Palette.contrast_ratio(Palette.text_on(bg), bg)])
	# (ج) محدودیت را می‌دانیم و ثبت می‌کنیم: خاکستریِ ویرانی هیچ‌جا سطحِ متنِ کدساز نیست؛
	# اگر روزی بشود، باید زیرِ رقم plate گرفت ✓ (نه این‌که تست را شل کنیم ✗✓)
	assert_true(Palette.contrast_ratio(Palette.text_on(Palette.STONE_GREY), Palette.STONE_GREY)
			< Palette.AA_TEXT_RATIO, "خاکستریِ میانی با هیچ جوهرِ §۲ AA نمی‌شود ✓ (مستند)")


# --------------------------------------------------------------------------
# ۲) تُن‌های دکمه = سنجیده‌شده ✓ (ریشۀ تغییر: stone از ۳٫۰۵ به ۵٫۰۲ رسید)
# --------------------------------------------------------------------------
func test_every_button_tone_passes_aa() -> void:
	for tone: String in UIKit.TONES.keys():
		var spec: Dictionary = UIKit.TONES[tone] as Dictionary
		var bg: Color = spec["bg"]
		var fg: Color = spec["fg"]
		var ratio: float = Palette.contrast_ratio(fg, bg)
		assert_true(ratio >= Palette.AA_TEXT_RATIO,
				"تُن «%s» کنتراستش %f است، AA ≥ %f ✗✓ (§۸ DoD)" % [tone, ratio, Palette.AA_TEXT_RATIO])


func test_stone_tone_is_the_deepened_grey_not_another_color() -> void:
	# §۲ رنگِ تازه برای ما نمی‌سازد ✗✓ پس همان هوی سنگی با ۲۵٪ تاریکی ✓ (و تست می‌گوید چرا)
	var spec: Dictionary = UIKit.TONES["stone"] as Dictionary
	var bg: Color = spec["bg"]
	assert_true(bg == Palette.STONE_UI, "تُنِ سنگی از پالت می‌آید، نه هگزِ در‌ودستی ✓§۲")
	var ref: Color = Palette.STONE_GREY.darkened(0.25)  # همین را `const` نمی‌توانست ✗✓
	assert_true(absf(bg.r - ref.r) < 0.012 and absf(bg.g - ref.g) < 0.012
			and absf(bg.b - ref.b) < 0.012,
			"ثابتِ `STONE_UI` همان ۲۵٪ تاریکی است (شد %s vs %s) ✓" % [bg.to_html(), ref.to_html()])
	assert_true(Palette.contrast_ratio(bg, Palette.CLOUD_WHITE) >= 4.9,
			"خاکستریِ تیره‌شده باید AA را رد کند (شد %f)" % Palette.contrast_ratio(bg, Palette.CLOUD_WHITE))
	assert_true(Palette.contrast_ratio(Palette.STONE_GREY, Palette.CLOUD_WHITE) < 4.5,
			"خاکستریِ خام زیرِ AA است ✗✓ (دلیلِ وجودِ این تُنِ تیره‌شده)")


func test_muted_text_exists_because_the_grey_did_not_pass() -> void:
	assert_true(Palette.contrast_ratio(Palette.MUTED_TEXT, Palette.DEEP_INDIGO) >= 4.5,
			"متنِ کم‌اهمیت هم باید AA باشد ✓ (۵٫۴۶ اندازه‌گیری‌شده)")
	assert_true(Palette.contrast_ratio(Palette.STONE_GREY, Palette.DEEP_INDIGO) < 4.5,
			"و دقیقاً به همین دلیل `MUTED_TEXT` اضافه شد ✗✓ نه برای تزئین")


func test_captions_no_longer_use_the_weak_grey() -> void:
	var dir := DirAccess.open(SKIN_DIR)
	assert_not_null(dir, "پوشۀ UI هست")
	dir.list_dir_begin()
	var f: String = dir.get_next()
	var scanned := 0
	while f != "":
		if f.ends_with(".gd"):
			scanned += 1
			for line: String in _read(SKIN_DIR + "/" + f).split("\n"):
				if (line.contains("make_label(") or line.contains("_add_label(")) \
						and line.contains("Palette.STONE_GREY"):
					assert_true(false, "%s: کپشن با خاکستریِ ضعیف ✗ (%s)" % [f, line.strip_edges()])
		f = dir.get_next()
	assert_gt(scanned, 8, "ممیزی واقعاً فایل‌ها را خوانده (وگرنه این تست دروغگو است ✗✓)")


# --------------------------------------------------------------------------
# ۳) تم و فونت ✓§۷
# --------------------------------------------------------------------------
func test_theme_is_wired_globally() -> void:
	var path: String = String(ProjectSettings.get_setting("gui/theme/custom", ""))
	assert_eq(path, "res://themes/Nexus.tres", "§۷ باید در **تم** باشد، نه در هر صحنه ✗✓")
	assert_true(ResourceLoader.exists(path), "فایل تم هست")
	var th: Theme = load(path) as Theme
	assert_not_null(th, "تم بارگذاری می‌شود ✓")
	assert_true(th.default_font_size >= UIKit.DIALOG_FONT_PX,
			"کفِ تم = %d ≥ ۲۴ ✓§۷" % th.default_font_size)
	var font: Font = th.default_font
	assert_not_null(font, "default_font دارد ✓ (وگرنه fallbackِ موتور جعبۀ فارسی می‌دهد ✗✗)")
	assert_true(font.resource_path.contains("Vazirmatn"),
			"خانواده باید Vazirmatn باشد (§۷): %s" % font.resource_path)


func test_palette_fonts_are_the_two_weights_of_one_family() -> void:
	var body: Font = Palette.ui_font()
	var heavy: Font = Palette.ui_font_bold()
	assert_ne(body.resource_path, "", "بدنه از فایل می‌آید، نه fallback ✓")
	assert_true(body.resource_path.ends_with("Medium.ttf"), "بدنه = Medium ✓§۷")
	assert_true(heavy.resource_path.ends_with("Bold.ttf"), "تأکید = Bold ✓§۷")
	assert_ne(body, heavy, "دو وزنِ واقعی، نه یک فایل با دو اسم ✗✓")
	assert_ne(body, ThemeDB.fallback_font, "فونتِ موتور دیگر به‌عنوان بدنه مصرف نمی‌شود ✗")


func test_fallback_font_only_survives_in_palette() -> void:
	# روی Android فونتِ موتور گلیف عربی/فارسی ندارد ⇒ «جعبه» ✗✓ (امروز در MasteryChart بود)
	for f: String in ["MasteryChart.gd", "UIKit.gd", "HUD.gd", "WorldMap.gd", "SettingsMenu.gd",
			"ParentDashboard.gd", "Onboarding.gd", "LevelResultBar.gd", "PauseMenu.gd"]:
		var src := _read(SKIN_DIR + "/" + f)
		if src == "":
			continue
		assert_false(src.contains("ThemeDB.fallback_font"),
				"%s هنوز fallback می‌گیرد ✗ ⇒ متنِ فارسی روی دستگاه می‌سوزد ✓✓" % f)
	assert_true(_read("res://scripts/data/Palette.gd").contains("ThemeDB.fallback_font"),
			"تنها مصرفِ مجاز: آخرین fallbackِ خودِ `Palette.ui_font()` ✓")


func test_orb_numbers_use_the_emphasis_weight() -> void:
	# §۶ «عدد ملموس» ⇒ عددِ روی کره باید از برچسبِ بدنه محکم‌تر باشد ✓ (تصمیمِ سند، نه سلیقه)
	var src := _read("res://scripts/gameplay/OrbVisual.gd")
	assert_true(src.contains("Palette.ui_font_bold()"), "عددها Bold ✓§۶/§۷")
	assert_false(src.contains("Palette.ui_font()\n"), "و بدنه نیست ✓ (جداسازیِ دو مصرف)")


func test_labels_get_the_floor_and_titles_get_bold() -> void:
	var body: Label = UIKit.make_label("common.next")
	add_child_autofree(body)
	assert_true(body.get_theme_font_size("font_size") >= 24,
			"برچسبِ معمولی ≥۲۴px ✓§۷ (شد %d)" % body.get_theme_font_size("font_size"))
	var title: Label = UIKit.make_label("common.next", UIKit.TITLE_FONT_PX, Palette.CLOUD_WHITE, true)
	add_child_autofree(title)
	var tf: Font = title.get_theme_font("font")
	assert_not_null(tf, "تیتر override فونت دارد ✓")
	assert_true(tf.resource_path.ends_with("Bold.ttf"), "تیتر = Bold ✓")
	assert_false(body.has_theme_font_override("font"), "بدنه از تم می‌آید (Medium) ✓")


# --------------------------------------------------------------------------
# ۴) آیکون‌ها ✓§۸ (SVG ایستا، صفر باینری) + جهت در RTL
# --------------------------------------------------------------------------
func test_four_icons_exist_and_decode() -> void:
	# §۸ «ترجیحاً SVG برای UI static» ✓ و ADR-057 «صفر باینری» ⇒ همین چهار فایل، هم‌اندازهٔ
	# یک پاراگراف متن؛ اگر روزی import نشوند، `icon_texture()` نال می‌دهد و تست قرمز ✓✓
	assert_eq(UIKit.ICON_PATHS.size(), 4, "چهار آیکون: راهنما/توقف/بازگشت/تیکِتمام ✓ (بی‌تزئین)")
	for name: String in UIKit.ICON_PATHS.keys():
		var tex: Texture2D = UIKit.icon_texture(name)
		assert_not_null(tex, "«%s» بارگذاری می‌شود ✗✓" % name)
		if tex == null:
			continue
		assert_gt(tex.get_width(), 8, "«%s» پهنای واقعی دارد (%d)" % [name, tex.get_width()])
		var path: String = String(UIKit.ICON_PATHS[name])
		var src := _read(path)
		assert_true(src.contains("viewBox"), "«%s» viewBox دارد ✓ (با expand_icon کشیده می‌شود)")
		assert_false(src.contains("<text"), "«%s» متنِ رندرشده ندارد ✓ (i18n §۷)")
	for icon_name: String in UIKit.ICON_PATHS.keys():
		# (نامِ حلقه عوض شد ✗✓ حلقۀ دومِ هم‌نام در همین scope خطای parse می‌داد:
		# «The variable 'name' is already declared in the same scope»)
		assert_true(FileAccess.file_exists(ICONS_DIR + "/" + icon_name + ".svg"),
				"«%s» روی دیسک هم هست ✓" % icon_name)
	# تیکِ «تمام شد» باید SVG باشد نه گلیفِ یونیکد چسبیده به عدد ✗✓ (Vazirmatn U+2713 ندارد
	# ⇒ روی Android جعبه می‌شد؛ یافتهٔ واقعیِ ۸.۴ از sweepِ گره‌های WorldMap)
	assert_true(UIKit.ICON_PATHS.has("done"), "تیکِ completion هم آیکون است ✓§۸")
	var wm := _read("res://scripts/ui/WorldMap.gd")
	assert_false(wm.contains('" ✓"'), "گلیفِ چسبیده به رقم حذف شد ✗✓")
	assert_true(wm.contains("icon_texture(\"done\")"), "گرهٔ تمام‌شده تیکِ SVG می‌گیرد ✓")


func test_unknown_icon_name_degrades_quietly() -> void:
	# آیکونِ گم‌شده نباید بازی را بشکند ✗✓ (صحنه بدون آیکون بهتر از صحنهٔ سیاه است)
	assert_null(UIKit.icon_texture("nope"), "نامِ ناشناخته ⇒ null ✓")
	var btn: Button = UIKit.make_button("common.back", "stone")
	add_child_autofree(btn)
	assert_same(UIKit.attach_icon(btn, "nope"), btn, "خودِ دکمه برگردانده می‌شود ✓")
	assert_null(btn.icon, "و آیکون اضافه نمی‌شود (صحنه نمی‌شکند) ✓")


func test_icon_side_follows_the_locale() -> void:
	Loc.set_locale("fa")
	assert_eq(UIKit.icon_alignment(), HORIZONTAL_ALIGNMENT_RIGHT,
			"در فارسی آیکون سمتِ «شروع» = راست ✓✗ چپ نیست (روی دسکتاپ این برعکس به‌نظر می‌رسد!)")
	Loc.set_locale("en")
	assert_eq(UIKit.icon_alignment(), HORIZONTAL_ALIGNMENT_LEFT, "در انگلیسی چپ ✓")


func test_declared_icons_are_really_used_in_hud() -> void:
	# جدولِ ICON_PATHS نباید «هنرِ مرده» شود ✗✓ (گیتِ ابزار هم همین را می‌سنجد؛ این‌جا
	# اثباتِ *سیم‌کشی* است: دکمهٔ واقعی داخل HUD آیکون دارد)
	var hud: Node = load("res://scenes/gameplay/HUD.tscn").instantiate()
	add_child_autofree(hud)
	var hint := hud.get_node_or_null("HintButton") as Button
	var pause := hud.get_node_or_null("PauseButton") as Button
	assert_not_null(hint, "HUD دکمۀ راهنما دارد")
	assert_not_null(pause, "HUD دکمۀ توقف دارد")
	if hint != null:
		assert_not_null(hint.icon, "دکمۀ راهنما آیکون می‌گیرد ✓§۸")
		assert_eq(hint.icon_alignment, UIKit.icon_alignment(), "جهتِ آیکون از Locale می‌آید ✓")
		assert_ne(hint.text, "", "متنِ ترجمه‌شده هم می‌ماند ✓ (آیکون به‌جای واژه نیست)")
	if pause != null:
		assert_not_null(pause.icon, "دکمۀ توقف آیکون می‌گیرد ✓")


func test_theme_reaches_a_real_scene() -> void:
	# تم باید از `ProjectSettings` به **ریشهٔ صحنه** برسد؛ اگر فقط فایل باشد و صحنه‌ای
	# `theme` خودش را ست کند، بچه‌ها فونتِ موتور می‌گیرند ✗✓ (روی Android = جعبه)
	var scene: Node = load("res://scenes/main/MainMenu.tscn").instantiate()
	add_child_autofree(scene)
	var root := scene as Control
	assert_not_null(root, "ریشهٔ MainMenu یک Control است ✓")
	if root != null:
		var f: Font = root.get_theme_default_font()
		assert_not_null(f, "فونتِ پیش‌فرضِ تم به صحنه می‌رسد ✓")
		assert_ne(f, ThemeDB.fallback_font, "فونتِ موتور نیست ✓✓ (§۷ روی دستگاه)")
		assert_true(f.resource_path.contains("Vazirmatn"), "همان خانوادۀ §۷ ✓ (%s)" % f.resource_path)
		assert_true(root.get_theme_default_font_size() >= 24,
				"کفِ ۲۴px از تم به ارث می‌رسد (شد %d) ✓§۷" % root.get_theme_default_font_size())


func test_result_bar_buttons_now_come_from_uikit() -> void:
	# یافتهٔ واقعیِ ۸.۴: `LevelResultBar` دکمه‌هایش را دستی می‌ساخت ✗✓ یعنی گوشۀ ۱۶px،
	# RTL، کوچک‌شدنِ فشار و لرزش فقط در `UIKit` بودند و این دو دکمه از آن می‌گریختند ✓
	var bar: Control = LevelResultBar.new()  # .tscn ندارد؛ خودش در `_ready` می‌سازد ✓
	add_child_autofree(bar)
	var found := 0
	for c: Node in bar.get_children():
		if c is Button:
			found += 1
			var btn := c as Button
			var sb: StyleBox = btn.get_theme_stylebox("normal")
			assert_true(sb is StyleBoxFlat, "سبکِ چهارحالته دارد ✓ (قبلاً نداشت ✗)")
			if sb is StyleBoxFlat:
				assert_true((sb as StyleBoxFlat).corner_radius_top_left >= int(UIKit.BUTTON_RADIUS),
						"گوشه ≥ ۱۶px ✓§۷")
			assert_true(btn.has_meta(&"nexus_press_wired"), "فشار ۰٫۹۵ + لرزش وصل است ✓§۷")
			assert_eq(btn.text_direction, Loc.text_direction(), "جهتِ متن از Loc ✓")
	assert_gt(found, 0, "دکمه‌ها پیدا شدند (وگرنه این تست دروغگو می‌شد ✗✓)")
