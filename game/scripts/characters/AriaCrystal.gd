class_name AriaCrystal
extends Node2D
# ===========================================================================
# تسک ۵.۴ — بدنه‌ی Aria (placeholder): چندوجهی نورانی، بدون صورت
# --------------------------------------------------------------------------
# Art Bible §۳: Aria یک موجود هندسی است، نه آدم/حیوان؛ بدن همیشه طلایی می‌ماند و
# فقط «هسته» رنگ عوض می‌کند. پس اینجا عمداً هیچ رنگی هاردکد نشده: رنگ از
# `self_modulate` می‌آید و AnimationPlayer همان را animate می‌کند (تسک ۵.۴).
# فاز ۸ این دو نود را با SVG/Atlas واقعی عوض می‌کند و کد دست‌نخورده می‌ماند.
# ===========================================================================

## لبه‌های پلی‌هیدرون (Art Bible: ایکوساهدرون؛ placeholder با پریزما کافی است)
@export var facets: int = 6
@export var radius: float = 34.0
@export var edge_alpha: float = 0.55


func _draw() -> void:
	var n: int = maxi(3, facets)
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(n):
		var a: float = TAU * float(i) / float(n) - PI / 2.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	# بدنه: یک پلیگان نیمه‌شفاف (گرادیان §۳ در فاز ۸ با shader/SVG می‌آید)
	draw_colored_polygon(pts, Color(1.0, 1.0, 1.0, 0.80))
	# خطوط نور داخلی («رگه‌ها») — تنها راهِ بیانِ حالت، چون صورتی در کار نیست
	var closed: PackedVector2Array = pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Color(1.0, 1.0, 1.0, 1.0), 2.0)
	for i: int in range(n):
		draw_line(Vector2.ZERO, pts[i], Color(1.0, 1.0, 1.0, edge_alpha), 1.5)
