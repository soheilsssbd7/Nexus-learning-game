extends Node2D
# ===========================================================================
# NEXUS — AriaCrystal: بدنه‌ی Aria (§۳ Art Bible | تسک ۵.۴ placeholder → ۸.۱ نهایی)
# --------------------------------------------------------------------------
# §۳: «ایکوساهدرون (بیست‌وجهی) نیمه‌شفاف به قطر تقریبی ۴۰ تا ۶۰ پیکسل» + «گرادیان از
# طلایی در مرکز به سفید در لبه‌ها با شفافیت ۷۰-۸۵٪» + «بدون صورت؛ به‌جای چشم/دهان،
# الگوی خطوط نور داخلِ چندوجهی شکل و سرعتش با حالت عوض می‌شود» ✓✓
#
# چرا بردارِ محاسباتی در `_draw()` و نه PNG/SVG؟
#  ۱) §۱: «رندر ارزان روی گوشی‌های ضعیف» ⇒ یک چندوجهیِ ۲۰ وجهی با ۲۰ `draw_polygon`
#     ارزان‌ترین راهِ ممکن است ✓ (و ۶۰fps روی §۹ گوشیِ ارزان را قمار نمی‌کنیم ✗);
#  ۲) انیمیشنِ «چرخش + رگه‌ها» فریم‌به‌فریم یعنی ۶ حالت × چند ده فریم باینری ✗
#     درحالی‌که §۱ «2D rigging به‌جای فریم‌به‌فریم» را ترجیح می‌دهد ✓✓ و این همان کار است;
#  ۳) بردار یعنی در هر چگالیِ صفحه تیز می‌ماند (موبایل‌های ۱۰۸۰..۱۴۴۰ ✗✓ بدونِ mipmapping).
# توپولوژی هم **محاسبه** می‌شود نه از روی جدولِ ایندکس ✗✓ (جدولِ دستیِ ۲۰ وجهی، یک
# عددِ اشتباه‌اش «چهار وجهیِ کج» است که در کد هیچ‌وقت قرمز نمی‌شود ✗؛ اینجا `face_count()`
# در تست به ۲۰ قفل است و اگر محاسبه بلغزد، CI می‌شکند ✓✓).
# ===========================================================================

const PHI: float = 1.6180339887498949

## §۳: قطر ۴۰..۶۰ ⇒ شعاع ۲۰..۳۰ (پیش‌فرض ۲۶ = ۵۲px ✓)
@export var radius: float = 26.0:
	set(v):
		radius = clampf(v, 12.0, 64.0)
		queue_redraw()
## سرعت چرخش بدنه (idle ≈ ۰٫۳ ✓ §۳ «چرخش کند»)
@export var spin_rate: float = 0.30:
	set(v):
		spin_rate = maxf(0.0, v)
@export var edge_alpha: float = 0.55
## «رگه‌های انرژی» (§۳): سرعت/روشنایی/رنگِ این سه عدد، تنها راهِ بیانِ حالت است ✗✓
@export var streak_rate: float = 0.35
@export var streak_alpha: float = 0.55
@export var streak_count: int = 5
## رنگِ رگه‌ها؛ `celebrating` روی Soft Teal می‌نشیند (§۳ «ترکیب Gold + Teal» ⇒ بدنه
## طلایی می‌ماند وTeal را رگه‌ها حمل می‌کنند ✗✓ نه یک رنگِ سومِ اختراعی ✓)
@export var streak_tint: Color = Color(1.0, 1.0, 1.0)
## §۳: شفافیت ۷۰..۸۵٪
@export var alpha_min: float = 0.70
@export var alpha_max: float = 0.85

var _t: float = 0.0
var _pulse_dir: Vector2 = Vector2.RIGHT
var _pulse: float = 0.0


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return  # §۱ «رندر ارزان»: آریای خارجِ دید هیچ frame مصرفی نمی‌گیرد ✓
	_t += delta
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 2.6)
	if radius > 0.0:
		queue_redraw()


func diameter_px() -> float:
	return radius * 2.0


## سطحِ پالسِ جاری (۱ → ۰) ✓ بدونِ این عدد، تستِ ۸.۱ نمی‌تواند ببیند پالسِ
## `hint_light` **واقعا** شلیک شده یا نه ✗✓ (و `_draw` در هدلس اجرا نمی‌شود)
func pulse_level() -> float:
	return _pulse


func pulse_direction() -> Vector2:
	return _pulse_dir


## §۳ «یک پالس نور مختصر به‌سمت بخش مرتبط از ترازو» ✓ هدف را کسی ست می‌کند که
## صحنه را می‌شناسد (آواتار/LevelScene)، نه این نود ⇒ جداسازیِ مسئولیت ✓
func pulse_toward(direction: Vector2 = Vector2.RIGHT) -> void:
	_pulse_dir = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	_pulse = 1.0
	queue_redraw()


## حالت‌ها از اینجا رد می‌شوند؛ تنها نقطهٔ «حسّ بصریِ هر حالت» ✓ (تستِ ۸.۱ همین‌ها را می‌سنجد)
func set_mood(p_spin: float, p_streak_rate: float, p_streak_alpha: float, p_tint: Color) -> void:
	spin_rate = p_spin
	streak_rate = p_streak_rate
	streak_alpha = p_streak_alpha
	streak_tint = p_tint
	queue_redraw()


# --------------------------------------------------------------------------
# توپولوژی ایکوساهدرون — از رویِ متریک، نه جدولِ دستی ✓✓
# --------------------------------------------------------------------------
static func icosahedron_vertices() -> PackedVector3Array:
	var v := PackedVector3Array()
	for s1: int in [-1, 1]:
		for s2: int in [-1, 1]:
			v.append(Vector3(0.0, s1 * 1.0, s2 * PHI))
			v.append(Vector3(s1 * 1.0, s2 * PHI, 0.0))
			v.append(Vector3(s2 * PHI, 0.0, s1 * 1.0))
	var norm := v[0].length()
	for i: int in v.size():
		v[i] = v[i] / norm
	return v


static func _min_edge(v: PackedVector3Array) -> float:
	var best := INF
	for i: int in v.size():
		for j: int in range(i + 1, v.size()):
			best = minf(best, v[i].distance_to(v[j]))
	return best


static func icosahedron_faces(v: PackedVector3Array = PackedVector3Array()) -> PackedInt32Array:
	if v.is_empty():
		v = icosahedron_vertices()
	# وجه = سه رأسی که **هر سه یالِشان** به طولِ کمینه است ✓ (۲۰ تا، و هر وجه مثلث ✓)
	var e: float = _min_edge(v) * 1.0001
	var out := PackedInt32Array()
	for i: int in v.size():
		for j: int in range(i + 1, v.size()):
			if v[i].distance_to(v[j]) > e:
				continue
			for k: int in range(j + 1, v.size()):
				if v[i].distance_to(v[k]) <= e and v[j].distance_to(v[k]) <= e:
					out.append(i)
					out.append(j)
					out.append(k)
	return out


static func icosahedron_edges(v: PackedVector3Array = PackedVector3Array()) -> PackedInt32Array:
	if v.is_empty():
		v = icosahedron_vertices()
	var e: float = _min_edge(v) * 1.0001
	var out := PackedInt32Array()
	for i: int in v.size():
		for j: int in range(i + 1, v.size()):
			if v[i].distance_to(v[j]) <= e:
				out.append(i)
				out.append(j)
	return out


static func face_count() -> int:
	return icosahedron_faces().size() / 3


static func vertex_count() -> int:
	return icosahedron_vertices().size()


static func edge_count() -> int:
	return icosahedron_edges().size() / 2


# --------------------------------------------------------------------------
func _draw() -> void:
	var verts: PackedVector3Array = icosahedron_vertices()
	var faces: PackedInt32Array = icosahedron_faces(verts)
	var spin := _t * spin_rate
	var rot := Basis(Vector3.UP, spin) * Basis(Vector3.RIGHT, spin * 0.37 + 0.42)
	var pts: PackedVector2Array = PackedVector2Array()
	var depth: PackedFloat32Array = PackedFloat32Array()
	pts.resize(verts.size())
	depth.resize(verts.size())
	for i: int in verts.size():
		var p: Vector3 = rot.xform(verts[i])
		pts[i] = Vector2(p.x, p.y) * radius
		depth[i] = p.z
	# نقاشی از عقب به جلو ✓ (painter's algorithm: بی‌‌نیاز از depth-buffer در CanvasItem ✓)
	var order: Array[int] = []
	for f: int in range(faces.size() / 3):
		order.append(f)
	order.sort_custom(func(a: int, b: int) -> bool:
		return _face_depth(faces, depth, a) < _face_depth(faces, depth, b))
	for f: int in order:
		var tri := PackedVector2Array()
		var centroid := Vector2.ZERO
		for c: int in 3:
			var idx: int = faces[f * 3 + c]
			tri.append(pts[idx])
			centroid += pts[idx] / 3.0
		# §۳: طلایی در مرکز → سفید در لبه‌ها ⇒ نسبتِ فاصلهٔ ثقلِ وجه از مرکز ✓
		var edge_mix: float = clampf(centroid.length() / maxf(radius, 1.0), 0.0, 1.0)
		var front: float = clampf(_face_depth(faces, depth, f) * 0.5 + 0.5, 0.0, 1.0)
		draw_colored_polygon(tri, face_fill_color(edge_mix, front, alpha_min, alpha_max))
		var ring := tri.duplicate()
		ring.append(tri[0])
		var ec: Color = Palette.CLOUD_WHITE.lerp(Palette.AELORIA_GOLD, 0.35)
		ec.a = edge_line_alpha(front, edge_alpha)
		draw_polyline(ring, ec, 1.0, true)
	_draw_streaks()
	if _pulse > 0.001:
		# پالسِ جهت‌دارِ `hint_light` ✓ (§۳: «به‌سمت بخشِ مرتبط از ترازو»)
		var to: Vector2 = _pulse_dir * radius * (1.0 + _pulse * 0.9)
		var flash: Color = Palette.CLOUD_WHITE
		flash.a = pulse_streak_alpha(_pulse)
		draw_line(_pulse_dir * radius * 0.2, to, flash, 3.0, true)
		var ring_c: Color = streak_tint
		ring_c.a = pulse_ring_alpha(_pulse)
		var center := to.normalized() * radius * 0.96
		if radius > 4.0:
			draw_arc(center, radius * 0.30 * _pulse, 0.0, TAU, 20, ring_c, 2.0, true)


static func _face_depth(faces: PackedInt32Array, depth: PackedFloat32Array, f: int) -> float:
	var s := 0.0
	for c: int in 3:
		s += depth[faces[f * 3 + c]]
	return s / 3.0


func _draw_streaks() -> void:
	# رگه‌ها: وتر‌هایی که روی بدنه می‌لغزند؛ «شکل و سرعت»شان با حالت عوض می‌شود ✓§۳
	var n: int = maxi(2, streak_count)
	for i: int in n:
		var ph: float = _t * streak_rate + float(i) * PI / float(n)
		var a0: float = ph
		var a1: float = ph + PI * 0.78
		var p0 := Vector2(cos(a0), sin(a0)) * radius * 0.88
		var p1 := Vector2(cos(a1), sin(a1)) * radius * 0.62
		var mid := (p0 + p1) * 0.5 + Vector2(-p1.y, p1.x) * 0.18
		var c2: Color = streak_tint
		c2.a = streak_alpha_for(i, n, _t, streak_rate, streak_alpha)
		var curve := PackedVector2Array([p0, mid.lerp(Vector2.ZERO, 0.35), p1])
		draw_polyline(curve, c2, 1.6, true)


# --------------------------------------------------------------------------
# قوانینِ §۳ به‌شکلِ توابعِ خالص ✓ ( `_draw` فقط لوله‌کشی است: در هدلس اجرا نمی‌شود ✗✓
# پس آنچه سنجیدنی است اینجا زندگی می‌کند، نه داخلِ فراخوانی‌های ترسیم.)
# --------------------------------------------------------------------------
## گرادیان «طلایی در مرکز → سفید در لبه» + شفافیت ۷۰..۸۵٪ (§۳) ✓
static func face_fill_color(edge_mix: float, front: float,
		a_min: float = 0.70, a_max: float = 0.85) -> Color:
	var col: Color = Palette.AELORIA_GOLD.lerp(Palette.CLOUD_WHITE, clampf(edge_mix, 0.0, 1.0))
	col.a = clampf(lerpf(a_min, a_max, clampf(front, 0.0, 1.0)), 0.0, 1.0)
	return col


## لبه‌های جلو پررنگ‌تر ⇒ «نور جامد» خوانده می‌شود ✓ (و هرگز از ۰٫۹۵ بالاتر نمی‌رود:
## لبه‌ی ممتدِ پرنور، چندوجهی را به یک دوناتِ پرنور تبدیل می‌کند ✗)
static func edge_line_alpha(front: float, base: float) -> float:
	return clampf(base * (0.45 + 0.55 * clampf(front, 0.0, 1.0)), 0.0, 0.95)


## نوسانِ رگه‌ها: دامنه‌اش از ۰٫۱ کمتر نمی‌رود ✗✓ «خاموش‌شدنِ کامل» یعنی آریا بی‌حالت ✓
static func streak_alpha_for(i: int, n: int, t: float, rate: float, base: float) -> float:
	# فازِ هر رگه از `n` می‌آید ✓ (توزیعِ یکنواخت؛ وگرنه رگه‌ها دسته می‌شوند و یکی‌دو
	# همیشه خاموش‌اند ✗✓ چیزی که روی اسپیکر/اسکرین‌شاتِ موبایل زشت به‌نظر می‌رسد)
	var spread: float = TAU * float(i) / maxf(float(n), 1.0)
	return clampf(base * (0.55 + 0.45 * sin(t * maxf(rate, 0.0) * 2.1 + spread)),
		maxf(base * 0.12, 0.0), 1.0)


static func pulse_streak_alpha(p: float) -> float:
	return clampf(0.35 + 0.5 * p, 0.0, 1.0)


static func pulse_ring_alpha(p: float) -> float:
	return clampf(0.30 + 0.55 * p, 0.0, 1.0)
