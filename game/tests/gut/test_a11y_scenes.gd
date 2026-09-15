extends GutTest
# ===========================================================================
# NEXUS — تست‌های تسک ۸.۴ «ب» (ممیزیِ دسترس‌پذیریِ **همهٔ صحنه‌ها** | DoD سند ۰۴)
# --------------------------------------------------------------------------
# DoD ۸.۴ کلمه‌به‌کلمه: «تست دسترس‌پذیری: تمام دکمه‌ها حداقل ۴۸×۴۸px، کنتراست
# متن/پس‌زمینه قابل‌قبول» ✓✗ «تمام» یعنی **سوییپ**، نه نمونه‌گیری: هر `.tscn` زیر
# `res://scenes` ساخته می‌شود و درختش_walk_می‌شود ✓✓ و چون شمارشِ صحنه‌ها هم تست است،
# صحنۀ جدیدی نمی‌تواند بی‌ممیزی اضافه شود (الگوی count-driven فاز ۷.۴ ✓✓).
# نکتهٔ هدلس: در CI layout اجرا نمی‌شود ⇒ `size` صفر است ✗✓ پس سنجش با
# `max(size, custom_minimum_size)` است — همان کاری که `UIKit.audit_touch_targets()` می‌کند؛
# یعنی **همان ابزاری که بازیکن روی دستگاه حس می‌کند، اینجا سنجیده می‌شود** ✓ (نه یک کپی).
# ===========================================================================

const SCENES_DIR := "res://scenes"
const EXPECTED_SCENES := 12


func after_each() -> void:
	Loc.set_locale(Loc.default_locale())


func _scenes(dir_path: String, out: Array[String]) -> Array[String]:
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var f: String = d.get_next()
	while f != "":
		var full := dir_path.path_join(f)
		if d.current_is_dir():
			_scenes(full, out)
		elif f.ends_with(".tscn"):
			out.append(full)
		f = d.get_next()
	d.list_dir_end()
	return out


func _scene(name: String) -> Node:
	var scene: Node = load(name).instantiate()
	# صحنه‌هایی که انتخابِ سطح/تغییرِ صحنه را خودکار می‌کنند، در تست **بی‌اثر** می‌شوند ✓
	scene.set("report_progress", false)
	scene.set("allow_scene_change", false)
	add_child_autofree(scene)
	return scene


func _walk(node: Node, klass: String, out: Array) -> Array:
	for c: Node in node.get_children():
		if c.get_class() == klass:
			out.append(c)
		_walk(c, klass, out)
	return out


# --------------------------------------------------------------------------
# ۱) خودِ ممیزی — «تمام دکمه‌ها» ✓
# --------------------------------------------------------------------------
func test_scene_inventory_is_discovered() -> void:
	var found: Array[String] = _scenes(SCENES_DIR, [] as Array[String])
	var why := "سوییپ باید %d صحنه ببیند (یافت: %d) ✗✓ اگر صحنه‌ای اضافه کرده‌اید، " % [
			EXPECTED_SCENES, found.size()]
	why += "EXPECTED_SCENES را با دلیل به‌روز کنید — بی این، صحنۀ جدید از ممیزی در می‌رود ✓"
	assert_eq(found.size(), EXPECTED_SCENES, why)


func test_sweep_finds_real_buttons() -> void:
	# ضدِ تستِ دروغگو ✓: اگر `_walk` چیزی پیدا نکند، همهٔ assertهای پایین سبزِ توخالی‌اند
	var total := 0
	for path: String in _scenes(SCENES_DIR, [] as Array[String]):
		var scene := _scene(path)
		total += _walk(scene, "Button", [] as Array).size()
	assert_gt(total, 10, "سوییپ باید دکمۀ واقعی ببیند (شد %d) ✗✓" % total)


func test_no_button_is_smaller_than_the_touch_floor() -> void:
	for path: String in _scenes(SCENES_DIR, [] as Array[String]):
		var scene := _scene(path)
		var bad: Array[String] = UIKit.audit_touch_targets(scene)
		var msg := ""
		for e: String in bad:
			msg += "\n   - " + e
		assert_true(bad.is_empty(), "%s: %d دکمۀ ریز ✗§۷ (%s)" % [path, bad.size(), msg])


func test_every_labelled_button_follows_the_text_direction() -> void:
	# §۷ «فارسی RTL به‌عنوان پیش‌فرض» ⇒ دکمه‌ای که `text_direction` پیش‌فرضِ خودش را نگه
	# دارد روی گوشیِ واقعی برعکسِ چیدمان می‌نشیند ✗✓ (در دسکتاپ دیده نمی‌شود)
	Loc.set_locale("fa")
	for path: String in _scenes(SCENES_DIR, [] as Array[String]):
		var scene := _scene(path)
		for b: Variant in _walk(scene, "Button", [] as Array):
			var btn := b as Button
			if btn.text == "":
				continue
			assert_eq(btn.text_direction, Control.TEXT_DIRECTION_RTL,
					"%s/%s جهتِ متن ندارد ✗" % [path, btn.name])


func test_no_button_is_skinless() -> void:
	# §۷ گوشۀ ۱۶px ⇒ هر دکمه باید styleboxِ خودش را داشته باشد؛ اگر theme‌ای نداشتیم و
	# دکمه‌ای از سبکِ پیش‌فرضِ موتور می‌آمد، «اسکین نهایی» فقط نیمه بود ✗✓
	for path: String in _scenes(SCENES_DIR, [] as Array[String]):
		var scene := _scene(path)
		for b: Variant in _walk(scene, "Button", [] as Array):
			var btn := b as Button
			# گره‌ای که override ندارد استایلِ پیش‌فرضِ موتور را می‌گیرد؛ آن *سبکِ ما* نیست ✗✓
			# پس قاعده این است: هر دکمه‌ای که در کد ساخته می‌شود باید skin را خودش بگذارد
			# (`UIKit.style_button` یا سه حالتِ `WorldMap.refresh_locks`) ✓✓
			assert_true(btn.has_theme_stylebox_override("normal"),
					"%s/%s پوستهٔ override ندارد ✗§۷" % [path, btn.name])
			var sb: StyleBox = btn.get_theme_stylebox("normal")
			if sb is StyleBoxFlat:
				assert_true((sb as StyleBoxFlat).corner_radius_top_left >= int(UIKit.BUTTON_RADIUS),
						"%s/%s گوشه‌اش %d است ✗§۷" % [path, btn.name,
						(sb as StyleBoxFlat).corner_radius_top_left])


func test_button_text_contrast_is_measured_on_real_scenes() -> void:
	# DoD: «کنتراست متن/پس‌زمینه قابل‌قبول» ⇒ برای هر دکمه‌ای که رنگِ متن را override کرده،
	# نسبتِ WCAG با پس‌زمینهٔ **همان دکمه** حساب می‌شود (نه با رنگِ نظری ✓✓)
	for path: String in _scenes(SCENES_DIR, [] as Array[String]):
		var scene := _scene(path)
		for b: Variant in _walk(scene, "Button", [] as Array):
			var btn := b as Button
			if not btn.has_theme_color_override("font_color"):
				continue
			var sb: StyleBoxFlat = btn.get_theme_stylebox("normal") as StyleBoxFlat
			if sb == null:
				continue
			var ratio: float = Palette.contrast_ratio(btn.get_theme_color("font_color"), sb.bg_color)
			assert_true(ratio >= Palette.AA_TEXT_RATIO,
					"%s/%s کنتراست %f ✗ (AA ≥ %f)" % [path, btn.name, ratio, Palette.AA_TEXT_RATIO])


# --------------------------------------------------------------------------
# ۲) کفِ متن و فونتِ خانوادگی ✓§۷
# --------------------------------------------------------------------------
func test_every_label_respects_the_font_floor() -> void:
	for path: String in _scenes(SCENES_DIR, [] as Array[String]):
		var scene := _scene(path)
		for l: Variant in _walk(scene, "Label", [] as Array):
			var label := l as Label
			# روی گرهٔ اضافه‌نشده نمی‌شود به resolve شدناش از ThemeDB تکیه کرد ✗✓ پس:
			# overrideِ خودش را می‌خوانیم، وگرنه `default_font_size` تم (۲۸px ✓§۷) معتبر است ✓
			var px: int = UIKit.DIALOG_FONT_PX
			if label.has_theme_font_size_override("font_size"):
				px = label.get_theme_font_size("font_size")
			else:
				var th: Theme = load(UIKit.THEME_PATH)
				if th != null and th.default_font_size > 0:
					px = th.default_font_size
			assert_true(px >= UIKit.DIALOG_FONT_PX,
					"%s/%s متنش %dpx است ✗§۷ (کفِ گفت‌وگو ۲۴)" % [path, label.name, px])


func test_dialogue_box_text_is_at_least_24px() -> void:
	# §۷ دقیقاً همین را می‌خواهد: «۲۴px برای متن گفت‌وگو» ⇒ آریا باید خوانا باشد ✓
	var box := _scene("res://scenes/ui/DialogueBox.tscn")
	var labels: Array = _walk(box, "Label", [] as Array)
	assert_gt(labels.size(), 0, "دیالوگ‌باکس برچسب دارد (وگرنه این تست دروغگو بود ✗✓)")
	for l: Variant in labels:
		var label := l as Label
		assert_true(label.get_theme_font_size("font_size") >= 24,
				"«%s» = %dpx ✗§۷" % [label.name, label.get_theme_font_size("font_size")])


func test_no_scene_falls_back_to_the_engine_font() -> void:
	# روی Android فونتِ موتور گلیف فارسی ندارد ⇒ «جعبه» ✗✓ تم باید به **ریشهٔ هر صحنه**
	# برسد؛ یک صحنه که `theme` خودش را ست کند، بچه‌هایش را از تم می‌دزدد ✓
	for path: String in _scenes(SCENES_DIR, [] as Array[String]):
		var scene := _scene(path)
		var ctrl := scene as Control
		if ctrl == null:
			continue
		var f: Font = ctrl.get_theme_default_font()
		assert_not_null(f, "%s فونتِ پیش‌فرض ندارد ✗" % path)
		if f != null:
			assert_ne(f, ThemeDB.fallback_font, "%s فونتِ موتور می‌گیرد ✗✗" % path)
			assert_true(f.resource_path.contains("Vazirmatn"),
					"%s خانواده‌اش عوض شده ✗§۷ (%s)" % [path, f.resource_path])


# --------------------------------------------------------------------------
# ۳) سیم‌کشیِ §۷ که قبلاً فرار می‌کرد ✓
# --------------------------------------------------------------------------
func test_aria_hud_and_map_buttons_are_touch_ready_with_icons() -> void:
	var hud := _scene("res://scenes/gameplay/HUD.tscn")
	var hint := hud.get_node_or_null("HintButton") as Button
	assert_not_null(hint, "HUD دکمۀ راهنما دارد")
	if hint != null:
		var effective := Vector2(maxf(hint.size.x, hint.custom_minimum_size.x),
				maxf(hint.size.y, hint.custom_minimum_size.y))
		assert_true(UIKit.touch_floor(effective), "راهنما ≥ کفِ لمسی ✓ (%s)" % str(effective))
		assert_not_null(hint.icon, "آیکونِ راهنما وصل است ✓§۸")


func test_world_map_level_nodes_are_exactly_the_floor() -> void:
	# گره‌های سطح روی نقشه **باید** ریزترینِ مجاز باشند ✓ (۴۵ گره در یک ستونِ باریک ⇒
	# اگر بزرگ‌تر شوند مسیرِ مارپیچ جا نمی‌شود ✗) پس دقیقاً کفِ §۷ — و تست همین را قفل می‌کند
	var map := _scene("res://scenes/main/WorldMap.tscn")
	var nodes: Array = []
	_walk(map, "Button", nodes)
	var level_nodes: Array = []
	for b: Variant in nodes:
		var btn := b as Button
		if String(btn.name).begins_with("Level_"):
			level_nodes.append(btn)
	assert_gt(level_nodes.size(), 0, "گره‌های سطح روی نقشه‌اند (وگرنه تست دروغگو بود ✗✓)")
	for b: Variant in level_nodes:
		var btn := b as Button
		assert_true(absf(btn.custom_minimum_size.x - UIKit.MIN_TOUCH_PX) < 0.01,
				"گرۀ %s باید دقیقاً %d باشد (شد %f) ✓" % [btn.name, UIKit.MIN_TOUCH_PX,
				btn.custom_minimum_size.x])


func test_haptics_setting_and_call_are_wired() -> void:
	# §۷ «haptic در صورت پشتیبانی» ⇒ هم تنظیم باشد، هم فراخوانی، هم احترام به پرچم ✗✓
	var src := FileAccess.open("res://scripts/ui/UIKit.gd", FileAccess.READ).get_as_text()
	assert_true(src.contains("Input.vibrate_handheld"), "لرزش واقعاً صدا زده می‌شود ✓")
	assert_true(src.contains("DisplayServer.is_touchscreen_available()"),
			"روی دسکتاپ لرزش درخواست نمی‌شود ✓ (بی‌معنی/خطازا)")
	assert_true(bool(SettingsStore.get_value("haptics_enabled")), "پیش‌فرض: روشن ✓")
	SettingsStore.set_value("haptics_enabled", false)
	assert_false(UIKit.haptics_allowed(), "خاموش ⇒ هیچ لرزشی ✗✓ (تنظیم والد/بچه محترم است)")
	assert_true(UIKit.HAPTIC_MS >= 5 and UIKit.HAPTIC_MS <= 40,
			"مدتِ لرزش «مختصر» است ✓§۷ (شد %d)" % UIKit.HAPTIC_MS)


func test_press_scale_is_the_bible_value() -> void:
	# §۷ «scale ۰.۹۵» عددِ دقیق داده است ⇒ عددِ دقیق نگه داشته می‌شود ✓✗ نه «تقریباً کوچک»
	assert_true(absf(UIKit.PRESSED_SCALE - 0.95) < 0.0001, "۰٫۹۵ ✓§۷")
	assert_true(UIKit.PRESSED_SCALE < 1.0 and UIKit.PRESSED_SCALE > 0.85,
			"«کوچک‌شدن مختصر» ✓§۷ (نه محو شدن، نه بی‌تغییری)")


func test_radius_is_16_everywhere_in_the_kit() -> void:
	assert_eq(int(UIKit.BUTTON_RADIUS), 16, "گوشۀ ۱۶px ✓§۷")
	var sb := UIKit.stylebox(Palette.DEEP_INDIGO)
	assert_eq(sb.corner_radius_top_left, 16, "styleboxِ واقعی هم همان ✓")
	assert_eq(sb.corner_radius_bottom_right, 16, "چهار گوشه، نه یکی ✗✓")
