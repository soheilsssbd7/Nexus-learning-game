extends Node
# ===========================================================================
# NEXUS — AnalyticsManager | تسک ۱۰.۳ (docs/04 §۱۰.۳)
# ---------------------------------------------------------------------------
# DoD: «یک جلسۀ کامل بازی، تمام رویدادهای مورد انتظار را در جدول `events` بک‌اند ثبت می‌کند» ✓
# شش رویداد §۵ = `session_start` `session_end` `level_started` `level_completed`
# `hint_shown` `error_occurred` ✓ — و **تنها** راهِ ورودشان به شبکه همین‌جاست ✓
#
# سه تصمیمی که این فایل را از «emit‌کردنِ ساده» جدا می‌کند ✗✓:
#  ۱) **ناظرِ EventBus، نه تولیدکننده** ✓ — سیگنال‌ها از قبل در نقاطِ درستِ کد می‌آیند
#     (`GameState:58/75`، `LevelController:591/619`، `AriaController:128`) ⇒ این کلاس
#     فقط ترجمه می‌کند؛ اگر روزی تولیدکننده‌ای حذف شود، تستِ ۱۳ می‌گوید ✗✓
#  ۲) **کمینه، نه آینه** ✓§۹ — هیچ رشته‌ای که *کودک* تولید کرده (متنِ راهنما، نامِ پروفایل)
#     از دستگاه بیرون نمی‌رود؛ `hint_shown` فقط `hint_id` را می‌برد ✗✓ (متن در
#     `ParentDashboard` محلی می‌ماند ✓) و `payload` تخت است، چون `JsonScalar`ِ بک‌اند
#     شیء/آرایه نمی‌پذیرد ⇒ ساختارِ تودرتو = ۴۰۰ همیشگی ✓✓ (تستِ ۴/۵)
#  ۳) **بی‌سکوت در حالتِ رد** ✓ (درسِ ADR-064 ✗✓) — هر دلیلِ رد در `stats().reason`
#     می‌نشیند: `cloud_sync_disabled` / `no_sink` / `sink_rejected` / `bad_level_id` /
#     `payload_dropped` ⇒ «آنالیتیکس کار می‌کند؟» با یک عدد جواب دارد، نه با حدس ✓
#
# ⚠ نوعِ `sink` عمداً `Node` است ✗✓ (نه Object/RefCounted): از خاکِ ۹.۶ — fakeِ تستِ GUT
#   باید به همان type قابل‌تزریق باشد، وگرنه خطا در `before_each` همهٔ تست‌ها را می‌بَرد ✓
# ===========================================================================

const TAG := "analytics"

## نقشۀ «رویداد §۵ ← هندلرش» ✓ کلیدها **باید** با `NetworkClient.EVENT_TYPES` و
## `EVENT_TYPES` بک‌اند (backend/src/schemas/events.ts) یکی باشند ✗✓ — تستِ ۱۲ و
## `check_backend_client_contract()` هر دو سمتِ این برابری را قفل می‌کنند ✓✓
const HANDLERS := {
	"session_start": "on_session_started",
	"session_end": "on_session_ended",
	"level_started": "on_level_started",
	"level_completed": "on_level_completed",
	"hint_shown": "on_hint_shown",
	"error_occurred": "on_error_detected",
}

## سقفِ رشته در `payload` ⇒ دقیقاً `JsonScalar`ِ بک‌اند (`z.string().max(200)`) ✓✗ بالاتر
## از این، zod رد می‌کند و کل دسته ۴۰۰ می‌گیرد (تستِ ۵ همین مرز را می‌سنجد ✓)
const MAX_SCALAR_LEN := 200

## تزریق‌پذیر برای تست ✓ (پیش‌فرض: `NetworkClient` ✓§۹.۶)
var sink: Node = null

var _last: Dictionary = {}
var _sent: int = 0
var _rejected: int = 0
var _dropped_keys: int = 0
var _bad_level_ids: int = 0
var _reason: String = ""
var _session_end_sent: bool = false


func _ready() -> void:
	# هندلرها متدِ public‌اند (نه lambda ✓) تا `is_connected` در تستِ ۱۳ معنا داشته باشد ✓
	EventBus.level_started.connect(on_level_started)
	EventBus.level_completed.connect(on_level_completed)
	EventBus.hint_shown.connect(on_hint_shown)
	EventBus.error_detected.connect(on_error_detected)
	EventBus.session_started.connect(on_session_started)
	EventBus.session_ended.connect(on_session_ended)
	# اندروید: «پایانِ نشستِ واقعی» همان لحظه‌ای است که برنامه به بک‌گراند می‌رود ✗✓ —
	# `NOTIFICATION_PREDELETE` ( GameState:226 ) وقتی است که دیگر هیچ HTTP نمی‌رسد ⇒
	# `session_end` در صفِ فقط-حافظه می‌ماند و می‌رود ✓. پس یک فراخوانیِ زودهنگام و
	# **idempotent** از `Window.focus_exited` می‌گیریم ✓ (تستِ ۱۱/۱۶: دو بار ⇒ یک رویداد ✓).
	# `has_signal` عمداً چک می‌شود: هدلس/GUT باید بی‌خطر رد شود ✗ و اختراعِ API هم نکنیم ✓
	# ⚠ عمداً با **رشته** connect می‌کنیم و اول `has_signal` می‌پرسیم ✗✓: نوشتنِ
	# `root.focus_exited.connect(...)` یعنی تکیه بر نمادی که اگر در این نسخه نبود،
	# فایل **parse** نمی‌شود و بیست‌ویک تست زنجیره‌ای می‌میرد ✓✓ (درسِ ۹.۶ با `join`)
	# — این‌جا بدترین حالت فقط «ویژگیِ زودهنگامِ session_end خاموش» است، نه کرش ✓
	var root: Window = get_tree().root
	if root != null and root.has_signal("focus_exited"):
		root.connect("focus_exited", Callable(self, "_on_app_backgrounded"))


## آخرین رویدادِ ساخته‌شده (تست و دیباگِ والد ✓) — کپی، نه ارجاع ✗
func last_event() -> Dictionary:
	return _last.duplicate(true)


func stats() -> Dictionary:
	return {
		"sent": _sent,
		"rejected": _rejected,
		"dropped_payload_keys": _dropped_keys,
		"bad_level_ids": _bad_level_ids,
		"reason": _reason,
		"enabled": enabled(),
	}


## پرچمِ والد ✓§۹: خاموش ⇒ **هیچ** رویدادی ساخته نمی‌شود (نه «ساخته و دور ریخته») ✗✓
## ⇒ صف هم رشد نمی‌کند؛ یعنی در پلی‌تستِ با `cloud_sync_enabled=false`، این کلاس صفر بایت
## و صفر مصرفِ حافظه است ✓ (docs/playtest-protocol.md §۳ ✓)
func enabled() -> bool:
	if not FeatureFlags.CLOUD_SYNC_ENABLED:
		return false
	return bool(SettingsStore.get_value("cloud_sync_enabled"))


## سازندۀ خالص ✓✗ پنج کلیدِ §۵ و نه یکی بیشتر (`EventSchema` در بک‌اند `.strict()` است ⇒
## هر کلیدِ اضافی = ۴۰۰ برای همهٔ دسته ✗✓؛ تستِ ۱۴ همین را قفل می‌کند ✓).
## `timestamp` را **این‌جا نمی‌سازیم** ✓ — `NetworkClient.enqueue_event` آن را با قالبِ
## UTCِ ±ناحیه می‌کشد (`.datetime({offset:true})` ✓§۵) و دو منبعِ زمان یعنی دو قالبِ ممکن ✗
static func build_event(type_name: String, player_id: String, level_id: String, payload: Dictionary) -> Dictionary:
	var out := {
		"event_type": type_name,
		"player_id": player_id,
		"payload": flatten_payload(payload),
	}
	if level_id != "":
		if _level_id_ok(level_id):
			out["level_id"] = level_id
		else:
			out["_bad_level_id"] = level_id  # فقط برای شمارش ✓ در `_send` پاک و لاگ می‌شود ✗✓
	return out


## payload ⇒ فقط `JsonScalar` (عدد/رشتهٔ ≤۲۰۰/بول/نال) ✓✗ هر چیزِ دیگر **شمرده** می‌افتد
static func flatten_payload(payload: Dictionary) -> Dictionary:
	var out := {}
	for key: String in payload.keys():
		var value: Variant = payload[key]
		match typeof(value):
			TYPE_BOOL, TYPE_INT, TYPE_FLOAT:
				out[key] = value
			TYPE_STRING:
				if (value as String).length() <= MAX_SCALAR_LEN:
					out[key] = value
			TYPE_NIL:
				out[key] = null
			_:
				pass  # Dictionary/Array/Object ⇒ رد ✓ (بک‌اند نمی‌پذیرد ✗✓)
	return out


static func _level_id_ok(s: String) -> bool:
	# قالبِ `LevelId` بک‌اند: ^tier[1-5]_level_[0-9]{2}$ ✓§۱ (بی‌RegEx: ارزان‌تر و قابل‌خواندن ✓)
	if not s.begins_with("tier") or s.find("_level_") != 5:
		return false
	var digit: String = s.substr(4, 1)
	if not digit.is_valid_int():
		return false
	var tier: int = digit.to_int()
	if tier < 1 or tier > 5:
		return false
	var tail: String = s.substr(12)
	return tail.length() == 2 and tail.is_valid_int()


func _sink() -> Node:
	if sink != null and is_instance_valid(sink):
		return sink
	var node: Node = get_node_or_null("/root/NetworkClient")
	return node if node != null else null


## `pid_override` اختیاری است ✓: فرستندۀ سیگنال گاهی شناسه را **می‌داند** (session_started ✓)
## و اولویت با اوست، وگرنه از مدلِ فعال خوانده می‌شود ✓ (`enqueue_event` بعداً اعتبارسنجی
## می‌کند ⇒ شناسۀ بد = `sink_rejected` در `stats()` ✓ نه رویدادِ نیمه‌کاره ✗)
func _send(type_name: String, level_id: String, payload: Dictionary, pid_override: String = "") -> bool:
	if not enabled():
		_reason = "cloud_sync_disabled"
		return false
	var target: Node = _sink()
	if target == null or not target.has_method("enqueue_event"):
		_reason = "no_sink"
		Log.warn(TAG, "مقصدِ رویداد نیست ⇒ رویداد «%s» ساخته شد ولی جایی نرفت ✗✓" % type_name)
		return false
	var pid: String = pid_override if pid_override != "" else _player_id()
	var built: Dictionary = build_event(type_name, pid, level_id, payload)
	if built.has("_bad_level_id"):
		_bad_level_ids += 1
		built.erase("_bad_level_id")
		_reason = "bad_level_id"
		Log.warn(TAG, "level_id خارج از قالبِ §۱ («%s») ⇒ کلید حذف شد، رویداد نه ✓" % level_id)
	var dropped: int = (payload as Dictionary).size() - (built.get("payload", {}) as Dictionary).size()
	if dropped > 0:
		_dropped_keys += dropped
		_reason = "payload_dropped"
	_last = built
	var ok := bool(target.call("enqueue_event", built.duplicate(true)))
	if ok:
		_sent += 1
		if _reason != "bad_level_id" and _reason != "payload_dropped":
			_reason = ""
	else:
		_rejected += 1
		_reason = "sink_rejected"
	return ok


func _player_id() -> String:
	var model: Variant = GameState.active_model
	if model != null and is_instance_valid(model):
		return str(model.player_id)
	return ""


# ------------------------------------------------------- شش هندلرِ §۵ ✓ ----
func on_session_started(player_id: String) -> bool:
	_session_end_sent = false  # نشستِ تازه ⇒ دوباره مجاز برای session_end ✓ (پروفایلِ دوم ✓)
	# `profiles: 1` = «یک پروفایل در این نشست فعال است» ✓✗ نه نام، نه تعدادِ کلِ پروفایل‌ها
	# (آنگاه می‌شد از روی تعداد، دستگاه را تشخیص داد ✓§۹ ⇒ عمداً بی‌اثر ✓)
	return _send("session_start", "", {"profiles": 1}, player_id)


func on_session_ended(session_stats: Dictionary) -> bool:
	# idempotent ✓✗ هم `focus_exited` و هم `PREDELETE` می‌آیند؛ دو «session_end» یعنی
	# تحلیلگرِ فاز ۱۱ دو بار بشمارد ✓ → یک بار، همان اولی ✓ (تستِ ۱۱ ✓)
	if _session_end_sent:
		return false  # دومین مسیرِ همان نشست ✓ (تستِ ۱۱)
	_session_end_sent = true
	var playtime: float = float(session_stats.get("total_playtime_sec", GameState.session_playtime_sec()))
	return _send("session_end", "", {"total_playtime_sec": playtime})


func on_level_started(level_id: String, tier: int) -> bool:
	return _send("level_started", level_id, {"tier": tier})


func on_level_completed(level_id: String, stats_dict: Dictionary) -> bool:
	# چهار کلیدِ §۵ ✓ (docs/03 §۵ نمونه) — `score` عمداً نمی‌آید: در مدلِ دستگاه هست ✓
	# و §۹ می‌گوید آنالیتیکس کمینه باشد، نه آینه ✓
	return _send("level_completed", level_id, {
		"time_to_solve_sec": float(stats_dict.get("time_to_solve_sec", 0.0)),
		"hints_used": int(stats_dict.get("hints_used", 0)),
		"attempts": int(stats_dict.get("attempts", 0)),
		"final_elo_delta": float(stats_dict.get("final_elo_delta", 0.0)),
	})


func on_hint_shown(hint_id: String, level_id: String, _text: String) -> bool:
	# ⚠ پارامتر سوم **عمداً مصرف نمی‌شود** ✓§۹: متنِ راهنما هرگز از دستگاه بیرون نمی‌رود ✗✓
	# (این خط، همان جایی است که «جمع‌آوری داده» می‌تواند بی‌سروصدا بزرگ شود ✓✓ تستِ ۳ می‌پاید)
	return _send("hint_shown", level_id, {"hint_id": hint_id})


func on_error_detected(error_type: String) -> bool:
	return _send("error_occurred", GameState.current_level_id, {"error_type": error_type})


func _on_app_backgrounded() -> void:
	# مسیرِ اندرویدِ «اپ به بک‌گراند رفت» ⇒ همان `session_ended`، یک بار ✓
	on_session_ended({"total_playtime_sec": GameState.session_playtime_sec()})
