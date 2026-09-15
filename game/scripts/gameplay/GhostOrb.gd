class_name GhostOrb
extends WeightOrb
# ===========================================================================
# GhostOrb — کره‌ی روح = متغیر مجهول (تسک ۲.۳)
# ---------------------------------------------------------------------------
# دو قانون از سند طراحی که این کلاس تضمین می‌کند:
#   ۱) `hidden_value` در **هیچ** مسیر UI بیرون نمی‌رود: نه متن، نه tooltip، نه لاگ.
#      (تست: display_text() باید "?" باشد و هیچ رشته‌ای عدد مخفی را نداشته باشد.)
#   ۲) ظاهر همیشه Ghost Violet با «؟» محو-پررنگ (§۶ سند هنری) — رنگ ثابت، در کل بازی.
# وزن واقعی در محاسبه‌ی تعادل لحاظ می‌شود → بازیکن از «کج بودن ترازو» مقدار را *استنتاج*
# می‌کند؛ همین استنتاج، هدف آموزشی Tier 3 است.
# ===========================================================================

const PULSE_MIN_ALPHA := 0.42
const PULSE_MAX_ALPHA := 0.78


func _init() -> void:
	orb_type = OrbType.GHOST
	# مقدار پیش‌فرضِ value بی‌معنی است؛ وزن از hidden_value می‌آید.
	value = 0.0


## تنها راه قانونی ست‌کردن وزن مخفی (LevelLoader/LevelController صدا می‌زنند).
func set_hidden_value(p_value: float) -> void:
	hidden_value = p_value
	weight_changed.emit(self)
	refresh_visual()


func display_text() -> String:
	return "?"


func fill_color() -> Color:
	return Palette.ghost_fill(PULSE_MIN_ALPHA)


func refresh_visual() -> void:
	super()
	if _visual != null:
		_visual.pulsing = true


## برای LevelController: مجهول را «کشف‌شده» کن (پس از حل معما می‌توان عدد را نشان داد).
func reveal() -> void:
	if _visual != null:
		_visual.kind = OrbVisual.Kind.GHOST
		# «همیشه Ghost Violet و نیمه‌شفاف» (§۶) ⇒ نه opaque، نه رنگِ سوم ✓
		# `ghost_fill()` تنها راهِ ساختِ رنگ روح است ✓ (یک‌منبعی ✓)
		_visual.refresh(Palette.ghost_fill(0.85), str(int(absf(hidden_value))),
			glyph_size(), false)
		_visual.pulsing = false
