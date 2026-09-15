extends GutTest
# ===========================================================================
# تسک ۶.۳ — SettingsStore: ترجیحات، در فایلِ جدا از PlayerModel (ADR-045)
# ---------------------------------------------------------------------------
# چیزی که اینجا گران است: فایل user:// ممکن است دست‌کاری/نیمه‌کاره باشد و کودک
# نباید هیچ‌وقت صفحه‌ی خطا ببیند؛ و «صدا/باس» فقط وقتی معنا دارد که چیدمان باسِ
# پروژه واقعاً Music/SFX داشته باشد — پس همان را هم از AudioServer می‌پرسیم.
# ===========================================================================

const TEST_PATH_TMPL := "user://test_ui_settings_%d.json"

var _path: String = ""


func before_each() -> void:
	SettingsStore.reset_for_tests()
	_path = TEST_PATH_TMPL % Time.get_ticks_msec()


func after_each() -> void:
	SettingsStore.reset_for_tests()
	# kill-switch یک autoload است؛ اگر تست آن را false بگذارد و برنگرداند،
	# سختیِ سطوح در فایل‌های تستِ بعدی عوض می‌شود (همان دامِ فاز ۴ با streak).
	DifficultyEngine.adaptive_selection = true
	SettingsStore.load_from()
	SettingsStore.apply_audio()
	Loc.set_locale(Loc.default_locale())
	SettingsStore.reset_for_tests()


func _remove(path: String) -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(path.get_file()):
		dir.remove(path.get_file())


func test_missing_file_falls_back_to_defaults() -> void:
	var path: String = _path
	_remove(path)
	assert_false(SettingsStore.load_from(path), "فایل نیست → false، ولی مقدارها باید بیایند")
	assert_almost_eq(float(SettingsStore.get_value("music_volume")), 0.8, 0.001)
	assert_true(bool(SettingsStore.get_value("adaptive_selection")), "پیش‌فرض: تطبیق روشن")
	assert_false(bool(SettingsStore.get_value("onboarding_done")))
	_remove(path)


func test_roundtrip_survives_a_reload() -> void:
	var path: String = _path
	SettingsStore.load_from(path)
	assert_true(SettingsStore.set_value("music_volume", 0.25))
	assert_true(SettingsStore.set_value("locale", "en"))
	assert_true(SettingsStore.set_avatar_choice("hair_style", 5))
	assert_true(SettingsStore.save_to(path))
	SettingsStore.reset_for_tests()
	assert_true(SettingsStore.load_from(path), "این‌بار فایل هست")
	assert_almost_eq(float(SettingsStore.get_value("music_volume")), 0.25, 0.001)
	assert_eq(str(SettingsStore.get_value("locale")), "en")
	assert_eq(int(SettingsStore.avatar()["hair_style"]), 5)
	_remove(path)


func test_out_of_range_and_wrong_types_are_clamped_not_trusted() -> void:
	assert_eq(float(SettingsStore.clamp_value("music_volume", 9.0)), 1.0)
	assert_eq(float(SettingsStore.clamp_value("music_volume", -3.0)), 0.0)
	assert_eq(float(SettingsStore.clamp_value("music_volume", "بلند!")), 0.8,
		"رشته‌ی بی‌معنی ⇒ پیش‌فرض، نه NaN و نه صفر")
	assert_almost_eq(float(SettingsStore.clamp_value("sfx_volume", "0.5")), 0.5, 0.001)
	assert_eq(str(SettingsStore.clamp_value("locale", "de")), "fa",
		"زبان تعریف‌نشده رد می‌شود؛ صفحه نباید نیمه‌انگلیسی شود")
	assert_eq(str(SettingsStore.clamp_value("haptics_enabled", "false")), "false")
	assert_null(SettingsStore.clamp_value("unknown.key", 1),
		"کلید ناشناخته ⇒ تهی، تا فراخواننده مجبور باشد تصمیم بگیرد (نه 0، نه false)")


func test_garbage_avatar_only_moves_the_allowed_range() -> void:
	var raw := {"avatar": {"skin_tone": 99, "hair_style": -4, "hair_color": "قرمز",
		"hat": "دزد دریایی"}}
	var clean: Dictionary = SettingsStore.sanitize(raw)
	var av: Dictionary = clean["avatar"]
	assert_eq(int(av["skin_tone"]), SettingsStore.SKIN_TONES - 1, "۶ تُن پوست (§۴)")
	assert_eq(int(av["hair_style"]), 0, "ایندکس منفی = اولی")
	assert_eq(int(av["hair_color"]), 0, "رنگ معتبر = ایندکس پالت")
	assert_false(av.has("hat"), "کلید ناشناخته وارد فایل نمی‌شود")


func test_sanitize_accepts_a_dict_of_wrong_shape() -> void:
	for bad: Variant in [[], "", 3, null, true]:
		var out: Dictionary = SettingsStore.sanitize(bad)
		assert_eq(int(out.keys().size()), SettingsStore.SPEC.keys().size(),
			"ساختار غلط ⇒ جدول پیش‌فرض کامل")


func test_unknown_key_is_refused_loudly() -> void:
	SettingsStore.load_from(_path)
	assert_false(SettingsStore.set_value("music_volme", 0.5), "تایپوی کلید باید لو برود")


func test_toggle_writes_through_to_the_difficulty_engine() -> void:
	SettingsStore.load_from(_path)
	# نقطهٔ شروعِ قطعی (بی‌وابستگی به ترتیب اجرای فایل‌ها) و ادعای **درست**: `toggle` فقط
	# ذخیره را عوض می‌کند و موتور تا `apply_gameplay_flags()` دست‌نخورده می‌ماند.
	# نوشتهٔ قبلی (`assert_false(موتور)`) دقیقاً همین رفتارِ درست را رد می‌کرد ✗ و فقط
	# وقتی سبز بود که تستِ قبلی موتور را خاموش کرده باشد — یعنی تست، تصادف را سنجید.
	DifficultyEngine.adaptive_selection = true
	assert_true(bool(SettingsStore.get_value("adaptive_selection")))
	var engine_before: bool = bool(DifficultyEngine.adaptive_selection)
	assert_true(SettingsStore.toggle("adaptive_selection"))
	assert_eq(bool(DifficultyEngine.adaptive_selection), engine_before,
		"تنها toggle موتور را عوض نمی‌کند؛ اثرش با apply دیده می‌شود")
	SettingsStore.apply_gameplay_flags()
	assert_false(bool(DifficultyEngine.adaptive_selection),
		"والد «پیشرفت خودکار» را خاموش کرد ⇒ موتور واقعاً خاموش می‌شود")
	assert_true(SettingsStore.toggle("adaptive_selection"))
	SettingsStore.apply_gameplay_flags()
	assert_true(bool(DifficultyEngine.adaptive_selection))
	_remove(_path)
	SettingsStore.load_from()


func test_the_project_defines_separate_music_and_sfx_buses() -> void:
	# DoD ۶.۳ («صدا (موسیقی/جلوه)») بدون دو باسِ جدا فقط یک اسلایدر است.
	assert_gte(SettingsStore.bus_index(SettingsStore.BUS_MUSIC), 1,
		"`assets/audio/default_bus_layout.tres` باید در پروژه بارگذاری شود")
	assert_gte(SettingsStore.bus_index(SettingsStore.BUS_SFX), 2)


func test_apply_volume_mutes_at_zero_and_is_audible_above() -> void:
	var idx: int = SettingsStore.bus_index(SettingsStore.BUS_MUSIC)
	if idx < 0:
		return
	SettingsStore.apply_volume(SettingsStore.BUS_MUSIC, 0.0)
	assert_true(AudioServer.is_bus_mute(idx), "صفر یعنی خاموش، نه «خیلی آرام»")
	SettingsStore.apply_volume(SettingsStore.BUS_MUSIC, 0.8)
	assert_false(AudioServer.is_bus_mute(idx))
	assert_gt(AudioServer.get_bus_volume_db(idx), SettingsStore.MIN_DB,
		"۰.۸ نباید در کفِ dB گیر کند")


func test_apply_locale_moves_the_string_layer() -> void:
	SettingsStore.load_from(_path)
	assert_true(SettingsStore.set_value("locale", "en"))
	SettingsStore.apply_locale()
	assert_eq(Loc.locale(), "en", "تنظیمات زبان باید متن‌ها را عوض کند")
	assert_true(SettingsStore.set_value("locale", "fa"))
	SettingsStore.apply_locale()
	assert_eq(Loc.locale(), "fa")
	_remove(_path)
	SettingsStore.load_from()
