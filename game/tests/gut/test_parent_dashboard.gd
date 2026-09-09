extends GutTest
# ===========================================================================
# تسک ۶.۵ — ParentDashboard: DoD «داده‌ها دقیقاً با مقادیر واقعی PlayerModel می‌خورند»
# ---------------------------------------------------------------------------
# روش کار: مدلِ ساختگی با اعدادِ **غیرردیف** (تا هیچ تصادفی باعث تصادق نشود)، بعد
# خواندنِ متن‌های داشبورد و مقایسه با همان فرمتی که `Loc` تولید می‌کند. اگر روزی
# کسی یک میانگین/گِردِ تازه داخل داشبورد حساب کند، این تست می‌شکند — که دقیقاً
# خواستِ سند است: داشبورد نباید «تقریبی‌تر» از مدل بشود.
# ===========================================================================

const DASH_SCENE := "res://scenes/ui/ParentDashboard.tscn"

var _saved_model: PlayerModel = null
var _saved_adaptive: bool = true


func before_each() -> void:
	_saved_model = GameState.active_model
	_saved_adaptive = DifficultyEngine.adaptive_selection
	SettingsStore.reset_for_tests()


func after_each() -> void:
	GameState.active_model = _saved_model
	DifficultyEngine.adaptive_selection = _saved_adaptive
	SettingsStore.reset_for_tests()
	Loc.set_locale(Loc.default_locale())


func _fake_model() -> PlayerModel:
	var m := PlayerModel.create_new("آزمون‌گر")
	m.total_playtime_sec = 3661.5
	m.hint_usage_rate = 0.234
	m.avg_time_to_solve_sec = 42.5
	var ids: Array[String] = ["tier1_level_01", "tier1_level_03", "tier1_level_02"]
	m.levels_completed = ids
	var rating := SkillRating.new()
	rating.elo = 1120.0
	rating.confidence = 0.62
	rating.attempts = 34
	m.skills["addition_basic"] = rating
	m.error_patterns = [
		{"type": "sign_flip_on_subtraction", "count": 3},
		{"type": "forgets_both_sides", "count": 11},
	]
	for i: int in range(120):
		m.aria_transcript_log.append({
			"timestamp": "2026-09-0%dT14:%02d:00Z" % [1 + int(i / 60), i % 60],
			"hint_id": "gentle_nudge_%02d" % (i % 9 + 1),
			"level_id": "tier1_level_%02d" % (i % 5 + 1),
			"text": "متنِ آزمایشیِ شمارهٔ %d" % i,
		})
	return m


## یک‌جا باز کردن قفل: از `dash.gate_seed` خوانده می‌شود تا هیچ تستی جوابِ
## seedِ دیگر را نفرستد (خطایی که قفل را نبازد و همهٔ assertهای بعدی را گمراه کند).
func _reveal(dash: ParentDashboard) -> void:
	var seed: int = dash.gate.question_seed
	assert_true(dash.gate.submit(str(int(ParentGate.make_question(seed)["answer"]))),
		"پاسخ درست باید قفل را باز کند")


func _make(seed: int = 4) -> ParentDashboard:
	var packed: PackedScene = load(DASH_SCENE)
	assert_not_null(packed, "ParentDashboard.tscn باید بارگذاری شود")
	var dash: ParentDashboard = packed.instantiate() as ParentDashboard
	assert_not_null(dash, "ریشه باید ParentDashboard باشد")
	dash.allow_scene_change = false
	dash.gate_seed = seed
	add_child_autofree(dash)
	return dash


func test_the_gate_lives_inside_the_dashboard_and_blocks_content() -> void:
	var dash := _make()
	assert_not_null(dash.gate, "قفل داخل همین صحنه است، نه در منو")
	assert_true(dash.gate_enabled, "پیش‌فرض: قفل روشن است")
	assert_false(dash.reveal_without_gate_for_debug)
	assert_false(dash.is_revealed())
	assert_false(dash.content.visible, "پشت قفل، هیچ آماری روی صفحه نیست")
	var answer: int = int(ParentGate.make_question(4)["answer"])
	assert_watch_signals(dash)
	dash.gate.submit(str(answer))
	assert_true(dash.is_revealed(), "پاسخ درست ⇒ محتوا")
	assert_true(dash.content.visible)
	assert_signal_emitted(dash, "content_revealed")
	assert_false(dash.gate.visible, "قفل بعد از عبور مخفی می‌شود (نه free: برای بازگشت لازم است)")


func test_every_number_on_the_screen_comes_from_the_model() -> void:
	GameState.active_model = _fake_model()
	var m: PlayerModel = GameState.active_model
	var dash := _make()
	_reveal(dash)
	dash.refresh()
	assert_eq(dash.stat_text("levels"), Loc.digits("3"))
	assert_eq(dash.stat_text("time"), Loc.duration_sec(m.total_playtime_sec))
	assert_eq(dash.stat_text("hint_rate"), Loc.percent(m.hint_usage_rate))
	assert_true(dash.stat_text("avg_time").contains(Loc.digits("42.5")),
		dash.stat_text("avg_time"))
	assert_eq(dash.chart.row_count(), 1, "یک مهارت در مدل ⇒ یک میله")
	assert_eq(float(dash.chart.rows[0]["elo"]), 1120.0)
	assert_almost_eq(float(dash.chart.rows[0]["fill"]), (1120.0 - 400.0) / 1600.0, 0.001,
		"قد میله از همان بازهٔ Elo می‌آید، نه از گِردکردن")
	assert_eq(dash.chart.rows[0]["label"], Loc.t("skill.addition_basic"),
		"نام قابل‌فهم والدی، نه کلیدِ فنی")


func test_the_transcript_is_complete_and_scrollable() -> void:
	GameState.active_model = _fake_model()
	var dash := _make()
	_reveal(dash)
	dash.refresh()
	var m: PlayerModel = GameState.active_model
	assert_eq(dash.transcript_row_count(), m.aria_transcript_log.size(),
		"§۲ سند داده‌ها: لاگ «کامل و بدون حذف» است ⇒ داشبورد هم نباید برش بزند")
	assert_eq(dash.stat_text("transcript_count"), Loc.digits("120"))
	var first: Label = dash.transcript_box.get_child(0) as Label
	assert_not_null(first)
	if first != null:
		assert_true(first.text.contains("gentle_nudge_01"), first.text)
		assert_true(first.text.contains(Loc.digits("14:00")), "ساعتِ محاوره‌ای از timestamp:")
	var last: Label = dash.transcript_box.get_child(dash.transcript_row_count() - 1) as Label
	assert_true(last.text.contains("شمارهٔ 119"), last.text)
	var scroll: ScrollContainer = dash.get_node("Content/Scroll") as ScrollContainer
	assert_not_null(scroll, "۱۲۰ ردیف باید قابل‌اسکرول باشد (§۶.۵ «قابل‌اسکرول»)")


func test_error_patterns_are_shown_biggest_first() -> void:
	# بدهی فاز ۴: `error_patterns` در داشبورد نمایش داده نمی‌شد
	GameState.active_model = _fake_model()
	var dash := _make()
	_reveal(dash)
	dash.refresh()
	assert_eq(dash.error_row_count(), 2)
	var top: Label = dash.error_box.get_child(0) as Label
	assert_true(top.text.contains(Loc.digits("11")), top.text)
	assert_true(top.text.contains(Loc.t("error.forgets_both_sides")), top.text)
	assert_false(top.text.contains("forgets_both_sides"),
		"کلیدِ فنی نباید به والد نمایش داده شود وقتی برچسبش تعریف شده است")


func test_the_adaptive_kill_switch_moves_the_engine_and_persists() -> void:
	GameState.active_model = _fake_model()
	var dash := _make()
	_reveal(dash)
	assert_true(DifficultyEngine.adaptive_selection)
	assert_eq(dash.adaptive_status.text, Loc.t("dashboard.adaptive_on"))
	dash.adaptive_toggle.set_pressed_no_signal(false)
	dash._on_adaptive_toggled(false)
	assert_false(DifficultyEngine.adaptive_selection,
		"دکمه باید موتور را خاموش کند، نه اینکه فقط ذخیره شود")
	assert_false(bool(SettingsStore.get_value("adaptive_selection")))
	assert_eq(dash.adaptive_status.text, Loc.t("dashboard.adaptive_off"))
	dash._on_adaptive_toggled(true)
	assert_true(DifficultyEngine.adaptive_selection)


func test_export_for_review_produces_valid_json_without_network() -> void:
	var m := _fake_model()
	GameState.active_model = m
	SaveSystem.bind_model(m)
	var dash := _make()
	_reveal(dash)
	assert_watch_signals(dash)
	dash.export_button.pressed.emit()
	assert_signal_emitted(dash, "export_requested")
	assert_true(dash.export_label.visible, "بازخورد «آماده شد» به والد داده می‌شود")
	var raw: Variant = JSON.parse_string(SaveSystem.export_json_for_parent())
	assert_true(raw is Dictionary, "خروجی باید JSONِ مدل باشد")
	if raw is Dictionary:
		var d: Dictionary = raw
		assert_eq((d.get("levels_completed", []) as Array).size(), 3)
		assert_eq(d.get("aria_transcript_log", []).size(), 120)
		assert_false(d.has("settings"), "تنظیمات دستگاه در خروجی مدل نیست (ADR-045)")


func test_translating_the_labels_does_not_translate_the_data() -> void:
	GameState.active_model = _fake_model()
	var dash := _make()
	_reveal(dash)
	dash.refresh()
	assert_true(Loc.set_locale("en"))
	UIKit.retranslate(dash)
	assert_eq(dash.stat_text("levels"), Loc.digits("3"))
	var row: Label = dash.transcript_box.get_child(0) as Label
	assert_true(row.text.contains("gentle_nudge_01"),
		"ردیف داده نباید با retranslate به یک رشتهٔ UI تبدیل شود: " + row.text)
	assert_true(Loc.set_locale("fa"))


func test_an_empty_model_is_explained_not_shown_as_zero_everywhere() -> void:
	GameState.active_model = PlayerModel.create_new("تازه‌وارد")
	var dash := _make()
	_reveal(dash)
	dash.refresh()
	assert_eq(dash.chart.row_count(), 0)
	assert_eq(dash.error_row_count(), 1, "یک ردیف «داده‌ای نیست» بهتر از جدول تهی است")
	assert_eq(dash.transcript_row_count(), 1)
	assert_eq(dash.stat_text("levels"), Loc.digits("0"))
	assert_true(UIKit.audit_touch_targets(dash).is_empty(), str(UIKit.audit_touch_targets(dash)))


func test_the_transcript_records_what_the_child_actively_asked_for() -> void:
	# حلقهٔ بستهٔ فاز ۵→۶: درخواست راهنما باید در لاگِ والدین بنشیند، با همان متن.
	LevelLoader.clear_pending_config()
	DifficultyEngine.reset_state()
	var m := PlayerModel.create_new("آزمون")
	GameState.active_model = m
	var scene: LevelController = LevelLoader.create_level_scene("tier1_level_01") as LevelController
	add_child_autofree(scene)
	await get_tree().process_frame
	assert_not_null(scene.hud)
	scene.hud.hint_button.pressed.emit()
	await get_tree().process_frame
	assert_eq(m.aria_transcript_log.size(), 1,
		"AriaController باید هر متنی که کودک دیده را ثبت کند")
	if m.aria_transcript_log.is_empty():
		return
	var entry: Dictionary = m.aria_transcript_log[0]
	assert_eq(str(entry.get("hint_id", "")), "gentle_nudge_01")
	assert_false(str(entry.get("text", "")).is_empty(), "متن هم ثبت می‌شود (ADR-048)")
	assert_eq(str(entry.get("text", "")), scene.hud.dialogue_box.visible_text())
