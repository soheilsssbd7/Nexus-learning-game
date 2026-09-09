extends GutTest
# ===========================================================================
# تسک ۶.۱ — UIKit: §۷ سند هنری یک بار نوشته می‌شود، پس قابل‌سنجش است
# ---------------------------------------------------------------------------
# DoD فاز ۶: «اندازه‌ی لمسی ≥ ۴۸px با تست خودکار». این فایل هم خودِ ابزار را می‌سنجد
# (ممیزی نباید درخت درست را قرمز کند یا دکمه‌ی ریز را سبز)، هم قواعد تایپوگرافی را.
# ===========================================================================


func after_each() -> void:
	Loc.set_locale(Loc.default_locale())
	SettingsStore.reset_for_tests()
	SettingsStore.load_from()


func test_the_dp_floor_is_derived_not_invented() -> void:
	assert_eq(UIKit.CANVAS_PX_PER_DP, 3.0, "بوم ۱۰۸۰px روی موبایل ۳۶۰dp (stretch=canvas_items)")
	assert_eq(UIKit.MIN_TOUCH_PX, 144.0, "§۷: ۴۸dp ⇒ ۱۴۴px")
	assert_eq(UIKit.px_for_dp(48.0), 144.0)
	assert_false(UIKit.touch_floor(Vector2(143.0, 900.0)), "۱px کمتر از کف، هنوز نقض است")
	assert_true(UIKit.touch_floor(Vector2(144.0, 144.0)))


func test_buttons_come_out_touch_ready_and_rtl() -> void:
	var btn: Button = UIKit.make_button("menu.play")
	add_child_autofree(btn)
	assert_eq(btn.text, Loc.t("menu.play"), "متن از Loc، نه hardcode")
	assert_eq(btn.text, "شروع بازی")
	assert_gte(btn.custom_minimum_size.x, UIKit.MIN_TOUCH_PX)
	assert_gte(btn.custom_minimum_size.y, UIKit.MIN_TOUCH_PX)
	assert_eq(btn.focus_mode, Control.FOCUS_NONE, "کودک نباید با فوکوس درگیر شود")
	assert_eq(btn.text_direction, Control.TEXT_DIRECTION_RTL)
	assert_eq(int(btn.get_theme_font_size("font_size")), UIKit.BUTTON_FONT_PX)


func test_button_radius_matches_the_art_bible() -> void:
	var btn: Button = UIKit.make_button("menu.settings", "teal")
	var sb: StyleBoxFlat = btn.get_theme_stylebox("normal") as StyleBoxFlat
	assert_not_null(sb, "§۷: دکمه‌ها گوشه‌ی گرد دارند")
	if sb == null:
		return
	assert_eq(sb.corner_radius_top_left, UIKit.BUTTON_RADIUS)
	assert_eq(sb.corner_radius_bottom_right, UIKit.BUTTON_RADIUS)
	var disabled: StyleBoxFlat = btn.get_theme_stylebox("disabled") as StyleBoxFlat
	assert_not_null(disabled)
	if disabled != null:
		assert_lt(disabled.bg_color.a, 1.0, "دکمه‌ی غیرفعال باید واضح فرق کند (نه فقط کم‌رنگِ همان رنگ)")


func test_style_button_never_shrinks_a_bigger_button() -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(900.0, 220.0)
	add_child_autofree(UIKit.style_button(btn, "stone"))
	assert_eq(btn.custom_minimum_size, Vector2(900.0, 220.0),
		"کفِ لمسی یک «حداقل» است، نه یک اندازهٔ دیکته‌ای")


func test_pressed_state_follows_the_spec() -> void:
	var btn: Button = UIKit.make_button("menu.quit", "stone")
	add_child_autofree(btn)
	UIKit._press_down(btn)
	assert_almost_eq(btn.scale.x, UIKit.PRESSED_SCALE, 0.001, "§۷: scale 0.95 هنگام فشرده‌شدن")
	assert_gt(btn.pivot_offset.x, 0.0, "pivot در مرکز، وگرنه دکمه به گوشه می‌چسبد و می‌پرد")
	assert_false(UIKit.haptics_allowed(),
		"لرزش فقط روی دستگاه لمسی؛ در CI/دسکتاپ باید بی‌صدا باشد (تستِ قطعی)")


func test_labels_ignore_touch_and_wrap() -> void:
	var label: Label = UIKit.make_label("hud.progress")
	add_child_autofree(label)
	assert_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"متن نباید درگِ بچه را قاپد (همان درسی که فاز ۲ با input گرفت)")
	assert_eq(int(label.get_theme_font_size("font_size")), UIKit.DIALOG_FONT_PX,
		"§۷: حداقل ۲۴px")
	assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(label.max_lines_visible, 3)


func test_panel_is_translucent_with_the_same_radius() -> void:
	var panel: PanelContainer = UIKit.make_panel()
	add_child_autofree(panel)
	var sb: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(sb)
	if sb == null:
		return
	assert_lt(sb.bg_color.a, 1.0)
	assert_eq(sb.corner_radius_top_left, UIKit.BUTTON_RADIUS)
	assert_eq(int(sb.content_margin_left), int(UIKit.MARGIN))
	assert_eq(panel.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_flow_direction_follows_the_locale() -> void:
	var box := VBoxContainer.new()
	var label := Label.new()
	var btn := Button.new()
	box.add_child(label)
	box.add_child(btn)
	add_child_autofree(box)
	Loc.set_locale("fa")
	UIKit.apply_flow(box)
	assert_eq(label.text_direction, Control.TEXT_DIRECTION_RTL)
	assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT)
	Loc.set_locale("en")
	UIKit.apply_flow(box)
	assert_eq(label.text_direction, Control.TEXT_DIRECTION_LTR,
		"جهت از داده می‌آید: زبان عوض شد، چیدمان عوض شد — بدون دست‌زدن به صحنه")
	assert_eq(btn.text_direction, Control.TEXT_DIRECTION_LTR)


func test_touch_audit_catches_a_small_button_only() -> void:
	var root := Control.new()
	root.name = "AuditRoot"
	var good := Button.new()
	good.name = "Good"
	good.size = Vector2(600.0, 150.0)
	var bad := Button.new()
	bad.name = "Bad"
	bad.size = Vector2(100.0, 40.0)
	root.add_child(good)
	root.add_child(bad)
	add_child_autofree(root)
	var offenders: Array[String] = UIKit.audit_touch_targets(root)
	assert_eq(offenders.size(), 1, "فقط دکمه‌ی ریز: " + str(offenders))
	if offenders.is_empty():
		return
	assert_true(offenders[0].contains("Bad"), offenders[0])


func test_audit_ignores_non_clickable_controls() -> void:
	var root := Control.new()
	root.name = "QuietRoot"
	var label := Label.new()
	label.size = Vector2(40.0, 12.0)
	var slider_track := ColorRect.new()
	root.add_child(label)
	root.add_child(slider_track)
	add_child_autofree(root)
	assert_true(UIKit.audit_touch_targets(root).is_empty(),
		"برچسب و پس‌زمینه «کنترل قابل‌کلیک» نیستند؛ ممیزی نباید سر‌و‌صدا کند")
