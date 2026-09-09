class_name PlayerAvatarPreview
extends Node2D
# ===========================================================================
# PlayerAvatarPreview — آواتارِ لایه‌ایِ انتخاب‌شده در Onboarding (تسک ۶.۲)
# ---------------------------------------------------------------------------
# §۴ سند هنری: ۶ تُن پوست (طیف واقعی، بدون نسبت‌دادن به قومیت)، ۸ مدل مو، رنگ مو
# آزاد، و لباس‌پایهٔ یکسان برای همه (پیش‌بند مهندسی Stone Grey با جزئیات Aeloria
# Gold) — تمایز از پوست/مو می‌آید، نه از لباس‌های جنسیت‌زده. عمداً بی‌اسلحه و
# بی‌خشونت است و «دفترچهٔ مهندسی» را هم ندارد: آن در کات‌سین‌ها می‌آید (§۴).
#
# هندسه در `_draw()` است (ADR-043): صحنه‌ی فاز ۸ همان سه عدد
# skin_tone/hair_style/hair_color را به یک اسپرایت لایه‌ای وصل می‌کند و این فایل
# می‌تواند حذف شود — منطق انتخاب و ذخیره هیچ‌جا نمی‌رود.
# ===========================================================================

const TAG := "AvatarPreview"

## §۴: طیف روشن → تیره؛ ۶ عضو (باید با `SettingsStore.SKIN_TONES` برابر بماند — تست).
const SKIN_COLORS: Array[Color] = [
	Color("F6DCC4"), Color("EFC49C"), Color("DDA97C"),
	Color("C08657"), Color("94603C"), Color("5F3B27"),
]

const HAIR_NAMES: Array[String] = [
	"short", "buzz", "curly", "braid", "bun", "ponytail", "bob", "coils",
]

const APRON_COLOR: Color = Palette.STONE_GREY
const TRIM_COLOR: Color = Palette.AELORIA_GOLD
const EYE_COLOR: Color = Palette.DEEP_INDIGO

@export var skin_tone: int = 0:
	set(value):
		skin_tone = clampi(value, 0, maxi(0, SKIN_COLORS.size() - 1))
		queue_redraw()
@export var hair_style: int = 0:
	set(value):
		hair_style = clampi(value, 0, maxi(0, HAIR_NAMES.size() - 1))
		queue_redraw()
@export var hair_color: int = 0:
	set(value):
		hair_color = clampi(value, 0, maxi(0, SettingsStore.HAIR_COLORS.size() - 1))
		queue_redraw()
## مقیاس نقاشی: ۱.۰ برای پیش‌نمایش Onboarding، بزرگ‌تر برای کارت‌های بعدی.
@export var unit: float = 1.0:
	set(value):
		unit = maxf(0.1, value)
		queue_redraw()


static func skin_count() -> int:
	return SKIN_COLORS.size()


static func hair_count() -> int:
	return HAIR_NAMES.size()


static func color_count() -> int:
	return SettingsStore.HAIR_COLORS.size()


static func skin_color(index: int) -> Color:
	return SKIN_COLORS[clampi(index, 0, SKIN_COLORS.size() - 1)]


static func hair_hex(index: int) -> String:
	return SettingsStore.HAIR_COLORS[clampi(index, 0, SettingsStore.HAIR_COLORS.size() - 1)]


static func hair_color_value(index: int) -> Color:
	return Color(hair_hex(index))


## یک انتخاب از UI: false یعنی بخش ناشناخته (تایپو در کد لو می‌رود، نه بی‌صدا).
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


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * unit)
	var skin: Color = skin_color(skin_tone)
	var hair: Color = hair_color_value(hair_color)

	# سایه — §۶ «هیچ‌چیز بی‌وزن روی زمین شناور نیست»
	draw_colored_polygon(PackedVector2Array([
		Vector2(-58.0, 118.0), Vector2(58.0, 118.0), Vector2(46.0, 130.0),
		Vector2(-46.0, 130.0)]), Color(0.0, 0.0, 0.0, 0.16))

	# پاها و بدن: پیش‌بند مهندسی یکسان برای همه (§۴)
	var legs := Color(0.28, 0.29, 0.35, 1.0)
	draw_rect(Rect2(-34.0, 84.0, 24.0, 34.0), legs)
	draw_rect(Rect2(10.0, 84.0, 24.0, 34.0), legs)
	draw_rect(Rect2(-46.0, -14.0, 92.0, 102.0), APRON_COLOR)
	draw_rect(Rect2(-46.0, 18.0, 92.0, 8.0), TRIM_COLOR)
	draw_line(Vector2(-24.0, -14.0), Vector2(-30.0, 18.0), TRIM_COLOR, 6.0)
	draw_line(Vector2(24.0, -14.0), Vector2(30.0, 18.0), TRIM_COLOR, 6.0)
	draw_rect(Rect2(-16.0, 34.0, 32.0, 24.0), Color(0.0, 0.0, 0.0, 0.12))
	draw_arc(Vector2(0.0, 46.0), 14.0, 0.0, TAU, 20, TRIM_COLOR, 3.0)

	# سر و گوش‌ها
	draw_circle(Vector2(-42.0, -52.0), 9.0, skin)
	draw_circle(Vector2(42.0, -52.0), 9.0, skin)
	draw_circle(Vector2(0.0, -52.0), 42.0, skin)
	# چشم‌ها؛ §۲ برای آياتا «بی‌صورت» می‌گوید، برای بازیکن مجاز است (حس هم‌شناسی)
	draw_circle(Vector2(-14.0, -54.0), 4.5, EYE_COLOR)
	draw_circle(Vector2(14.0, -54.0), 4.5, EYE_COLOR)
	_draw_hair(hair)


## هشت مدل مو (§۴: متنوع از نظر بافت و طول) — هر کدام شکلِ هندسیِ خودش، تا
# «تغییر مدل مو» واقعاً روی پیش‌نمایش دیده شود نه فقط در عددِ ذخیره‌شده.
func _draw_hair(hair: Color) -> void:
	match hair_style:
		0:  # کوتاه
			draw_arc(Vector2(0.0, -54.0), 44.0, PI * 1.02, PI * 1.98, 24, hair, 16.0)
		1:  # بسیار کوتاه (buzz)
			draw_arc(Vector2(0.0, -56.0), 42.0, PI * 1.1, PI * 1.9, 20, hair, 8.0)
		2:  # فرفری — چند حلقه
			for i: int in range(7):
				var a: float = PI * (1.05 + 0.15 * float(i))
				draw_circle(Vector2(cos(a), sin(a)) * 44.0 + Vector2(0.0, -54.0), 12.0, hair)
		3:  # بافت — دو دنبالهٔ قطره‌ای
			draw_arc(Vector2(0.0, -54.0), 44.0, PI * 1.02, PI * 1.98, 24, hair, 14.0)
			for side: float in [-1.0, 1.0]:
				for k: int in range(3):
					draw_circle(Vector2(side * 40.0, -30.0 + float(k) * 22.0),
						13.0 - float(k) * 2.5, hair)
		4:  # گوجه‌ای (bun)
			draw_arc(Vector2(0.0, -54.0), 44.0, PI * 1.05, PI * 1.95, 24, hair, 12.0)
			draw_circle(Vector2(0.0, -98.0), 18.0, hair)
		5:  # دم‌اسبی
			draw_arc(Vector2(0.0, -54.0), 44.0, PI * 1.02, PI * 1.98, 24, hair, 14.0)
			draw_circle(Vector2(38.0, -78.0), 14.0, hair)
			for k: int in range(3):
				draw_circle(Vector2(48.0 + float(k) * 12.0, -66.0 + float(k) * 16.0),
					12.0 - float(k) * 2.0, hair)
		6:  # باب — کلاهک صاف تا زیر گوش
			draw_rect(Rect2(-46.0, -92.0, 92.0, 46.0), hair)
			draw_rect(Rect2(-46.0, -60.0, 14.0, 26.0), hair)
			draw_rect(Rect2(32.0, -60.0, 14.0, 26.0), hair)
		_:  # حلقه‌ای (coils)
			for i: int in range(8):
				var ang: float = TAU * float(i) / 8.0
				draw_arc(Vector2(cos(ang) * 30.0, -56.0 + sin(ang) * 24.0), 11.0,
					0.0, TAU, 14, hair, 5.0)
