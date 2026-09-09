extends GutTest
# ===========================================================================
# تسک ۵.۴ — DoD: «هر ۶ state از کد قابل‌فراخوانی و از نظر بصری قابل‌تفکیک است»
# «قابل‌تفکیک» را با خواندن clip خودِ AnimationPlayer می‌سنجیم: رنگ هسته، مدت و
# ترَک‌های متحرک باید فرق داشته باشند (رد کردنِ «شش انیمیشنِ کپی‌شده»).
# ===========================================================================

const ARIA_SCENE := "res://scenes/characters/Aria.tscn"

var _aria: AriaAvatar = null


func before_each() -> void:
	watch_signals(EventBus)
	_aria = null


func _make() -> AriaAvatar:
	var scene: AriaAvatar = load(ARIA_SCENE).instantiate() as AriaAvatar
	assert_not_null(scene, "صحنه Aria باید با اسکریپتِ کلاس‌دار لود شود")
	add_child_autofree(scene)
	return scene


func _player(node: AriaAvatar) -> AnimationPlayer:
	return node.get_node_or_null("Anim") as AnimationPlayer


func test_the_scene_has_the_body_core_and_player() -> void:
	_aria = _make()
	assert_not_null(_aria, "ریشه AriaAvatar است")
	assert_not_null(_aria.get_node_or_null("Body") as AriaCrystal, "بدنه‌ی چندوجهی")
	assert_not_null(_aria.get_node_or_null("Body/Core") as AriaCore, "هسته‌ی نورانی")
	assert_not_null(_player(_aria), "AnimationPlayer لازم است (§۳)")


func test_all_six_states_exist_and_are_playable_from_code() -> void:
	_aria = _make()
	var known: Array[String] = _aria.known_states()
	assert_eq(known.size(), AriaAvatar.STATES.size(), "شش state لیست Art Bible §۳، نه کمتر")
	for state: String in AriaAvatar.STATES:
		assert_true(known.has(state), "%s ساخته نشده" % state)
	for state: String in AriaAvatar.STATES:
		assert_true(_aria.play_state(state), "%s باید قابل‌فراخوانی باشد" % state)
		assert_eq(str(_player(_aria).current_animation), state)
		assert_eq(_aria.current_state, state)


func test_states_are_visually_distinguishable() -> void:
	# §۳: «فقط رنگ هسته عوض می‌شود» → تفکیک‌پذیری را روی خودِ نود می‌سنجیم (نه کیفریم‌های
	# clip)، چون clipها placeholder‌ی کد هستند و فاز ۸ جابه‌جا می‌شوند (ADR-043).
	_aria = _make()
	var p := _player(_aria)
	var colors := {}
	var durations := {}
	var looped := {}
	for state: String in AriaAvatar.STATES:
		assert_true(_aria.play_state(state), state + " قابل‌فراخوانی است")
		colors[str(_aria.core_modulate())] = state
		var anim: Animation = p.get_animation(state)
		assert_not_null(anim, state + " باید clip داشته باشد")
		if anim == null:
			return
		assert_gt(anim.length, 0.05, "%s مدتِ نامفهوم ندارد" % state)
		durations[state] = anim.length
		looped[state] = anim.loop_mode != Animation.LOOP_NONE
		assert_true(anim.get_track_count() >= 1, "%s بی‌ترَک نیست" % state)
	assert_eq(colors.size(), AriaAvatar.STATES.size(),
		"رنگ هسته‌ی هر شش state باید متفاوت باشد: " + str(colors))
	var dmin: float = 1e9
	var dmax: float = -1e9
	for k: Variant in durations.keys():
		dmin = minf(dmin, float(durations[k]))
		dmax = maxf(dmax, float(durations[k]))
	assert_true(dmin < dmax, "مدت انیمیشن‌ها فرق دارد (نوسان آرام vs پالس سریع)")
	assert_true(bool(looped[AriaAvatar.STATE_IDLE]), "idle لوپ است (§۳ «حالت پیش‌فرض»)")
	assert_false(bool(looped[AriaAvatar.STATE_CELEBRATING]),
		"celebrating یک‌بار پخش می‌شود و تمام")
	for state: String in AriaAvatar.STATES:
		assert_eq(str(_aria.core_modulate()), str(AriaAvatar.core_color_for(state)),
			state + ": رنگ هسته از همان جدول §۳ می‌آید")


func test_the_encouraging_pulse_matches_the_art_bible() -> void:
	_aria = _make()
	var anim: Animation = _player(_aria).get_animation(AriaAvatar.STATE_ENCOURAGING)
	assert_not_null(anim)
	if anim == null:
		return
	# §۳: «scale پالسی ۱.۰ → ۱.۱۵ → ۱.۰ طی ۰.۴ ثانیه»
	assert_true(absf(anim.length - 0.4) < 0.001, "مدت ۰.۴ ثانیه (§۳)، نه هر عددی")
	var scale_track: int = anim.find_track("Body:scale", Animation.TYPE_VALUE)
	assert_ne(scale_track, -1, "ترَک scale دارد")
	if scale_track < 0:
		return
	var peak: Vector2 = anim.track_get_key_value(scale_track, 1)
	assert_true(absf(peak.x - 1.15) < 0.001, "قله‌ی پالس ۱.۱۵ (§۳)")


func test_unknown_state_is_ignored_and_idle_starts_by_default() -> void:
	_aria = _make()
	assert_eq(_aria.current_state, AriaAvatar.STATE_IDLE, "حالت پیش‌فرض §۳ = idle")
	assert_false(_aria.play_state("spinning_bear"))
	assert_eq(_aria.current_state, AriaAvatar.STATE_IDLE, "حالت قبلی نمی‌شکند")
	assert_false(_aria.has_state("nope"))


func test_it_listens_to_the_event_bus_state_signal() -> void:
	_aria = _make()
	EventBus.aria_state_changed.emit(AriaAvatar.STATE_CELEBRATING)
	assert_eq(_aria.current_state, AriaAvatar.STATE_CELEBRATING)
	assert_eq(str(_player(_aria).current_animation), AriaAvatar.STATE_CELEBRATING)
	EventBus.aria_state_changed.emit("nothing_here")
	assert_eq(_aria.current_state, AriaAvatar.STATE_CELEBRATING,
		"ورودیِ بی‌ربطِ فازهای بعد آواتار را خاموش نمی‌کند")


func test_the_controller_and_the_avatar_agree_on_state_names() -> void:
	# دو فهرست (AriaController و AriaAvatar) نباید از هم دور شوند؛ ADR-043
	for state: String in AriaController.STATE_NAMES:
		assert_true(AriaAvatar.STATES.has(state), "`%s` در آواتار نیست" % state)
	for state: String in AriaAvatar.STATES:
		assert_true(AriaController.STATE_NAMES.has(state), "`%s` را کنترلر نمی‌شناسد" % state)


func test_the_avatar_survives_without_clips() -> void:
	# اگر فاز ۸ clipها را در فایل صحنه بگذارد، `build_placeholder_clips=false`
	# باید بی‌صدا از کد ساختن رد شود و بازی نشکند
	var scene: AriaAvatar = load(ARIA_SCENE).instantiate() as AriaAvatar
	scene.build_placeholder_clips = false
	add_child_autofree(scene)
	_aria = scene
	assert_false(_aria.has_state(AriaAvatar.STATE_IDLE))
	assert_false(_aria.play_state(AriaAvatar.STATE_IDLE))
	assert_eq(_aria.known_states().size(), 0)
