class_name NegativeOrb
extends WeightOrb
# ===========================================================================
# NegativeOrb — حباب ضد-وزن (تسک ۲.۴)
# ---------------------------------------------------------------------------
# دو رفتار که این کلاس اضافه می‌کند:
#   ۱) `weight()` منفی است → `_sum_weights` آن را **کم** می‌کند (DoD تسک ۲.۴).
#   ۲) وقتی روی کفه نیست، آرام رو‌به‌بالا می‌رود (§۶ سند هنری: «غرق نمی‌شود، بالا می‌کشد»).
#      drift فقط روی نود Visual اعمال می‌شود، نه روی ریشه → چیدمان/برخورد دقیق می‌ماند
#      و تست‌های هندسی فاز ۲ آسیب نمی‌بینند.
# ===========================================================================

## دامنه‌ی بالا-پایین رفتن در سینی (پیکسل)
const DRIFT_RANGE := 14.0
const DRIFT_SPEED := 1.1

var _drift_phase: float = 0.0


func _init() -> void:
	orb_type = OrbType.NEGATIVE
	if value > 0.0:
		# داده همیشه «مقدار مطلق + نوع» ذخیره می‌شود؛ علامت را نوع تعیین می‌کند.
		value = -value


func weight() -> float:
	return -absf(value)


func display_text() -> String:
	var abs_w: float = absf(value)
	var text: String = str(int(abs_w)) if is_equal_approx(abs_w, roundf(abs_w)) else "%.1f" % abs_w
	return "-" + text


func fill_color() -> Color:
	return Palette.negative_bubble(value)


## نفس‌نفسِ رو‌به‌بالا: آرام بالا می‌رود و برمی‌گردد (القای «وزن منفی»).
func _process(delta: float) -> void:
	if _visual == null:
		return
	if is_placed or is_dragging():
		if _visual.position.y != 0.0:
			_visual.position = Vector2.ZERO
		return
	_drift_phase = fmod(_drift_phase + delta * DRIFT_SPEED, TAU)
	_visual.position.y = -absf(sin(_drift_phase)) * DRIFT_RANGE
