extends Node
# ===========================================================================
# StateReader — شبیه‌سازی «یک صحنه‌ی دیگر» برای تست DoD تسک ۱.۴
# (تغییر در یک صحنه باید در صحنه‌ی دیگر قابل مشاهده باشد)
# ===========================================================================

var seen_level: String = ""
var seen_tier: int = 0


func read_level() -> String:
	seen_level = GameState.current_level_id
	seen_tier = GameState.current_tier
	return seen_level
