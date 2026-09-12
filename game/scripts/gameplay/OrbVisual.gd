class_name OrbVisual
extends Node2D
# ===========================================================================
# OrbVisual — تنه‌ی بصری یک کره (بدون فیزیک؛ «قوانینِ §۶» در static‌های تست‌شدنی ✓)
# ---------------------------------------------------------------------------
# همه‌ی انیمیشن‌ها (lift هنگام درگ، محو/پررنگ «؟»، drift حباب) روی **این** نود
# اعمال می‌شود و هرگز روی ریشه‌ی Area2D؛ آن‌طور مکانِ برخورد/انتخاب و چیدمان
# کفه دقیق می‌ماند (تست‌های فاز ۲ هم به همین geometry تکیه می‌کنند).
# DRAW-CALL budget: یک `_draw()` ساده ⇒ رندر ارزان روی گوشی ارزان (`02` §۱) ✓ و از ۸.۵،
# سه **زبانِ هندسی** دارد (کریستال/حلقه‌ی نور/حبابِ باز ✓§۶) تا تمایزِ نوع در سیاه‌وسفید
# هم زنده بماند ✓ (`silhouette_signature()` همان عدد‌ها را می‌سنجد ✗✓ ADR-059).
# ===========================================================================

const TAG := "OrbVisual"

## سه نوع کره‌ی §۶ سند هنری ⇒ سه «زبانِ هندسی» ✗✓ (نه سه رنگ ✗: رنگ فقط *مقدار* را
## می‌گوید §۶، و سیلوئت باید با **فرم** خوانده شود تا در تستِ سیاه‌وسفید §۸ زنده بماند ✓)
enum Kind {
	## کره‌ی عدد ملموس: چندوجهیِ پر + پرتوهای داخلی (حسِ «شیءِ سخت» ✓§۶)
	NUMBER = 0,
	## کره‌ی روح: حلقه + دیسکِ نرمِ نیمه‌شفاف + دنباله‌ی نور (فریادِ «مجهول» ✓)
	GHOST = 1,
	## حباب ضد-وزن: پوسته‌ی باز در پایین + حبابکِ اقماری (حباب، نه کره ✓§۶)
	BUBBLE = 2,
}

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
@export var kind: Kind = Kind.NUMBER:
	set(v):
		kind = v
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
	var body_pts: PackedVector2Array = body_polygon(kind, radius)
	var alpha: float = body_alpha_for(kind, _body_color().a)
	if kind == Kind.BUBBLE:
		# پوسته‌ی حباب: دو کمان با دهانه‌ی پایین ✓ (حباب «باز» است؛ کرهٔ پر ✗§۶)
		var c: Color = _edge_color()
		c.a = clampf(0.55 + 0.4 * highlight, 0.0, 0.95)
		# دهانه در **پایین** (§۶ «حرکت روبه‌بالا» ⇒ حباب از بالا بسته و از پایین باز است ✓)
		# در مختصاتِ y-پایینِ Godot، «پایین» = زاویه‌ی +π/2 ✗✓ شروعِ اشتباه (= -π/2) دهانه
		# را به سقف می‌برد و span هم از ۲π رد می‌شد ⇒ یک دورِ کاملِ همپوش ✓✗ (این باگ در
		# هدلس دیده نمی‌شود ✗✓ پس span را صریح محاسبه می‌کنیم و تست عددش را می‌سنجد)
		var from_a: float = bubble_arc_start(kind)
		draw_arc(center, radius, from_a, from_a + bubble_arc_span(kind), 40, c, 3.0, true)
		if satellite_ratio(kind) > 0.0:
			var sat := Vector2(radius * 0.86, -radius * 0.72)
			draw_circle(sat, radius * 0.16, Color(c.r, c.g, c.b, c.a * 0.7))
	elif kind == Kind.GHOST:
		# حلقه‌ی محو + دیسکِ نرم: «چیزی که هنوز معلوم نیست» ✓
		var gc: Color = _body_color()
		gc.a = alpha * 0.55
		draw_colored_polygon(body_pts, gc)
		var rc: Color = _edge_color()
		rc.a = alpha
		draw_arc(center, radius, 0.0, TAU, 40, rc, 3.5, true)
		for i: int in wisp_count_for(kind):
			var off: float = float(i - 1) * radius * 0.42
			var wc: Color = rc
			wc.a = alpha * 0.45
			draw_arc(Vector2(off, radius * 1.02), radius * 0.24, PI * 0.15, PI * 0.85, 12, wc,
				2.0, true)
	else:
		# عدد ملموس: چندوجهیِ پر + پرتوها (رگه‌های شکستِ نورِ کریستال ✓)
		var fc: Color = _body_color()
		fc.a = alpha
		draw_colored_polygon(body_pts, fc)
		var oc: Color = _edge_color()
		oc.a = clampf(alpha + 0.12, 0.0, 1.0)
		var closed := body_pts.duplicate()
		closed.append(body_pts[0])
		draw_polyline(closed, oc, 3.0, true)
		var n: int = body_pts.size()
		for i: int in facet_spokes_for(kind):
			var p: Vector2 = body_pts[(i * 2) % n] * 0.92
			var sc: Color = oc
			sc.a = alpha * 0.30
			draw_line(Vector2.ZERO, p, sc, 1.5, true)
	if radius > 20.0:
		# هایلایت: یک کمان روشن در ربع بالا-چپ، حس «کریستال»
		draw_arc(center + Vector2(-radius * 0.22, -radius * 0.24), radius * 0.52, PI * 0.95, PI * 1.85, 20,
			Color(1, 1, 1, highlight_alpha_for(kind, highlight)), 4.0, true)
	if not glyph.is_empty():
		# §۶ «عدد ملموس» + §۷ «Bold برای تأکید» ⇒ عددِ روی کفه/کره با وزنِ Bold ✓✓
		# (متنِ بدنه از تم، Medium است ✓ — دو مصرف، دو وزن، یک خانواده ✓)
		var font: Font = Palette.ui_font_bold()
		var text_size: Vector2 = font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, glyph_size)
		draw_string(font, center - Vector2(text_size.x * 0.5, -text_size.y * 0.34), glyph,
			HORIZONTAL_ALIGNMENT_CENTER, -1, glyph_size, _glyph_color())


# --------------------------------------------------------------------------
# هندسه‌ی هر نوع — توابعِ خالص و تست‌شدنی ✓ (ADR-058: `_draw` لوله‌کشی است)
# --------------------------------------------------------------------------
## چندضلعیِ بدنه ✓ حباب/روح «دیسکِ نرم» دارند و عدد «چهارده‌وجهیِ کریستال» ✓§۶
static func body_polygon(k: Kind, r: float) -> PackedVector2Array:
	var n: int = facets_for(k)
	var pts := PackedVector2Array()
	var rot: float = PI / float(n) if k == Kind.NUMBER else 0.0
	for i: int in n:
		var a: float = TAU * float(i) / float(n) + rot
		var rr: float = r if k == Kind.NUMBER else r * 0.9  # دیسکِ نرمِ روح ✗ پر نیست ✓
		pts.append(Vector2(cos(a), sin(a)) * rr)
	return pts


## اضلاعِ بدنه: کریستالِ ۱۲وجهی برای «ملموس»، دیسکِ ۲۴وجهی برای «نورِ نرم» ✓
static func facets_for(k: Kind) -> int:
	match k:
		Kind.NUMBER:
			return 12
		Kind.GHOST:
			return 24
		_:
			return 0  # حباب: بدنه‌ی بسته نداریم ⇒ دهانه‌دار ✓§۶


static func facet_spokes_for(k: Kind) -> int:
	return 6 if k == Kind.NUMBER else 0


static func wisp_count_for(k: Kind) -> int:
	return 3 if k == Kind.GHOST else 0


## دهانه‌ی پایینِ حباب (درجه) ✓ «باز بودن» را حتی در سیاه‌وسفید خوانا می‌کند ✓§۸
static func gap_degrees_for(k: Kind) -> float:
	return 46.0 if k == Kind.BUBBLE else 0.0


## طولِ کمانِ بدنهٔ حباب (رادیان) ✓ از `gap` می‌آید؛ اگر کسی span را دستی بسازد،
## دهانه گم می‌شود و حباب «کره» می‌شود ✗✓ (همین، باگِ نسخهٔ اولِ ۸.۵ بود)
static func bubble_arc_span(k: Kind) -> float:
	return TAU - deg_to_rad(gap_degrees_for(k)) if k == Kind.BUBBLE else TAU


## زاویه‌ی شروعِ کمانِ حباب ✓ (π/2 = پایینِ صفحه در Godot؛ دهانه باید آن‌جا باشد §۶)
static func bubble_arc_start(k: Kind) -> float:
	return PI * 0.5 + deg_to_rad(gap_degrees_for(k)) * 0.5 if k == Kind.BUBBLE else 0.0


## نسبتِ شعاعِ حبابکِ اقماری ✓ (حرکتِ روبه‌بالا را «رهایش» یادآوری می‌کند §۶)
static func satellite_ratio(k: Kind) -> float:
	return 0.22 if k == Kind.BUBBLE else 0.0


## آلفای بدنه: §۶ می‌گوید روح «نیمه‌شفاف» و حباب «شفاف» است ⇒ هرگزِ ۱٫۰ ✗✓
static func body_alpha_for(k: Kind, base: float) -> float:
	match k:
		Kind.NUMBER:
			return clampf(base, 0.55, 0.95)
		Kind.GHOST:
			return clampf(minf(base, 0.62), 0.25, 0.62)
		_:
			return clampf(minf(base, 0.22), 0.06, 0.22)


static func highlight_alpha_for(k: Kind, hl: float) -> float:
	# حباب «نورِ کم‌سو» دارد ✗ روی کریستال هایلایتِ پررنگ‌تر خوانا‌تر است ✓
	var base: float = 0.34 if k == Kind.NUMBER else 0.24
	return clampf(base + 0.3 * hl, 0.0, 0.72)


## نسبتِ مساحتِ بدنه به دایعه ✓ معیارِ «پر یا خالی» در ممیزیِ سیلوئت ✓§۸
func coverage_ratio() -> float:
	var pts: PackedVector2Array = body_polygon(kind, radius)
	if pts.size() < 3 or radius <= 0.0:
		return 0.0
	var area := 0.0
	for i: int in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		area += a.x * b.y - b.x * a.y
	return absf(area) * 0.5 / (PI * radius * radius)


## امضایِ سیلوئت ✓ «هر سه نوع از فاصلهٔ بازی قابل‌تمایزند» (DoD ۸.۵) را با عدد
## می‌سنجد، نه با چشم ✗✓ (CI هدلس `_draw()` را اجرا نمی‌کند ⇒ هندسه را مقایسه می‌کنیم ✓)
func silhouette_signature() -> Dictionary:
	return {
		"kind": int(kind),
		"coverage": snappedf(coverage_ratio(), 0.001),
		"facets": facets_for(kind),
		"spokes": facet_spokes_for(kind),
		"wisps": wisp_count_for(kind),
		"gap_deg": gap_degrees_for(kind),
		"satellite": satellite_ratio(kind),
		"arc_span": snappedf(bubble_arc_span(kind), 0.001),
		"arc_start": snappedf(bubble_arc_start(kind), 0.001),
		"body_alpha": snappedf(body_alpha_for(kind, fill_color.a), 0.001),
		"highlight_alpha": snappedf(highlight_alpha_for(kind, highlight), 0.001),
		"glyph_empty": glyph.is_empty(),
	}


## فاصلهٔ دو سیلوئت = تعدادِ ویژگی‌های متمایز ✓ (≥۳ یعنی «یک‌نگاه» کافی است ✗✓
## نه «دقت کن تا فرقش را ببینی» — همان چیزی که DoD ۸.۵ خواسته ✓)
static func signature_distance(a: Dictionary, b: Dictionary) -> int:
	var keys: Array = ["coverage", "facets", "spokes", "wisps", "gap_deg", "satellite",
		"body_alpha", "arc_span", "arc_start"]
	var diff := 0
	for k: String in keys:
		if absf(float(a.get(k, 0.0)) - float(b.get(k, 0.0))) > 0.001:
			diff += 1
	return diff


func _body_color() -> Color:
	var c: Color = fill_color
	if c.a <= 0.02:  # رنگی که کسی alpha نداده → پررنگ در نظر گرفته می‌شود
		c.a = 1.0
	return c


func _edge_color() -> Color:
	return fill_color.lightened(0.30).lerp(Palette.CLOUD_WHITE, 0.25 + 0.35 * highlight)


func _glyph_color() -> Color:
	return Palette.text_on(fill_color)


## استفاده‌ی داخلی: WeightOrb رنگ را ست می‌کند و redraw می‌گیرد
func refresh(p_fill: Color, p_glyph: String, p_size: int, p_pulse: bool) -> void:
	fill_color = p_fill
	glyph = p_glyph
	glyph_size = p_size
	pulsing = p_pulse
	queue_redraw()
