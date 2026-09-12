class_name Palette
extends RefCounted
# ===========================================================================
# Palette — کدهای رنگ رسمی `docs/02-ART-BIBLE.md` §۲
# ---------------------------------------------------------------------------
# چرا در کد و نه در فایل دارایی؟ چون فازهای ۲ تا ۵ با placeholder کار می‌کنند و
# هنر نهایی (فاز ۸) **باید** همین رنگ‌ها را داشته باشد. یک نقطه‌ی تعریف = یک
# نقطه‌ی تضمین. تست `test_palette.gd` قانون «هیچ قرمز تهاجمی» را می‌سنجد.
# ===========================================================================

const AELORIA_GOLD := Color("F4C95D")   ## تعادل/موفقیت/نور Aria
const DEEP_INDIGO := Color("2B2F77")    ## آسمان، حالت «عدم تعادل»
const WARM_CORAL := Color("FF7A5C")      ## هشدار ملایم، کفه‌ی سنگین‌تر
const SOFT_TEAL := Color("4FD1C5")       ## کفه‌ی سبک‌تر، عناصر مثبت UI
const CLOUD_WHITE := Color("FBF9F4")     ## متن روی تیره، نور اصلی
const STONE_GREY := Color("8A8FA3")     ## ساختارهای شکسته/غیرفعال
const GHOST_VIOLET := Color("B79CED")    ## کره‌ی روح — همیشه، در کل بازی ثابت

## مقیاس «گرمایی» کره‌های عددی: Teal (کوچک) → Gold (بزرگ) — §۶ سند هنری
const THERMAL_MIN_VALUE: float = 1.0
const THERMAL_MAX_VALUE: float = 9.0

## پهنای رنگ «سنگینی» روی کفه (نشان‌دهنده‌ی اختلاف، نه «خطا»)
const IMBALANCE_MIX: float = 0.45


## §۴ سند هنری: شش تُن پوستِ **واقعی و فراگیر**، روشن → تیره ✗✓ تنها دو فهرستِ
## مجازِ «بیرونِ پالت اصلی» در کل بازی (پوست و مو) — دلیلش در ADR-060: §۴ طیفِ انسانی
## می‌خواهد که پالتِ پادشاهی (طلایی/فیروزه‌ای) پوشش نمی‌دهد ✗✓ پس قانون این است:
## **فقط** این دو فهرست، و هیچ رنگِ پراکنده‌ای در کدِ آواتار ✗✓ (تست می‌سنجد ✓).
const SKIN_TONES: Array[Color] = [
	Color("F6DCC4"), Color("EFC49C"), Color("DDA97C"),
	Color("C08657"), Color("94603C"), Color("5F3B27"),
]


static func thermal(value: float, max_value: float = THERMAL_MAX_VALUE) -> Color:
	var t: float = 0.0
	if max_value > THERMAL_MIN_VALUE:
		t = clampf((absf(value) - THERMAL_MIN_VALUE) / (max_value - THERMAL_MIN_VALUE), 0.0, 1.0)
	return SOFT_TEAL.lerp(AELORIA_GOLD, t)


static func negative_bubble(value: float) -> Color:
	# حباب ضد-وزن: فیروزه‌ای کم‌رنگ + لبه‌ی روشن (هرگز قرمز؛ §۲ و §۶)
	return SOFT_TEAL.lerp(CLOUD_WHITE, clampf(absf(value) / 6.0, 0.0, 0.7))


static func ghost_fill(alpha: float = 0.62) -> Color:
	var c := GHOST_VIOLET
	c.a = alpha
	return c


static func imbalance_color(strength: float) -> Color:
	## هرچه تعادل دورتر، کفه‌ی سنگین‌تر گرم‌تر می‌شود — «هشدار ملایم»، نه خطا.
	return WARM_CORAL.lerp(STONE_GREY, clampf(1.0 - strength, 0.0, 1.0))


## رنگ متن مناسب روی این پالت (کنتراست ≥ ۴.۵ روی تیره‌ها)
static func text_on(background: Color) -> Color:
	return DEEP_INDIGO if background.get_luminance() > 0.55 else CLOUD_WHITE


static func ui_font() -> Font:
	# placeholder تا تم نهایی (تسک ۸.۴). اگر import فونت آماده نبود، font پیش‌فرض
	# موتور برگردانده می‌شود تا هیچ صحنه‌ای به‌خاطر دارایی نشکند.
	var f: Font = null
	if ResourceLoader.exists("res://assets/fonts/Vazirmatn-Bold.ttf"):
		f = load("res://assets/fonts/Vazirmatn-Bold.ttf")
	if f == null:
		f = ThemeDB.fallback_font
	return f
