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
## همان هوی §۲ با ۲۵٪ تاریکی (= ×۰٫۷۵ روی هر کانال) ✓§۸ — برای `UIKit.TONES["stone"]`.
## چرا ثابتِ جدا؟ چون `STONE_GREY.darkened(0.25)` در `const` **مجاز نیست** ✗✓ و همان یک
## خط، کل `UIKit` را از کامپایل می‌انداخت (۱۰۵ تست قرمز ⇒ درسِ ADR-062)؛ عددِ هگز از
## همان عبارت حساب شده و تست، وفاداریش را می‌سنجد ✓✓ (گیتِ `check_const_expressions`)
const STONE_UI := Color("676B7A")
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


## §۷ (تسک ۸.۴): خانواده = **Vazirmatn** ✓ «Medium برای بدنه، Bold برای تیتر» ✗✓ دو فایل
## TTF از قبل در `assets/fonts/`‌اند و در بودجۀ `check_art_assets` شمرده‌اند ⇒ این‌جا فقط
## سیم‌کشی می‌شود ✓✗ دانلود/باینریِ تازه ممنوع (ADR-057).
const FONT_MEDIUM := "res://assets/fonts/Vazirmatn-Medium.ttf"
const FONT_BOLD := "res://assets/fonts/Vazirmatn-Bold.ttf"

## آستانۀ «قابل‌قبول» §۷ = **WCAG 2.2 AA** (1.4.3) ✓✓ عددِ سلیقه‌ای نیست: متن عادی ≥ ۴٫۵
## (و ما استثنای «متن بزرگ» را هم نمی‌گیریم ✗✓ چون کودک این بازی را در آفتاب بازی می‌کند
## §۷ «روی موبایل» ⇒ هر جفتی که زیر ۴٫۵ باشد رنگش را عوض می‌کنیم، نه آستانه را ✓✓).
const AA_TEXT_RATIO := 4.5

## متنِ کم‌اهمیت (کپشن/محور چارت/راهنمای داشبورد) ✗✓ `STONE_GREY` مستقیم روی `DEEP_INDIGO`
## فقط ۳٫۶۸ است ⇒ زیرِ AA؛ همین تُنِ سنگی را **روشن** می‌کنیم تا هوی §۲ حفظ شود و عدد برسد
## = ۵٫۴۶ روی `DEEP_INDIGO` ✓✓ (اندازه‌گیریِ WCAG در `test_ui_skin.gd`، نه ادعا).
const MUTED_TEXT := Color("AEAFC0")


static func ui_font() -> Font:
	# بدنه (§۷: Medium). اگر import آماده نبود، fallbackِ موتور ✓ تا صحنه هیچ‌وقت نشکند.
	var f: Font = null
	if ResourceLoader.exists(FONT_MEDIUM):
		f = load(FONT_MEDIUM)
	if f == null and ResourceLoader.exists(FONT_BOLD):
		f = load(FONT_BOLD)
	if f == null:
		f = ThemeDB.fallback_font
	return f


static func ui_font_bold() -> Font:
	# تیترها/عددِ روی کره (§۶ «عدد ملموس» ⇒ Bold روی شیدرِ متحرک) ✓
	var f: Font = null
	if ResourceLoader.exists(FONT_BOLD):
		f = load(FONT_BOLD)
	return f if f != null else ui_font()


## کنتراستِ WCAG ✓ (خطی‌سازی sRGB ⇒ luminance نسبی ⇒ نسبت). عمداً همین‌جا نشسته:
## هر جا رنگی انتخاب می‌شود باید بتواند **سنجیده** شود ✗✓ و تستِ دسترس‌پذیریِ ۸.۴
## (DoD: «کنتراست متن/پس‌زمینه قابل‌قبول») از همین یک تابع می‌پرسد ✓✓.
static func relative_luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)


static func contrast_ratio(a: Color, b: Color) -> float:
	var la: float = relative_luminance(a)
	var lb: float = relative_luminance(b)
	var hi: float = maxf(la, lb)
	var lo: float = minf(la, lb)
	return (hi + 0.05) / (lo + 0.05)


## رنگ متنِ مناسب روی این پس‌زمینه ✓✗ دو نامزدِ §۲ و انتخاب با **نسبتِ واقعی** است،
## نه آستانۀ لومینانسِ حدسی ✓✓ (نسخۀ قبلی `> 0.55` بود که روی خاکستریِ سنگی می‌سوخت ✗).
static func text_on(background: Color) -> Color:
	var white: float = contrast_ratio(CLOUD_WHITE, background)
	var indigo: float = contrast_ratio(DEEP_INDIGO, background)
	return CLOUD_WHITE if white >= indigo else DEEP_INDIGO
