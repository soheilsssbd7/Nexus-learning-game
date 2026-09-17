class_name BalancePan
extends Area2D
# ===========================================================================
# BalancePan — یک کفه‌ی ترازو (تسک ۲.۲: «دو Area2D به‌عنوان کفه‌ی چپ/راست»)
# ---------------------------------------------------------------------------
# ریشه‌ی این نود **نقطه‌ی آویز** است (انتهای بازو)؛ کفه‌ی واقعی `dish_offset`
# پایین‌تر است. برای همین:
#   * `contains_point()` حول مرکز کفه سنجش می‌کند، نه نقطه‌ی آویز.
#   * کفه در `BalanceScale` در مقابل چرخش بازو counter-rotate می‌شود تا **افقی**
#     بماند (مثل ترازوی واقعی) و کره‌ها روی آن سر نخورند.
# تشخیص جای‌گذاری هندسی است (فاصله تا مرکز کفه) و نه overlap فیزیک → رفتار در
# حالت headless/تست قطعی و بدون وابستگی به زمان فیزیک است (ADR-031).
# ===========================================================================

const TAG := "BalancePan"
const SIDE_LEFT: int = 0
const SIDE_RIGHT: int = 1

@export var side: int = SIDE_LEFT
## شعاع «منطقه‌ی پذیرش» کفه در واحد جهان
@export var pan_radius: float = 170.0
## فاصله‌ی کفه از نقطه‌ی آویز (طول طناب)
@export var dish_offset: float = 104.0
@export var max_orbs: int = 14

var orbs: Array[WeightOrb] = []
var scale_ref: BalanceScale = null


func side_name() -> String:
	return "left" if side == SIDE_LEFT else "right"


func dish_position() -> Vector2:
	return global_position + Vector2(0.0, dish_offset)


func total_weight() -> float:
	return BalanceScale._sum_weights(orbs)


## BalanceScale بعد از هر تغییر وزن صدا می‌زند (رنگ کفه‌ی سنگین‌تر — §۶ سند هنری)
func refresh_look() -> void:
	queue_redraw()


func is_empty() -> bool:
	return orbs.is_empty()


func contains_point(world_pos: Vector2) -> bool:
	return dish_position().distance_to(world_pos) <= pan_radius


# --------------------------------------------------------------------------
# پذیرش / آزادکردن کره
# --------------------------------------------------------------------------
func add_orb(orb: WeightOrb) -> bool:
	if orb == null or orb.is_placed:
		return false
	if orbs.size() >= max_orbs:
		return false
	# موقعیت را **قبل** از جداکردن می‌گیریم؛ بعد از remove_child مقدار جهانی بی‌معنی است
	var from_global: Vector2 = orb.global_position
	var prev: Node = orb.get_parent()
	if prev != null and prev != self:
		prev.remove_child(orb)
	orbs.append(orb)
	orb.is_placed = true
	orb.pan = self
	orb.top_level = false
	if orb.get_parent() != self:
		add_child(orb)
	orb.global_position = from_global
	# ادامه‌ی بصری: اول همان‌جا که رها شد بنشین، بعد به اسلاتTween شود
	orb.global_position = from_global
	relayout(true)
	if scale_ref != null:
		scale_ref.on_weights_changed(orb, true)
	return true


func remove_orb(orb: WeightOrb) -> bool:
	if orb == null or not orbs.has(orb):
		return false
	orbs.erase(orb)
	orb.is_placed = false
	orb.pan = null
	if scale_ref != null:
		scale_ref.on_weights_changed(orb, false)
	relayout(true)
	return true


## چیدمان روی کفه: کمانِ ملایم از چپ به راست (تا تعداد زیاد هم خوانا بماند)
func slot_position(index: int, count: int) -> Vector2:
	var spread: float = pan_radius * 1.32
	if count <= 1:
		return Vector2(0.0, dish_offset)
	var step: float = spread / float(count - 1)
	var x: float = -spread * 0.5 + step * float(index)
	# یک قوس کوچک: کره‌های کناری کمی بالاتر می‌نشینند (حس «سینی کاسه‌ای»)
	var t: float = float(index) / float(count - 1) - 0.5
	var y: float = dish_offset + (absf(t) * 18.0) - 9.0
	return Vector2(x, y)


func relayout(animated: bool = false) -> void:
	var count: int = orbs.size()
	for i: int in range(count):
		var orb: WeightOrb = orbs[i]
		if orb == null or orb.is_dragging():
			continue
		var target: Vector2 = slot_position(i, count)
		if animated and orb.position.distance_to(target) > 4.0:
			var tw := orb.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(orb, "position", target, 0.16)
		else:
			orb.position = target


# --------------------------------------------------------------------------
# ظاهر placeholder (§۶ سند هنری: کاسه‌ی کریستالی روی طناب‌های نورانی)
# --------------------------------------------------------------------------
func _draw() -> void:
	var dish := Vector2(0.0, dish_offset)
	var heavy: bool = scale_ref != null and scale_ref.is_side_heavier(side)
	var fill: Color = Palette.WARM_CORAL if heavy else Palette.SOFT_TEAL
	# طناب‌ها
	var rope := Color(Palette.CLOUD_WHITE.r, Palette.CLOUD_WHITE.g, Palette.CLOUD_WHITE.b, 0.55)
	draw_line(Vector2.ZERO, dish + Vector2(-pan_radius * 0.82, -8.0), rope, 4.0, true)
	draw_line(Vector2.ZERO, dish + Vector2(pan_radius * 0.82, -8.0), rope, 4.0, true)
	draw_line(Vector2.ZERO, dish, rope, 3.0, true)
	# سایه‌ی تماس + کفِ سفالیِ کاسه: پرشدنِ نرم، بعد لبه‌ی ضخیم.
	draw_set_transform(dish + Vector2(0.0, 18.0), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, pan_radius * 0.86, Color(0.0, 0.0, 0.0, 0.18))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(dish, 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, pan_radius * 0.95, Color(fill, 0.42))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_arc(dish, pan_radius, 0.06 * TAU, 0.94 * TAU, 40, fill, 16.0, true)
	draw_line(dish + Vector2(-pan_radius * 0.92, -4.0), dish + Vector2(pan_radius * 0.92, -4.0),
		Color(Palette.CLOUD_WHITE, 0.56), 5.0, true)
