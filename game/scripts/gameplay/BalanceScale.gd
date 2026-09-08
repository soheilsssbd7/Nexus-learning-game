class_name BalanceScale
extends Node2D
# ===========================================================================
# BalanceScale — ترازو (تسک ۲.۲)
# ---------------------------------------------------------------------------
# `calculate_tilt()` دقیقاً همان قطعه‌کد تسک ۲.۲ است (شامل clamp و نرمال‌ساز ۲۰).
# بازو با Tween می‌چرخد (پرش ناگهانی ممنوع) و کفه‌ها counter-rotate می‌شوند تا
# افقی بمانند. بعد از هر تغییر وزن، `EventBus.balance_changed` منتشر می‌شود.
#
# **چند-ترازویی بودن از همین‌جا**: این کلاس هیچ ارجاعی به «سطح» یا «برد» ندارد و
# مستقل از تعداد نمونه‌های خودش کار می‌کند؛ Tier 4 (Twin Observatory — دو ترازوی
# پیوندخورده) فقط یک `BalanceScale` دیگر در LevelScene می‌سازد (ADR-029).
# ===========================================================================

signal weights_changed(scale: BalanceScale, left: float, right: float, tilt: float)
signal placement_changed(orb: WeightOrb, placed: bool)

const TAG := "BalanceScale"
## §۲.۲: حداکثر زاویه‌ی بازو (درجه). بزرگ‌تر از این، خوانایی کفه‌ها را روی موبایل از بین می‌برد.
const MAX_TILT_ANGLE_DEG := 14.0
## §۲.۲: `max_diff` — اختلافی که tilt را کامل می‌کند
const WEIGHT_NORMALIZER := 20.0

@export var scale_id: String = "main"
@export var arm_length: float = 320.0
@export var pivot_offset: Vector2 = Vector2(0.0, -240.0)
@export var tilt_seconds: float = 0.35
@export var build_children_in_code: bool = true

@export var beam: Node2D = null
@export var left_pan: BalancePan = null
@export var right_pan: BalancePan = null

var _animating: bool = false
var _tween: Tween = null


func _ready() -> void:
	if beam == null or left_pan == null or right_pan == null:
		build_children()
	set_process(false)


## ساختار درختی وقتی صحنه دستی ساخته نشده باشد (تست‌های هدلس، تسک ۲.۶)
func build_children() -> void:
	var pivot := Node2D.new()
	pivot.name = "Pivot"
	pivot.position = pivot_offset
	add_child(pivot)
	beam = Node2D.new()
	beam.name = "Beam"
	pivot.add_child(beam)
	left_pan = _make_pan(BalancePan.SIDE_LEFT, "LeftPan")
	right_pan = _make_pan(BalancePan.SIDE_RIGHT, "RightPan")
	beam.add_child(left_pan)
	beam.add_child(right_pan)
	left_pan.position = Vector2(-arm_length, 0.0)
	right_pan.position = Vector2(arm_length, 0.0)


func _make_pan(p_side: int, p_name: String) -> BalancePan:
	var pan := BalancePan.new()
	pan.name = p_name
	pan.side = p_side
	pan.scale_ref = self
	pan.input_pickable = false
	pan.monitoring = false
	pan.monitorable = false
	return pan


# --------------------------------------------------------------------------
# فیزیکِ تعادل
# --------------------------------------------------------------------------
## §۲.۲ — «مجموع وزن یک کفه». static است تا در تست‌ها بدون ساخت صحنه قابل‌سنجش باشد.
static func _sum_weights(orbs: Array[WeightOrb]) -> float:
	var total: float = 0.0
	for orb: WeightOrb in orbs:
		if orb != null:
			total += orb.weight()
	return total


func left_orbs() -> Array[WeightOrb]:
	var out: Array[WeightOrb] = []
	if left_pan != null:
		out = left_pan.orbs
	return out


func right_orbs() -> Array[WeightOrb]:
	var out: Array[WeightOrb] = []
	if right_pan != null:
		out = right_pan.orbs
	return out


func left_weight() -> float:
	return left_pan.total_weight() if left_pan != null else 0.0


func right_weight() -> float:
	return right_pan.total_weight() if right_pan != null else 0.0


## §۲.۲ doD — زاویه‌ی هدف بازو؛ right سنگین‌تر ⇒ ساعت‌گرد (مثبت) ⇒ کفه‌ی راست پایین.
func calculate_tilt() -> float:
	var left_sum: float = _sum_weights(left_orbs())
	var right_sum: float = _sum_weights(right_orbs())
	var diff: float = right_sum - left_sum
	var max_diff: float = WEIGHT_NORMALIZER
	return clamp(diff / max_diff, -1.0, 1.0) * MAX_TILT_ANGLE_DEG


func is_balanced(tolerance: float = 0.0) -> bool:
	return absf(left_weight() - right_weight()) <= tolerance


func is_side_heavier(p_side: int) -> bool:
	var diff: float = right_weight() - left_weight()
	if is_equal_approx(diff, 0.0):
		return false
	return (diff > 0.0) == (p_side == BalancePan.SIDE_RIGHT)


func placed_count() -> int:
	return left_orbs().size() + right_orbs().size()


func total_weights() -> Vector2:
	return Vector2(left_weight(), right_weight())


# --------------------------------------------------------------------------
# به‌روزرسانی / انیمیشن
# --------------------------------------------------------------------------
func on_weights_changed(orb: WeightOrb = null, placed: bool = true) -> void:
	refresh(true)
	placement_changed.emit(orb, placed)


## انیمیت بازو + انتشار سیگنال‌ها. `animated=false` برای setup اولیه (پرش مجاز است).
func refresh(animated: bool = true) -> void:
	if beam == null:
		return
	var target: float = calculate_tilt()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if animated and tilt_seconds > 0.0 and not is_equal_approx(beam.rotation_degrees, target):
		_tween = create_tween()
		_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(beam, "rotation_degrees", target, tilt_seconds)
		_tween.finished.connect(_on_anim_finished)
		_animating = true
		set_process(true)
	else:
		beam.rotation_degrees = target
		_sync_pans()
		_animating = false
		set_process(false)
	_emit_state()


func _on_anim_finished() -> void:
	_animating = false
	_sync_pans()
	set_process(false)
	_emit_state()


func _process(_delta: float) -> void:
	if not _animating:
		return
	_sync_pans()
	queue_redraw()


## کفه‌ها همیشه افقی می‌مانند (مثل ترازوی واقعی) — فقط بازو می‌چرخد.
func _sync_pans() -> void:
	var counter: float = -beam.rotation_degrees
	if left_pan != null:
		left_pan.rotation_degrees = counter
		left_pan.queue_redraw()
	if right_pan != null:
		right_pan.rotation_degrees = counter
		right_pan.queue_redraw()


func _emit_state() -> void:
	if left_pan != null:
		left_pan.refresh_look()
	if right_pan != null:
		right_pan.refresh_look()
	var l: float = left_weight()
	var r: float = right_weight()
	weights_changed.emit(self, l, r, calculate_tilt())
	EventBus.balance_changed.emit(l, r)
	EventBus.scale_state_changed.emit(scale_id, l, r)


## همه‌ی کره‌ها را از کفه‌ها بیرون می‌آورد (فاز ۳: LevelLoader قبل از build جدید)
func clear_pans() -> void:
	for pan: BalancePan in [left_pan, right_pan]:
		if pan == null:
			continue
		for orb: WeightOrb in pan.orbs.duplicate():
			pan.remove_orb(orb)
	refresh(false)


func reset() -> void:
	clear_pans()


# --------------------------------------------------------------------------
# ظاهر placeholder: پایه + بازو (هنر نهایی فاز ۸، بدون تغییر در این منطق)
# --------------------------------------------------------------------------
func _draw() -> void:
	var base_y: float = -pivot_offset.y
	# پایه از سنگ Stone Grey (§۶ سند هنری)
	draw_rect(Rect2(-64.0, base_y - 22.0, 128.0, 22.0), Palette.STONE_GREY, true)
	draw_line(Vector2(0.0, base_y), pivot_offset, Palette.STONE_GREY.lightened(0.15), 14.0)
	# بازو از «نور جامد»
	var angle: float = 0.0
	if beam != null:
		angle = deg_to_rad(beam.rotation_degrees)
	var dir := Vector2.from_angle(angle)
	var a: Vector2 = pivot_offset - dir * arm_length
	var b: Vector2 = pivot_offset + dir * arm_length
	var heavy_right: bool = right_weight() > left_weight()
	var beam_color: Color = Palette.AELORIA_GOLD if is_balanced(0.001) else (
		Palette.WARM_CORAL if heavy_right else Palette.SOFT_TEAL)
	draw_line(a, b, beam_color, 9.0)
	draw_circle(pivot_offset, 13.0, Palette.CLOUD_WHITE)
	draw_circle(pivot_offset, 22.0, Color(Palette.CLOUD_WHITE.r, Palette.CLOUD_WHITE.g, Palette.CLOUD_WHITE.b, 0.22))
