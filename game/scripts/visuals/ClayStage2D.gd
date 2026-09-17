class_name ClayStage2D
extends Node2D
# ===========================================================================
# NEXUS — ClayStage2D
# ---------------------------------------------------------------------------
# لایه‌ی بصریِ «خمیریِ سه‌نما» برای گیم‌پلی. منطقِ ترازو همچنان دوبعدی و قطعی
# می‌ماند، اما این stage با سایه‌ی تماس، هایلایت، عمقِ لایه‌ها و جزیره‌های نرم
# همان خوانشِ سه‌بعدیِ سبکِ بازی‌های مدرن را می‌سازد؛ بدون texture بزرگ یا شبکه.
# این تصمیم با راهنمای game-dev-skills هم‌راستاست: قاب/پالت/سیلوئت اول قفل شده،
# دارایی‌ها خانواده‌ای هستند، و خروجی در اندازه‌ی واقعیِ بازی سنجیده می‌شود.
# ===========================================================================

const DEFAULT_CANVAS := Vector2(1080.0, 1920.0)
const MAX_ALPHA := 0.46

@export var region: RegionBackdrop.Region = RegionBackdrop.Region.MEADOW
@export_range(0.0, 1.0, 0.01) var restoration: float = 0.0:
	set(value):
		restoration = clampf(value, 0.0, 1.0)
		queue_redraw()
@export var canvas_size: Vector2 = DEFAULT_CANVAS
@export var animate: bool = true
@export var motion_speed: float = 0.22

var _time: float = 0.0


func _ready() -> void:
	z_index = -15
	set_process(animate)
	queue_redraw()


func _process(delta: float) -> void:
	if not animate or not is_visible_in_tree():
		return
	_time = fmod(_time + delta * motion_speed, TAU)
	queue_redraw()


func set_world(p_region: RegionBackdrop.Region, progress: float) -> void:
	region = p_region
	restoration = progress
	queue_redraw()


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, canvas_size)
	_draw_sky(box)
	_draw_clouds(box)
	_draw_far_islands(box)
	_draw_main_island(box)
	_draw_repair_bridges(box)
	_draw_clay_garden(box)


func _draw_sky(box: Rect2) -> void:
	var colors: PackedColorArray = RegionBackdrop.sky_gradient(region)
	var stations: int = 12
	for i: int in stations:
		var t: float = float(i) / float(stations - 1)
		var c: Color = colors[min(int(float(i) * float(colors.size()) / float(stations)), colors.size() - 1)]
		c = c.lerp(RegionBackdrop.light_color(region), t * 0.22)
		c.a = 1.0
		draw_rect(Rect2(box.position.x, box.position.y + box.size.y * t,
			box.size.x, box.size.y / float(stations) + 2.0), c, true)
	# نورِ نرمِ پشتِ صحنه؛ در مرزِ آلفای محیط می‌ماند تا عددها و متن همیشه جلو باشند.
	_draw_ellipse(Vector2(720.0, 430.0), Vector2(420.0, 250.0),
		Color(Palette.CLOUD_WHITE, 0.07 + restoration * 0.08))
	_draw_ellipse(Vector2(120.0, 980.0), Vector2(360.0, 170.0),
		Color(Palette.GHOST_VIOLET, 0.04 + RegionBackdrop.brokenness(region, restoration) * 0.06))


func _draw_clouds(box: Rect2) -> void:
	var cloud_color := Color(Palette.CLOUD_WHITE, 0.075)
	for i: int in 4:
		var x: float = box.size.x * (0.10 + 0.29 * float(i))
		var y: float = 260.0 + 54.0 * sin(float(i) * 1.7 + _time * 0.4)
		_draw_ellipse(Vector2(x, y), Vector2(130.0 + 24.0 * float(i % 2), 28.0), cloud_color)
		_draw_ellipse(Vector2(x + 80.0, y + 8.0), Vector2(96.0, 22.0), cloud_color)


func _draw_far_islands(_box: Rect2) -> void:
	var broken: float = RegionBackdrop.brokenness(region, restoration)
	var light: Color = RegionBackdrop.light_color(region)
	for i: int in 3:
		var center := Vector2(230.0 + float(i) * 330.0,
			850.0 + float(i % 2) * 120.0 + sin(_time + float(i)) * 10.0)
		var size := Vector2(210.0 + 44.0 * float(i), 76.0 + 18.0 * float(i))
		var c := light.lerp(Palette.STONE_GREY, 0.44 + broken * 0.20)
		c.a = 0.18
		_draw_clay_island(center, size, c, 2.0 + float(i), 0.72)
	# خطوط راهنما: نور از جزیره‌ی دور به فضای حل می‌رسد.
	for i: int in 4:
		var x := 132.0 + float(i) * 274.0
		var c := Color(Palette.AELORIA_GOLD, 0.08 + restoration * 0.08)
		draw_line(Vector2(x, 1010.0), Vector2(x + 90.0, 1130.0), c, 5.0, true)


func _draw_main_island(_box: Rect2) -> void:
	var base := RegionBackdrop.light_color(region)
	base = base.lerp(Palette.CLOUD_WHITE, 0.10)
	_draw_clay_island(Vector2(540.0, 1220.0), Vector2(820.0, 250.0), base, 0.8, 1.0)
	# لبه‌ی خمیریِ دوم، مثل لایه‌ی سفال زیرِ سطح.
	var underside := base.darkened(0.18)
	_draw_clay_island(Vector2(540.0, 1292.0), Vector2(650.0, 114.0), underside, 3.8, 0.58)
	_draw_ellipse(Vector2(540.0, 1400.0), Vector2(380.0, 66.0), Color(0.0, 0.0, 0.0, 0.16))


func _draw_repair_bridges(_box: Rect2) -> void:
	var total: int = RegionBackdrop.bridge_total(region)
	var built: int = RegionBackdrop.bridges_built(region, restoration)
	for i: int in total:
		var t: float = float(i) / maxf(float(total - 1), 1.0)
		var at := Vector2(176.0 + t * 720.0, 1132.0 - absf(t - 0.5) * 80.0)
		var is_built: bool = i < built
		var body := Palette.AELORIA_GOLD if is_built else Palette.STONE_GREY
		var alpha := 0.62 if is_built else 0.18
		_draw_ellipse(at + Vector2(0.0, 18.0), Vector2(84.0, 12.0), Color(0.0, 0.0, 0.0, 0.14))
		draw_line(at - Vector2(72.0, 0.0), at + Vector2(72.0, 0.0), Color(body, alpha), 22.0, true)
		draw_line(at - Vector2(64.0, -5.0), at + Vector2(64.0, -5.0), Color(Palette.CLOUD_WHITE, alpha * 0.65), 4.0, true)


func _draw_clay_garden(_box: Rect2) -> void:
	var density: int = mini(RegionBackdrop.prop_density(region), 9)
	var light := RegionBackdrop.light_color(region)
	for i: int in density:
		var x: float = 98.0 + fmod(float(i) * 163.0, 884.0)
		var y: float = 1140.0 + fmod(float(i) * 47.0, 92.0)
		var h: float = 32.0 + fmod(float(i) * 17.0, 34.0)
		var c := light.lerp(Palette.SOFT_TEAL, 0.32 + 0.08 * float(i % 3))
		_draw_ellipse(Vector2(x, y + 8.0), Vector2(25.0, 8.0), Color(0.0, 0.0, 0.0, 0.10))
		_draw_clay_blob(Vector2(x, y - h * 0.25), Vector2(22.0, h), c, float(i) * 0.81, 0.14)
		_draw_ellipse(Vector2(x - 7.0, y - h * 0.55), Vector2(6.0, h * 0.18), Color(Palette.CLOUD_WHITE, 0.22))


func _draw_clay_island(center: Vector2, size: Vector2, color: Color, seed: float, lift: float) -> void:
	_draw_ellipse(center + Vector2(0.0, size.y * 0.34), size * Vector2(1.03, 0.28), Color(0.0, 0.0, 0.0, 0.18))
	var lower := color.darkened(0.14)
	_draw_clay_blob(center + Vector2(0.0, size.y * 0.13), size * Vector2(0.98, 0.83), lower, seed + 1.2, 0.16)
	_draw_clay_blob(center - Vector2(0.0, size.y * 0.08), size, color, seed, 0.12)
	_draw_ellipse(center - size * Vector2(0.24, 0.23), size * Vector2(0.34, 0.16),
		Color(Palette.CLOUD_WHITE, 0.10 + lift * 0.10))


func _draw_clay_blob(center: Vector2, size: Vector2, color: Color, seed: float, wobble: float) -> void:
	var points := PackedVector2Array()
	var count: int = 18
	for i: int in count:
		var angle: float = TAU * float(i) / float(count)
		var wave: float = 1.0 + wobble * sin(angle * 3.0 + seed) + wobble * 0.45 * cos(angle * 5.0 - seed)
		points.append(center + Vector2(cos(angle) * size.x, sin(angle) * size.y) * wave)
	draw_colored_polygon(points, color)
	var edge := color.darkened(0.16)
	points.append(points[0])
	draw_polyline(points, Color(edge, minf(0.42, color.a + 0.22)), 4.0, true)


func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	if radius.x <= 0.0 or radius.y <= 0.0:
		return
	draw_set_transform(center, 0.0, radius)
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
