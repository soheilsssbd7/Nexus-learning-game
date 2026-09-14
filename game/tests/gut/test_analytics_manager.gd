extends GutTest
# ===========================================================================
# NEXUS — تسک ۱۰.۳ | DoD: «تمام ۶ رویداد §۵ در نقاطِ درست trigger و به NetworkClient
# فرستاده می‌شوند» ✓✓ → اینجا همان شش تا را **به قراردادِ بک‌اند** می‌سازیم: `EventSchema`
# در `backend/src/schemas/events.ts` روی `.strict()` است ⇒ یک کلیدِ اضافی = ۴۰۰ برای
# تمامِ دسته ✗✓ پس تستِ ۱۸ (کلیدهای مجاز) و ۵ (متن کودک بیرون نمی‌رود) ارزشِ اصلی این
# فایل‌اند، نه «تعدادِ رویداد» ✓
# ---------------------------------------------------------------------------
# چرا هندلرها مستقیم صدا زده می‌شوند و `EventBus.*.emit` نه؟ چون autoload های دیگر
# (GameState/LevelController/AriaController) هم به همان سیگنال‌ها وصل‌اند ✗✓ و emit کردن
# یعنی آن‌ها هم در این تست دوّار شوند ⇒ نویزِ بی‌مورد و save‌های ناخواسته ✓. اتصالِ واقعیِ
# باس را تستِ ۱۳ و ۱۹ می‌سنجند ✓ (تفکیکِ «سیم‌کشی» از «منطق» ✓§۶.۵)
# ===========================================================================

const MGR := preload("res://scripts/autoload/AnalyticsManager.gd")
const NET := preload("res://scripts/autoload/NetworkClient.gd")

## مقصدِ تستی ✓⚠ **Node** و نه RefCounted — فیلدِ `sink` در کلاس `Node` type است و
## خطایِ نوع در `_ready`/`before_each` یعنی تمامِ تست‌های فایل، بی‌معنا ✗✓ (درسِ ۹.۶ ✓)
class FakeSink extends Node:
	var events: Array[Dictionary] = []
	var accept: bool = true

	func enqueue_event(event: Dictionary) -> bool:
		if not accept:
			return false
		events.append(event)
		return true

	func count() -> int:
		return events.size()

	func last() -> Dictionary:
		return events[events.size() - 1] if not events.is_empty() else {}


var _mgr: Node = null
var _sink: FakeSink = null
var _flag_was: Variant = null


func before_each() -> void:
	_flag_was = SettingsStore.get_value("cloud_sync_enabled")
	SettingsStore.set_value("cloud_sync_enabled", true)
	_sink = FakeSink.new()
	add_child_autofree(_sink)
	_mgr = MGR.new()  # `_ready` اتصال‌ها را می‌زند ✓ (روی گرهٔ افزوده‌شده ⇒ مطمئنیم اجرا شده ✓)
	add_child_autofree(_mgr)
	_mgr.sink = _sink


func after_each() -> void:
	SettingsStore.set_value("cloud_sync_enabled", _flag_was)


func _sorted_keys(d: Dictionary) -> Array:
	var keys: Array = d.keys()
	keys.sort()
	return keys


# --------------------------------------------------- ۱) نقشه ⟺ قرارداد (§۵) ----
func test_every_backend_event_type_has_a_handler() -> void:
	# ← این همان «قفلِ دوزبانه» است ✓§۹.۶: هر نوعِ رویدادِ بک‌اند باید هندلر داشته باشد ✗✓
	for type_name: String in NET.EVENT_TYPES:
		assert_true(bool(MGR.HANDLERS.has(type_name)), "«%s» در `HANDLERS` نیست ⇒ هیچ‌وقت trigger نمی‌شود ✗✓" % type_name)
		var method: String = str(MGR.HANDLERS[type_name])
		assert_true(_mgr.has_method(method), "هندلرِ «%s» وجود ندارد ✗" % method)
	# «کمتر» یعنی رویدادِ گمشده ✗ «بیشتر» یعنی رویدادی که §۵ نمی‌شناسد و سرور ۴۰۰ می‌دهد ✗✓
	# (دو ادعا در یک تست، به‌خاطر سقفِ gdlint روی ۲۰ متدِ publicِ هر فایل ✓§۸.۴ — نه تنبلی ✓)
	assert_eq(int(MGR.HANDLERS.size()), 6, "§۵ دقیقاً شش رویداد برای MVP دارد ✓")
	for extra: String in MGR.HANDLERS.keys():
		assert_true(NET.EVENT_TYPES.has(extra), "«%s» خارج از enumِ بک‌اند است ✗✓" % extra)


func test_ready_connects_every_handler_to_the_bus() -> void:
	# اول: سیگنال هست؟ (اگر عوض/حذف شود، `connect` در `_ready` ترکه ✗✓ این اول می‌گوید کدام ✓)
	for sig_name: String in ["level_started", "level_completed", "hint_shown", "error_detected",
			"session_started", "session_ended"]:
		assert_true(bool(EventBus.has_signal(sig_name)), "EventBus.%s مفقود شد ✗✓" % sig_name)
	assert_true(bool(EventBus.level_started.is_connected(_mgr.on_level_started)), "سیمِ level_started ✗")
	assert_true(bool(EventBus.level_completed.is_connected(_mgr.on_level_completed)), "سیمِ level_completed ✗")
	assert_true(bool(EventBus.hint_shown.is_connected(_mgr.on_hint_shown)), "سیمِ hint_shown ✗")
	assert_true(bool(EventBus.error_detected.is_connected(_mgr.on_error_detected)), "سیمِ error_detected ✗")
	assert_true(bool(EventBus.session_started.is_connected(_mgr.on_session_started)), "سیمِ session_started ✗")
	assert_true(bool(EventBus.session_ended.is_connected(_mgr.on_session_ended)), "سیمِ session_ended ✗")


# ------------------------------------------------------- ۲) شکلِ هر رویداد ✓ ----
func test_level_started_event_shape() -> void:
	_mgr.on_level_started("tier1_level_03", 3)
	var ev: Dictionary = _sink.last()
	assert_eq(str(ev.get("event_type", "")), "level_started", "نوع ✓")
	assert_eq(str(ev.get("level_id", "")), "tier1_level_03", "level_id در قالبِ §۱ ✓")
	assert_eq(int((ev.get("payload", {}) as Dictionary).get("tier", 0)), 3, "tier در payload ✓")


func test_level_completed_uses_exactly_the_four_schema_keys() -> void:
	_mgr.on_level_completed("tier2_level_07", {
		"time_to_solve_sec": 52.0, "hints_used": 1, "attempts": 4,
		"final_elo_delta": 12.5, "score": 0.8,  # ← `score` در مدلِ دستگاه هست ✓§۲
	})
	var payload: Dictionary = _sink.last().get("payload", {}) as Dictionary
	assert_eq(_sorted_keys(payload), ["attempts", "final_elo_delta", "hints_used", "time_to_solve_sec"],
			"چهار کلیدِ §۵، نه پنج‌تا ✓✗ آنالیتیکس کمینه است نه آینه ✓§۹")
	assert_true(float(payload.get("time_to_solve_sec", 0.0)) > 51.9, "عددِ واقعی رسید ✓")


func test_hint_shown_never_carries_the_text() -> void:
	# ⚠ مهم‌ترین تستِ این فایل ✓✗§۹: «جمع‌آوری داده» در همین‌جا می‌تواند بی‌سروصدا بزرگ شود
	_mgr.on_hint_shown("hint_step_two", "tier1_level_01", "جوابِ درست ۱۲ است، به یاد داشته باش")
	var ev: Dictionary = _sink.last()
	assert_eq(str(ev.get("event_type", "")), "hint_shown", "نوع ✓")
	assert_eq(str((ev.get("payload", {}) as Dictionary).get("hint_id", "")), "hint_step_two", "شناسۀ قالب ✓")
	var text: String = JSON.stringify(ev)
	assert_false(text.contains("جوابِ درست"), "متنِ راهنما هرگز از دستگاه بیرون نمی‌رود ✗✓§۹")
	assert_false(text.contains("۱۲"), "هیچ رقمِ «جوابی» هم در رویداد نیست ✓ (قاعدۀ §۵/Aria ✓)")


func test_error_occurred_uses_current_level_from_game_state() -> void:
	_mgr.on_error_detected("wrong_operation")
	var ev: Dictionary = _sink.last()
	assert_eq(str(ev.get("event_type", "")), "error_occurred", "نوعِ §۵ «error_occurred» است، نه نامِ سیگنال ✗✓")
	assert_eq(str((ev.get("payload", {}) as Dictionary).get("error_type", "")), "wrong_operation", "کلاس خطا ✓")
	assert_eq(str(ev.get("level_id", "")), str(GameState.current_level_id), "سطحِ جاری از GameState ✓")


# ------------------------------------------- ۳) سخت‌گیریِ payload/level_id ✓ ----
func test_nested_payload_is_dropped_and_counted() -> void:
	_mgr.on_session_ended({"total_playtime_sec": 300.0, "levels": [1, 2, 3], "debug": {"x": 1}})
	var payload: Dictionary = _sink.last().get("payload", {}) as Dictionary
	assert_true(payload.has("total_playtime_sec"), "اسکالر ماند ✓")
	assert_false(payload.has("levels") or payload.has("debug"), "آرایه/شیء نمی‌رود ✗✓ (`JsonScalar` بک‌اند)")
	assert_true(int(_mgr.stats()["dropped_payload_keys"]) >= 2, "و **شمرده** می‌افتد ✓ (بی‌سکوت ✓)")


func test_long_string_is_dropped_not_truncated() -> void:
	var long_s := ""
	for _i: int in range(MGR.MAX_SCALAR_LEN + 1):
		long_s += "a"
	var ok_s: String = long_s.substr(0, MGR.MAX_SCALAR_LEN)
	var flat: Dictionary = MGR.flatten_payload({"a": long_s, "b": ok_s})
	assert_eq(int(flat.size()), 1, "۲۰۰ تا می‌ماند، ۲۰۱ تا می‌رود ✓ (مرزِ دقیقِ `z.string().max(200)`)")
	assert_true(flat.has("b"), "کلیدِ سالمِ کناری **نباید** با آن برود ✗✓")
	assert_false(flat.has("a"), "بریدنِ رشته ممنوع ⇒ نصفه‌معنا می‌شود ✓")


func test_level_id_formats_gate_the_key() -> void:
	for good: String in ["tier1_level_01", "tier5_level_45"]:
		var ev: Dictionary = MGR.build_event("level_started", "p_193f2a7e", good, {})
		assert_eq(str(ev.get("level_id", "")), good, "«%s» قالبِ §۱ است ✓" % good)
		assert_false(ev.has("_bad_level_id"), "برچسبِ داخلی در رویداد نمی‌ماند ✓")
	for bad: String in ["tier0_level_01", "tier6_level_01", "tier1_level_1", "tier1_level_0a", "level_1_01"]:
		var ev2: Dictionary = MGR.build_event("level_started", "p_193f2a7e", bad, {})
		assert_true(ev2.has("_bad_level_id"), "«%s» باید بیفتد ✗✓ (`LevelId` بک‌اند همین قالب را می‌خواهد)" % bad)


func test_bad_level_id_drops_key_but_keeps_the_event() -> void:
	_mgr.on_level_started("level_1_01", 1)
	assert_eq(int(_sink.count()), 1, "رویداد دور ریخته نمی‌شود ✓ (کلیدِ بد ≠ دادهٔ بد)")
	assert_false(_sink.last().has("level_id"), "کلیدِ نامعتبر نمی‌رود ✗✓")
	assert_eq(str(_mgr.stats()["reason"]), "bad_level_id", "دلیل در stats می‌نشیند ✓ (سکوت نه ✓)")
	assert_eq(int(_mgr.stats()["bad_level_ids"]), 1, "و شمرده می‌شود ✓")


# ------------------------------------------------------- ۴) نشست/idempotency ----
func test_session_start_uses_the_emitted_player_id() -> void:
	_mgr.on_session_started("p_deadbeef")
	var ev: Dictionary = _sink.last()
	assert_eq(str(ev.get("player_id", "")), "p_deadbeef", "شناسه از سیگنال ✓ (مدل هنوز نخاسته باشد هم ✓)")
	assert_eq(str(ev.get("event_type", "")), "session_start", "نامِ رویداد «session_start» است (§۵) ✗✓ نه session_started")


func test_session_end_is_sent_once_per_session() -> void:
	_mgr.on_session_ended({"total_playtime_sec": 61.5})
	_mgr.on_session_ended({"total_playtime_sec": 61.5})  # مثلِ `focus_exited` + `PREDELETE` ✗✓
	assert_eq(int(_sink.count()), 1, "دو بارِ پشت‌سرهم ⇒ یک رویداد ✓ (وگرنه فاز ۱۱ دو برابر می‌شمارد ✗)")
	_mgr.on_session_started("p_193f2a7e")
	_mgr.on_session_ended({"total_playtime_sec": 12.0})
	assert_eq(int(_sink.count()), 3, "نشستِ تازه ⇒ دوباره مجاز ✓ (سوئیچِ پروفایل ✓§۶.۲)")


func test_the_bus_path_and_direct_call_are_the_same_event() -> void:
	# مسیرِ واقعیِ « GameState پایان نشست را emit می‌کند » ✓✗ و باید بی‌شمارشِ دوباره باشد ✓
	EventBus.session_ended.emit({"total_playtime_sec": 90.0})
	_mgr.on_session_ended({"total_playtime_sec": 90.0})
	assert_eq(int(_sink.count()), 1, "هر دو مسیر یک رویدادند ✓✓")


# --------------------------------------------------------- ۵) پرچم/خطاها ✓ ----
func test_parent_flag_off_means_zero_events() -> void:
	# DoDِ «کودک = صفر بایت بیرونی» از همین‌ست ✓§۹ (نه از «فیلتر در سرور» ✗)
	SettingsStore.set_value("cloud_sync_enabled", false)
	_mgr.on_level_started("tier1_level_01", 1)
	_mgr.on_hint_shown("h", "tier1_level_01", "x")
	assert_eq(int(_sink.count()), 0, "خاموش ⇒ هیچ رویدادی **ساخته** نمی‌شود ✓ (صف هم رشد نمی‌کند ✓)")
	assert_eq(str(_mgr.stats()["reason"]), "cloud_sync_disabled", "و دلیلش گزارش می‌شود ✓")


func test_rejection_by_sink_is_counted_not_silent() -> void:
	_sink.accept = false
	var ok := bool(_mgr.on_level_started("tier1_level_01", 1))
	assert_false(ok, "رد شد ✓")
	assert_eq(int(_mgr.stats()["rejected"]), 1, "شمرده شد ✓ (بی‌سکوت ✓ADR-064)")
	assert_eq(str(_mgr.stats()["reason"]), "sink_rejected", "با دلیل ✓")


func test_last_event_is_a_copy() -> void:
	_mgr.on_level_started("tier1_level_02", 1)
	var snapshot: Variant = _mgr.last_event()
	snapshot["event_type"] = "tampered"
	assert_eq(str(_mgr.last_event().get("event_type", "")), "level_started", "درونِ کلاس دست‌نخورده ✓")


func test_only_schema_allowed_top_level_keys() -> void:
	# `EventSchema` بک‌اند `.strict()` است ⇒ یک کلیدِ اضافی = ۴۰۰ برای **کلِ دسته** ✗✓
	var allowed := ["event_type", "level_id", "payload", "player_id", "timestamp"]
	_mgr.on_session_started("p_193f2a7e")
	_mgr.on_level_started("tier1_level_01", 1)
	_mgr.on_level_completed("tier1_level_01", {"time_to_solve_sec": 10.0})
	_mgr.on_hint_shown("h1", "tier1_level_01", "متن")
	_mgr.on_error_detected("computation_error")
	_mgr.on_session_ended({"total_playtime_sec": 5.0})
	assert_eq(int(_sink.count()), 6, "ششِ §۵ ساخته شد ✓✓ (DoDِ ۱۰.۳ در سطحِ واحد ✓)")
	for ev: Dictionary in _sink.events:
		for key: String in ev.keys():
			assert_true(allowed.has(key), "کلیدِ «%s» خارج از §۵ ⇒ zod رد می‌کند ✗✓" % key)
		assert_true(bool(ev.has("event_type")), "بدون نوع نمی‌رود ✓")


func test_manager_does_not_stamp_the_timestamp() -> void:
	# زمان را `NetworkClient._now_iso()` می‌کشد ✓ (قالبِ UTCِ ±ناحیه ✓§۵) ⇒ دو منبعِ زمان
	# یعنی دو قالبِ ممکن و ۴۲۲ِ تصادفی ✗✓ پس این تست «نبود» را می‌سنجد ✓
	_mgr.on_level_started("tier1_level_01", 1)
	assert_false(_sink.last().has("timestamp"), "اینجا timestamp نمی‌سازیم ✓ (منبعِ واحد ✓)")
