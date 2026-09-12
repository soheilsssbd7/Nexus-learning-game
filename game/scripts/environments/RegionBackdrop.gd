class_name RegionBackdrop
extends Node2D
# ===========================================================================
# NEXUS — RegionBackdrop: شش منطقۀ Aeloria با «بازیابی» (§۵ سند هنری | تسک ۸.۳)
# --------------------------------------------------------------------------
# §۵ یک جدول می‌دهد (منطقه · Tier · مفهوم بصری · نور غالب) و یک **قانونِ کلیدی**:
#   «میزان ویرانی/شکستگیِ ساختارهای هر منطقه باید مستقیماً با پیشرفت بازیکن در همان
#    Tier کاهش یابد — یعنی پل‌ها ساخته شوند» ✓✗ پس این نود فقط دو ورودی دارد:
#   `region` و `restoration` (۰=ویران … ۱=بازسازی) و همه‌چیز از همان دو عدد درمی‌آید ✓
#
# چرا بردارِ محاسباتی و نه PNG/Terrain؟ همان استدلالِ ADR-058 (کاراکترها): §۱ «Flat
# Vector + Soft Gradient» + «رندر ارزان روی گوشی ضعیف» ✓؛ محیط **پشتِ سرِ گیم‌پلی** است
# ⇒ نباید از کره‌ها/ترازو مهم‌تر شود (سقفِ آلفا در `LAYER_ALPHA_MAX` قفل است ✓)؛ و شش
# منطقه × چند حالت = ۱۲+ تصویر ⇒ فایل‌گرا یعنی ده‌ها باینری در APK ✗✗ اینجا صفر بایت ✓
# و «۲ حالت برای هر منطقه» (DoD ۸.۳) یک **تابع** است، نه دو فایلِ جدا ✗✓.
#
# قاعدهٔ ADR-058 رعایت شده: هیچ منطقی داخل `_draw()` نیست ✗✓ (هدلس `_draw` را اجرا
# نمی‌کند ⇒ همه‌چیز staticهای خالص‌اند و تست همان‌ها را می‌سنجد ✓✓).
# ===========================================================================

const TAG := "RegionBackdrop"

## هفت رنگِ پالت (§۲) ⇒ تنها «مادهٔ اولیهٔ» هنر؛ جدول‌های پایین فقط این‌ها را
## روشن/تیره یا با هم قاطی می‌کنند ✗✓ پس §۸ («فقط پالت رسمی») یک **ساختار** است ✓
const BASES: Array[Color] = [
	Palette.AELORIA_GOLD, Palette.SOFT_TEAL, Palette.DEEP_INDIGO, Palette.GHOST_VIOLET,
	Palette.WARM_CORAL, Palette.CLOUD_WHITE, Palette.STONE_GREY,
]

## §۵ «نور غالب» هر منطقه: [پایه، میزانِ روشن/تیره (منفی=تیره)، پایهٔ دوم برای قاطی، t] ✓
const LIGHT_BASE: Array[int] = [0, 0, 2, 3, 1, 0]
const LIGHT_ADJ: Array[float] = [-0.10, 0.20, 0.34, 0.16, 0.12, 0.0]
const LIGHT_MIX: Array[int] = [-1, -1, -1, -1, -1, 5]
const LIGHT_MIX_T: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.30]

## ویرانیِ پایه: هر منطقه چقدر شکسته شروع می‌شود ✓§۵ (Hub «نیمه‌ویران» است، قله کمتر ✗✓)
const RUIN_BASE: Array[float] = [0.78, 0.34, 0.58, 0.86, 0.62, 0.22]
## چند پل/اتصال باید ساخته شود (Hub بیشترین ⇒ «پل‌های نورانی که دوباره ساخته می‌شوند») ✓§۵
const BRIDGE_TOTAL: Array[int] = [5, 2, 3, 4, 2, 3]
## چگالیِ عنصر محیطی (بوتهٔ کریستالی / بلور / سایهٔ محو / ستون) ⇒ زبانِ هر منطقه ✓§۵
const PROP_DENSITY: Array[int] = [6, 9, 7, 5, 4, 8]
## ایستگاه‌های آسمان: [پایه، t قاطی با نورِ منطقه] ×۳ ✓§۱ «Soft Gradient»
const SKY_FROM: Array[int] = [2, 2, 5]
const SKY_MIX_T: Array[float] = [0.30, 0.62, 0.55]

## سقفِ آلفای هر لایه ⇒ محیط هرگز مزاحمِ خواناییِ کفه/کره نمی‌شود ✓§۱/§۸ (تست می‌سنجد ✓)
## کادرِ پیش‌فرضِ `layers()` ✓ عبارتِ ثابت (سازندهٔ type داخلی مجاز است، فراخوانیِ تابع ✗✓
## همان دامی که امروز `CORE_LIFT` در آن افتاد) ⇒ در تستِ هدلس هم همین عدد سنجیده می‌شود
const DEFAULT_BOX := Rect2(0.0, 0.0, 1280.0, 720.0)

const LAYER_ALPHA_MAX := 0.46
const SHADOW_VEIL := Color(0.0, 0.0, 0.0, 0.20)

## کلیدهایِ `ambient_art` در `data/narrative/story_beats.json` **همین** نام‌ها هستند ✓
## (گیتِ ابزار این دو واژگان را به هم قفل می‌کند ✗✓ یک روز تغییرِ نام ⇒ قرمز، نه محیطِ خاموش)
enum Region {
	HUB,          ## Aeloria Hub — معماری معلق نیمه‌ویران با پل‌های نورانی ✓§۵
	MEADOW,       ## Sunlit Meadow — دشت‌های شناور با گیاهان کریستالیِ ساده
	CAVERNS,      ## Whisper Caverns — غارهای معلقِ کم‌نور (اعداد منفی/کمبود)
	RUINS,        ## Ghostlight Ruins — خرابه‌ها با سایه‌های محو (متغیر مجهول)
	OBSERVATORY,  ## Twin Observatory — دو برجِ به‌هم‌پیوسته (دستگاه دومجهولی)
	SUMMIT,       ## Summit of Equilibrium — قله: ترکیبِ هماهنگِ همهٔ رنگ‌ها
}

const REGION_NAMES: Array[String] = [
	"Aeloria Hub", "Sunlit Meadow", "Whisper Caverns", "Ghostlight Ruins",
	"Twin Observatory", "Summit of Equilibrium",
]

@export var region: Region = Region.HUB:
	set(value):
		region = value
		queue_redraw()
## ۰ = ویران (شروع Tier) · ۱ = بازسازی (پایان Tier) ✓ `GameState.tier_restoration`
@export_range(0.0, 1.0, 0.01) var restoration: float = 0.0:
	set(value):
		restoration = clampf(value, 0.0, 1.0)
		queue_redraw()
## شناوریِ آرامِ جزیره‌ها ✓§۱ «Flat Vector» ⇒ یک سینوسِ کم‌دامنه، بی‌فیزیک
@export var motion: float = 0.35
@export var animate: bool = true

var _t: float = 0.0


func _ready() -> void:
	z_index = -20  # همیشه پشتِ HUD/گیم‌پلی ✓ (تستِ لایه‌بندی همین را می‌سنجد)
	set_process(animate)


func _process(delta: float) -> void:
	if not animate or not is_visible_in_tree():
		return
	_t = fmod(_t + delta * 0.25, TAU)
	queue_redraw()


# --------------------------------------------------------------------------
# واژگانِ منطقه ✓
# --------------------------------------------------------------------------
static func region_count() -> int:
	return REGION_NAMES.size()


static func region_name(r: Region) -> String:
	return REGION_NAMES[clampi(int(r), 0, REGION_NAMES.size() - 1)]


static func region_named(find: String) -> int:
	return REGION_NAMES.find(find)


## Tier → منطقه ✓§۵ (۰ یا بیرونِ بازه ⇒ Hub، چون نقشهٔ جهان همان است ✓) — عمداً `int`
## برمی‌گرداند: `enum as` در GDScript شکننده است ✗✓ و assignmentٔ int→enum مجاز و ثابت‌شده ✓
static func region_for_tier(tier: int) -> int:
	return clampi(tier, 0, 5)


static func base(i: int) -> Color:
	return BASES[clampi(i, 0, BASES.size() - 1)]


## نورِ غالبِ منطقه ✓ از جدولِ «پایه + قاطی» ساخته می‌شود (هیچ رنگِ تازه‌ای ✗§۸)
static func light_color(r: Region) -> Color:
	var idx: int = clampi(int(r), 0, LIGHT_BASE.size() - 1)
	var c: Color = base(LIGHT_BASE[idx])
	var adj: float = LIGHT_ADJ[idx]
	if adj != 0.0:
		c = c.lightened(adj) if adj > 0.0 else c.darkened(-adj)
	var mix: int = LIGHT_MIX[idx]
	if mix >= 0:
		c = c.lerp(base(mix), LIGHT_MIX_T[idx])
	return c


## آسمان: سه ایستگاه ✓§۱ («Soft Gradient») — همه از BASES با `light_color` منطقه ✓
static func sky_gradient(r: Region) -> PackedColorArray:
	var light: Color = light_color(r)
	var out := PackedColorArray()
	for i: int in SKY_FROM.size():
		var c: Color = base(SKY_FROM[i]).lerp(light, SKY_MIX_T[i])
		c.a = 0.30 + 0.12 * float(i)
		out.append(c)
	return out


## «چقدر شکسته است؟» ✓§۵: با بازیابیِ بازیکن خطی کم می‌شود (قانونِ کلیدیِ سند)
static func brokenness(r: Region, progress: float) -> float:
	var ru: float = RUIN_BASE[clampi(int(r), 0, RUIN_BASE.size() - 1)]
	return clampf(ru * (1.0 - clampf(progress, 0.0, 1.0)), 0.0, 1.0)


static func bridge_total(r: Region) -> int:
	return BRIDGE_TOTAL[clampi(int(r), 0, BRIDGE_TOTAL.size() - 1)]


## چند پل ساخته شده ✓ «پل‌های نورانی که با پیشرفت دوباره ساخته می‌شوند» (§۵) — پلکانیِ
## یکنوا ✓ (هیچ‌وقت دو پل با هم ظاهر نمی‌شوند مگر در آخرین گام ✓ کودک پیشرفت را ببیند)
static func bridges_built(r: Region, progress: float) -> int:
	var total: int = bridge_total(r)
	var p: float = clampf(progress, 0.0, 1.0)
	if p >= 0.999:
		return total
	return int(floor(float(total) * p))


static func prop_density(r: Region) -> int:
	return PROP_DENSITY[clampi(int(r), 0, PROP_DENSITY.size() - 1)]


## سقفِ آلفا ✓ (تستِ §۸ «مزاحم‌نبودنِ خوانایی» همین را می‌سنجد)
static func layer_max_alpha() -> float:
	return LAYER_ALPHA_MAX


static func base_y_of(box: Rect2, h: float, t: float) -> float:
	return box.position.y + h * t


## پلانِ لایه‌ها ✓ تنها چیزی که `_draw` مصرف می‌کند (هندسه + رنگ + آلفا ✓ تک‌حقیقت)
## kind: sky|ridge|isle|bridge|prop|light ✓ هر منطقه ترکیبِ خودش را دارد ✓§۵
static func layers(r: Region, progress: float, box: Rect2 = DEFAULT_BOX) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var brk: float = brokenness(r, progress)
	var light: Color = light_color(r)
	var sky: PackedColorArray = sky_gradient(r)
	var w: float = maxf(box.size.x, 1.0)
	var h: float = maxf(box.size.y, 1.0)
	out.append({"kind": "sky", "rect": box, "color": sky[0],
		"alpha": clampf(sky[0].a, 0.0, LAYER_ALPHA_MAX)})
	# سه رشته‌کوه/جزیره: هرچه ویران‌تر، بریدگیِ بیشتر و ارتفاعِ نامتوازن‌تر ✗✓
	for i: int in 3:
		var base_y: float = base_y_of(box, h, 0.52 + 0.14 * float(i))
		var jag: float = h * 0.10 * (0.4 + brk)
		var shift: float = w * 0.06 * float(i - 1) * (1.0 - progress * 0.5)
		out.append({
			"kind": "isle" if i == 1 else "ridge",
			"rect": Rect2(box.position.x + shift, base_y - jag, w * 0.62, h * 0.42),
			"color": base(6).darkened(0.30 - 0.12 * float(i)).lerp(light, 0.18),
			"alpha": clampf(0.30 + 0.08 * float(i), 0.0, LAYER_ALPHA_MAX),
			"jag": jag,
			"broken": brk,
		})
	# پل‌ها: فقط ساخته‌شده‌ها پر می‌شوند ⇒ «تغییرِ حالت» بصری است، نه فقط رنگی ✗✓
	var built: int = bridges_built(r, progress)
	var total: int = bridge_total(r)
	for i: int in total:
		var t: float = float(i) / maxf(float(total - 1), 1.0)
		out.append({
			"kind": "bridge",
			"built": i < built,
			"rect": Rect2(box.position.x + w * (0.12 + 0.66 * t), base_y_of(box, h, 0.56),
				w * 0.16, h * 0.03),
			"color": light,
			"alpha": 0.42 if i < built else 0.08,
			## خطِ نورِ روی پلِ ساخته‌شده ✓§۵ — رنگ و آلفایش هم در **پلان** است، نه در `_draw`
			"edge": base(5),
			"edge_alpha": clampf(0.18 + 0.14 * progress, 0.0, LAYER_ALPHA_MAX),
		})
	# عنصرهای محیطی ✓§۵ — چگالی از جدول، و ارتفاع‌شان با ویرانی کم می‌شود ✓
	for i: int in prop_density(r):
		var t2: float = float(i) / maxf(float(prop_density(r)), 1.0)
		var seed_x: float = fmod(float(i) * 0.377 + 0.11, 1.0)
		out.append({
			"kind": "prop",
			"height": h * (0.05 + 0.055 * fmod(float(i) * 0.617, 1.0)) * (1.0 - brk * 0.45),
			"at": Vector2(box.position.x + w * (0.06 + 0.88 * seed_x),
				base_y_of(box, h, 0.60 + 0.05 * t2)),
			"color": base(5).lerp(light, 0.35 + 0.4 * fmod(float(i) * 0.293, 1.0)),
			"alpha": clampf(0.24 + 0.16 * fmod(float(i) * 0.53, 1.0), 0.0, LAYER_ALPHA_MAX),
		})
	# نورِ غالب: هالهٔ بیضوی ✓§۵ — شدتش با بازیابی بالا می‌رود (پاداشِ بصریِ واقعی ✓)
	out.append({
		"kind": "light",
		"rect": Rect2(w * 0.26, h * 0.10, w * 0.5, h * 0.34),
		"color": light,
		"alpha": clampf(0.16 + 0.20 * progress, 0.0, LAYER_ALPHA_MAX),
	})
	return out


## امضایِ بصریِ یک (منطقه، بازیابی) ✓ «دو حالتِ متمایز برای هر منطقه» (DoD ۸.۳) با همین
## سنجیده می‌شود ✗✓ (CI هدلس `_draw` را اجرا نمی‌کند ⇒ ممیزیِ هندسه/کنتراست ✓ ADR-058/059)
static func signature(r: Region, progress: float) -> Dictionary:
	var props := 0.0
	var alphas := 0.0
	var kinds := {}
	for l: Dictionary in layers(r, progress):
		kinds[String(l.kind)] = true
		alphas += float(l.alpha)
		if String(l.kind) == "prop":
			props += float(l.height)
	return {
		"region": int(r),
		"brokenness": snappedf(brokenness(r, progress), 0.001),
		"bridges": bridges_built(r, progress),
		"props": prop_density(r),
		"prop_mass": snappedf(props, 0.01),
		"alpha_sum": snappedf(alphas, 0.01),
		"sky_mid": sky_gradient(r)[1],
		"light": light_color(r),
		"layers": layers(r, progress).size(),
		"kinds": kinds.size(),
	}


## فاصله = تعدادِ ویژگی‌های متمایز ✓ (≥۲ یعنی «یک‌نگاه» فرقِ دو حالت دیده می‌شود ✓✗)
static func signature_distance(a: Dictionary, b: Dictionary) -> int:
	var diff := 0
	if absf(float(a.brokenness) - float(b.brokenness)) > 0.001:
		diff += 1
	if int(a.bridges) != int(b.bridges):
		diff += 1
	if int(a.props) != int(b.props):
		diff += 1
	if absf(float(a.prop_mass) - float(b.prop_mass)) > 0.01:
		diff += 1
	if absf(float(a.alpha_sum) - float(b.alpha_sum)) > 0.01:
		diff += 1
	if str(a.sky_mid) != str(b.sky_mid):
		diff += 1
	if str(a.light) != str(b.light):
		diff += 1
	return diff


## `animate=false` ⇒ فوری ✓ (ورودِ صحنه: نباید «از صفر ساخته شود» ✗)
## `animate=true` ⇒ ۱٫۲ ثانیه ✓§۵ «پل‌ها با پیشرفت دوباره ساخته می‌شوند» ⇒ بازیکن
## **لحظهٔ** ساختن را می‌بیند، نه فقط نتیجه را ✓✓ (تستِ ۸.۳ هر دو مسیر را می‌سنجد ✓)
func set_restoration(value: float, animate: bool = true) -> void:
	var target: float = clampf(value, 0.0, 1.0)
	if not animate or target == restoration:
		restoration = target
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "restoration", target, 1.2)


func debug_state() -> Dictionary:
	var s := signature(region, restoration)
	s["region_name"] = region_name(region)
	s["animate"] = animate
	return s


# --------------------------------------------------------------------------
func _draw() -> void:
	var box := _box()
	var drift: float = sin(_t) * motion * 6.0
	for l: Dictionary in layers(region, restoration, box):
		var c: Color = l.color
		c.a = clampf(float(l.alpha), 0.0, LAYER_ALPHA_MAX)
		match String(l.kind):
			"sky":
				draw_rect(l.rect, c)
			"ridge", "isle":
				var rb: Rect2 = l.rect
				rb.position.y += drift * (0.4 + 0.3 * float(l.kind == "isle"))
				_draw_broken_poly(rb, float(l.jag), float(l.broken), c)
			"bridge":
				var r: Rect2 = l.rect
				r.position.y += drift
				if bool(l.built):
					draw_rect(r, c)
					var e: Color = l.edge
					e.a = float(l.edge_alpha)
					draw_line(r.position, r.position + Vector2(r.size.x, 0.0), e, 2.0, true)
				else:
					# شکافِ باز ✓§۵ «هنوز ساخته نشده» ⇒ فقط خطِ نورِ کم‌رنگ، نه دیوار ✗
					draw_line(r.position + Vector2(0.0, r.size.y * 0.5),
						r.position + Vector2(r.size.x, r.size.y * 0.5), c, 2.0, true)
			"prop":
				var at: Vector2 = l.at
				at.y += drift
				var hh: float = float(l.height)
				draw_colored_polygon(PackedVector2Array([at, at + Vector2(-hh * 0.34, hh),
					at + Vector2(hh * 0.34, hh)]), c)
			"light":
				var lr: Rect2 = l.rect
				draw_colored_polygon(_ellipse(lr.get_center(), lr.size.x * 0.5,
					lr.size.y * 0.5, 28), c)


func _draw_broken_poly(r: Rect2, jag: float, brk: float, c: Color) -> void:
	var pts := PackedVector2Array()
	var steps: int = 7
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		var bump: float = jag * (1.0 - 2.0 * fmod(t * 3.7 + brk * 1.3, 1.0))
		pts.append(Vector2(r.position.x + r.size.x * t, r.position.y + absf(bump)))
	pts.append(Vector2(r.end.x, r.end.y))
	pts.append(Vector2(r.position.x, r.end.y))
	draw_colored_polygon(pts, c)


static func _ellipse(center: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in maxi(6, n):
		var a: float = TAU * float(i) / float(maxi(6, n))
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## کادرِ نقاشی: viewport واقعی از بالا-چپ ✓ (هم‌جهت با `Sky`ِ ColorRect ⇒ هیچ‌گاه نیمه‌ای
## بیرونِ صفحه نمی‌ماند ✗✓) با کفِ ابعادِ طراحی، تا در گوشیِ عریض «لبهٔ سیاه» نبینیم ✓
func _box() -> Rect2:
	var s := design_size()
	return Rect2(Vector2.ZERO, s)


static func design_size() -> Vector2:
	var vp := Vector2(1280.0, 720.0)
	var loop := Engine.get_main_loop() as SceneTree
	if loop != null and loop.root != null:
		vp = loop.root.get_visible_viewport_rect().size
	return Vector2(maxf(vp.x, 640.0), maxf(vp.y, 360.0))
