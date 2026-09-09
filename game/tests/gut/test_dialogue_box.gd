extends GutTest
# ===========================================================================
# تسک ۵.۵ — DoD: «پیام‌های بلند و کوتاه هر دو درست نمایش داده می‌شوند، بدون overflow»
# به‌علاوه §۷ Art Bible (فونت ≥ ۲۴، RTL، autowrap) که با چشم روی موبایلِ ارزان سنجیده
# می‌شود ولی اینجا با خودِ Propertyها ثابت می‌شود.
# ===========================================================================

const BOX_SCENE := "res://scenes/ui/DialogueBox.tscn"
const SHORT_TEXT := "آفرین، داری درست می‌ری."
const LONG_TEXT := ("الان داری به کفه‌ای اضافه می‌کنی که خودش سنگین‌تر است؛ اگر به‌جای "
	+ "اضافه کردن، یکی از همان طرف برداری و بعد دوباره نگاه کنی، میله آرام‌تر "
	+ "جابه‌جا می‌شود و شاید همان چیزی باشد که لازم داری.")

var _box: DialogueBox = null


func before_each() -> void:
	watch_signals(EventBus)
	_box = null


func _make() -> DialogueBox:
	var box: DialogueBox = load(BOX_SCENE).instantiate() as DialogueBox
	assert_not_null(box, "صحنه DialogueBox باید بارگذاری شود")
	add_child_autofree(box)
	return box


func test_it_follows_the_typography_rules_of_the_art_bible() -> void:
	_box = _make()
	assert_not_null(_box.label, "برچسب متن ساخته می‌شود")
	assert_not_null(_box.panel, "کادر پشت متن")
	if _box.label == null:
		return
	assert_gte(int(_box.label.get_theme_font_size("font_size")), DialogueBox.MIN_FONT_SIZE,
		"§۷: متن گفت‌وگو حداقل ۲۴px")
	assert_eq(int(_box.label.text_direction), int(Control.TEXT_DIRECTION_RTL), "فارسی RTL")
	assert_eq(int(_box.label.autowrap_mode), int(TextServer.AUTOWRAP_WORD_SMART),
		"سرتیتر نمی‌شکند؛ کلمه‌به‌کلمه می‌پیچد")
	assert_eq(int(_box.label.horizontal_alignment), int(HORIZONTAL_ALIGNMENT_FILL),
		"ترازوی منطقی برای RTL")
	assert_lte(int(_box.label.max_lines_visible), DialogueBox.MAX_LINES)


func test_short_and_long_messages_fit_without_overflow() -> void:
	var screen: Vector2 = get_tree().root.get_visible_rect().size
	for text: String in [SHORT_TEXT, LONG_TEXT]:
		_box = _make()
		_box.show_text(text)
		await get_tree().process_frame
		await get_tree().process_frame
		assert_true(_box.visible, "پیام باید دیده شود")
		assert_eq(_box.visible_text(), text)
		assert_true(_box.size.x <= screen.x + 0.01,
			"جعبه از عرض صفحه بیرون نمی‌زند (%f vs %f)" % [_box.size.x, screen.x])
		var label_w: float = _box.label.size.x
		assert_true(label_w <= _box.panel.size.x + 0.01, "متن داخل کادر است")
		if text == LONG_TEXT:
			assert_gt(int(_box.label.get_line_count()), 1,
				"متن بلند واقعاً می‌پیچد (وگرنه overflow داریم)")
		else:
			assert_true(int(_box.label.get_line_count()) >= 1)


func test_empty_text_hides_the_box_instead_of_showing_an_empty_panel() -> void:
	_box = _make()
	_box.show_text("چیزی")
	assert_true(_box.is_showing())
	_box.show_text("   ")
	await get_tree().process_frame
	assert_false(_box.visible, "کادر خالی روی صفحه نمی‌ماند")
	assert_false(_box.is_showing())


func test_it_reacts_to_the_hint_shown_signal() -> void:
	_box = _make()
	EventBus.hint_shown.emit("gentle_nudge_01", "tier1_level_01", "یک کره را امتحان کن.")
	await get_tree().process_frame
	assert_true(_box.visible)
	assert_eq(_box.visible_text(), "یک کره را امتحان کن.")
	_box.hide_now()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(_box.visible, "خروج هم ملایم است، نه ناپدیدشدنِ ناگهانی")


func test_it_can_be_silent_and_can_stay_forever() -> void:
	var box: DialogueBox = load(BOX_SCENE).instantiate() as DialogueBox
	box.listen_to_event_bus = false
	box.auto_hide_sec = 0.0
	add_child_autofree(box)
	_box = box
	EventBus.hint_shown.emit("x", "y", "متن")
	await get_tree().process_frame
	assert_false(box.visible, "حالت گوش‌ندادن (برای صحنه‌های دیباگ/کات‌سین)")
	box.show_text("بمانید")
	assert_true(box.visible)
	assert_false(box.auto_hide_running(), "با auto_hide_sec=0 تایمر روشن نمی‌شود")


func test_a_real_hint_travels_from_template_to_the_box() -> void:
	# زنجیره‌ی واقعی فاز ۵: قالب → AriaController → hint_shown → DialogueBox
	var aria := AriaController.new()
	add_child_autofree(aria)
	assert_true(aria.load_templates(), "قالب‌های فاز ۵ باید بارگذاری شوند")
	_box = _make()
	EventBus.hint_requested.emit("gentle_nudge_01")
	await get_tree().process_frame
	assert_true(_box.visible, "Aria حرف زد، جعبه هم نشان می‌دهد")
	var shown: String = _box.visible_text()
	var tpl: DialogueTemplate = aria.by_id.get("gentle_nudge_01", null)
	assert_not_null(tpl, "این id را داده‌ی سطح ۰۱ صدا می‌زند")
	if tpl == null:
		return
	assert_true(tpl.text_variants.has(shown),
		"متن نمایش‌داده‌شده باید عیناً یکی از واریانت‌های فایل باشد: " + shown)
	var has_digit: bool = false
	for i: int in range(shown.length()):
		var c: String = shown[i]
		if (c >= "0" and c <= "9") or (c >= "۰" and c <= "۹"):
			has_digit = true
	assert_false(has_digit, "رقم در متن راهنما ممنوع (§۴ قانون طلایی)")
