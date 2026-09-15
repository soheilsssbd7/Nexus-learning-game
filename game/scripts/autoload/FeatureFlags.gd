extends Node
# ===========================================================================
# FeatureFlags — تک‌نقطه‌ی کنترل قابلیت‌ها (ADR-016؛ نیاز تسک ۵.۶ و فاز ۹)
# ---------------------------------------------------------------------------
# چرا autoload است و نه const داخل کلاس‌ها؟ چون چند سیستم (AriaController،
# NetworkClient، AnalyticsManager، PauseMenu) باید **همه** یک مقدار ببینند و
# در تست‌های GUT هم بتوانیم موقتاً عوضشان کنیم.
#
# قانون حیاتی پروژه: LIVE_AI_ENABLED در master همیشه false است.
# بازی باید با قطع کامل شبکه، بدون هیچ فراخوانی بیرونی کار کند
# (docs/01-ARCHITECTURE.md §5 و §3 «اصل طراحی حیاتی»).
# ===========================================================================

## وصل‌کردن Aria به یک مدل زبانی زنده. **در MVP خاموش** (تسک ۵.۶).
const LIVE_AI_ENABLED := false
## ارسال رویدادها/مدل به بک‌اند. والد می‌تواند در Settings خاموشش کند (ADR-010).
const ANALYTICS_ENABLED_DEFAULT := true
## همگام‌سازی مدل بازیکن با بک‌اند (فاز ۹). اگر false → بازی صددرصد آفلاین.
const CLOUD_SYNC_ENABLED := true
## حداکثر رویداد نگه‌داشته‌شده در صف آفلاین (فاز ۹، تسک ۹.۶).
const OFFLINE_QUEUE_MAX := 500
## دروازه‌ی والدین قبل از Dashboard (تسک ۶.۵).
const PARENT_GATE_ENABLED := true
## لرزش/بازخورد لمسی (Art Bible §۷). Input.vibrate_handheld روی اندروید.
const HAPTICS_ENABLED := true
## حالت دیباگ: از خود موتور پرسیده می‌شود، نه از این flag.
var debug_overlay: bool = false


func _ready() -> void:
	debug_overlay = OS.is_debug_build()
	set_process(false)


static func live_ai_allowed() -> bool:
	# تنها نقطه‌ای که بقیه کد اجازه دارد بپرسد؛ تا اگر روزی وصل شد، guard یک‌جا باشد.
	return LIVE_AI_ENABLED
