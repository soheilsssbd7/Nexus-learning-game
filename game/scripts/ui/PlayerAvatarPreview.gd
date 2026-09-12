class_name PlayerAvatarPreview
extends Node2D
# ===========================================================================
# PlayerAvatarPreview — آواتار لایه‌ایِ بازیکن (تسک ۶.۲ → هنرِ نهایی ۸.۲)
# --------------------------------------------------------------------------
# §۴ سند هنری: ۶ تُن پوست (طیف واقعی، بدون نسبت‌دادن به قومیت) · ۸ مدل مو با
# **بافت و طولِ متفاوت** · رنگ مو آزاد · لباس‌پایهٔ یکسان برای همه (پیش‌بند مهندسی
# Stone Grey با جزئیات Aeloria Gold) · بی‌اسلحه و بی‌خشونت · «دفترچهٔ مهندسی» ✓
# تمایز از پوست/مو می‌آید، نه از لباس‌های جنسیت‌زده ✓ (پروفایل: چیبی-متوسط،
# سر:بدن ≈ ۱:۳ ✓ — عددِ §۴ که قبلاً ۱:۱٫۶ بود ✗✓ و تستِ ۸.۲ قفلاش می‌کند).
#
# چرا «ترکیب‌پذیر» و نه ۴۸ فایل؟ DoD ۸.۲ «تمام ترکیب‌ها بدون گلیچ قابل‌انتخاب‌اند» ✓✗
# ۴۸ اسپرایت یعنی ۴۸ فرصتِ گلیچِ متفاوت ✗؛ اینجا ۱ هندسه + ۸ دیکشنریِ مو ⇒ و تست می‌تواند
# هر ۴۸ ترکیب را **ریاضی** بسنجد (باکس/پوشش/دیده‌شدنِ صورت ✓✓) نه با چشم ✗.
# تمامِ اعداد در static‌های بیرونِ `_draw` اند ✗✓ (قاعدهٔ ADR-058: هدلس `_draw` را اجرا
# نمی‌کند ⇒ هر چیزی که در `_draw` حساب شود، در CI سبزِ توخالی می‌ماند ✗✗).
# ===========================================================================

const TAG := "AvatarPreview"

# --- پیکربندیِ بدنه (§۴: نسبت سر به بدن ≈ ۱ به ۳ ✓) -----------------------
const HEAD_R: float = 30.0      # رأسِ سر تا مرکز ⇒ ارتفاع سر = ۶۰ ✓
const BODY_H: float = 122.0     # تنه (پیش‌بند) ✓
const LEGS_H: float = 58.0      # پاها ✓ ⇒ ۶۰ : (۱۲۲+۵۸=۱۸۰) = دقیقاً ۱:۳ ✓✓
const SHOULDER_W: float = 46.0
const HEAD_Y: float = 0.0
const LEGS_TOP_Y: float = HEAD_R + BODY_H

## §۴: طیف روشن → تیره؛ باید با `SettingsStore.SKIN_TONES` برابر بماند (تست ✓)
const SKIN_COLORS: Array[Color] = Palette.SKIN_TONES
const HAIR_NAMES: Array[String] = [
	"short", "buzz", "curly", "braid", "bun", "ponytail", "bob", "coils",
]
const APRON_COLOR: Color = Palette.STONE_GREY
const TRIM_COLOR: Color = Palette.AELORIA_GOLD
const EYE_COLOR: Color = Palette.DEEP_INDIGO
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.16)
const POCKET_COLOR := Color(0.0, 0.0, 0.0, 0.12)

## هشت «زبانِ مو» ✓§۴: `reach` = طولِ نسبی (۰ تا ۱ ✓) و `texture` = بافت ✓ —
## اگر دو مدل فقط نامشان فرق می‌کرد، DoD ۸.۵/۸.۲ «تمایزِ یک‌نگاه» می‌مرد ✗✓ (تست می‌سنجد)
const HAIR_SHAPES: Array[Dictionary] = [
	{"cap_r": 32.0, "cap_w": 10.0, "reach": 0.10, "strands": 0, "bulb_r": 0.0,
		"texture": "smooth", "side_x": 0.0},                      # کوتاه
	{"cap_r": 31.0, "cap_w": 5.0, "reach": 0.04, "strands": 0, "bulb_r": 0.0,
		"texture": "smooth", "side_x": 0.0},                      # بسیار کوتاه (buzz)
	{"cap_r": 34.0, "cap_w": 12.0, "reach": 0.18, "strands": 7, "bulb_r": 8.0,
		"texture": "coiled", "side_x": 0.0},                       # فرفری
	{"cap_r": 32.0, "cap_w": 11.0, "reach": 0.62, "strands": 3, "bulb_r": 9.0,
		"texture": "braided", "side_x": 26.0},                      # بافتِ دوتایی
	{"cap_r": 32.0, "cap_w": 9.0, "reach": 0.14, "strands": 0, "bulb_r": 13.0,
		"texture": "smooth", "side_x": 0.0},                       # گوجه‌ای (bun)
	{"cap_r": 32.0, "cap_w": 10.0, "reach": 0.48, "strands": 3, "bulb_r": 8.0,
		"texture": "wavy", "side_x": 30.0},                        # دم‌اسبی
	{"cap_r": 33.0, "cap_w": 12.0, "reach": 0.34, "strands": 0, "bulb_r": 0.0,
		"texture": "smooth", "side_x": 24.0},                      # باب (کلاهک + پنلِ کنار)
	{"cap_r": 36.0, "cap_w": 6.0, "reach": 0.30, "strands": 8, "bulb_r": 11.0,
		"texture": "coiled", "side_x": 0.0},                        # حلقه‌ای (afro/coils)
]

@export var skin_tone: int = 0:
	set(value):
		skin_tone = clampi(value, 0, maxi(0, SKIN_COLORS.size() - 1))
		queue_redraw()
@export var hair_style: int = 0:
	set(value):
		hair_style = clampi(value, 0, maxi(0, HAIR_SHAPES.size() - 1))
		queue_redraw()
@export var hair_color: int = 0:
	set(value):
		hair_color = clampi(value, 0, maxi(0, SettingsStore.HAIR_COLORS.size() - 1))
		queue_redraw()
## مقیاس نقاشی: ۱٫۰ برای پیش‌نمایش Onboarding، بزرگ‌تر برای کارت‌های بعدی ✓
@export var unit: float = 1.0:
	set(value):
		unit = maxf(0.1, value)
		queue_redraw()
## جعبهٔ در دسترس (صفر = بی‌تنظیم) ✓ با مقدارگیریِ **خودکارِ** مقیاس بر اساس بلندترین
## مدل مو ✗✓ هشت مدل، هشت ارتفاع دارند؛ یک عددِ ثابت یعنی «این مدل به ردیفِ دکمه
## می‌رسد، آن یکی شناور است» ⇒ همان «گلیچِ بصری» که DoD ۸.۲ منع می‌کند ✓✓
@export var fit_box: Vector2 = Vector2.ZERO:
	set(value):
		fit_box = value
		queue_redraw()


# --------------------------------------------------------------------------
# شمارش‌ها و رنگ‌ها (قراردادِ API از فاز ۶ ✓ دست‌نخورده ✓)
# --------------------------------------------------------------------------
static func skin_count() -> int:
	return SKIN_COLORS.size()


static func hair_count() -> int:
	return HAIR_SHAPES.size()


static func color_count() -> int:
	return SettingsStore.HAIR_COLORS.size()


static func skin_color(index: int) -> Color:
	return SKIN_COLORS[clampi(index, 0, SKIN_COLORS.size() - 1)]


static func hair_hex(index: int) -> String:
	return SettingsStore.HAIR_COLORS[clampi(index, 0, SettingsStore.HAIR_COLORS.size() - 1)]


static func hair_color_value(index: int) -> Color:
	return Color(hair_hex(index))


## نامِ مدل مو ✓ (Onboarding/کارتِ والد این را برای برچسب مصرف می‌کند)
static func hair_name(index: int) -> String:
	return HAIR_NAMES[clampi(index, 0, HAIR_NAMES.size() - 1)]


func set_choice(part: String, index: int) -> bool:
	match part:
		"skin_tone":
			skin_tone = index
			return true
		"hair_style":
			hair_style = index
			return true
		"hair_color":
			hair_color = index
			return true
		_:
			Log.warn(TAG, "بخش آواتار ناشناخته: " + part)
			return false


func config() -> Dictionary:
	return {"skin_tone": skin_tone, "hair_style": hair_style, "hair_color": hair_color}


func apply_config(values: Dictionary) -> void:
	skin_tone = int(values.get("skin_tone", skin_tone))
	hair_style = int(values.get("hair_style", hair_style))
	hair_color = int(values.get("hair_color", hair_color))


# --------------------------------------------------------------------------
# هندسهٔ خالص ✓ (همه‌چیز از همین‌جا؛ `_draw` فقط مصرف‌کننده است ✓)
# --------------------------------------------------------------------------
## نسبتِ سر به بدن (§۴) ⇒ باید ~۰٫۳۳۳ باشد ✓✓ (تستِ ۸.۲)
static func head_to_body_ratio() -> float:
	return (HEAD_R * 2.0) / (BODY_H + LEGS_H)


static func head_center() -> Vector2:
	return Vector2(0.0, HEAD_Y)


static func body_rect() -> Rect2:
	return Rect2(-SHOULDER_W, HEAD_R, SHOULDER_W * 2.0, BODY_H)


static func leg_rects() -> Array[Rect2]:
	return [Rect2(-34.0, LEGS_TOP_Y, 24.0, LEGS_H), Rect2(10.0, LEGS_TOP_Y, 24.0, LEGS_H)]


## نوارِ چشم‌ها ✓ «گلیچ بصری» در §۴ یعنی مویی که صورت را بپوشاند ⇒ صریح ممنوع ✓✓
static func eye_band() -> Rect2:
	return Rect2(-22.0, HEAD_Y - 8.0, 44.0, 20.0)


## کادرِ مجازِ کل آواتار ✓ (اگر مدلی از این بیرون بزند، در Onboarding کلیپ/برخورد
## با لبه‌ی پنل می‌خورد ✗✓ همان «گلیچِ» که DoD ۸.۵ می‌گوید)
static func frame_rect() -> Rect2:
	return Rect2(-78.0, -78.0, 156.0, 320.0)


static func shape_for(style: int) -> Dictionary:
	return HAIR_SHAPES[clampi(style, 0, HAIR_SHAPES.size() - 1)]


## کلاهک مو: کمانی بالای سر ✓ از `PI*1.03` تا `PI*1.97` (پیشانی باز می‌ماند ✓§۴)
static func cap_arc(style: int) -> Dictionary:
	var sh := shape_for(style)
	return {
		"center": head_center() + Vector2(0.0, -2.0),
		"radius": float(sh.cap_r),
		"from": PI * 1.03,
		"to": PI * 1.97,
		"width": float(sh.cap_w),
	}


## رشته‌ها/حباب‌های مو ✓ (تعداد و جای هرکدام از `texture` می‌آید، نه از if در `_draw` ✗✓)
static func hair_points(style: int) -> PackedVector2Array:
	var sh := shape_for(style)
	var n: int = int(sh.strands)
	var pts := PackedVector2Array()
	if n <= 0:
		return pts
	var reach: float = float(sh.reach) * 150.0  # حداکثرِ سقوطِ مو = ۱۵۰px ✓ (تا روی سینه)
	var side: float = float(sh.side_x)
	var texture: String = String(sh.texture)
	for i: int in n:
		var t: float = float(i) / float(maxi(1, n - 1)) if n > 1 else 0.5
		if texture == "coiled":
			# حلقه‌ها روی کلاهک پخش می‌شوند ⇒ بافت، نه طول ✗✓
			var a: float = PI * (1.05 + 0.9 * t)
			pts.append(head_center() + Vector2(cos(a), sin(a)) * float(sh.cap_r))
		elif texture == "braided":
			# بافت: دو دنبالهٔ عمودی با قطرِ رو به کاهش ✓
			pts.append(Vector2(side, 6.0 + t * reach))
			pts.append(Vector2(-side, 6.0 + t * reach))
		elif texture == "wavy":
			# موج: دنباله‌ی کج‌ومعوجِ یک‌طرفه ✓ (دم‌اسبی)
			pts.append(Vector2(side + sin(t * PI * 1.6) * 10.0, -18.0 + t * reach))
		else:
			pts.append(Vector2(side, t * reach))
	return pts


## گوجه/باندِ بالای سر ✓ (فقط مدل‌های bun/ponytail یک تودهٔ جدا دارند ✓)
static func hair_bulb(style: int) -> Dictionary:
	var sh := shape_for(style)
	var r: float = float(sh.bulb_r)
	if r <= 0.0:
		return {"center": Vector2.ZERO, "radius": 0.0}
	var center := head_center() + Vector2(0.0, -(HEAD_R + r * 0.55))
	if String(sh.texture) == "wavy":
		center = head_center() + Vector2(30.0, -18.0)
	return {"center": center, "radius": r}


## پیش‌بند: جیب + نوارِ طلایی ✓§۴ (یکسان برای همه ⇒ تمایز از لباس نمی‌آید ✓)
static func apron_pocket_rect() -> Rect2:
	return Rect2(-16.0, HEAD_R + BODY_H * 0.44, 32.0, 24.0)


## §۴ «دفترچهٔ مهندسی (کروکی‌بوک)» ✓ ابزارِ قابل‌حمل، بی‌اسلحه ✗✓
static func notebook_rect() -> Rect2:
	return Rect2(-SHOULDER_W - 12.0, HEAD_R + BODY_H * 0.52, 28.0, 22.0)


## جعبهٔ چشم‌ها ✓ «موی صورت‌پوش» = گلیچِ §۴ ⇒ با همین هندسه سنجیده می‌شود (نه با چشم ✗✓)
static func eye_boxes() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for side: float in [-1.0, 1.0]:
		var c := head_center() + Vector2(side * 11.0, 2.0)
		out.append(Rect2(c - Vector2(3.2, 3.2), Vector2(6.4, 6.4)))
	return out


## جعبه‌هایِ موی یک مدل ✓ از **همان** ثابت‌های `_draw` (HAIR_SHAPES + HEAD_R) ⇒ اگر
## `_draw` و این دو مسیر جدا می‌شدند، تست «بی‌گلیچ» فقط کاغذ بود ✗✓ (تک‌حقیقت ✓)
static func hair_bboxes(style: int) -> Array[Rect2]:
	var sh := shape_for(style)
	var out: Array[Rect2] = []
	var cap_r: float = float(sh.cap_r)
	var cap_w: float = float(sh.cap_w)
	var c := head_center() + Vector2(0.0, -2.0)
	# کلاهک: نیم‌حلقه ⇒ جعبه‌ی بالا ✓ (کمان از π*1.03 تا π*1.97 = نیمه‌ی بالایی ✓)
	out.append(Rect2(c.x - cap_r - cap_w * 0.5, c.y - cap_r - cap_w * 0.5,
		(cap_r + cap_w * 0.5) * 2.0, cap_r + cap_w * 0.5))
	var r: float = float(sh.bulb_r)
	for pt: Vector2 in hair_points(style):
		out.append(Rect2(pt.x - r, pt.y - r, r * 2.0, r * 2.0))
	var bulb := hair_bulb(style)
	if float(bulb.radius) > 0.0:
		var br: float = float(bulb.radius)
		out.append(Rect2(bulb.center.x - br, bulb.center.y - br, br * 2.0, br * 2.0))
	var side: float = float(sh.side_x)
	if side > 0.0 and String(sh.texture) == "smooth":
		out.append(Rect2(-side - 8.0, -HEAD_R * 0.4, 8.0, 26.0))
		out.append(Rect2(side, -HEAD_R * 0.4, 8.0, 26.0))
	return out


static func hair_overlaps_eyes(style: int) -> bool:
	for hb: Rect2 in hair_bboxes(style):
		for eb: Rect2 in eye_boxes():
			if hb.intersects(eb):
				return true
	return false


## مرزِ کل آواتار برای یک مدل ✓ (سر + تنه + پا + دفترچه + مو + سایه ✓)
static func layout_bbox(style: int) -> Rect2:
	var acc := body_rect().merge(leg_rects()[0]).merge(leg_rects()[1])
	acc = acc.merge(Rect2(head_center() - Vector2(HEAD_R, HEAD_R), Vector2(HEAD_R * 2.0, HEAD_R * 2.0)))
	acc = acc.merge(notebook_rect())
	for hb: Rect2 in hair_bboxes(style):
		acc = acc.merge(hb)
	var feet := LEGS_TOP_Y + LEGS_H
	return acc.merge(Rect2(-52.0, feet + 6.0, 104.0, 12.0))


## سطحِ پوششِ مو نسبت به سر ✓ «کم‌حجم vs پرحجم» ⇒ بافت واقعاً فرق می‌کند (تست §۴ ✓)
static func coverage(style: int) -> float:
	var sh := shape_for(style)
	var cap_r: float = float(sh.cap_r)
	var cap_w: float = float(sh.cap_w)
	var band := PI * 0.5 * ((cap_r + cap_w * 0.5) ** 2 - (cap_r - cap_w * 0.5) ** 2)
	var r: float = float(sh.bulb_r)
	var area := band + float(hair_points(style).size()) * PI * (r * 0.9) ** 2
	if r > 0.0:
		area += PI * r * r
	return area / maxf(PI * HEAD_R * HEAD_R, 1.0)


## گزارشِ یک مدل ✓ (DoD ۸.۲ «تمامِ ترکیب‌ها بدونِ گلیچ» = همین چهار سنجش ✓✓)
static func combo_report(style: int) -> Dictionary:
	var sh := shape_for(style)
	var box := layout_bbox(style)
	var frame := frame_rect()
	return {
		"style": style,
		"name": hair_name(style),
		"texture": String(sh.texture),
		"length": float(sh.reach),
		"strands": hair_points(style).size(),
		"coverage": coverage(style),
		"in_frame": frame.encloses(box),
		"overlaps_eyes": hair_overlaps_eyes(style),
		"bbox": box,
	}


## فهرستِ هر هشت مدل ✓ (تست روی همین حلقه می‌زند؛ تُنِ پوست هندسه را عوض نمی‌کند ⇒
## «۴۸ ترکیب» در تست = ۶ تُن × همین ۸ گزارش، که رنگ‌ها همجدا از  سنجیده می‌شوند ✓)
static func all_combos() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for style: int in HAIR_SHAPES.size():
		out.append(combo_report(style))
	return out


# --------------------------------------------------------------------------
## واحدِ مؤثر: سقفِ `unit` و تنگ‌تر از جعبهٔ در دسترس ✓ (هیچ مدلی بیرون نمی‌زند ✓)
func effective_unit() -> float:
	if fit_box.x <= 0.0 or fit_box.y <= 0.0:
		return unit
	return minf(unit, unit_for_box(fit_box, hair_style))


## مرکزِ هندسه، تا جابه‌جاییِ نود یعنی «وسطِ کادر» نه «وسطِ سر» ✓ (آریا هم همین‌طور است)
func draw_origin() -> Vector2:
	return -layout_bbox(hair_style).get_center() * effective_unit()


static func unit_for_box(box: Vector2, style: int) -> float:
	if box.x <= 0.0 or box.y <= 0.0:
		return 1.0
	var b: Rect2 = layout_bbox(style)
	return minf(box.x / maxf(b.size.x, 1.0), box.y / maxf(b.size.y, 1.0))


func _draw() -> void:
	var u: float = effective_unit()
	draw_set_transform(draw_origin(), 0.0, Vector2.ONE * u)
	var skin: Color = skin_color(skin_tone)
	var hair: Color = hair_color_value(hair_color)
	var shape := shape_for(hair_style)

	# سایه ✓§۶ «هیچ‌چیز بی‌وزن روی زمین شناور نیست»
	var feet := LEGS_TOP_Y + LEGS_H
	draw_colored_polygon(PackedVector2Array([Vector2(-52.0, feet + 6.0), Vector2(52.0, feet + 6.0),
		Vector2(40.0, feet + 18.0), Vector2(-40.0, feet + 18.0)]), SHADOW_COLOR)

	# پاها و تنه (پیش‌بندِ یکسان برای همه ✓§۴)
	var legs := Palette.STONE_GREY.darkened(0.28)
	for r: Rect2 in leg_rects():
		draw_rect(r, legs)
	draw_rect(body_rect(), APRON_COLOR)
	draw_rect(Rect2(-SHOULDER_W, HEAD_R + BODY_H * 0.26, SHOULDER_W * 2.0, 8.0), TRIM_COLOR)
	draw_line(Vector2(-24.0, HEAD_R), Vector2(-30.0, HEAD_R + BODY_H * 0.26), TRIM_COLOR, 6.0)
	draw_line(Vector2(24.0, HEAD_R), Vector2(30.0, HEAD_R + BODY_H * 0.26), TRIM_COLOR, 6.0)
	draw_rect(apron_pocket_rect(), POCKET_COLOR)
	draw_arc(apron_pocket_rect().get_center(), 12.0, 0.0, TAU, 18, TRIM_COLOR, 2.0)

	# دفترچهٔ مهندسی ✓§۴ — ترتیبِ لایه‌ها **ثابت** است (پیش‌بند ← دفترچه ← سر ← مو) ⇒ هیچ
	# ترکیبی هم‌پوشانیِ متغیر تولید نمی‌کند ✓ («بی‌گلیچ» در DoD یعنی همین ✓✓)
	var nb := notebook_rect()
	draw_rect(nb, Palette.CLOUD_WHITE.darkened(0.06))
	draw_rect(Rect2(nb.position.x, nb.position.y, 5.0, nb.size.y), TRIM_COLOR)
	draw_line(nb.position + Vector2(10.0, 6.0), nb.position + Vector2(nb.size.x - 5.0, 6.0),
		legs, 1.5)

	# سر + گوش‌ها + چشم‌ها (§۲ «بی‌صورت» فقط برای آریاست؛ بازیکن می‌تواند چهره داشته باشد ✓)
	draw_circle(head_center() + Vector2(-(HEAD_R - 1.0), 2.0), 6.5, skin)
	draw_circle(head_center() + Vector2(HEAD_R - 1.0, 2.0), 6.5, skin)
	draw_circle(head_center(), HEAD_R, skin)
	draw_circle(head_center() + Vector2(-11.0, 2.0), 3.2, EYE_COLOR)
	draw_circle(head_center() + Vector2(11.0, 2.0), 3.2, EYE_COLOR)

	# مو ✓ لایه‌های پشتِ کلاهک، بعدِ خودِ کلاهک (ترتیبِ ثابت ⇒ بی‌گلیچ ✓)
	for p: Vector2 in hair_points(hair_style):
		draw_circle(p, float(shape.bulb_r) * 0.9, hair)
	var bulb := hair_bulb(hair_style)
	if float(bulb.radius) > 0.0:
		draw_circle(bulb.center, float(bulb.radius), hair)
	var arc := cap_arc(hair_style)
	draw_arc(arc.center, float(arc.radius), float(arc.from), float(arc.to), 28, hair,
		float(arc.width))
	if float(shape.side_x) > 0.0 and String(shape.texture) == "smooth":
		# پنل‌های کنارِ صورت در مدل «باب» ✓ (تا زیرِ گوش، بدونِ پوشاندنِ چشم ✓§۴)
		var side: float = float(shape.side_x)
		draw_rect(Rect2(-side - 8.0, -HEAD_R * 0.4, 8.0, 26.0), hair)
		draw_rect(Rect2(side, -HEAD_R * 0.4, 8.0, 26.0), hair)
