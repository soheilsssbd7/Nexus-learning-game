extends GutTest
# ===========================================================================
# تسک ۷.۶ — AudioManager: placeholderهای صوتی، integrate‌شده و قابل‌شنیدن
# ---------------------------------------------------------------------------
# DoD ۷.۶ می‌گوید «قابل‌شنیدن» ✗✓ در CIِ هدلس اسپیکر نداریم ⇒ چیزی که سنجیدنی است
# این‌هاست: (۱) هر شناسه‌ی manifest **سنتز دارد** و برعکس (دو منبع حقیقت، جفت ✓)؛
# (۲) خروجی **بی‌صدا نیست** (RMS غیرصفر ✓✓ یک `AudioStreamWAV`ِ صامت، سبزترین دروغِ
# ممکن است ✗)؛ (۳) محدودیت‌های **حجم/زمان** گوشی ارزان ✓؛ (۴) حلقهٔ موزیک **بی‌درز** است
# (نمونهٔ اول و آخر نزدیک ⇒ «تق»ی هر ۴ ثانیه نداریم ✓)؛ (۵) **سکوت از باس می‌آید**، نه
# از فلگِ دوم (والد باید بتواند خاموش کند — §۶.۵ ✗✓ این یکی از الزاماتِ Polina/GDPR نیست،
# از الزاماتِ «بازیِ کودک» است ✓)؛ (۶) باس‌ها را **کد نمی‌سازد** (منبع حقیقت:
# `default_bus_layout.tres` ✓✓ من خودم یک‌بار همین اشتباه را کردم ✗ و تست نگهبان شد).
# ===========================================================================

const AM_SCRIPT := preload("res://scripts/autoload/AudioManager.gd")
const MANIFEST_PATH := "res://data/audio/audio_assets.json"
const SFX_EXT := [".wav", ".ogg", ".mp3", ".flac"]
const MAX_ALL_SFX_MS := 4000.0	# بودجهٔ «رویه‌سازیِ همه‌ی SFX» در شروعِ بازی ✗✓ (کوتاهِ موبایل)

var _assets: Array = []


var _saved_sfx_volume := 1.0
var _saved_music_volume := 1.0


func before_all() -> void:
	# مقدارِ واقعیِ والد را نگه می‌داریم ✗✓ تستِ «سکوت از باس» اسلایدر را تکان می‌دهد و اگر
	# برنگردد، بقیهٔ فایل‌ها با تنظیماتِ دست‌کاری‌شده اجرا می‌شوند (ترتیبِ GUT = فایل، سپس نامِ تست ✗).
	_saved_sfx_volume = float(SettingsStore.get_value("sfx_volume"))
	_saved_music_volume = float(SettingsStore.get_value("music_volume"))



	assert_true(FileAccess.file_exists(MANIFEST_PATH), "manifest صوتی نیست: %s" % MANIFEST_PATH)
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert_true(parsed is Dictionary, "audio_assets.json باید object باشد ✗")
	if parsed is Dictionary:
		_assets = (parsed as Dictionary).get("assets", []) as Array


func test_manifest_and_synthesizer_are_paired() -> void:
	# نه یتیمِ یک‌طرفه ✗✓ (صدایی که سنتز ندارد = بی‌صدا؛ سنتزی که manifest ندارد = داراییِ
	# بی‌سردست که هیچ‌وقت به فایلِ نهایی تبدیل نمی‌شود ✗ و در «لیستِ سفارش» هم نیست ✓)
	var shapes: Dictionary = AM_SCRIPT.SHAPES
	var in_manifest := {}
	for a: Variant in _assets:
		var d: Dictionary = a as Dictionary
		var id: String = str(d.get("id", ""))
		assert_false(in_manifest.has(id), "id تکراری در manifest: %s ✗" % id)
		in_manifest[id] = true
		assert_true(shapes.has(id), "`%s` در manifest است ولی سنتز ندارد ⇒ بی‌صدا می‌ماند ✗" % id)
	for id: String in shapes.keys():
		assert_true(in_manifest.has(id), "سنتزِ `%s` در manifest نیست ⇒ در لیستِ سفارش هم نیست ✗" % id)
	assert_gte(in_manifest.size(), 15, "MVP به ۹ SFX + ۸ موزیک نیاز دارد ✗")


func test_every_id_synthesizes_non_silent_audio_within_its_budget() -> void:
	var shapes: Dictionary = AM_SCRIPT.SHAPES
	var max_sec := {}
	for a: Variant in _assets:
		var d: Dictionary = a as Dictionary
		max_sec[str(d.get("id"))] = float(d.get("max_sec", 0.0))
	for id: String in shapes.keys():
		var samples: PackedFloat32Array = AM_SCRIPT.synth_samples(shapes[id] as Array)
		assert_gt(samples.size(), 0, "%s: خروجی خالی ⇒ هیچ صدایی ✗" % id)
		var seconds := float(samples.size()) / float(AM_SCRIPT.SAMPLE_RATE)
		var cap: float = float(max_sec.get(id, 0.0))
		if cap > 0.0:
			assert_lt(seconds, cap + 0.06,
				"%s: %.2fs از سقفِ %.2fs بلندتر است ⇒ آزارِ حسی ✗" % [id, seconds, cap])
		var power: float = AM_SCRIPT.rms(samples)
		# «غیرصفر» کافی نیست ✗ اگر RMS زیرِ ۰٫۰۱ باشد، روی اسپیکرِ موبایل عملاً شنیده نمی‌شود ✓
		assert_gt(power, 0.01, "%s: RMS=%.4f ⇒ عملاً سکوت است ✗" % [id, power])
		assert_lt(power, 0.95, "%s: RMS=%.4f ⇒ کلیپ/اعوجاج روی اسپیکرِ کوچک ✗" % [id, power])


func test_music_loops_are_seamless_and_sfx_are_one_shot() -> void:
	var shapes: Dictionary = AM_SCRIPT.SHAPES
	for id: String in shapes.keys():
		var shape: Array = shapes[id] as Array
		var is_pad := str(shape[0]) == "pad"
		var samples: PackedFloat32Array = AM_SCRIPT.synth_samples(shape)
		var stream: AudioStreamWAV = AM_SCRIPT.build_stream(samples,
			float(AM_SCRIPT.MUSIC_SEC) if is_pad else 0.0)
		if is_pad:
			assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD,
				"%s: موزیک باید حلقه شود ✗ (موزیکِ ۴ ثانیه‌ای که تمام شود، سکوت است ✓)" % id)
			var gap: float = absf(samples[0] - samples[samples.size() - 1])
			var peak: float = 0.0
			for s: float in samples:
				peak = maxf(peak, absf(s))
			assert_lt(gap, maxf(peak * 0.25, 0.02),
				"%s: درزِ حلقه (%.3f) ⇒ «تق» در هر دور ✗" % [id, gap])
		else:
			assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_DISABLED,
				"%s: SFX نباید حلقه شود ✗" % id)


func test_silence_is_a_bus_property_not_a_second_flag() -> void:
	# §۶.۵: والد باید بتواند صدا را خاموش کند و «صفر» یعنی صفر ✗✓ اگر `AudioManager`
	# فلگِ دومِ خودش را داشته باشد، اسلایدرِ والدین می‌تواند «روشن» بماند و صدا بی‌صدا
	# باشد (یا برعکس) ⇒ دو منبع حقیقتِ سکوت ✗✓ تستِ رفتاری: باس mute است ⇒ خروجیِ والدین
	# را همان باس می‌بندد، و `AudioManager` هنوز صدا را «پخش» می‌کند ✓ (منطقِ بازی نباید
	# به شنیده‌شدن وابسته باشد ✗✓ این چیزی است که در هدلس هم سنجیدنی است ✓).
	var idx: int = AudioServer.get_bus_index(SettingsStore.BUS_SFX)
	assert_gte(idx, 0, "باس SFX نیست ⇒ `default_bus_layout` بارگذاری نشده ✗")
	if idx < 0:
		return
	var before: int = int(AudioManager.debug_state().get("play_count", 0))
	SettingsStore.set_value("sfx_volume", 0.0)
	SettingsStore.apply_audio()
	assert_true(AudioServer.is_bus_mute(idx), "صفر باید mute باشد، نه «خیلی آروم» ✗")
	assert_true(AudioManager.play_sfx("ui_tap", "test:bus_silence"))
	assert_eq(int(AudioManager.debug_state().get("play_count", 0)), before + 1,
		"سکوتِ باس نباید منطقِ پخش را بخواباند ✗ (فیلترِ دوباره = دو منبع حقیقت ✓)")
	SettingsStore.set_value("sfx_volume", 1.0)
	SettingsStore.apply_audio()
	assert_false(AudioServer.is_bus_mute(idx), "برگشتِ صدا باید با همان اسلایدر باشد ✓")


func after_all() -> void:
	SettingsStore.set_value("sfx_volume", _saved_sfx_volume)
	SettingsStore.set_value("music_volume", _saved_music_volume)
	SettingsStore.apply_audio()


func test_buses_come_from_the_project_not_from_code() -> void:
	# منبع حقیقتِ چیدمانِ باس، `project.godot` + `default_bus_layout.tres` است ✗✓ اگر کد
	# در `_ready` باس بسازد، دو نسخه از واقعیت داریم (و باسِ تکراری در ادیتور هم دیده
	# می‌شود ✗). این تست **متنِ منبع** را می‌خواند ✗✓ چون تنها راهِ ارزانِ بستنِ این دام است.
	var src: String = FileAccess.get_file_as_string("res://scripts/autoload/AudioManager.gd")
	assert_false(src.contains("AudioServer.add_bus"),
		"AudioManager نباید باس بسازد؛ چیدمان از `default_bus_layout.tres` می‌آید ✗")
	assert_gte(AudioServer.get_bus_index(SettingsStore.BUS_MUSIC), 0)
	assert_gte(AudioServer.get_bus_index(SettingsStore.BUS_SFX), 0)


func test_twenty_sounds_in_one_frame_do_not_grow_the_player_pool() -> void:
	# کره‌ریختنِ پشت‌سرهم ⇒ سرقتِ نوبتی ✓✓ (نه صف، نه ساختِ player بی‌نهایت ✗)
	var before: int = AudioManager.get_child_count()
	var st: Dictionary = AudioManager.debug_state()
	var voices: int = int(st.get("voices", 0))
	assert_gte(voices, 4, "استخرِ صدا باید چندتایی باشد ✗")
	for i: int in 20:
		assert_true(AudioManager.play_sfx("orb_drop", "test:stress"),
			"صدای %d پخش نشد ⇒ `play_sfx` بی‌صدا false می‌دهد ✗" % i)
	assert_eq(AudioManager.get_child_count(), before,
		"بازیکنِ تازه ساخته شد ✗✓ استخر باید ثابت بماند (حافظه/کانال روی گوشی ارزان)")
	var after: Dictionary = AudioManager.debug_state()
	assert_eq(int(after.get("play_count", 0)) - int(st.get("play_count", 0)), 20)


func test_no_committed_audio_binaries_yet() -> void:
	# قاعدهٔ ریپو «باینری تولیدی در گیت نه» ✓✓ برای صدا هم جاری است ✗✓ (placeholderها
	# رویه‌ای‌اند؛ فایلِ سفارشیِ نهایی در فاز ۸/۱۱ با سیاستِ حجم می‌آید، نه الان ✓)
	var dir := DirAccess.open("res://assets/audio")
	if dir == null:
		return
	dir.list_dir_begin()
	var found: Array[String] = []
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.get_extension().to_lower() in SFX_EXT:
			found.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	assert_true(found.is_empty(), "فایل صوتی در گیت commit شده ✗ (placeholder باید رویه‌ای باشد): %s" % str(found))


func test_generating_every_asset_stays_inside_the_startup_budget() -> void:
	# سنتز در CPU است ✗✓ اگر روی گوشیِ ارزان ۴۰۰ms بگیرد، کودکِ ما نباید اولِ بازی
	# معطل شود ⇒ همه‌ی ۱۷ شناسه را یک‌جا می‌سازیم و زمان را می‌سنجیم ✓ (کش ⇒ یک‌بار ✓)
	var t0 := Time.get_ticks_msec()
	for id: String in (AM_SCRIPT.SHAPES as Dictionary).keys():
		assert_not_null(AudioManager.stream_for(id), "%s: stream نساخت ✗" % id)
	var took := float(Time.get_ticks_msec() - t0)
	assert_lt(took, MAX_ALL_SFX_MS,
		"سنتزِ کامل %.0fms از بودجه‌ی %.0fms بیشتر شد ⇒ روی گوشی ارزان محسوس است ✗"
			% [took, MAX_ALL_SFX_MS])
