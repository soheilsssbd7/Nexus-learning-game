extends GutTest
# ===========================================================================
# تسک ۴.۳ — HintTimingSystem (docs/04 §۴.۳، docs/07 §۵-الف)
# --------------------------------------------------------------------------
# DoD سند ۰۴: «بی‌حرکتی ۴۵ ثانیه‌ای سیگنال hint را trigger می‌کند؛ ۳ تلاش ناموفق هم
# همین‌طور». این‌جا زمان **دستی** جلو می‌رود (`tick()`): در CI هیچ‌کس ۴۵ ثانیه
# نمی‌خوابد، و آزمون دقیق‌تر هم می‌شود (مرزِ آستانه، نه «حدوداً ۴۵ ثانیه»).
# ===========================================================================

const LEVEL_IDS := ["tier1_level_01", "tier1_level_02", "tier1_level_03",
	"tier1_level_04", "tier1_level_05"]

var _sys: HintTimingSystem = null


func before_each() -> void:
	watch_signals(EventBus)
	GameState.begin_level("tier1_level_01", 1)


func after_each() -> void:
	if _sys != null and is_instance_valid(_sys):
		_sys.stop()
		_sys.queue_free()
	_sys = null
	GameState.end_level()


func _make_sys(config: Dictionary) -> HintTimingSystem:
	var sys := HintTimingSystem.new()
	sys.name = "HintTimingUnderTest"
	sys.auto_idle_timer = false  # زمان فقط با tick() جلو می‌رود
	add_child(sys)
	sys.configure(config)
	_sys = sys
	return sys


func _steps(entries: Array) -> Dictionary:
	return {"level_id": "tier1_level_01", "tier": 1, "tolerance": 0.0,
		"scales": [], "available_orbs": [], "narrative_intro": "آزمون", "hint_sequence": entries}


# --------------------------------------------------------------------------
func test_defaults_match_the_spec() -> void:
	assert_eq(HintTimingSystem.DEFAULT_IDLE_SEC, 45.0, "§۴.۳: پیش‌فرض ۴۵ ثانیه بی‌حرکتی")
	assert_eq(HintTimingSystem.ESCALATION_FAILS, 2)
	var sys := _make_sys({})
	assert_eq(sys.idle_sec, 45.0, "پیش‌فرضِ export هم همان است")
	assert_eq(sys.fail_threshold, 3, "§۴.۳: سه تلاشِ ناموفق پشت‌سرهم")


func test_parse_steps_reads_every_trigger_shape() -> void:
	var steps: Array[Dictionary] = HintTimingSystem.parse_steps(_steps([
		{"trigger": "idle_30s", "hint_id": "a"},
		{"trigger": "first_wrong_attempt", "hint_id": "b"},
		{"trigger": "fail_4x", "hint_id": "c"},
		{"trigger": "help_requested", "hint_id": "d"},
		{"trigger": "hover_2s", "hint_id": "e"},  # ناشناخته → باید بیفتد
		{"trigger": "idle_20s", "hint_id": ""},  # بی‌hint_id → بی‌فایده
	]))
	assert_eq(steps.size(), 4, "تریگر ناشناخته و hint_id تهی پذیرفته نمی‌شوند")
	assert_eq(str(steps[0]["kind"]), "idle")
	assert_eq(float(steps[0]["threshold"]), 30.0, "عددِ داخل `idle_30s` منبع است، نه export")
	assert_eq(str(steps[1]["kind"]), "first_wrong")
	assert_eq(str(steps[2]["kind"]), "fail")
	assert_eq(float(steps[2]["threshold"]), 4.0)
	assert_eq(str(steps[3]["kind"]), "help")


func test_idle_fires_exactly_at_its_threshold_and_only_once() -> void:
	var sys := _make_sys(_steps([{"trigger": "idle_2s", "hint_id": "gentle_nudge_01"}]))
	sys.tick(1.9)
	assert_eq(get_signal_emit_count(EventBus, "hint_requested"), 0, "زودتر از آستانه نه")
	sys.tick(0.15)
	assert_eq(get_signal_emit_count(EventBus, "hint_requested"), 1)
	assert_signal_emitted_with_parameters(EventBus, "hint_requested", ["gentle_nudge_01"])
	sys.tick(30.0)
	assert_eq(get_signal_emit_count(EventBus, "hint_requested"), 1, "یک ردیف نردبان، یک بار")


func test_moving_an_orb_resets_the_idle_clock() -> void:
	var sys := _make_sys(_steps([{"trigger": "idle_2s", "hint_id": "gentle_nudge_01"}]))
	sys.tick(1.5)
	# اتصال به باس: حرکتِ کره (نه تابعی که تست صدا بزند) باید ساعت را صفر کند
	EventBus.orb_placed.emit({"value": 2.0, "placed": true})
	sys.tick(1.5)
	assert_eq(get_signal_emit_count(EventBus, "hint_requested"), 0, "ساعت ریست شد")
	sys.tick(0.6)
	assert_eq(get_signal_emit_count(EventBus, "hint_requested"), 1)


func test_first_wrong_attempt_then_the_fail_ladder() -> void:
	var sys := _make_sys(_steps([
		{"trigger": "first_wrong_attempt", "hint_id": "compare_sides_01"},
		{"trigger": "fail_3x", "hint_id": "socratic_operation_01"},
	]))
	GameState.register_attempt_failed()
	assert_signal_emitted_with_parameters(EventBus, "hint_requested", ["compare_sides_01"])
	assert_eq(get_signal_emit_count(EventBus, "hint_requested"), 1, "اشتباهِ اول: فقط ردیف اول")
	GameState.register_attempt_failed()
	assert_eq(get_signal_emit_count(EventBus, "hint_requested"), 1, "دو تلاش هنوز به ۳ نمی‌رسد")
	GameState.register_attempt_failed()
	assert_eq(get_signal_emit_count(EventBus, "hint_requested"), 2)
	assert_signal_emitted_with_parameters(EventBus, "hint_requested", ["socratic_operation_01"])
	assert_eq(sys.fails(), 3)


func test_the_last_ladder_step_repeats_every_two_extra_fails() -> void:
	var sys := _make_sys(_steps([{"trigger": "fail_3x", "hint_id": "socratic_specific_01"}]))
	for i: int in range(2):
		GameState.register_attempt_failed()
	assert_eq(sys.fired_count(), 0, "آستانه‌ی سطح هنوز نیامده")
	GameState.register_attempt_failed()
	assert_eq(sys.fired_count(), 1, "سه تلاش = پله‌ی اول")
	GameState.register_attempt_failed()
	assert_eq(sys.fired_count(), 1, "یک تلاشِ اضافه کافی نیست")
	GameState.register_attempt_failed()
	GameState.register_attempt_failed()
	assert_eq(sys.fired_count(), 2, "هر %d تلاشِ اضافه، همان پله تکرار می‌شود"
		% HintTimingSystem.ESCALATION_FAILS)


func test_request_help_walks_the_ladder() -> void:
	var sys := _make_sys(_steps([
		{"trigger": "idle_999s", "hint_id": "gentle_nudge_01"},
		{"trigger": "fail_999x", "hint_id": "socratic_operation_01"},
		{"trigger": "help_requested", "hint_id": "inventory_count_01"},
	]))
	var order: Array[String] = []
	for i: int in range(4):
		sys.request_help()
		var args: Variant = get_signal_parameters(EventBus, "hint_requested", i)
		order.append(str((args as Array)[0]) if args is Array else "<none>")
	assert_eq(order, ["inventory_count_01", "gentle_nudge_01", "socratic_operation_01",
		"socratic_operation_01"],
		"نوبتِ اول = درخواستِ خود بازیکن؛ بعد هر فشار یک پله از نردبان بالا، و روی آخرین پله می‌ماند")


func test_hint_usage_is_counted_for_the_score() -> void:
	var sys := _make_sys(_steps([{"trigger": "idle_2s", "hint_id": "gentle_nudge_01"}]))
	assert_eq(GameState.hints_used_this_level, 0, "شمارنده درbegin_level صفر شده")
	sys.tick(2.1)
	assert_eq(GameState.hints_used_this_level, 1,
		"هر راهنما باید در `hints_used` بنشیند تا success_score آن را ببیند (ADR-015)")


func test_silent_before_configuration_and_after_a_win() -> void:
	var sys := HintTimingSystem.new()
	sys.auto_idle_timer = false
	add_child(sys)
	assert_false(sys.is_armed(), "بدون configure هیچ راهنمایی روی صفحه‌ی منو نمی‌آید")
	sys.tick(1000.0)
	assert_eq(get_signal_emit_count(EventBus, "hint_requested"), 0)
	_sys = sys
	sys.configure(_steps([{"trigger": "idle_1s", "hint_id": "gentle_nudge_01"}]))
	assert_true(sys.is_armed())
	sys.tick(1.1)
	assert_eq(sys.fired_count(), 1)
	EventBus.level_completed.emit("tier1_level_01", {"attempts": 1})
	assert_false(sys.is_armed(), "بعد از برد، نردبان خاموش می‌شود")
	sys.tick(60.0)
	assert_eq(sys.fired_count(), 1, "راهنمای تازه‌ای در صفحه‌ی نتیجه لازم نیست")


func test_level_started_rearms_the_ladder_for_the_next_level() -> void:
	var sys := _make_sys(_steps([{"trigger": "idle_2s", "hint_id": "gentle_nudge_01"}]))
	EventBus.level_completed.emit("tier1_level_01", {})
	assert_false(sys.is_armed())
	GameState.begin_level("tier1_level_02", 1)  # → EventBus.level_started
	assert_true(sys.is_armed(), "surface تازه = نردبان از اول")
	assert_eq(sys.fired_count(), 0, "شمارشِ «فایردشده‌ها» هم صفر می‌شود")


func test_real_tier1_levels_drive_the_authored_ladder() -> void:
	# همان پله‌هایی که در JSON نوشته‌ایم، از این مسیر اجرا می‌شوند (قرارداد فاز ۵)
	var lv: LevelData = LevelLoader.load_level("tier1_level_01")
	assert_not_null(lv)
	if lv == null:
		return
	var steps: Array[Dictionary] = HintTimingSystem.parse_steps(lv.to_config_dict())
	assert_eq(steps.size(), 3, "L1 سه پله دارد: idle_45s، fail_3x، fail_6x")
	assert_eq(str(steps[0]["hint_id"]), "gentle_nudge_01")
	assert_eq(float(steps[0]["threshold"]), 45.0, "بچه باید جا برای فکرکردن داشته باشد")
	assert_eq(str(steps[2]["hint_id"]), "socratic_specific_01")
	assert_eq(float(steps[2]["threshold"]), 6.0)
	var sys := _make_sys(lv.to_config_dict())
	for i: int in range(3):
		GameState.register_attempt_failed()
	assert_signal_emitted_with_parameters(EventBus, "hint_requested", ["socratic_operation_01"])
	for i: int in range(3):
		GameState.register_attempt_failed()
	assert_signal_emitted_with_parameters(EventBus, "hint_requested", ["socratic_specific_01"])
	sys.tick(45.0)
	assert_signal_emitted_with_parameters(EventBus, "hint_requested", ["gentle_nudge_01"])


func test_no_hint_file_needed_yet_and_no_network() -> void:
	# فاز ۴ نباید به `aria_templates.json` (فاز ۵) وابسته شود؛ فقط id رد می‌کند
	assert_true(FileAccess.file_exists("res://data/levels/tier1/level_1_01.json"))
	for id: String in LEVEL_IDS:
		var sys := _make_sys(LevelLoader.load_config(id))
		assert_true(sys.is_armed(), "%s پارس می‌شود" % id)
		sys.tick(60.0)
		assert_eq(sys.fired_count(), 1, "%s: یک پله‌ی idle، بدون هیچ فایل دیالوگی" % id)
		_sys = null
		sys.queue_free()
