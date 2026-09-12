extends Node
# ===========================================================================
# NEXUS — AudioManager (تسک ۷.۶ | docs/04 §فاز ۷)
# ---------------------------------------------------------------------------
# دو کار، و هر دو لازم:
#  ۱) **باس‌ها را می‌خواهد** ✓ (نه می‌سازد ✗): `SFX`/`Music` از `assets/audio/
#     default_bus_layout.tres` می‌آیند (تسک ۶.۳ ✓ `project.godot §buses`) و `SettingsStore`
#     روی همان‌ها volume/mute می‌گذارد ✗✓ «دو سازندهٔ باس» = دو منبع حقیقت ⇒ اینجا فقط
#     **ادعا** می‌کنیم و اگر نبود، بلند خطا می‌دهیم ✓✓ (اولین تلاشِ من ساختنِ باس در `_ready`
#     بود و در سندِ کامیت، فاز ۶ را «اسلات» خواندم ✗✗ بعد دیدم `default_bus_layout` از قبل هست
#     و تستش هم سبز بود ⇒ ادعایم غلط بود و پس گرفتم ✓✓ — سندِ اجرا نباید برای قشنگ‌شدنِ
#     کارِ خودم، کارِ دورِ قبل را کوچک کند ✗).
#  ۲) **placeholderِ رویه‌ای** برای هر شناسهٔ `data/audio/audio_assets.json` ✓ با
#     `AudioStreamWAV`ِ درحافظه ✗ بدونِ حتی یک بایت صوتی در گیت ✓✓ (قاعدهٔ ریپو:
#     SVG-first و بدونِ باینری؛ صدا هم «procedural-first» می‌شود ✗✓ و فایلِ نهایی در
#     `assets/audio/` جای می‌گیرد بی‌آنکه لایه‌ی پخش عوض شود).
# چرا رویه‌ای؟ چون DoD ۷.۶ می‌گوید «حداقل placeholder هر مورد integrate و
# قابل‌شنیدن است» ✗✓ «قابل‌شنیدن» یعنی **جریانِ سیگنالِ واقعی در خودِ بازی** — نه یک
# فایلِ بلادرِ بی‌صاحب ✓✓؛ و سیگنالِ ساخته‌شده در CPU را می‌توان در هدلس هم سنجید
# (RMS غیرصفر ✓) ولی فایلِ commit‌نشده را هیچ‌وقت ✗.
# ===========================================================================

const TAG := "AudioManager"
const MANIFEST_PATH := "res://data/audio/audio_assets.json"

const SAMPLE_RATE := 22050			# ۲۲kHz برای SFX/موزیکِ بی‌کلام کافی است ✓ (و نصفِ RAMِ ۴۴kHz)
const SFX_VOICES := 8				# سقفِ هم‌زمانیِ کره‌ریختنِ پشت‌سرهم ✗✓ (بی‌سقف، کودک با ۳۰ کره = ۳۰ player می‌ساخت)
const MUSIC_SEC := 4.0				# حلقهٔ کوتاهِ هم‌خانواده: ۴ ثانیه × ۸ تم ✗✓ بودجهٔ حافظهٔ گوشی ارزان

## شکلِ هر شناسه: [نوع، پارامترها] — تنها منبعِ حقیقتِ «چه چیزی ساخته می‌شود» ✓
## و `audio_assets.json` فهرستِ «چه چیزی لازم است» ⇒ تست، برابریِ این دو را می‌سنجد ✓✓
const SHAPES: Dictionary = {
	# --- SFX ---
	"orb_lift": ["tone", 660.0, 0.11, 0.55, 0.0],
	"orb_drop": ["tone", 392.0, 0.16, 0.9, 0.0],
	"scale_creak": ["sweep", 240.0, 150.0, 0.34, 0.5],
	"win_chime": ["chime", [784.0, 988.0, 1175.0], 0.62, 0.72, 0.0],
	"fail_blip": ["tone", 196.0, 0.16, 0.62, 0.0],
	"gate_open": ["sweep", 180.0, 720.0, 0.7, 0.55],
	"aria_blip": ["chime", [523.0, 659.0], 0.2, 0.4, 0.0],
	"ui_tap": ["tone", 520.0, 0.06, 0.35, 0.0],
	"ui_confirm": ["chime", [587.0, 880.0], 0.16, 0.4, 0.0],
	# --- Music (حلقهٔ ملایم؛ هر Tier یک «فاصلهٔ امن» و یک نُتِ پایهٔ خودش ✓ GDD §۴ هنر) ---
	"theme_hub": ["pad", 220.0, [1.0, 1.5, 2.0], 0.16],
	"theme_tier1": ["pad", 196.0, [1.0, 1.5, 2.0], 0.14],
	"theme_tier2": ["pad", 174.6, [1.0, 1.2, 1.8], 0.12],
	"theme_tier3": ["pad", 164.8, [1.0, 1.335, 2.0], 0.11],
	"theme_tier4": ["pad", 196.0, [1.0, 1.5, 2.25], 0.12],
	"theme_tier5": ["pad", 233.1, [1.0, 1.5, 2.0, 3.0], 0.13],
	"stinger_level_win": ["sweep", 523.0, 1046.0, 0.5, 0.5],
	"stinger_game_end": ["chime", [523.0, 659.0, 784.0, 1046.0], 1.1, 0.7, 0.0],
}

var _ready_ok := false
var _manifest: Dictionary = {}
var _streams: Dictionary = {}			# id → AudioStreamWAV (کشِ تنبل ✓)
var _voices: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer = null
var _next_voice := 0
var _current_music := ""
var _generated := 0
var _play_count := 0

# برای تست/عیوب‌یابی: آخرین‌ها را نگه می‌داریم چون در هدلس `is_playing()` معنایی ندارد ✗✓
var last_sfx_id := ""
var last_play_reason := ""


func _ready() -> void:
	_check_buses()
	_build_pool()
	_load_manifest()
	EventBus.orb_removed.connect(_on_orb_removed)
	EventBus.orb_placed.connect(_on_orb_placed)
	EventBus.level_started.connect(_on_level_started)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.attempt_failed.connect(_on_attempt_failed)
	EventBus.aria_state_changed.connect(_on_aria_state_changed)
	_ready_ok = true
	Log.debug(TAG, "آماده: %d باس، %d صدا، %d شناسه در manifest"
		% [AudioServer.bus_count, SFX_VOICES, _manifest_asset_ids().size()])


# --------------------------------------------------------------------------
# باس‌ها — حلقهٔ مفقودِ SettingsStore ✗✓
# --------------------------------------------------------------------------
## باس‌ها را **نمی‌سازد**؛ فقط وجودشان را تأیید می‌کند ✓✗ چیدمانِ باس متعلق به
## `project.godot` است (`buses/default_bus_layout`) ⇒ اگر کسی آن را بردارد، بازی نباید
## بی‌صدا «باِسِ دومی» بسازد ✗✓ باید در لاگ فریاد بزند (و `debug_state()` هم همان را
## لو می‌دهد ✓✓ تستِ `test_audio_manager.gd` این را می‌سنجد).
func _check_buses() -> void:
	for bus_name: String in [SettingsStore.BUS_SFX, SettingsStore.BUS_MUSIC]:
		if AudioServer.get_bus_index(bus_name) < 0:
			Log.error(TAG, "باس «%s» نیست ⇒ `default_bus_layout.tres` بارگذاری نشده ✗" % bus_name)


func _build_pool() -> void:
	for i: int in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = SettingsStore.BUS_SFX
		p.name = "SfxVoice%d" % i
		add_child(p)
		_voices.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = SettingsStore.BUS_MUSIC
	_music.name = "MusicPlayer"
	add_child(_music)


func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		Log.warn(TAG, "manifest صوتی نیست (%s) ⇒ فقط شناسه‌های SHAPES" % MANIFEST_PATH)
		_manifest = {}
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if parsed is Dictionary:
		_manifest = parsed
	else:
		Log.error(TAG, "manifest صوتی پارس نشد ⇒ پخش روی SHAPES می‌ماند ✗")
	var assets: Variant = _manifest.get("assets")
	if not (assets is Array):
		Log.error(TAG, "manifest: `assets` آرایه نیست ✗")


func _manifest_asset_ids() -> Array[String]:
	var out: Array[String] = []
	var assets: Variant = _manifest.get("assets")
	if assets is Array:
		for a in assets:
			var d: Dictionary = a as Dictionary
			var id: String = str(d.get("id", ""))
			if not out.has(id):
				out.append(id)
	return out


# --------------------------------------------------------------------------
# سنتزِ رویه‌ای (هیچ بایتی از دیسک خوانده نمی‌شود ✗✓)
# --------------------------------------------------------------------------
## نمونه‌های float در [-1,1] می‌گیرد و `AudioStreamWAV` ۱۶بیتی می‌سازد؛
## `loop_sec > 0` ⇒ حلقه (موزیک ✓) وگرنه تک‌ضربه (SFX ✓).
static func build_stream(samples: PackedFloat32Array, loop_sec: float = 0.0) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SAMPLE_RATE
	w.stereo = false
	var n: int = samples.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i: int in n:
		var v: int = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	w.data = bytes
	if loop_sec > 0.0:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = maxi(1, int(loop_sec * float(SAMPLE_RATE)) - 1)
	else:
		w.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return w


## پاکتِ نماییِ ساده ✓ (کودک باید «ضربه» را بشنود نه بوقِ پیوسته ✓✓ پس attack کوتاه و
## decay نرمال، وگرنه هر SFX یک بیپِ آزارنده است ✗).
static func _env(i: int, n: int, attack: float) -> float:
	var t := float(i) / float(maxi(n, 1))
	var a: float = attack
	if t < a and a > 0.0:
		return t / a
	return exp(-3.4 * (t - a) / maxf(1e-6, 1.0 - a))


## دو نمونهٔ ابتدایی و انتهایی برابر ⇒ پرشِ حلقه ندارد ✗✓ (کلیکِ هر ۴ ثانیه روی
## گوشیِ ارزان، از خودِ موسیقیِ بی‌کیفیت بدتر است ✓)
## `phase` ∈ [0,1) جایِ حلقه است؛ برای هر هارمونیک **تعداد چرخهٔ صحیح** می‌سازیم ✗✓
## وگرنه (الف) گامِ موسیقی با طولِ حلقه عوض می‌شود ✗ و (ب) در درزِ حلقه «تق» می‌افتد ✗
## (روی اسپیکرِ گوشیِ ارزان، کلیپِ حلقه‌شوندهٔ بد از خودِ ملودیِ بد آزارنده‌تر است ✓).
static func _pad_cycle(freq: float, ratios: Array, phase: float) -> float:
	var s := 0.0
	var cycles: int = maxi(1, int(round(freq * MUSIC_SEC)))
	for r: Variant in ratios:
		var part: int = maxi(1, int(round(float(cycles) * float(r))))
		s += sin(phase * TAU * float(part)) / float(ratios.size())
	return s


static func synth_samples(shape: Array) -> PackedFloat32Array:
	var kind := str(shape[0])
	match kind:
		"tone":
			var f0: float = float(shape[1])
			var secs: float = float(shape[2])
			var gain: float = float(shape[3])
			var n: int = int(secs * SAMPLE_RATE)
			var out := PackedFloat32Array()
			out.resize(n)
			for i: int in n:
				var t := float(i) / float(SAMPLE_RATE)
				out[i] = sin(TAU * f0 * t) * gain * _env(i, n, 0.02)
			return out
		"sweep":
			var fa: float = float(shape[1])
			var fb: float = float(shape[2])
			var secs2: float = float(shape[3])
			var gain2: float = float(shape[4])
			var n2: int = int(secs2 * SAMPLE_RATE)
			var out2 := PackedFloat32Array()
			out2.resize(n2)
			var phase := 0.0
			for i2: int in n2:
				var k := float(i2) / float(maxi(n2, 1))
				var f: float = lerpf(fa, fb, k)
				phase += f / float(SAMPLE_RATE)
				out2[i2] = sin(TAU * phase) * gain2 * _env(i2, n2, 0.06)
			return out2
		"chime":
			var freqs: Array = shape[1] as Array
			var secs3: float = float(shape[2])
			var gain3: float = float(shape[3])
			var n3: int = int(secs3 * SAMPLE_RATE)
			var out3 := PackedFloat32Array()
			out3.resize(n3)
			for i3: int in n3:
				var t3 := float(i3) / float(SAMPLE_RATE)
				var s3 := 0.0
				for j3: int in freqs.size():
					var delay: float = 0.07 * float(j3)
					if t3 >= delay:
						s3 += sin(TAU * float(freqs[j3]) * (t3 - delay)) / float(freqs.size())
				out3[i3] = s3 * gain3 * _env(i3, n3, 0.01)
			return out3
		"pad":
			var base: float = float(shape[1])
			var ratios: Array = shape[2] as Array
			var gain4: float = float(shape[3])
			var n4: int = int(MUSIC_SEC * SAMPLE_RATE)
			var out4 := PackedFloat32Array()
			out4.resize(n4)
			for i4: int in n4:
				# فاز کامل در طولِ حلقه ⇒ سرِ حلقه و تهٔ حلقه همنگشت‌اند ✗✓ (بی‌کلیک ✓)
				var ph := float(i4) / float(n4)
				out4[i4] = _pad_cycle(base, ratios, ph) * gain4
			return out4
		_:
			Log.error(TAG, "شکلِ ناشناخته: %s ✗" % kind)
			return PackedFloat32Array()
	return PackedFloat32Array()


func stream_for(id: String) -> AudioStreamWAV:
	if _streams.has(id):
		return _streams[id] as AudioStreamWAV
	if not SHAPES.has(id):
		Log.error(TAG, "شناسهٔ صوتی بدونِ سنتز: %s ✗ (manifest ↔ SHAPES باید جفت باشد)" % id)
		return null
	var samples: PackedFloat32Array = synth_samples(SHAPES[id] as Array)
	if samples.is_empty():
		return null
	var loop_sec := MUSIC_SEC if str(SHAPES[id][0]) == "pad" else 0.0
	var s := build_stream(samples, loop_sec)
	_streams[id] = s
	_generated += 1
	return s


# --------------------------------------------------------------------------
# پخش
# --------------------------------------------------------------------------
func play_sfx(id: String, reason: String = "manual") -> bool:
	if id.is_empty():
		return false
	last_sfx_id = id
	last_play_reason = reason
	# «خاموش» بودن از **باس** می‌آید (`SettingsStore.apply_audio` باس را mute می‌کند ✓)
	# و اینجا کلیدِ تازه‌ای اختراع نمی‌کنیم ✗✓ دو منبعِ حقیقتِ سکوت = یک روزِ باگ ✗
	var s: AudioStreamWAV = stream_for(id)
	if s == null:
		return false
	var v := _free_voice()
	v.stream = s
	v.play()
	_play_count += 1
	return true


## باسِ SFX تنبل است ✗✓ اگر هشت کره در یک فریم رها شود، نهمی نباید بازی را قفل
## کند یا صفِ بی‌پایان بسازد ⇒ **سرقتِ نوبتی** (round-robin): `play()` روی بازیکنِ
## مشغول، همان لحظه stream تازه را از اول می‌گذارد ✓✓ عمداً `is_playing()`/
## `get_playback_position()` را نمی‌خوانم: در هدلسِ CI درایور Dummy است و آن حالت‌ها
## معنای قابل‌اتکایی ندارند ✗✓ (تستِ «۲۰ صدا با ۸ بازیکن» همین را اثبات می‌کند ✓).
func _free_voice() -> AudioStreamPlayer:
	var v: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % SFX_VOICES
	return v


func play_music(id: String) -> bool:
	if id.is_empty() or id == _current_music:
		return id == _current_music and not id.is_empty()
	var s: AudioStreamWAV = stream_for(id)
	if s == null:
		return false
	_music.stop()
	_music.stream = s
	_music.play()
	_current_music = id
	Log.debug(TAG, "موسیقی: %s" % id)
	return true


func stop_music() -> void:
	if _music != null:
		_music.stop()
	_current_music = ""


func reapply_settings() -> void:
	# بعد از تغییرِ تنظیماتِ والد، باس‌ها را دوباره می‌سنجیم ✗✓ (SettingsStore خودش
	# `apply_audio()` را صدا می‌زند؛ این فقط برای فراخوانی‌های بیرونی/تست است ✓)
	SettingsStore.apply_audio()


func debug_state() -> Dictionary:
	return {
		"ready": _ready_ok,
		"current_music": _current_music,
		"last_sfx_id": last_sfx_id,
		"last_play_reason": last_play_reason,
		"play_count": _play_count,
		"generated": _generated,
		"cached": _streams.size(),
		"voices": SFX_VOICES,
		"manifest_ids": _manifest_asset_ids().size(),
		"shape_ids": SHAPES.size(),
		"sfx_bus_index": AudioServer.get_bus_index(SettingsStore.BUS_SFX),
		"music_bus_index": AudioServer.get_bus_index(SettingsStore.BUS_MUSIC),
	}


## آمارِ سیگنالِ سنتز (RMS) ✓✓ تنها راهِ سنجشِ «صدا واقعاً تولید می‌شود» در هدلس ✗
static func rms(samples: PackedFloat32Array) -> float:
	if samples.is_empty():
		return 0.0
	var acc := 0.0
	for s: float in samples:
		acc += s * s
	return sqrt(acc / float(samples.size()))


# --------------------------------------------------------------------------
# وصله‌ها به EventBus (جریانِ بازی ⇒ صدا؛ بدونِ این، سنتز «مرده» می‌ماند ✗)
# --------------------------------------------------------------------------
func _on_orb_placed(_orb_data: Dictionary) -> void:
	play_sfx("orb_drop", "event:orb_placed")


func _on_orb_removed(_orb_data: Dictionary) -> void:
	play_sfx("orb_lift", "event:orb_removed")


func _on_level_started(level_id: String, tier: int) -> void:
	var theme := "theme_tier%d" % clampi(tier, 1, 5)
	if SHAPES.has(theme):
		play_music(theme)
		Log.debug(TAG, "Tier %d از `%s` ⇒ %s" % [tier, level_id, theme])


func _on_level_completed(_level_id: String, _stats: Dictionary) -> void:
	play_sfx("win_chime", "event:level_completed")


func _on_attempt_failed(_attempt_index: int) -> void:
	# خطا نباید تنبیهی داشته باشد ✗✓ یک «نُتِ پایینِ کوتاه» که تمام نمی‌شود، نه بوق ✗
	play_sfx("fail_blip", "event:attempt_failed")


func _on_aria_state_changed(state_name: String) -> void:
	# آریا حرف نمی‌زند (صدای گفتاری پس از MVP ✗) ⇒ فقط «حضورِ غیرکلامی» ✓
	# عمداً فهرستِ نامِ حالت‌ها را این‌جا تکرار نمی‌کنم ✗✓ (نام‌ها در `AriaController.STATE_NAMES`
	# زندگی می‌کنند و کپی‌شان یعنی یک روز بی‌صدا از‌دست‌رفتن ✓) — قاعده: «هر تغییرِ حالت
	# به‌جز بی‌‌کاری، یک نُتِ نرم»؛ idle بی‌صداست چون سکوتِ بازیکن نباید تشویق شود ✗✓
	if state_name != AriaController.STATE_IDLE:
		play_sfx("aria_blip", "event:aria:" + state_name)
