class_name AriaAvatar
extends Node2D
# ===========================================================================
# تسک ۵.۴ — آواتار Aria: شش حالت AnimationPlayer، قابل‌فراخوانی از کد
# --------------------------------------------------------------------------
# Art Bible §۳ دقیقاً شش state می‌خواهد: idle / thinking / hint_light /
# encouraging / celebrating / concerned. این نود آن‌ها را به‌صورت clipهای
# placeholder می‌سازد (ADR-043): clipها فقط سه چیز را animate می‌کنند —
# `Body:position`, `Body:scale`/`rotation` و `Body/Core:self_modulate` (رنگ هسته) —
# پس فاز ۸ می‌تواند همان نام‌ها را با انیمیشن واقعیِ هنر جایگزین کند بدون آنکه
# یک خط کد منطق عوض شود. تریگر از بیرون: `EventBus.aria_state_changed`
# (که AriaController publish می‌کند) یا `play_state()` مستقیم.
# ===========================================================================

const TAG := "AriaAvatar"

const STATE_IDLE := "idle"
const STATE_THINKING := "thinking"
const STATE_HINT := "hint_light"
const STATE_ENCOURAGING := "encouraging"
const STATE_CELEBRATING := "celebrating"
const STATE_CONCERNED := "concerned"
const STATES: Array[String] = [STATE_IDLE, STATE_THINKING, STATE_HINT, STATE_ENCOURAGING,
	STATE_CELEBRATING, STATE_CONCERNED]

## رنگ هسته (§۳): بدنه همیشه طلایی می‌ماند، فقط این شش عدد عوض می‌شوند
const CORE_COLORS := {
	# همه از **پالت رسمی** مشتق می‌شوند ✗✓ (§۸ چک‌لیست: «فقط از پالت رنگ رسمی» ⇒ هگزِ
	# دست‌نویس یعنی یک روز پالت عوض می‌شود و آریا بیرونش می‌رقصد ✓✓)
	STATE_IDLE: Palette.AELORIA_GOLD,
	STATE_THINKING: Palette.SOFT_TEAL,
	STATE_HINT: Palette.SOFT_TEAL.lightened(0.22),
	STATE_ENCOURAGING: Palette.AELORIA_GOLD.lightened(0.30),
	# §۳ «ترکیب Gold + Teal» ⇒ هسته طلاییِ روشن می‌ماند و Teal را رگه‌ها حمل می‌کنند ✓
	STATE_CELEBRATING: Palette.AELORIA_GOLD.lightened(0.12),
	STATE_CONCERNED: Palette.WARM_CORAL.lightened(0.42),
}

## حسِّ بصری هر حالت روی بدنه (چرخش/رگه‌ها) ✓§۳ — تنها جایی که «سرعتِ نور» تعریف می‌شود
## [spin_rate, streak_rate, streak_alpha, streak_tint] ✓ (تستِ ۸.۱ همین جدول را می‌سنجد)
const MOODS := {
	STATE_IDLE: [0.30, 0.35, 0.55, Color(1.0, 1.0, 1.0)],
	STATE_THINKING: [0.16, 0.14, 0.50, Color(1.0, 1.0, 1.0)],
	STATE_HINT: [0.24, 1.20, 0.80, Color(1.0, 1.0, 1.0)],
	STATE_ENCOURAGING: [0.42, 0.80, 0.72, Color(1.0, 1.0, 1.0)],
	STATE_CELEBRATING: [0.85, 1.60, 0.85, Palette.SOFT_TEAL],
	STATE_CONCERNED: [0.12, 0.18, 0.30, Color(1.0, 1.0, 1.0)],
}

## حالت‌هایی که روی هم می‌مانند (idle/thinking) و باید لوپ شوند
const LOOPING: Array[String] = [STATE_IDLE, STATE_THINKING, STATE_CONCERNED]

@export var follow_event_bus: bool = true
## ساختن clipها در کد؛ اگر فاز ۸ آن‌ها را در فایل صحنه گذاشت، این را false کن
@export var build_placeholder_clips: bool = true
@export var start_state: String = STATE_IDLE

## جهتِ پالسِ `hint_light` (LevelScene می‌تواند کفهٔ مرتبط را بدهد ✗✓ اگر صفر بود،
## پالس شعاعی می‌ماند ⇒ آواتار به گیم‌پلی وابسته نیست ✓)
@export var hint_target: Vector2 = Vector2.ZERO
var current_state: String = ""
var _player: AnimationPlayer = null
var _core: CanvasItem = null


func _ready() -> void:
	_player = get_node_or_null("Anim") as AnimationPlayer
	_core = get_node_or_null("Body/Core") as CanvasItem
	if _player == null:
		Log.warn(TAG, "AnimationPlayer ندارد؛ حالت‌ها فقط ثبت می‌شوند")
	if build_placeholder_clips and _player != null:
		_build_clips()
	if follow_event_bus:
		EventBus.aria_state_changed.connect(_on_state_requested)
	if not is_playing():
		play_state(start_state)


func has_state(state: String) -> bool:
	return _player != null and _player.has_animation(state)


func known_states() -> Array[String]:
	var out: Array[String] = []
	for s: String in STATES:
		if has_state(s):
			out.append(s)
	return out


func is_playing() -> bool:
	return _player != null and _player.is_playing()


## @return false یعنی چنین حالتی وجود ندارد (بی‌صدا رد می‌شود، نه خطا)
func play_state(state: String) -> bool:
	if not STATES.has(state) or not has_state(state):
		return false
	current_state = state
	# رنگ هسته را صراحتاً هم ست می‌کنیم: clipها placeholder‌اند (ADR-043) و فاز ۸ آن‌ها را
	# بازنویسی می‌کند؛ §۳ می‌گوید «تنها هسته رنگ عوض می‌کند»، پس این خط تضمین می‌دهد
	# تفکیک‌پذیریِ بصری هیچ‌وقت به salute بودن clipها وابسته نباشد.
	if _core != null:
		_core.self_modulate = _core_color(state)
	var body := get_node_or_null("Body") as AriaCrystal
	if body != null:
		var m: Array = mood_for(state)
		body.set_mood(float(m[0]), float(m[1]), float(m[2]), m[3] as Color)
	if state == STATE_HINT and body != null:
		# §۳: «یک پالس نور مختصر به‌سمت بخشِ مرتبط از ترازو» ✓ جهت را هرکس می‌داند که
		# صحنه را می‌شناسد ⇒ `hint_target` ست می‌شود؛ اگر ست نشد، پالسِ شعاعی ✓
		body.pulse_toward(hint_target if hint_target != Vector2.ZERO else Vector2.RIGHT)
	# 0.18 = blend کوتاه؛ §۳ «تغییر حالت نباید پرش داشته باشد»
	_player.play(state, 0.18)
	return true


func _on_state_requested(state: String) -> void:
	if not play_state(state):
		Log.debug(TAG, "حالت ناشناخته‌ی `%s` نادیده گرفته شد" % state)


## رنگ هسته‌ی یک حالت (§۳) — تنها نقطه‌ی تعریف، پس آواتار و تست یک عدد می‌بینند.
## جدولِ حسّ بصریِ یک حالت ✓ (یکجا، تا آواتار/تست/فاز ۸ یک منبع داشته باشند)
static func mood_for(state: String) -> Array:
	return MOODS.get(state, MOODS[STATE_IDLE]) as Array


static func core_color_for(state: String) -> Color:
	var c: Variant = CORE_COLORS.get(state, Palette.AELORIA_GOLD)
	return c as Color if c is Color else Palette.AELORIA_GOLD


func core_modulate() -> Color:
	return _core.self_modulate if _core != null else Color.WHITE


func _core_color(state: String) -> Color:
	var c: Variant = CORE_COLORS.get(state, Palette.AELORIA_GOLD)
	return c as Color if c is Color else Palette.AELORIA_GOLD


# --------------------------------------------------------------------------
# clipهای placeholder (ADR-043)
# --------------------------------------------------------------------------
func _build_clips() -> void:
	var lib: AnimationLibrary = _player.get_animation_library("") \
		if _player.has_animation_library("") else null
	if lib == null:
		lib = AnimationLibrary.new()
		_player.add_animation_library("", lib)
	for state: String in STATES:
		if lib.has_animation(state):
			continue
		lib.add_animation(state, _make_clip(state))


func _make_clip(state: String) -> Animation:
	var anim := Animation.new()
	anim.resource_name = state
	anim.loop_mode = Animation.LOOP_LINEAR if LOOPING.has(state) else Animation.LOOP_NONE
	match state:
		STATE_IDLE:
			anim.length = 2.0
			_add_color_track(anim, state, 0.0, 2.0)
			_add_vec_track(anim, "Body:position", [Vector2(0, 0), Vector2(0, -6),
				Vector2(0, 0)])
		STATE_THINKING:
			anim.length = 3.0
			_add_color_track(anim, state, 0.0, 3.0)
			_add_float_track(anim, "Body:rotation", [0.0, 0.32, 0.0])
		STATE_HINT:
			anim.length = 0.6
			_add_color_track(anim, state, 0.0, 0.6)
			_add_scale_track(anim, [Vector2.ONE, Vector2(1.14, 1.14), Vector2.ONE])
		STATE_ENCOURAGING:
			# §۳: «scale پالسی ۱.۰ → ۱.۱۵ → ۱.۰ طی ۰.۴ ثانیه»
			anim.length = 0.4
			_add_color_track(anim, state, 0.0, 0.4)
			_add_scale_track(anim, [Vector2.ONE, Vector2(1.15, 1.15), Vector2.ONE])
		STATE_CELEBRATING:
			anim.length = 0.8
			_add_color_track(anim, state, 0.0, 0.8)
			_add_vec_track(anim, "Body:position", [Vector2(0, 0), Vector2(0, -20),
				Vector2(0, 2), Vector2(0, 0)])
			_add_float_track(anim, "Body:rotation", [0.0, TAU])
		STATE_CONCERNED:
			anim.length = 1.6
			_add_color_track(anim, state, 0.0, 1.6)
			_add_scale_track(anim, [Vector2.ONE, Vector2(0.94, 0.94), Vector2.ONE])
		_:
			anim.length = 1.0
	return anim


func _add_color_track(anim: Animation, state: String, t0: float, t1: float) -> void:
	var idx: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(idx, "Body/Core:self_modulate")
	# نام درست در Godot 4: `track_set_interpolation_type` (نه `track_set_interp_mode`)
	anim.track_set_interpolation_type(idx, Animation.INTERPOLATION_LINEAR)
	var col: Color = _core_color(state)
	var dim: Color = Color(col.r, col.g, col.b, 0.55)
	anim.track_insert_key(idx, t0, dim)
	anim.track_insert_key(idx, (t0 + t1) * 0.5, col)
	anim.track_insert_key(idx, t1, dim)


func _add_vec_track(anim: Animation, path: String, values: Array) -> void:
	var idx: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(idx, path)
	for i: int in range(values.size()):
		var t: float = float(i) / float(maxi(1, values.size() - 1))
		anim.track_insert_key(idx, t, values[i])


func _add_float_track(anim: Animation, path: String, values: Array) -> void:
	var idx: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(idx, path)
	for i: int in range(values.size()):
		var t: float = float(i) / float(maxi(1, values.size() - 1))
		anim.track_insert_key(idx, t, values[i])


func _add_scale_track(anim: Animation, values: Array) -> void:
	_add_vec_track(anim, "Body:scale", values)
