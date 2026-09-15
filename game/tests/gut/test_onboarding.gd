extends GutTest
# ===========================================================================
# تسک ۶.۲ — Onboarding: «یادگیری با عمل، بدون متن طولانی» و بی‌نوشتن آمار
# ---------------------------------------------------------------------------
# دو ادعای مهم این فاز:
#   الف) آموزش همان مکانیک واقعی است (یک `LevelController` واقعی، نه ماکت) — پس
#      باید ثابت کنیم بردِ آموزش، `PlayerModel`/دشواری/شمارنده‌ها را دست نمی‌زند؛
#      وگرنه کودک بعد از آموزش، سطح ۰۱ را «حل‌شده» حساب می‌کند.
#   ب) §۴ سند هنری (۶ تُن پوست، ۸ مدل مو، رنگ مو) با محدودهٔ ذخیره‌سازی یکی است —
#      اگر هنر ۷ گزینه بدهد و `SettingsStore` ۶ را بپذیرد، انتخاب هفتم بی‌صدا
#      می‌پرد؛ این تست همان برابری را می‌سنجد.
# ===========================================================================

const SCENE := "res://scenes/main/Onboarding.tscn"
const TMP := "user://test_onboarding_settings.json"

var _saved_model: PlayerModel = null


func before_each() -> void:
	_saved_model = GameState.active_model
	SettingsStore.reset_for_tests()
	SettingsStore.load_from(TMP)


func after_each() -> void:
	GameState.active_model = _saved_model
	SettingsStore.reset_for_tests()
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(TMP.get_file()):
		dir.remove(TMP.get_file())


func _make(step: String = Onboarding.STEP_AVATAR) -> Onboarding:
	var packed: PackedScene = load(SCENE)
	assert_not_null(packed, "Onboarding.tscn باید بارگذاری شود")
	var onb: Onboarding = packed.instantiate() as Onboarding
	assert_not_null(onb, "ریشه باید Onboarding باشد")
	onb.allow_scene_change = false
	onb.start_step = step
	add_child_autofree(onb)
	return onb


func _model() -> PlayerModel:
	var m := PlayerModel.create_new("آزمون")
	GameState.active_model = m
	GameState.is_first_run = true
	return m


func test_the_two_steps_and_only_one_is_on_screen() -> void:
	var onb := _make()
	assert_true(onb.has_node("Step_avatar"), "گام آواتار")
	assert_true(onb.has_node("Step_scale"), "گام ترازو (§۶.۲: آموزش تعاملیِ یک‌مرحله‌ای)")
	assert_eq(onb.visible_steps(), [Onboarding.STEP_AVATAR])
	assert_false(onb.is_tutorial_interactive(),
		"کره‌های آموزش نباید از پشت صفحهٔ آواتار کشیده شوند")
	onb.next_step()
	assert_eq(onb.visible_steps(), [Onboarding.STEP_SCALE])
	assert_true(onb.is_tutorial_interactive())
	assert_eq(onb.current_step, Onboarding.STEP_SCALE)


func test_the_avatar_options_match_the_art_bible_and_the_storage_range() -> void:
	var onb := _make()
	assert_eq(onb.skin_buttons.size(), SettingsStore.SKIN_TONES, "§۴: شش تُن پوست")
	assert_eq(onb.hair_buttons.size(), SettingsStore.HAIR_STYLES, "§۴: هشت مدل مو")
	assert_eq(onb.color_buttons.size(), SettingsStore.HAIR_COLORS.size(),
		"رنگ مو از پالت انتخاب می‌شود (کودک متن تایپ نمی‌کند)")
	assert_eq(PlayerAvatarPreview.skin_count(), SettingsStore.SKIN_TONES,
		"هنر و محدودهٔ ذخیره باید یک عدد ببینند")
	assert_eq(PlayerAvatarPreview.hair_count(), SettingsStore.HAIR_STYLES)


func test_tapping_a_swatch_updates_the_preview_and_persists_immediately() -> void:
	var onb := _make()
	watch_signals(onb)
	var chip: Button = onb.skin_buttons[3]
	chip.pressed.emit()
	assert_eq(onb.preview.skin_tone, 3, "پیش‌نمایش همان لحظه عوض می‌شود")
	assert_eq(int(SettingsStore.avatar()["skin_tone"]), 3,
		"دکمهٔ «ذخیره» برای کودک نداریم: انتخاب باید بلافاصله نوشته شود")
	assert_signal_emitted_with_parameters(onb, "avatar_choice_made", ["skin_tone", 3])
	# «رنگ مو آزاد» ولی خارج از پالت نه: setter ایندکس را در بازه نگه می‌دارد
	onb.preview.hair_color = 99
	assert_eq(onb.preview.hair_color, SettingsStore.HAIR_COLORS.size() - 1)


func test_the_tutorial_is_the_real_mechanic_with_the_bookkeeping_off() -> void:
	var onb := _make(Onboarding.STEP_SCALE)
	var c: LevelController = onb.controller
	assert_not_null(c, "آموزش باید همان LevelController باشد")
	if c == null:
		return
	assert_false(c.report_progress, "§۶.۲: آموزش نباید آمار کودک را بنویسد")
	assert_null(c.hint_timing, "نردبان راهنما در آموزش خاموش است (بدون سروصدا، فقط عمل)")
	assert_null(c.result_bar)
	assert_false(c.error_classification_enabled)
	assert_eq(c.tray_orbs.size(), 3, "یک کرهٔ ۵ و دو کرهٔ ۲: یک کشیدن کافی است")


func test_winning_the_tutorial_teaches_without_touching_progress() -> void:
	var m: PlayerModel = _model()
	var onb := _make(Onboarding.STEP_SCALE)
	var c: LevelController = onb.controller
	if c == null:
		return
	c.attempt_settle_sec = 0.05
	var before_levels: int = m.levels_completed.size()
	var before_attempts: int = GameState.level_attempts
	var five: WeightOrb = null
	for orb: WeightOrb in c.tray_orbs:
		if orb != null and is_equal_approx(orb.value, 5.0):
			five = orb
	assert_not_null(five, "سینی آموزش باید کرهٔ ۵ را داشته باشد")
	c.place_on_right([five])
	await get_tree().process_frame
	assert_true(c.is_won(), "ترازو صاف شد ⇒ بردِ آموزش")
	assert_true(onb.is_won())
	assert_false(onb.done_button.disabled, "«بریم» فقط بعد از عمل واقعی باز می‌شود")
	assert_true(onb.feedback_label.visible, "§۶: بازخورد آرام، بی‌جشنِ بی‌مورد")
	await get_tree().process_frame
	assert_eq(m.levels_completed.size(), before_levels,
		"آموزش سطح ۰۱ را «حل‌شده» نمی‌کند — کودک واقعاً از اول بازی می‌کند")
	assert_eq(GameState.level_attempts, before_attempts)
	assert_true(m.error_patterns.is_empty(), "خطای آموزش در الگوها ثبت نمی‌شود")
	assert_true(m.aria_transcript_log.is_empty())


func test_a_wrong_move_in_the_tutorial_is_not_counted_as_an_attempt() -> void:
	var m: PlayerModel = _model()
	var onb := _make(Onboarding.STEP_SCALE)
	var c: LevelController = onb.controller
	if c == null:
		return
	c.attempt_settle_sec = 0.05
	var wrong: Array[WeightOrb] = []
	for orb: WeightOrb in c.tray_orbs:
		if orb != null and is_equal_approx(orb.value, 2.0):
			wrong.append(orb)
	assert_gte(wrong.size(), 1, "دو کرهٔ ۲ برای «اشتباهِ آموزشی» در سینی است")
	c.place_on_right(wrong)
	await get_tree().create_timer(0.2).timeout
	assert_false(c.is_won(), "۲+۲ تعادل نمی‌سازد")
	assert_eq(GameState.level_attempts, 0, "آموزش «تلاش ناموفق» ثبت نمی‌کند")
	assert_true(m.error_patterns.is_empty())
	assert_true(onb.done_button.disabled,
		"تا تعادل برقرار نشده «بریم» قفل می‌ماند")


func test_finish_records_the_visit_and_skip_only_works_on_the_avatar_step() -> void:
	var onb := _make()
	watch_signals(onb)
	assert_false(onb.is_done_recorded())
	onb.show_step(Onboarding.STEP_SCALE)
	onb.skip_to_end()
	assert_eq(get_signal_emit_count(onb, "finished"), 0,
		"ردکردنِ گام عمل = ردکردنِ خودِ آموزش ⇒ اجازه نداریم")
	onb.show_step(Onboarding.STEP_AVATAR)
	onb.skip_to_end()
	assert_signal_emitted(onb, "finished")
	assert_true(onb.is_done_recorded(), "ردکردن هم رکورد می‌گذارد تا منو اذیت نکند")
	assert_false(GameState.is_first_run)


func test_no_text_wall_in_the_tutorial() -> void:
	for step: String in [Onboarding.STEP_AVATAR, Onboarding.STEP_SCALE]:
		var onb := _make(step)
		var labels: Array[Label] = []
		_collect_labels(onb, labels)
		var too_long: Array[String] = []
		for label: Label in labels:
			if label.visible and label.text.length() > Onboarding.MAX_LABEL_LEN:
				too_long.append("%s=%d" % [label.name, label.text.length()])
		assert_true(too_long.is_empty(),
			"§۶.۲ «بدون متن طولانی»: " + str(too_long))
		var shown: int = 0
		for label: Label in labels:
			if label.visible:
				shown += 1
		assert_lte(shown, Onboarding.MAX_LABELS_PER_STEP,
			"حداکثر %d برچسب در هر گام (گام %s)" % [Onboarding.MAX_LABELS_PER_STEP, step])


func test_the_scene_is_touch_ready_and_never_overflows_the_canvas() -> void:
	for step: String in [Onboarding.STEP_AVATAR, Onboarding.STEP_SCALE]:
		var onb := _make(step)
		assert_true(UIKit.audit_touch_targets(onb).is_empty(),
			"گام %s: %s" % [step, str(UIKit.audit_touch_targets(onb))])
		var over: Array[String] = []
		_check_overflow(onb, over)
		assert_true(over.is_empty(), "گام %s از عرض ۱۰۸۰ بیرون می‌زند: %s" % [step, str(over)])


func _collect_labels(node: Node, out: Array[Label]) -> void:
	for child: Node in node.get_children():
		if child is Label:
			out.append(child)
		_collect_labels(child, out)


func _check_overflow(node: Node, out: Array[String]) -> void:
	for child: Node in node.get_children():
		if child is Control:
			var ctrl := child as Control
			if ctrl.visible and ctrl.size.x > 0.0:
				var right: float = ctrl.global_position.x + ctrl.size.x
				if right > 1080.5 or ctrl.global_position.x < -0.5:
					out.append("%s → %s" % [str(child.name), str(right)])
		_check_overflow(child, out)
