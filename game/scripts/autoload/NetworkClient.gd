extends Node
# ===========================================================================
# NEXUS — NetworkClient (تسک ۹.۶ | docs/04 §۹) — HTTP wrapper با صف آفلاین
# ---------------------------------------------------------------------------
# اصلِ حاکم: **هیچ «تشخیص اتصال» جعلی نداریم** ✗✓ — Godot 4 هیچ «آیا آنلاینم؟» ندارد
# (`OS.get_network_status` در `PHANTOM_API` گیت ثبت شده تا کسی دوباره اختراعش نکند ✓✓)،
# پس حدس نمی‌زنیم: می‌فرستیم و **نتیجه** را می‌بینیم؛ خطا یعنی «فعلاً نه» ⇒ صف می‌ماند ✓
#
# چهار invariant که تست‌ها همین‌ها را می‌پایند، نه رنگ‌ها را:
#  ۱) بی‌`base_url` یا با پرچمِ خاموش ⇒ **صفر** درخواست، حتی اگر هزار رویداد enqueue شود ✓§۹
#     (امروز بازی هیچ مصرف‌کننده‌ای ندارد — AnalyticsManager = تسک ۱۰.۳ ⇒ buildِ پیش‌فرض یعنی
#     «هیچ بایتی بیرون نمی‌رود» ✓؛ امنیت از **ساختار**، نه از انضباط ✓)
#  ۲) صف FIFO با سقفِ `FeatureFlags.OFFLINE_QUEUE_MAX` ✓ + شمارندهٔ انداخته‌ها ✓ (سکوتِ
#     بی‌نظمی بدتر از ریختن است: «حافظه پاک شد» ≠ «داده گم شد» ⇒ `stats().dropped` ✓)
#  ۳) معنای وضعیت‌ها (قراردادِ ADR-063 بند «هـ»): 401 ⇒ توکن باطل، mint تازه، صف **می‌ماند** ✓
#     4xx ⇒ دستهٔ سمّی ⇒ همان دسته دور + `rejected` ✓ 5xx/خطای شبکه ⇒ نگه‌داشتن + backoff ✓
#  ۴) «اول موفقیت، بعد حذف از صف» ✓✗ — آیتم‌ها تا پاسخِ 2xx از صف برداشته نمی‌شوند
#     (peek ⇒ commit ✓). الگوی «اول pop، بعدً retry» در همین تسک نوشته شد و **رویداد گم می‌کرد**
#     ✗✗ با هیچ تستی هم لو نمی‌رفت اگر `_take_back` صوری را ندیده بودم ✓✓ (درس: retryِ صف باید
#     در تست «شمارشِ آیتم‌های مانده» داشته باشد، نه فقط «صفر نشدنِ کرش» ✓)
#
# این فایل **تنها** جای کدِ بازی است که نامِ `HTTPRequest`/`HTTPClient` را می‌برد ✓✗ و تستِ
# فاز ۵ (`test_live_ai_provider.gd`) با allowlistِ صریح همین را قفل می‌کند ⇒ افزودن فایل دیگر
# به آن فهرست یعنی شکستنِ «آفلاین‌بودنِ MVP» ✗✓ (هر دو فهرست، این و گیت، چک می‌شوند ✓).
# ===========================================================================

## یک درخواست تمام‌شده ⇒ `kind, code, status` ✓ (دیباگ فاز ۱۰ + آزمون‌های همین تسک ✓)
signal request_finished(kind: String, code: int, status: int)
## اندازهٔ صف و شمارندهٔ انداخته‌ها ✓
signal queue_changed(size: int, dropped: int)
## توکن لازم است/باطل شد ⇒ مصرف‌کننده (داشبورد والدین در ۱۰/۱۱) می‌تواند خبردار شود ✓
signal auth_required()

## باید **دقیقاً** با `backend/src/schemas/events.ts` یکی باشد ✗✓ (گیت: `check_backend_client_contract`)
const EVENT_TYPES: Array[String] = [
	"session_start", "session_end", "level_started",
	"level_completed", "hint_shown", "error_occurred",
]
## سقف دسته ⇒ `MAX_EVENTS_PER_REQUEST` سرور (۲۰۰) ✓ بزرگ‌تر یعنی ۴۲۲ همیشگی ✗ (گیت همین ✓)
const BATCH_LIMIT := 200
const BACKOFF_BASE_SEC := 2.0
const BACKOFF_MAX_SEC := 300.0
## تلاش برای **یک** دسته؛ بعدش صف می‌ماند و cooldown به سقف می‌رسد (نه بی‌نهایتِ فعال ✓§۹)
const MAX_ATTEMPTS := 6
const TOKEN_PATH := "user://device_token.save"
const ENDPOINT_EVENTS := "/api/events"
const ENDPOINT_DEVICE := "/api/device"
const ENDPOINT_SYNC_FMT := "/api/player-model/%s/sync"
const ENDPOINT_MODEL_FMT := "/api/player-model/%s"

## آدرس بک‌اند؛ خالی = «هیچ شبکه‌ای» ✓§۹ (تنظیمش کارِ فاز ۱۰/۱۱ است، نه پیش‌فرضِ MVP ✗✓)
@export var base_url: String = ""

## تزریق‌پذیر برای تست ⇒ هر Node با `send(req: Dictionary, done: Callable) -> void` ✓
## (fake همگام work می‌کند، HTTP واقعی ناهمگام ✓✓ ⇒ رفتارِ هدلس == رفتارِ دستگاه ✓)
var transport: Node = null

var _queue: Array[Dictionary] = []
var _dropped: int = 0
var _rejected: int = 0
var _cooldown: float = 0.0
var _attempts: int = 0
var _inflight: int = 0
var _last_error: String = ""
var _device_token: String = ""
var _token_exp: float = 0.0
var _player_id: String = ""
var _requester: Node = null


func _ready() -> void:
	load_device_token()


## فاصلهٔ تلاش‌ها: تصاعدی با سقف ✓ (تابعِ خالص ⇒ تستِ عددی، بی‌زمانِ واقعی ✓✓)
static func retry_delay(attempt: int) -> float:
	if attempt <= 0:
		return 0.0
	return minf(BACKOFF_BASE_SEC * pow(2.0, float(attempt - 1)), BACKOFF_MAX_SEC)


static func is_known_event(event_type: String) -> bool:
	return EVENT_TYPES.has(event_type)


## `p_` + هشت هگزِ کوچک — همان قرارداد §۲ (و همان regexِ zodِ سرور ✓✓ دو طرف یک قانون ✓)
static func is_player_id(pid: String) -> bool:
	if pid.length() != 10 or not pid.begins_with("p_"):
		return false
	for i: int in range(2, 10):
		if not _is_hex_char(pid[i]):
			return false
	return true


static func _is_hex_char(c: String) -> bool:
	return (c >= "0" and c <= "9") or (c >= "a" and c <= "f")


## تنها دروازهٔ ارسال ✓: پرچمِ فیچر + پرچمِ والد + آدرسِ تنظیم‌شده ✓§۹
func enabled() -> bool:
	if not FeatureFlags.CLOUD_SYNC_ENABLED:
		return false
	if base_url == "":
		return false
	return bool(SettingsStore.get_value("cloud_sync_enabled"))


func queue_size() -> int:
	return _queue.size()


func queued_items() -> int:
	var n: int = 0
	for entry: Dictionary in _queue:
		n += int((entry.get("items", [entry]) as Array).size())
	return n


func clear_queue() -> void:
	_queue.clear()
	_attempts = 0
	_cooldown = 0.0
	_emit_queue_changed()


func stats() -> Dictionary:
	return {
		"queued": _queue.size(),
		"items": queued_items(),
		"dropped": _dropped,
		"rejected": _rejected,
		"attempts": _attempts,
		"inflight": _inflight,
		"cooldown": _cooldown,
		"enabled": enabled(),
		"has_token": _device_token != "",
		"last_error": _last_error,
	}


## رویداد §۵ ⇒ صف ✓ (`false` = ردِ بی‌کرش: نوعِ ناشناخته/شناسهٔ بد ✗✓ نه استثنا)
func enqueue_event(event: Dictionary) -> bool:
	var kind: String = str(event.get("event_type", ""))
	if not is_known_event(kind):
		_last_error = "unknown_event_type"
		Log.warn("network", "رویدادِ ناشناخته رد شد: «%s» (§۵ فقط %d نوع می‌شناسد ✓)"
				% [kind, EVENT_TYPES.size()])
		return false
	if not is_player_id(str(event.get("player_id", ""))):
		_last_error = "bad_player_id"
		Log.warn("network", "رویداد بی‌player_id معتبر رد شد ✗✓")
		return false
	var item := event.duplicate(true)
	if not item.has("timestamp"):
		item["timestamp"] = _now_iso()
	_enqueue({"kind": "events", "items": [item]})
	return true


## همگام‌سازی مدل (§۲) ⇒ همان صف، همان ترتیب ✓ (و `player_id` کلیدِ مسیر است ✓)
func sync_player_model(model: Dictionary) -> bool:
	var pid: String = str(model.get("player_id", ""))
	if not is_player_id(pid):
		_last_error = "bad_player_id"
		return false
	_player_id = pid
	_enqueue({"kind": "model", "model": model.duplicate(true)})
	return true


## خواندن مدل از سرور ✓ (`callback(ok: bool, payload: Dictionary)`)
func request_model(callback: Callable) -> bool:
	if not is_player_id(_player_id):
		_last_error = "no_player"
		return false
	_enqueue({"kind": "model_get", "callback": callback})
	return true


func tick(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(0.0, _cooldown - delta)
		return
	if _inflight > 0 or _queue.is_empty() or not enabled():
		return
	flush_once()


func _process(delta: float) -> void:
	tick(delta)


## یک دسته برمی‌دارد و می‌فرستد؛ تعداد **آیتم‌های** ارسالی برمی‌گردد ✓ (0 = چیزی نداد ✓)
## آزمون‌ها دقیقاً همین را صدا می‌زنند ⇒ لازم نیست صبرِ زمانی شبیه‌سازی شود ✓✓ (هدلس ✓)
func flush_once() -> int:
	if _inflight > 0 or _queue.is_empty() or not enabled():
		return 0
	var head: Dictionary = _queue[0] as Dictionary
	var kind: String = str(head.get("kind", ""))
	match kind:
		"events":
			var batch: Array = []
			var take: int = 0
			while take < _queue.size() and batch.size() < BATCH_LIMIT \
					and str(_queue[take].get("kind", "")) == "events":
				for item: Variant in (_queue[take] as Dictionary).get("items", []) as Array:
					batch.append(item)
				take += 1
			if batch.is_empty():
				_queue.pop_front()
				_emit_queue_changed()
				return 0
			_send(ENDPOINT_EVENTS, "POST", JSON.stringify({"events": batch}),
					{"kind": "events", "take": take, "count": batch.size()})
			return batch.size()
		"model":
			var model: Dictionary = head.get("model", {}) as Dictionary
			var pid: String = str(model.get("player_id", _player_id))
			_send(ENDPOINT_SYNC_FMT % pid, "POST", JSON.stringify(model),
					{"kind": "model", "take": 1, "count": 1})
			return 1
		"model_get":
			_send(ENDPOINT_MODEL_FMT % _player_id, "GET", "",
					{"kind": "model_get", "take": 1, "count": 1,
					"callback": head.get("callback", Callable())})
			return 1
		_:
			_last_error = "unknown_kind"
			_queue.pop_front()
			_emit_queue_changed()
			return 0


func _enqueue(entry: Dictionary) -> void:
	var cap: int = maxi(1, int(FeatureFlags.OFFLINE_QUEUE_MAX))
	while _queue.size() >= cap:
		# قدیمی‌ترین می‌رود (تازه‌ها برای تحلیلِ یادگیری ارزش‌مندترند ✓) و **شمرده** می‌شود ✓
		_queue.pop_front()
		_dropped += 1
	_queue.append(entry)
	_emit_queue_changed()


func _send(path: String, method: String, body: String, meta: Dictionary) -> void:
	_inflight += 1
	var req := {
		"url": base_url + path,
		"method": method,
		"body": body,
		"headers": _headers(),
		"meta": meta,
	}
	var sender: Node = transport
	if sender == null:
		sender = _ensure_requester()
	if sender == null or not sender.has_method("send"):
		# نه transport تزریق شده، نه کسی تنظیم شده ⇒ مثل هر قطعیِ شبکه ✓ (صف می‌ماند ✓)
		_handle_result(req, {"ok": false, "status": 0, "code": ERR_UNAVAILABLE})
		return
	sender.call("send", req, Callable(self, "_handle_result"))


func _handle_result(req: Dictionary, result: Dictionary) -> void:
	_inflight = maxi(0, _inflight - 1)
	var meta: Dictionary = req.get("meta", {}) as Dictionary
	var kind: String = str(meta.get("kind", ""))
	var count: int = int(meta.get("count", 0))
	var take: int = int(meta.get("take", 0))
	var status: int = int(result.get("status", 0))
	var code: int = int(result.get("code", OK))
	request_finished.emit(kind, code, status)

	var ok: bool = bool(result.get("ok", false)) and status >= 200 and status < 300
	if ok:
		_commit(take)
		_attempts = 0
		_cooldown = 0.0
		_last_error = ""
		if kind == "model_get":
			var cb: Callable = meta.get("callback", Callable())
			if cb.is_valid():
				cb.call(true, _parse_dict(str(result.get("body", ""))))
		elif kind == "device":
			_store_token_from_body(str(result.get("body", "")))
		return

	if status == 401:
		# توکن باطل/منقضی ⇒ mint تازه و **نگه‌داشتنِ صف** ✓ (دور ریختن = گم‌شدن داده ✗✓)
		_last_error = "auth"
		auth_required.emit()
		_bump_backoff()
		_refresh_token()
		return
	if status >= 400 and status < 500:
		# سمّی: تکرار هم همان ۴۲۲ می‌گیرد ⇒ همان دسته دور، ولی **ثبت** می‌شود ✓
		_commit(take)
		_rejected += count
		_last_error = "rejected_%d" % status
		_attempts = 0
		_cooldown = 0.0
		return

	_last_error = ("net_%d" % code) if status == 0 else ("server_%d" % status)
	_bump_backoff()


## «موفق شد» ⇒ حالا می‌تواند از صف برود ✓ (تنها جایی که داده حذف می‌شود ✗✓)
func _commit(take: int) -> void:
	for _i: int in range(take):
		if _queue.is_empty():
			break
		_queue.pop_front()
	_emit_queue_changed()


func _bump_backoff() -> void:
	_attempts += 1
	if _attempts >= MAX_ATTEMPTS:
		# ناامیدیِ **موقت**: صف می‌ماند، فقط سرد می‌شویم ✗✓ (نه بی‌نهایتِ داغ، نه دور ریختن)
		_attempts = 0
		_cooldown = BACKOFF_MAX_SEC
		return
	_cooldown = retry_delay(_attempts)


func _refresh_token() -> void:
	if _player_id == "" or base_url == "":
		return
	_send(ENDPOINT_DEVICE, "POST", JSON.stringify({"player_id": _player_id}),
			{"kind": "device", "take": 0, "count": 0})


func _store_token_from_body(body: String) -> void:
	var parsed := _parse_dict(body)
	if parsed.is_empty():
		return
	var token: String = str(parsed.get("device_token", ""))
	if token == "":
		return
	# `expires_in_days` سرور (۴۰۰ ✓) ⇒ تخمینِ exp همین‌جا؛ بی‌آن هر بار mint می‌کردیم ✗✓
	var days: float = float(parsed.get("expires_in_days", 400))
	save_device_token(token, Time.get_unix_time_from_system() + days * 86400.0)


func _headers() -> PackedStringArray:
	var out := PackedStringArray(["Content-Type: application/json"])
	if _device_token != "":
		out.append("Authorization: Bearer " + _device_token)
	return out


func _now_iso() -> String:
	# `Z` دستی لازم است ✗✓: `get_datetime_string_from_system(utc)` «2026-09-12T09:00:00»
	# می‌دهد و zodِ §۵ (`.datetime({offset:true})`) رشتهٔ بی‌ناحیه را **رد** می‌کند ⇒ هر رویداد
	# با ۴۲۲ برمی‌گشت و صف تا ابد پر می‌ماند ✗✓ (تستِ «به Z ختم شود» همین را قفل می‌کند ✓)
	var stamp: String = Time.get_datetime_string_from_system(true)
	if stamp.length() == 19:
		stamp += "Z"
	return stamp


static func _parse_dict(text: String) -> Dictionary:
	if text == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func load_device_token() -> void:
	if not FileAccess.file_exists(TOKEN_PATH):
		return
	var f := FileAccess.open(TOKEN_PATH, FileAccess.READ)
	if f == null:
		return
	var d := _parse_dict(f.get_as_text())
	_device_token = str(d.get("token", ""))
	_token_exp = float(d.get("exp", 0.0))
	if _token_exp > 0.0 and _token_exp <= Time.get_unix_time_from_system():
		_device_token = ""
		_last_error = "token_expired"


func save_device_token(token: String, exp_unix: float) -> void:
	_device_token = token
	_token_exp = exp_unix
	var f := FileAccess.open(TOKEN_PATH, FileAccess.WRITE)
	if f == null:
		_last_error = "token_unstored"
		return
	f.store_string(JSON.stringify({"token": token, "exp": exp_unix}))
	f.flush()


## برای آزمون/دیباگ: توکنِ فعلی (هیچ‌وقت در لاگ چاپ نمی‌شود ✓§۹)
func has_valid_token() -> bool:
	if _device_token == "":
		return false
	return _token_exp <= 0.0 or _token_exp > Time.get_unix_time_from_system()


func _emit_queue_changed() -> void:
	queue_changed.emit(_queue.size(), _dropped)


## HTTPRequest تنها وقتی ساخته می‌شود که `base_url` تنظیم شده باشد ✓§۹ ⇒ تست‌های هدلس هرگز
## سوکت باز نمی‌کنند ✗✓ (CI ما هیچ‌وقت «اتصال به 127.0.0.1» نمی‌زند ✓)
func _ensure_requester() -> Node:
	if base_url == "":
		return null
	if _requester == null:
		var r := Requester.new()
		_requester = r
		add_child(_requester)
	return _requester


## لایهٔ واقعی: یک `HTTPRequest` برای هر درخواست ✓ (Godot 4: سیگنال با Callable ✓✗ نه bindِ
## نامِ متد ✓§۹ — همان چیزی که `check_godot4_api` می‌پاید ✓). تنها ساخته می‌شود اگر
## `base_url` تنظیم شده باشد ⇒ در تست/CI هیچ سوکتی باز نمی‌شود ✓✓
class Requester extends Node:
	func send(req: Dictionary, done: Callable) -> void:
		var http := HTTPRequest.new()
		add_child(http)
		http.request_completed.connect(_on_done.bind(req, done, http))
		var method: int = HTTPClient.METHOD_GET if str(req.get("method", "POST")) == "GET" \
				else HTTPClient.METHOD_POST
		var err: int = http.request(str(req.get("url", "")), headers_of(req), method,
				str(req.get("body", "")))
		if err != OK:
			http.queue_free()
			# خطای **ارسال** (نه پاسخ) ⇒ مثل قطعیِ شبکه: صف نگه داشته می‌شود ✓§۹
			done.call(req, {"ok": false, "status": 0, "code": err})

	## بدونِ `as` روی نوعِ builtin ✗✓ (درسِ ۹.۶: تبدیلِ نوع‌های داخلیِ Variant شکننده است؛
	## gdparse هم این را نمی‌گیرد ⇒ typeof صریح ✓✓)
	func headers_of(req: Dictionary) -> PackedStringArray:
		var raw: Variant = req.get("headers", PackedStringArray())
		return raw if typeof(raw) == TYPE_PACKED_STRING_ARRAY else PackedStringArray()

	func _on_done(result: int, status: int, _headers_in: PackedStringArray,
			body: PackedByteArray, req: Dictionary, done: Callable, http: HTTPRequest) -> void:
		done.call(req, {
			"ok": result == HTTPRequest.RESULT_SUCCESS,
			"status": status,
			"code": result,
			"body": body.get_string_from_utf8(),
		})
		http.queue_free()
