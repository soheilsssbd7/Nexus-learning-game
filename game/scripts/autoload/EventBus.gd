extends Node
# ===========================================================================
# EventBus — باس مرکزی سیگنال‌ها (تسک ۱.۱ | docs/04-BUILD-PLAN.md)
# ---------------------------------------------------------------------------
# الگوی Signal Bus: هیچ سیستمی مستقیماً به سیستم دیگر ارجاع ندارد.
# این کلاس **هیچ state و هیچ منطقی** ندارد؛ فقط تعریف سیگنال.
# هر سیگنال با «مصرف‌کننده» کامنت شده تا حذف/تغییر امضای آن آگاهانه باشد.
#
# امضاها دقیقاً شامل ۵ سیگنال مشخص‌شده در تسک ۱.۱ است؛ بقیه افزوده‌های لازمِ
# فازهای ۲ تا ۱۰ هستند و در docs/06 (ADR-016) ثبت شده‌اند.
# ===========================================================================

# --- گیم‌پلی (فاز ۲) --------------------------------------------------------
## BalanceScale/HUD: یک کره روی کفه‌ای قرار گرفت.
## orb_data: {orb_type:int, value:float, side:int, is_ghost:bool, hidden_value:float}
signal orb_placed(orb_data: Dictionary)
## یک کره از کفه برداشته/به سینی برگشت.
signal orb_removed(orb_data: Dictionary)
## مجموع وزن دو کفه عوض شد. BalanceScale بعد از هر Tween این را emit می‌کند.
signal balance_changed(left_weight: float, right_weight: float)
## بازیکن یک «تلاش» (placement یا press-to-check) انجام داد که تراز نبود.
signal attempt_failed(attempt_index: int)

# --- سطح (فاز ۳ و ۴) -------------------------------------------------------
signal level_started(level_id: String, tier: int)
## stats: {time_sec:float, attempts:int, hints_used:int, score:float, elo_delta:float}
signal level_completed(level_id: String, stats: Dictionary)

# --- هوش آموزشی (فاز ۴ و ۵) -----------------------------------------------
## ErrorClassifier: نوع خطای طبقه‌بندی‌شده (idle | wrong_operation |
## sign_flip_on_subtraction | forgets_both_sides | computation_error)
signal error_detected(error_type: String)
## HintTimingSystem درخواست نمایش یک قالب خاص را می‌دهد.
signal hint_requested(hint_id: String)
## AriaController واقعاً پیام را نمایش داد (برای Analytics + transcript والدین).
signal hint_shown(hint_id: String, level_id: String, text: String)
## تغییر حالت انیمیشن Aria: idle|thinking|hint_light|encouraging|celebrating|concerned
signal aria_state_changed(state_name: String)

# --- نشست / حلقه‌ی محصول (فاز ۶ و ۱۰) --------------------------------------
signal session_started(player_id: String)
signal session_ended(stats: Dictionary)
## LevelLoader → SaveSystem: درخواست write (debounce در SaveSystem انجام می‌شود).
signal save_requested
## تغییر وضعیت قفل/باز بودن شبکه (NetworkClient → HUD).
signal connection_state_changed(online: bool)


func _ready() -> void:
	# autoload باید قبل از هر صحنه‌ای آماده باشد؛ nothing else.
	set_process(false)
