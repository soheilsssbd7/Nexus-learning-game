extends GutTest
# ===========================================================================
# تسک ۵.۳ — AriaController (DoDِ سند ۰۴ «تست دستی» با ADR-013 به این تست تبدیل شد)
# --------------------------------------------------------------------------
# سه چیز باید ثابت شود: چرخشی‌بودن (نه تصادفی)، بی‌صداییِ امن وقتی قالبی نیست، و
# درست‌بودنِ هر شش حالت آواتار روی رویدادهای واقعیِ بازی.
# ===========================================================================

var _aria: AriaController = null


func before_each() -> void:
	watch_signals(EventBus)
	GameState.begin_level("tier1_level_01", 1)


func after_each() -> void:
	GameState.end_level()


func _make(auto_load: bool = false) -> AriaController:
	var c := AriaController.new()
	c.name = "AriaUnderTest"
	c.auto_load_templates = auto_load
	add_child_autofree(c)
	_aria = c
	return c


## قالب‌های ساختگی، تا متن‌ها و ترتیبشان در تست قطعی باشد.
func _arm(c: AriaController, entries: Array) -> void:
	var by_id: Dictionary = {}
	var ids := PackedStringArray()
	for e: Dictionary in entries:
		var tpl: DialogueTemplate = DialogueTemplate.from_dict(e)
		if tpl == null or by_id.has(tpl.hint_id):
			continue
		by_id[tpl.hint_id] = tpl
		ids.append(tpl.hint_id)
	c.by_id = by_id
	c.order = ids


func _two_variant_entry(id: String, types: Array, mn: int = 1, mx: int = 5) -> Dictionary:
	return {
		"hint_id": id, "applies_to_error_types": types, "min_tier": mn, "max_tier": mx,
		"text_variants": ["متن یک", "متن دو"],
	}


# --------------------------------------------------------------------------
func test_it_loads_the_shipped_templates() -> void:
	var c := _make(true)
	assert_true(c.load_templates(), "فایل فاز ۵ باید خوانده شود")
	assert_gte(c.template_count(), 15)
	assert_gte(int(DialogueTemplate.count_variants(c.by_id)), 30)


func test_missing_or_broken_file_is_not_fatal() -> void:
	var c := _make()
	assert_false(c.load_templates("res://data/dialogue/does_not_exist.json"),
		"نبود فایل = false، نه crash")
	assert_eq(c.template_count(), 0)
	c.show_hint("gentle_nudge_01")
	assert_signal_emit_count(EventBus, "hint_shown", 0, "بی‌قالب → بی‌صدا")
	assert_eq(c.last_text, "")


func test_selection_is_rotational_not_random() -> void:
	var c := _make()
	_arm(c, [_two_variant_entry("h1", ["idle"])])
	var texts: Array[String] = []
	for i: int in range(5):
		texts.append(c.text_for_hint("h1"))
	assert_eq(texts[0], "متن یک")
	assert_eq(texts[1], "متن دو")
	assert_eq(texts[2], "متن یک", "چرخش کامل")
	for i: int in range(1, texts.size()):
		assert_ne(texts[i], texts[i - 1], "هیچ واریانتی دو بار پشت‌سرهم نمی‌آید (§۴)")


func test_each_hint_id_rotates_on_its_own_counter() -> void:
	var c := _make()
	_arm(c, [_two_variant_entry("a", ["idle"]), _two_variant_entry("b", ["idle"])])
	assert_eq(c.text_for_hint("a"), "متن یک")
	assert_eq(c.text_for_hint("b"), "متن یک", "شمارنده‌ها جدا هستند")
	assert_eq(c.text_for_hint("a"), "متن دو")
	assert_eq(c.text_for_hint("unknown_id"), "", "id ناشناخته = رشته‌ی تهی، نه crash")


func test_the_first_error_only_changes_the_face() -> void:
	var c := _make()
	_arm(c, [_two_variant_entry("e1", ["computation_error"])])
	EventBus.error_detected.emit("computation_error")
	assert_eq(c.last_state, "concerned", "Art Bible §۳: همدل، نه سرزنش‌گر")
	assert_signal_emitted_with_parameters(EventBus, "aria_state_changed", ["concerned"])
	assert_signal_emit_count(EventBus, "hint_shown", 0,
		"ADR-042: خطای اول هنوز حرف تازه‌ای نمی‌شنود")


func test_the_second_error_releases_a_hint() -> void:
	var c := _make()
	_arm(c, [_two_variant_entry("e1", ["computation_error"])])
	EventBus.error_detected.emit("computation_error")
	EventBus.error_detected.emit("computation_error")
	assert_signal_emit_count(EventBus, "hint_shown", 1)
	var args: Variant = get_signal_parameters(EventBus, "hint_shown", 0)
	assert_true(args is Array and (args as Array).size() == 3, "payload = (hint_id, level_id, text)")
	if args is Array and (args as Array).size() == 3:
		var arr: Array = args as Array
		assert_eq(str(arr[0]), "e1")
		assert_eq(str(arr[1]), "tier1_level_01")
		assert_eq(str(arr[2]), "متن یک")
	assert_eq(c.last_state, "hint_light")


func test_the_tier_window_is_respected_before_the_fallback() -> void:
	var c := _make()
	# قالبِ خطا فقط برای Tier ۳+ است، اما بازی در Tier ۱ است → باید به nudge بیفتد
	_arm(c, [
		_two_variant_entry("tier3", ["computation_error"], 3, 5),
		_two_variant_entry("gentle_nudge_01", ["idle"]),
	])
	EventBus.error_detected.emit("computation_error")
	EventBus.error_detected.emit("computation_error")
	assert_signal_emitted_with_parameters(EventBus, "hint_shown", [
		"gentle_nudge_01", "tier1_level_01", "متن یک"])


func test_a_hint_with_no_template_stays_silent() -> void:
	var c := _make()
	_arm(c, [_two_variant_entry("only", ["idle"])])
	EventBus.error_detected.emit("sign_flip_on_subtraction")
	EventBus.error_detected.emit("sign_flip_on_subtraction")
	assert_signal_emit_count(EventBus, "hint_shown", 0,
		"نه قالب و نه fallback → سکوت (بدون جمله‌ی بی‌ربط)")


## همه‌ی ورودی‌ها با emit واقعی می‌آیند (نه فراخوانی متد): همان مسیرِ صحنه، پس
## اتصال‌ها هم در همین تست سنجیده می‌شوند.
func test_the_six_states_follow_the_real_events() -> void:
	var c := _make()
	assert_eq(c.last_state, "idle", "حالت پیش‌فرض (§۳)")
	EventBus.orb_placed.emit({"value": 3.0})
	assert_eq(c.last_state, "thinking")
	# فاصله از ۸ به ۱ می‌رسد: «تلاشِ درستِ جزئی» → encouraging
	EventBus.balance_changed.emit(8.0, 0.0)
	EventBus.balance_changed.emit(5.0, 4.0)
	assert_eq(c.last_state, "encouraging")
	c.set_state("celebrating")
	assert_eq(c.last_state, "celebrating")
	EventBus.level_completed.emit("tier1_level_01", {})
	assert_eq(c.last_state, "celebrating")
	EventBus.level_started.emit("tier1_level_02", 1)
	assert_eq(c.last_state, "idle", "سطح تازه = چهره‌ی آرام")


func test_unknown_state_never_reaches_the_ui() -> void:
	var c := _make()
	watch_signals(EventBus)
	c.set_state("dancing_bear")
	assert_eq(c.last_state, "idle", "حالت ناشناخته به idle برمی‌گردد")
	assert_signal_emit_count(EventBus, "aria_state_changed", 0,
		"و اصلاً publish نمی‌شود تا آواتار گیج نشود")
	c.set_state("concerned")
	assert_signal_emitted_with_parameters(EventBus, "aria_state_changed", ["concerned"])


func test_reset_session_restarts_the_rotation() -> void:
	var c := _make()
	_arm(c, [_two_variant_entry("h1", ["idle"])])
	assert_eq(c.text_for_hint("h1"), "متن یک")
	assert_eq(c.text_for_hint("h1"), "متن دو")
	c.reset_session()
	assert_eq(c.text_for_hint("h1"), "متن یک", "نشست تازه = چرخش تازه")
	assert_eq(c.last_text, "")


func test_hint_shown_can_be_switched_off() -> void:
	var c := _make()
	c.emits_hint_shown = false
	_arm(c, [_two_variant_entry("h1", ["idle"])])
	c.show_hint("h1")
	assert_eq(c.last_text, "متن یک", "متن برای UIهای دیگر حساب می‌شود")
	assert_signal_emit_count(EventBus, "hint_shown", 0, "حالت بی‌صدای قابل‌استفاده در دیباگ")
