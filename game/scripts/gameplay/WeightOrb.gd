class_name WeightOrb
extends Area2D
# ===========================================================================
# WeightOrb — کره‌ی وزن (تسک ۲.۱)
# ---------------------------------------------------------------------------
# `Area2D` قابل‌درگ با سه نوع: NUMBER / GHOST / NEGATIVE (زیرکلاس‌ها).
# منطق درگ عمداً از `Input` می‌خواند و نه از مختصات رویداد: با
# `pointing/emulate_mouse_from_touch` (پیش‌فرض true در Godot 4) یک مسیر برای
# لمس و موس کافی است و نیازی به تبدیل screen→world دستی نیست
# (توضیح در docs/06 ADR-030).
#
# این کلاس **هیچ چیزی درباره‌ی برد/باخت نمی‌داند**: فقط جابه‌جایی و سیگنال.
# تصمیم‌گیری با LevelController است (تسک ۲.۵).
# ===========================================================================

enum OrbType { NUMBER, GHOST, NEGATIVE }

const TAG := "WeightOrb"
const LIFT_SCALE := 1.10
const LIFT_OFFSET_Y := -22.0
const PLACE_SCALE := 1.0

## رویدادهای محلی (LevelController به این‌ها گوش می‌دهد؛ بین-صحنه‌ای از EventBus می‌رود)
signal drag_began(orb: WeightOrb)
signal drag_ended(orb: WeightOrb, world_pos: Vector2)
signal weight_changed(orb: WeightOrb)

@export var orb_type: OrbType = OrbType.NUMBER
## مقدارِ کره. برای GHOST این عدد نمایش/استفاده نمی‌شود (وزن = hidden_value).
@export var value: float = 1.0
## true وقتی روی یکی از کفه‌ها نشسته است.
@export var is_placed: bool = false
## کفه‌ای که الان روی آن است (null = سینی/درگ).
@export var pan: BalancePan = null
@export var drag_enabled: bool = true
@export var radius: float = 44.0

var hidden_value: float = 0.0  # فقط GHOST — هرگز در UI نمایش داده نمی‌شود (تسک ۲.۳)
var home_position: Vector2 = Vector2.ZERO  # جای اصلی در سینی (برای بازگشت)
var _dragging: bool = false
var _grab_offset: Vector2 = Vector2.ZERO
var _visual: OrbVisual = null
var _body: CollisionShape2D = null


func _ready() -> void:
	_ensure_nodes()
	refresh_visual()
	input_pickable = drag_enabled


## صحنه‌ها این نودها را دارند؛ ساخت در کد هم مجاز است (تست‌های هدلس، تسک ۲.۶)
func _ensure_nodes() -> void:
	_visual = get_node_or_null("Visual") as OrbVisual
	if _visual == null:
		_visual = OrbVisual.new()
		_visual.name = "Visual"
		add_child(_visual)
	_body = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _body != null:
		var existing := _body.shape as CircleShape2D
		if existing != null and not is_equal_approx(existing.radius, radius):
			existing.radius = radius
	if _body == null:
		var shape := CircleShape2D.new()
		shape.radius = radius
		_body = CollisionShape2D.new()
		_body.name = "CollisionShape2D"
		_body.shape = shape
		add_child(_body)


## `_exit_tree` عمداً درگ را ریست نمی‌کند: هر جابه‌جایی والد (سینی↔کفه) هم آن را می‌زند
## و خاموش‌کردن `_dragging` آنجا باعث می‌شد `end_drag` بی‌صدا برگردد و `drag_ended`
## هرگز emit نشود (باگ واقعی که ۶ تست فاز ۲ را می‌شکست). کره‌ی درگ‌شده به‌جای reparent،
## `top_level = true` می‌گیرد؛ اگر صحنه وسط درگ برود، نود با صحنه آزاد می‌شود.


# --------------------------------------------------------------------------
# وزن — تنها حقیقتی که ترازو می‌بیند
# --------------------------------------------------------------------------
## §۶ سند هنری: حباب ضد-وزن «کم می‌کند»؛ کره‌ی روح وزن واقعیِ مخفی دارد.
func weight() -> float:
	match orb_type:
		OrbType.GHOST:
			return hidden_value
		OrbType.NEGATIVE:
			return -absf(value)
		_:
			return value


func is_ghost() -> bool:
	return orb_type == OrbType.GHOST


## متن روی کره. کره‌ی روح هرگز عدد نمی‌دهد (تسک ۲.۳: «نمایش داده نمی‌شود تا حل نشود»).
func display_text() -> String:
	if is_ghost():
		return "?"
	var w: float = weight()
	var abs_w: float = absf(w)
	var text: String = str(int(abs_w)) if is_equal_approx(abs_w, roundf(abs_w)) else "%.1f" % abs_w
	if orb_type == OrbType.NEGATIVE:
		return "-" + text
	return text


func fill_color() -> Color:
	match orb_type:
		OrbType.GHOST:
			return Palette.ghost_fill(0.66)
		OrbType.NEGATIVE:
			return Palette.negative_bubble(value)
		_:
			return Palette.thermal(weight())


func refresh_visual() -> void:
	if _visual == null:
		return
	_visual.radius = radius
	_visual.refresh(fill_color(), display_text(), glyph_size(), is_ghost())


func glyph_size() -> int:
	return int(radius * 0.86)


func set_value(new_value: float) -> void:
	value = new_value
	weight_changed.emit(self)
	refresh_visual()


# --------------------------------------------------------------------------
# درگ (لمس + موس) — تسک ۲.۱
# --------------------------------------------------------------------------
func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not drag_enabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			begin_drag()
		else:
			end_drag()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			begin_drag()
		elif _dragging:
			end_drag()
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and _dragging):
		drag_to(pointer_world_pos())


## محل فعلی اشاره‌گر در مختصات جهان. `get_global_mouse_position()` برای لمس هم
## درست کار می‌کند (emulate_mouse_from_touch) و تبدیل stretch را خود Godot انجام می‌دهد.
func pointer_world_pos() -> Vector2:
	if not is_inside_tree():
		return global_position
	return get_global_mouse_position()


func begin_drag(at: Vector2 = Vector2.INF) -> void:
	if _dragging or not drag_enabled:
		return
	_dragging = true
	input_pickable = true
	var p: Vector2 = _resolve(at)
	_grab_offset = global_position - p
	z_index = 100
	drag_began.emit(self)
	if _visual != null:
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_visual, "position:y", LIFT_OFFSET_Y, 0.10)
		tw.parallel().tween_property(_visual, "scale", Vector2.ONE * LIFT_SCALE, 0.10)
		_visual.highlight = 1.0


func drag_to(at: Vector2 = Vector2.INF) -> void:
	if not _dragging:
		return
	global_position = _resolve(at) + _grab_offset


func end_drag(at: Vector2 = Vector2.INF) -> void:
	if not _dragging:
		return
	_dragging = false
	z_index = 0
	if at != Vector2.INF:
		# تست‌ها (و مسیر بدون ماوس) نقطه‌ی رهاکردن را صریح می‌دهند
		global_position = _resolve(at) + _grab_offset
	if _visual != null:
		_visual.highlight = 0.0
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_visual, "position:y", 0.0, 0.12)
		tw.parallel().tween_property(_visual, "scale", Vector2.ONE, 0.12)
	drag_ended.emit(self, global_position)


func is_dragging() -> bool:
	return _dragging


func _resolve(at: Vector2) -> Vector2:
	if at == Vector2.INF:
		return pointer_world_pos()
	return at
