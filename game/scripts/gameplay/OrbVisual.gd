class_name OrbVisual
extends Node2D
# ===========================================================================
# OrbVisual — تنه‌ی بصری یک کره (بدون فیزیک، بدون منطق)
# ---------------------------------------------------------------------------
# همه‌ی انیمیشن‌ها (lift هنگام درگ، محو/پررنگ «؟»، drift حباب) روی **این** نود
# اعمال می‌شود و هرگز روی ریشه‌ی Area2D؛ آن‌طور مکانِ برخورد/انتخاب و چیدمان
# کفه دقیق می‌ماند (تست‌های فاز ۲ هم به همین geometry تکیه می‌کنند).
# DRAW-CALL budget: یک _draw() ساده → رندر ارزان روی گوشی ارزان (`02` §۱).
# ===========================================================================

const TAG := "OrbVisual"

@export var radius: float = 44.0:
	set(v):
		radius = maxf(8.0, v)
		queue_redraw()
@export var fill_color: Color = Palette.SOFT_TEAL:
	set(v):
		fill_color = v
		queue_redraw()
@export var glyph: String = "":
	set(v):
		glyph = v
		queue_redraw()
@export var glyph_size: int = 30:
	set(v):
		glyph_size = maxi(8, v)
		queue_redraw()
## کره‌ی روح: «؟» نفس می‌کشد (§۶ سند هنری — محو و پررنگ می‌شود)
@export var pulsing: bool = false:
	set(v):
		pulsing = v
		set_process(v)
@export var highlight: float = 0.0:
	set(v):
		highlight = clampf(v, 0.0, 1.0)
		queue_redraw()

var _pulse_phase: float = 0.0


func _ready() -> void:
	set_process(pulsing)


func _process(delta: float) -> void:
	if not pulsing:
		return
	_pulse_phase = fmod(_pulse_phase + delta * 1.6, TAU)
	# به‌جای queue_redraw برای متن، شفافیت مودولات را تکان می‌دهیم (ارزان‌تر)
	modulate.a = 0.72 + 0.28 * (0.5 + 0.5 * sin(_pulse_phase))


func _draw() -> void:
	var center := Vector2.ZERO
	# بدنه: دایره‌ی پر + حلقه‌ی نورانی (flat vector + گرادیان نرم — §۱ سند هنری)
	draw_circle(center, radius, _body_color())
	draw_arc(center, radius, 0.0, TAU, 48, _edge_color(), 3.0)
	if radius > 20.0:
		# هایلایت: یک کمان روشن در ربع بالا-چپ، حس «کریستال»
		draw_arc(center + Vector2(-radius * 0.22, -radius * 0.24), radius * 0.52, PI * 0.95, PI * 1.85, 20,
			Color(1, 1, 1, 0.34 + 0.3 * highlight), 4.0)
	if not glyph.is_empty():
		var font: Font = Palette.ui_font()
		var text_size: Vector2 = font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, glyph_size)
		draw_string(font, center - Vector2(text_size.x * 0.5, -text_size.y * 0.34), glyph,
			HORIZONTAL_ALIGNMENT_CENTER, -1, glyph_size, _glyph_color())


func _body_color() -> Color:
	var c: Color = fill_color
	if c.a <= 0.02:  # رنگی که کسی alpha نداده → پررنگ در نظر گرفته می‌شود
		c.a = 1.0
	return c


func _edge_color() -> Color:
	return fill_color.lighten(0.30).lerp(Palette.CLOUD_WHITE, 0.25 + 0.35 * highlight)


func _glyph_color() -> Color:
	return Palette.text_on(fill_color)


## استفاده‌ی داخلی: WeightOrb رنگ را ست می‌کند و redraw می‌گیرد
func refresh(p_fill: Color, p_glyph: String, p_size: int, p_pulse: bool) -> void:
	fill_color = p_fill
	glyph = p_glyph
	glyph_size = p_size
	pulsing = p_pulse
	queue_redraw()
