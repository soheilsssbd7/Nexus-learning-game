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
	if active_model != null:
		active_model.current_level = level_id
		SaveSystem.request_save()
	EventBus.level_started.emit(level_id, tier)


func end_level() -> void:
	level_started_msec = 0


func elapsed_level_sec() -> float:
	if level_started_msec == 0:
		return 0.0
	return float(Time.get_ticks_msec() - level_started_msec) / 1000.0


## زمان کل نشست (منطقه‌ی نمایشی). زمانِ *انباشته‌ی* بازی در PlayerModel است.
func session_playtime_sec() -> float:
	return float(Time.get_ticks_msec() - session_started_msec) / 1000.0


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
	var delta_sec: float = float(now - _last_playtime_commit_msec) / 1000.0
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
