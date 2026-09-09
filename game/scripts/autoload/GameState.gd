extends Node
# ===========================================================================
# GameState — وضعیت نشست جاری (تسک ۱.۴)
# ---------------------------------------------------------------------------
# «همین حالا چه چیزی روی صفحه است» اینجاست؛ «بازیکن چه بلَد شده» در PlayerModel.
# state اینجا persist **نمی‌شود** — تنها از طریق PlayerModel + SaveSystem ذخیره می‌شود.
# چون autoload است، تغییر `current_level_id` در WorldMap در LevelScene هم دیده می‌شود
# (DoD تسک ۱.۴).
# ===========================================================================

const TAG := "GameState"
const WORLD_BALANCE_REALM := "balance_realm"

var active_model: PlayerModel = null
var current_world: String = WORLD_BALANCE_REALM
var current_level_id: String = ""
var current_tier: int = 1
## اولین اجرا = هیچ save‌ای روی دستگاه نبود → Onboarding باز می‌شود (تسک ۶.۲).
var is_first_run: bool = true
var is_paused: bool = false

# شمارنده‌های همین سطح — ورودی HintTimingSystem (تسک ۴.۳) و آمار level_completed.
var level_attempts: int = 0
var hints_used_this_level: int = 0

var session_started_msec: int = 0
var level_started_msec: int = 0
var _last_playtime_commit_msec: int = 0
# فاز ۶ (تسک ۶.۳): پاز نباید در زمان «حل کردن» یا «زمان بازی» شمرده شود. بدون این
# شمارنده‌ها، بازکردن پاز برای یک لیوان آب، هم `avg_time_to_solve_sec` و هم
# `total_playtime_sec` (داشبورد والدین) و هم escalation راهنما را عوض می‌کرد (ADR-046).
var _level_paused_msec: int = 0
var _pause_open_msec: int = 0
var _session_paused_msec: int = 0
var _session_paused_committed_msec: int = 0


func _ready() -> void:
	session_started_msec = Time.get_ticks_msec()
	_last_playtime_commit_msec = session_started_msec
	process_mode = Node.PROCESS_MODE_ALWAYS


## یک‌بار در شروع بازی (MainMenu و تست‌ها) صدا زده می‌شود.
func bootstrap() -> void:
	active_model = SaveSystem.load_player_model(true)
	is_first_run = not SaveSystem.had_save_on_load
	if active_model == null:
		active_model = PlayerModel.create_new()
		is_first_run = true
	SaveSystem.bind_model(active_model)
	current_level_id = active_model.current_level
	if not active_model.levels_completed.is_empty():
		current_tier = _tier_from_level_id(active_model.levels_completed[active_model.levels_completed.size() - 1])
	EventBus.session_started.emit(active_model.player_id)
	Log.info(TAG, "نشست شروع شد (اولین اجرا=%s)" % ("بله" if is_first_run else "خیر"))


# --------------------------------------------------------------------------
# چرخه‌ی سطح
# --------------------------------------------------------------------------
func begin_level(level_id: String, tier: int) -> void:
	current_level_id = level_id
	current_tier = maxi(1, mini(5, tier))
	level_attempts = 0
	hints_used_this_level = 0
	level_started_msec = Time.get_ticks_msec()
	_level_paused_msec = 0
	if active_model != null:
		active_model.current_level = level_id
		SaveSystem.request_save()
	EventBus.level_started.emit(level_id, tier)


func end_level() -> void:
	level_started_msec = 0


func elapsed_level_sec() -> float:
	if level_started_msec == 0:
		return 0.0
	var paused: int = _level_paused_msec
	if _pause_open_msec > 0:
		paused += Time.get_ticks_msec() - _pause_open_msec
	return maxf(0.0, float(Time.get_ticks_msec() - level_started_msec - paused) / 1000.0)


# --------------------------------------------------------------------------
# پاز (تسک ۶.۳) — شمارنده‌ها این‌جا زندگی می‌کنند، نه در PauseMenu:
# هر چیزی که می‌خواهد بازی را نگه دارد (پاز، دیالوگ والدین، بعداً کات‌سین فاز ۷)
# همان سه‌خطی را صدا می‌زند و زمان عادلانه می‌ماند.
# --------------------------------------------------------------------------
func begin_pause() -> void:
	if _pause_open_msec != 0:
		return
	_pause_open_msec = Time.get_ticks_msec()
	is_paused = true


func end_pause() -> void:
	if _pause_open_msec == 0:
		return
	var span: int = Time.get_ticks_msec() - _pause_open_msec
	_pause_open_msec = 0
	is_paused = false
	_level_paused_msec += span
	_session_paused_msec += span


## شروعِ شمارش زمان برای تست: پنجرهٔ commit را هم‌اکنون صفر می‌کند تا ادعاهای
## «زمان پاز شمرده نمی‌شود» قابل‌سنجش باشند (تست‌ها `_last_*` خصوصی را دست نمی‌زنند).
func reset_time_windows_for_tests() -> void:
	var now: int = Time.get_ticks_msec()
	session_started_msec = now
	level_started_msec = now
	_last_playtime_commit_msec = now
	_level_paused_msec = 0
	_session_paused_msec = 0
	_session_paused_committed_msec = 0
	_pause_open_msec = 0
	is_paused = false


func is_pause_open() -> bool:
	return _pause_open_msec != 0


func paused_level_sec() -> float:
	var paused: int = _level_paused_msec
	if _pause_open_msec > 0:
		paused += Time.get_ticks_msec() - _pause_open_msec
	return float(paused) / 1000.0


## زمان کل نشست (منطقه‌ی نمایشی). زمانِ *انباشته‌ی* بازی در PlayerModel است.
func session_playtime_sec() -> float:
	var paused: int = _session_paused_msec
	if _pause_open_msec > 0:
		paused += Time.get_ticks_msec() - _pause_open_msec
	return maxf(0.0, float(Time.get_ticks_msec() - session_started_msec - paused) / 1000.0)


func register_attempt_failed() -> void:
	level_attempts += 1
	# همه‌ی «تلاش ناموفق»ها از همین‌جا می‌گذراند تا شماره‌ی تلاش یک‌دست باشد (تسک ۱.۱)
	EventBus.attempt_failed.emit(level_attempts)


func register_hint_used() -> void:
	hints_used_this_level += 1


## payload استاندارد رویداد level_completed (اسکیمای §۵ سند داده‌ها) + فیلد داخلی score.
func build_level_stats(score: float, elo_delta: float, time_sec: float) -> Dictionary:
	return {
		"time_to_solve_sec": time_sec,
		"hints_used": hints_used_this_level,
		"attempts": level_attempts,
		"final_elo_delta": elo_delta,
		"score": score,
	}


## §۲: playtime انباشته در مدل. پایان هر سطح + هنگام خروج صدا زده می‌شود.
func commit_playtime() -> void:
	if active_model == null or not is_instance_valid(active_model):
		return
	var now: int = Time.get_ticks_msec()
	# زمانِ پازِ همین پنجره کم می‌شود: جمع pauseهای بسته‌شده از آخرین commit، بعلاوهٔ
	# pauseِ بازِ جاری اگر داخل همین پنجره شروع شده باشد.
	var window_paused: int = _session_paused_msec - _session_paused_committed_msec
	# `>=` و نه `>`: اگر پاز **همان millisecondِ** آخرین commit باز شده باشد (در تست‌ها
	# دقیقاً همین می‌افتد) پنجره هم پاز است؛ بی‌این، ۴۵۰ms خواب کودک به‌عنوان
	# «زمان بازی» در داشبورد والدین صورتحساب می‌شد ✗ (خطای واقعیِ همین دور CI).
	if _pause_open_msec > 0 and _pause_open_msec >= _last_playtime_commit_msec:
		window_paused += now - _pause_open_msec
	_session_paused_committed_msec = _session_paused_msec
	window_paused = clampi(window_paused, 0, maxi(0, now - _last_playtime_commit_msec))
	var delta_sec: float = float(now - _last_playtime_commit_msec - window_paused) / 1000.0
	_last_playtime_commit_msec = now
	if delta_sec > 0.0:
		active_model.add_playtime(delta_sec)
		SaveSystem.request_save()


func _tier_from_level_id(level_id: String) -> int:
	if not level_id.begins_with("tier"):
		return current_tier
	var digit: String = level_id.substr(4, 1)
	if digit.is_valid_int():
		return clampi(digit.to_int(), 1, 5)
	return current_tier


func _notification(what: int) -> void:
	# autoload هنگام خروج آزاد می‌شود → آخرین فرصت برای flush.
	# (Peak-order frees: SaveSystem هم flush را در NOTIFICATION_PREDELETE خودش انجام می‌دهد.)
	if what == NOTIFICATION_PREDELETE:
		commit_playtime()
		if active_model != null and is_instance_valid(active_model):
			EventBus.session_ended.emit({"total_playtime_sec": active_model.total_playtime_sec})
