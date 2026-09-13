extends GutTest
# ===========================================================================
# NEXUS — تسک ۹.۶ | DoD: «قطع اینترنت شبیه‌سازی‌شده ⇒ بازی بدون کرش ادامه می‌یابد؛
# با وصلِ مجدد، صف خالی می‌شود» ✓✓
# ---------------------------------------------------------------------------
# چرا fake و نه HTTP واقعی؟ CI هدلس هیچ شبکه‌ای ندارد ✗✓ و «تستِ network» با سوکت یعنی
# نوسان/timeout؛ اینجا `transport` تزریق می‌شود ⇒ همان `_handle_result` واقعیِ کلاس، با
# پاسخ‌های از پیش نوشته‌شده ✓✗ پس مسیرِ کدِ production می‌آزماید، نه یک بدلِ حرف‌زدنی ✓✓
# و تست ۱۸ ثابت می‌کند هیچ `HTTPRequest` واقعی ساخته نمی‌شود ⇒ CI هرگز socket باز نمی‌کند ✓
# ===========================================================================

const NET := preload("res://scripts/autoload/NetworkClient.gd")
const TEST_URL := "http://nexus.test.invalid"  # هرگز resolve نمی‌شود ✓ (transport تزیری است ✓)
const PID := "p_193f2a7e"


## پاسخ‌سازِ همگام: `send()` همان‌جا `done` را صدا می‌زند ⇒ رفتارِ قابل‌پیش‌بینی در تست ✓
class FakeSender extends RefCounted:
	var sent: Array[Dictionary] = []
	var results: Array[Dictionary] = []
	var default_result: Dictionary = {"ok": true, "status": 200, "code": OK}

	func send(req: Dictionary, done: Callable) -> void:
		sent.append(req)
		var result: Dictionary = default_result
		if not results.is_empty():
			result = results.pop_front()
		done.call(req, result)

	func last_body() -> Dictionary:
		if sent.is_empty():
			return {}
		var parsed: Variant = JSON.parse_string(String(sent[sent.size() - 1].get("body", "")))
		return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


var _net: Node = null
var _sender: FakeSender = null
var _sync_was: Variant = null


func before_each() -> void:
	_sync_was = SettingsStore.get_value("cloud_sync_enabled")
	_net = NET.new()
	add_child_autofree(_net)
	_net.set_process(false)  # تایمینگِ موتور از معادله بیرون ⇒ همه‌چیز با `tick/flush` خودمان ✓
	_sender = FakeSender.new()
	_net.transport = _sender
	_net.base_url = TEST_URL


func after_each() -> void:
	SettingsStore.set_value("cloud_sync_enabled", _sync_was)
	DirAccess.remove_absolute("user://device_token.save")


func _event(type_name: String) -> Dictionary:
	return {"event_type": type_name, "player_id": PID}


func _enqueue_n(n: int) -> void:
	for i: int in range(n):
		_net.enqueue_event(_event("hint_shown"))


# ---------------------------------------------------------------- ۱) دروازه‌ها ----
func test_no_base_url_means_zero_requests_even_with_queue() -> void:
	# DoD §۹/۹.۶: «آفلاین‌بودنِ پیش‌فرض» باید **ساختاری** باشد نه احتیاطی ✓
	_net.base_url = ""
	_enqueue_n(5)
	assert_eq(int(_net.flush_once()), 0, "بی‌آدرس، هیچ ارسالی نیست ✗✓")
	assert_eq(_sender.sent.size(), 0, "fake هم چیزی ندیده است ✓")
	assert_eq(_net.queue_size(), 5, "صف حفظ شد ✓ (داده گم نشد ✗✓)")


func test_parent_flag_off_means_disabled() -> void:
	SettingsStore.set_value("cloud_sync_enabled", false)
	assert_false(bool(_net.enabled()), "والد خاموش کرد ⇒ خاموش ✓§۹")
	_enqueue_n(2)
	assert_eq(int(_net.flush_once()), 0, "با پرچمِ خاموش هم صفر ارسال ✓")


func test_unknown_event_type_is_rejected_not_crashed() -> void:
	assert_false(bool(_net.enqueue_event({"event_type": "pixel_clicked", "player_id": PID})),
			"نوعِ خارج از §۵ ⇒ رد ✓ (و نه کرش ✓)")
	assert_false(bool(_net.enqueue_event(_event(""))), "بی‌نوع ⇒ رد ✓")
	assert_eq(_net.queue_size(), 0, "چیزی وارد صف نشد ✓")


func test_bad_player_id_is_rejected() -> void:
	assert_false(bool(_net.enqueue_event({"event_type": "session_start", "player_id": "kid"})))
	assert_false(bool(_net.sync_player_model({"player_id": "P_UPPERCASE"})),
			"§۲ = `p_` + هشت هگزِ کوچک ✗✓ (همان regexِ zodِ سرور ✓)")
	assert_eq(_net.queue_size(), 0, "رد شد ✓")


func test_all_six_mvp_events_are_accepted_and_stamped() -> void:
	for type_name: String in NET.EVENT_TYPES:
		assert_true(bool(_net.enqueue_event(_event(type_name))), "«%s» مجاز است ✓" % type_name)
	assert_eq(_net.queue_size(), 6, "شش تا ✓§۵")
	var body: Dictionary = _sender.last_body()
	assert_eq((body.get("events", []) as Array).size(), 6, "بدنهٔ دسته ✓")


# --------------------------------------------------------- ۲) صف/سقف/ترتیب ----
func test_queue_cap_drops_oldest_and_counts() -> void:
	var cap: int = int(FeatureFlags.OFFLINE_QUEUE_MAX)  # سقف از FeatureFlags ✓§۹ (یک‌منبعه)
	for i: int in range(cap + 3):
		_net.enqueue_event(_event("level_started"))
	assert_eq(_net.queue_size(), cap, "سقفِ FeatureFlags محترم ماند ✗✓ (§۹ حافظهٔ کودک‌محور)")
	assert_eq(int(_net.stats()["dropped"]), 3, "سه تای قدیمی **شمرده** افتاد ✓ (سکوت نه ✗✓)")


func test_fifo_order_is_preserved_model_after_events() -> void:
	# DoD: «به‌محض اتصال، **به‌ترتیب** ارسال می‌شوند» ✓✗ پس ترتیبِ مسیرها must ثابت باشد
	_enqueue_n(1)
	assert_true(bool(_net.sync_player_model({"player_id": PID, "schema_version": 1})))
	assert_eq(int(_net.flush_once()), 1, "اول رویداد ✓")
	assert_eq(int(_net.flush_once()), 1, "بعد مدل ✓")
	assert_true(String(_sender.sent[0]["url"]).ends_with(NET.ENDPOINT_EVENTS), "اول events ✓")
	assert_true(String(_sender.sent[1]["url"]).contains("/api/player-model/" + PID + "/sync"),
			"بعد sync با همان player ✓✓")


func test_batch_limit_never_exceeds_server_cap() -> void:
	_enqueue_n(250)
	var sent_now: int = int(_net.flush_once())
	assert_eq(sent_now, NET.BATCH_LIMIT, "یک دسته = سقفِ سرور (۲۰۰) ✗✓")
	assert_eq(_net.queue_size(), 50, "پنجاه تا برای دورِ بعد ماند ✓")


# ------------------------------------------------------- ۳) معناهای وضعیت ✓ ----
func test_server_error_keeps_the_queue_and_warms_backoff() -> void:
	_sender.default_result = {"ok": false, "status": 503, "code": OK}
	_enqueue_n(3)
	_net.flush_once()
	assert_eq(_net.queue_size(), 3, "۵۰۳ ⇒ صف **می‌ماند** ✓§۹ (بازی آفلاین نباید داده ببازد)")
	assert_eq(int(_net.stats()["attempts"]), 1, "یک تلاش شمرده شد ✓")
	assert_almost_eq(float(_net.stats()["cooldown"]), NET.retry_delay(1), 0.001,
			"cooldown = backoffِ تلاشِ اول ✓")


func test_backoff_is_monotonic_and_capped() -> void:
	assert_eq(float(NET.retry_delay(0)), 0.0, "تلاش صفر ⇒ بی‌فاصله ✓")
	assert_eq(float(NET.retry_delay(1)), 2.0, "پایه ✓")
	assert_true(NET.retry_delay(4) > NET.retry_delay(3), "تصاعدی ✓")
	assert_eq(float(NET.retry_delay(40)), NET.BACKOFF_MAX_SEC, "سقف ۳۰۰ ثانیه ✓ (بمباران نه ✗)")


func test_repeated_failures_cool_down_without_losing_items() -> void:
	# این همان تستی است که «اول pop، بعد retry» را لو می‌داد ✗✓ (باگِ واقعیِ همین تسک)
	# ⚠ `ERR_CONNECTION_FAILURE` در Godot 4 حذف شده (میراث 3.x) ✗✓ و parser آن را
	# «not declared in the current scope» می‌خواند ⇒ همان ERR_UNAVAILABLE که خودِ
	# NetworkClient برای «host نیست» می‌دهد ✓✓ (تست هم‌راستا با مسیرِ واقعی شد ✓)
	_sender.default_result = {"ok": false, "status": 0, "code": ERR_UNAVAILABLE}
	_enqueue_n(4)
	for i: int in range(NET.MAX_ATTEMPTS):
		_net.flush_once()
	assert_eq(_net.queue_size(), 4, "هیچ رویدادی گم نشد ✗✓ (سرد شدن ≠ دور ریختن ✓)")
	assert_almost_eq(float(_net.stats()["cooldown"]), NET.BACKOFF_MAX_SEC, 0.001,
			"بعد از سقفِ تلاش ⇒ cooldownِ کامل ✓")


func test_client_error_drops_only_the_poison_batch_and_counts_it() -> void:
	_sender.default_result = {"ok": true, "status": 422, "code": OK}
	_enqueue_n(2)
	_net.flush_once()
	assert_eq(_net.queue_size(), 0, "دستهٔ سمّی تکرار نمی‌شود ✓")
	assert_eq(int(_net.stats()["rejected"]), 2, "و **شمرده** می‌شود ✓ (بی‌سکوت ✓§۹)")


func test_401_keeps_queue_and_asks_for_a_new_token() -> void:
	_sender.results = [{"ok": true, "status": 401, "code": OK},
			{"ok": true, "status": 201, "code": OK}]
	_enqueue_n(1)
	watch_signals(_net)
	_net.flush_once()
	assert_eq(_net.queue_size(), 1, "بی‌توکن ⇒ داده نمی‌رود ✗✓ صف می‌ماند ✓")
	assert_signal_emitted(_net, "auth_required", "والد/دیباگ خبردار شد ✓")
	assert_eq(_sender.sent.size(), 2, "درخواستِ mintِ توکن هم ارسال شد ✓✓ (۹.۵↔۹.۶)")
	assert_true(String(_sender.sent[1]["url"]).ends_with(NET.ENDPOINT_DEVICE), "مسیر /api/device ✓")


# --------------------------------------------------- ۴) بدنه/پاسخِ مدل ✓ ----
func test_sync_body_is_the_model_and_header_has_token() -> void:
	_net.save_device_token("tok-abc", Time.get_unix_time_from_system() + 600.0)
	assert_true(bool(_net.sync_player_model({"player_id": PID, "schema_version": 1,
			"hint_usage_rate": 0.2})))
	_net.flush_once()
	var headers: PackedStringArray = _sender.sent[0].get("headers", PackedStringArray())
	# ⚠ در Godot 4 متد `join` روی خودِ رشتهٔ جداکننده است ✓ — `PackedStringArray` و
	# `Array` آن را ندارند ✗ (`headers.join("|")` = خطای پارس ✓✓)
	assert_true("|".join(headers).contains("Bearer tok-abc"), "توکن در هدر رفت ✓✓")
	assert_true(String(_sender.sent[0].body).contains("\"schema_version\":1"), "بدنه = مدل §۲ ✓")


func test_model_get_callback_receives_payload() -> void:
	_net.sync_player_model({"player_id": PID, "schema_version": 1})
	_net.flush_once()
	_sender.default_result = {"ok": true, "status": 200, "code": OK,
			"body": JSON.stringify({"model": {"hint_usage_rate": 0.77}, "schema_version": 1})}
	var got: Array = []
	assert_true(bool(_net.request_model(func(ok: bool, payload: Dictionary) -> void:
		got.append([ok, payload]))))
	_net.flush_once()
	assert_eq(got.size(), 1, "callback صدا زده شد ✓")
	assert_eq(bool(got[0][0]), true, "با موفقیت ✓")
	assert_eq(float((got[0][1] as Dictionary).get("model", {}).get("hint_usage_rate", 0.0)), 0.77,
			"مدلِ سرور رسید ✓✓ (DoDِ «دریافت مجدد» در سمتِ بازی ✓)")


# ----------------------------------------- ۵) توکن/دورِ آفلاینِ کامل ✓ ----
func test_device_token_roundtrip_and_expiry() -> void:
	_net.save_device_token("tok-xyz", Time.get_unix_time_from_system() + 3600.0)
	var fresh: Node = NET.new()
	add_child_autofree(fresh)
	assert_true(bool(fresh.has_valid_token()), "از user:// خوانده شد ✓§۹ (بی‌جدولِ سروری ✓)")
	var stale: Node = NET.new()
	add_child_autofree(stale)
	stale.save_device_token("tok-old", Time.get_unix_time_from_system() - 1.0)
	var stale2: Node = NET.new()
	add_child_autofree(stale2)
	assert_false(bool(stale2.has_valid_token()), "منقضی ⇒ نامعتبر ✓ (۴۰۰ روزِ سرور §۹.۵)")


func test_offline_then_reconnect_empties_the_queue() -> void:
	# DoDِ ۹.۶، کلمه‌به‌کلمه ✓✗ «قطعِ شبیه‌سازی‌شده» = سه خطای شبکه، «وصلِ مجدد» = 200
	_enqueue_n(5)
	for i: int in range(3):
		_sender.default_result = {"ok": false, "status": 0, "code": ERR_UNAVAILABLE}
		_net.flush_once()
	assert_eq(_net.queue_size(), 5, "قطع ⇒ چیزی نرفت و چیزی گم نشد ✓✓ (بدون کرش ✓)")
	assert_eq(int(_net.stats()["inflight"]), 0, "هیچ درخواستِ معلق‌ای نماند ✓")
	_sender.default_result = {"ok": true, "status": 200, "code": OK}
	var sent_total: int = 0
	for i: int in range(3):
		sent_total += int(_net.flush_once())
	assert_eq(sent_total, 5, "پنج رویداد رسیدند ✓")
	assert_eq(_net.queue_size(), 0, "«با وصلِ مجدد، صف خالی می‌شود» ✓✓")
	assert_eq(int(_net.stats()["attempts"]), 0, "شمارندۀ تلاش صفر شد ✓ (وگرنه cooling ابدی ✗)")


func test_no_real_http_requester_is_built_when_transport_is_injected() -> void:
	# CIِ هدلس باید **هرگز** socket باز نکند ✓✗ این تست همان است (فایل allowlist را هم قفل می‌کند)
	_enqueue_n(2)
	_net.flush_once()
	assert_eq(_net.queue_size(), 0, "fake جواب داد ✓")
	assert_null(_net.get("_requester"), "HTTPRequestِ واقعی ساخته نشد ✓✓ (بی‌شبکه در CI ✓)")

