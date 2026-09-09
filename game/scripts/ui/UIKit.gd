class_name UIKit
extends RefCounted
# ===========================================================================
# UIKit — یک جا که §۷ سند هنری به کد تبدیل می‌شود (تسک ۶.۱)
# ---------------------------------------------------------------------------
# §۷ می‌گوید: متن گفت‌وگو ≥ ۲۴px، دکمه ≥ ۴۸×۴۸dp، گوشه‌ی ۱۶px، حالت فشرده =
# scale 0.95 + بازخورد لمسی، و فارسی RTL. اگر این‌ها در هر صحنه جدا نوشته شوند،
# در فاز ۸ (skin) نصفشان گم می‌شود — پس همه‌ی صحنه‌های UI از همین‌جا می‌سازند و
# `test_ui_kit.gd` همان‌ها را روی **مینیاتور صحنه‌ها** می‌سنجد (DoD فاز ۶).
#
# تبدیل dp→px: بوم پروژه ۱۰۸۰×۱۹۲۰ با `stretch/mode = canvas_items` است، پس
# عرض منطقی ۱۰۸۰px روی موبایلِ ۳۶۰dp یعنی ۳px بر هر dp ⇒ کفِ لمسی ۱۴۴px.
# (اگر روزی بوم عوض شود، فقط `CANVAS_PX_PER_DP` ویرایش می‌شود.)
# ===========================================================================

const TAG := "UIKit"

const MIN_TOUCH_DP := 48.0
const CANVAS_PX_PER_DP := 3.0
const MIN_TOUCH_PX: float = MIN_TOUCH_DP * CANVAS_PX_PER_DP

const BUTTON_RADIUS := 16.0
const PRESSED_SCALE := 0.95
const HAPTIC_MS := 15

const DIALOG_FONT_PX := 24
const BUTTON_FONT_PX := 40
const TITLE_FONT_PX := 56
const GAP := 24.0
const MARGIN := 24.0

const DEFAULT_BUTTON_SIZE := Vector2(560.0, 148.0)

## تُن‌های مجاز دکمه (§۲/§۷): طلایی = فعل اصلی، ابری = ثانویه، سنگی = بازگشت/خروج.
## عمداً Warm Coral در دکمه‌ها نیست؛ §۳ آن را رنگِ «نگرانی» می‌داند نه «فعل».
const TONES := {
	"gold": {"bg": Palette.AELORIA_GOLD, "fg": Palette.DEEP_INDIGO},
	"teal": {"bg": Palette.SOFT_TEAL, "fg": Palette.DEEP_INDIGO},
	"cloud": {"bg": Palette.CLOUD_WHITE, "fg": Palette.DEEP_INDIGO},
	"stone": {"bg": Palette.STONE_GREY, "fg": Palette.CLOUD_WHITE},
}


static func px_for_dp(dp: float) -> float:
	return dp * CANVAS_PX_PER_DP


## کفِ لمسی باید از `custom_minimum_size` هم بیاید، وگرنه یک Container اندازه را
## کوچک می‌کند و «دکمه‌ی ۴۸dp» روی کاغذ می‌ماند.
static func touch_floor(size: Vector2) -> bool:
	return size.x >= MIN_TOUCH_PX and size.y >= MIN_TOUCH_PX


static func stylebox(color: Color, radius: float = BUTTON_RADIUS,
		alpha: float = 1.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, color.a * alpha)
	sb.corner_radius_top_left = int(radius)
	sb.corner_radius_top_right = int(radius)
	sb.corner_radius_bottom_left = int(radius)
	sb.corner_radius_bottom_right = int(radius)
	sb.content_margin_left = MARGIN
	sb.content_margin_right = MARGIN
	sb.content_margin_top = MARGIN * 0.5
	sb.content_margin_bottom = MARGIN * 0.5
	return sb


## دکمه‌ی آمادهٔ لمس: RTL، بی‌فوکوس (بچه با صفحه‌کلید بازی نمی‌کند)، stylebox
## چهارحالت، فونت §۷ و کفِ لمسی §۷.
static func style_button(btn: Button, tone: String = "gold") -> Button:
	var spec: Dictionary = TONES.get(tone, TONES["gold"]) as Dictionary
	var bg: Color = spec["bg"] as Color
	var fg: Color = spec["fg"] as Color
	btn.add_theme_stylebox_override("normal", stylebox(bg, BUTTON_RADIUS))
	btn.add_theme_stylebox_override("hover", stylebox(bg.lightened(0.06), BUTTON_RADIUS))
	btn.add_theme_stylebox_override("pressed", stylebox(bg.darkened(0.08), BUTTON_RADIUS))
	btn.add_theme_stylebox_override("disabled", stylebox(Palette.STONE_GREY, BUTTON_RADIUS, 0.5))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	btn.add_theme_color_override("font_pressed_color", fg)
	btn.add_theme_color_override("font_disabled_color", Palette.CLOUD_WHITE)
	btn.add_theme_font_size_override("font_size", BUTTON_FONT_PX)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.text_direction = Loc.text_direction()
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if btn.custom_minimum_size.x < MIN_TOUCH_PX or btn.custom_minimum_size.y < MIN_TOUCH_PX:
		btn.custom_minimum_size = Vector2(
			maxf(btn.custom_minimum_size.x, MIN_TOUCH_PX),
			maxf(btn.custom_minimum_size.y, MIN_TOUCH_PX))
	pressed_feedback(btn)
	return btn


## §۷ «حالت فشرده‌شده با کوچک‌شدن مختصر + بازخورد لمسی»: scale روی خودِ کنترل،
## pivot در مرکز؛ و چون والد ممکن است Container باشد، `size` دست‌نخورده می‌ماند
## (چیدمان به خاطر انیمیشن جهش نمی‌کند).
static func pressed_feedback(btn: Button) -> void:
	if btn.has_meta(&"nexus_press_wired"):
		return
	btn.set_meta(&"nexus_press_wired", true)
	btn.button_down.connect(_press_down.bind(btn))
	btn.button_up.connect(_release_up.bind(btn))


## دو helper جدا به‌جای lambda داخل `connect`: همان Callable قابل‌تست می‌ماند و
## زنجیره‌ی چندخطیِ روش‌ها در GDScript مجاز نیست (needs backslash) ⇒ خط پارس.
static func _press_down(btn: Button) -> void:
	btn.pivot_offset = btn.size * 0.5
	btn.scale = Vector2(PRESSED_SCALE, PRESSED_SCALE)
	kick_haptic()


static func _release_up(btn: Button) -> void:
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)


static func make_button(key: String, tone: String = "gold",
		size: Vector2 = DEFAULT_BUTTON_SIZE) -> Button:
	var btn := Button.new()
	btn.name = key.replace(".", "_")
	btn.text = Loc.t(key)
	# هر متنی که از Loc آمده یک `loc_key` هم دارد: با عوض‌شدن زبان، صحنه‌ها یک
	# «retranslate» می‌خواهند نه بازسازی. (چیپ‌های رنگی متا ندارند ⇒ بی‌متن می‌مانند.)
	btn.set_meta(&"loc_key", key)
	btn.custom_minimum_size = size
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return style_button(btn, tone)


static func make_label(key: String, px: int = DIALOG_FONT_PX,
		color: Color = Palette.CLOUD_WHITE) -> Label:
	var label := Label.new()
	label.name = key.replace(".", "_")
	label.text = Loc.t(key)
	label.set_meta(&"loc_key", key)
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 3
	label.clip_text = true
	label.text_direction = Loc.text_direction()
	label.horizontal_alignment = Loc.alignment()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## برچسبِ **داده** (نه رشته‌ی UI): بی‌`loc_key`، تا `retranslate()` عددِ مدل را با
## ترجمه‌ی یک کلید عوض نکند (خطایی که در داشبورد والدین فاجعه است: جای «۳ ساعت»
## بنشیند «زمان بازی»).
static func make_raw_label(text_value: String, px: int = DIALOG_FONT_PX,
		color: Color = Palette.CLOUD_WHITE) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_direction = Loc.text_direction()
	label.horizontal_alignment = Loc.alignment()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## کادر نیمه‌شفاف (پشت‌زمینه‌ی متن‌ها/HUD) — همان گوشه‌ی ۱۶px و حاشیه‌ی ۲۴px.
static func make_panel(alpha: float = 0.82, padding: float = MARGIN) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := stylebox(Palette.DEEP_INDIGO, BUTTON_RADIUS, alpha)
	sb.content_margin_top = padding
	sb.content_margin_bottom = padding
	sb.content_margin_left = padding
	sb.content_margin_right = padding
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


static func make_vbox(separation: float = GAP) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(separation))
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


## جهت یک کانتینر از Locale می‌آید؛ «RTL درست» یعنی اگر زبان en شد، همان چیدمان
## برمی‌گردد — نه اینکه صحنه‌ها `if fa: ...` داشته باشند.
static func apply_flow(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			var ctrl := child as Control
			ctrl.text_direction = Loc.text_direction()
			if ctrl is LineEdit:
				(ctrl as LineEdit).alignment = Loc.alignment()
			elif ctrl is Label:
				(ctrl as Label).horizontal_alignment = Loc.alignment()
			elif ctrl is Button:
				(ctrl as Button).text_direction = Loc.text_direction()
		apply_flow(child)


## زبان عوض شد؟ یک پاس روی درخت کافی است: هر برچسب/دکمه‌ای که با `make_label/
## make_button` ساخته شده متنش را از `Loc` می‌گیرد ⇒ «i18n-ready» یعنی همین، نه بیشتر.
static func retranslate(root: Node) -> int:
	var touched: int = 0
	for child: Node in root.get_children():
		if child is Control and (child as Object).has_meta(&"loc_key"):
			var key: String = str((child as Object).get_meta(&"loc_key"))
			var text: String = Loc.t(key)
			if child is Button:
				(child as Button).text = text
				touched += 1
			elif child is Label:
				(child as Label).text = text
				touched += 1
		touched += retranslate(child)
	return touched


static func anchor_full(ctrl: Control) -> void:
	ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT,
		Control.PRESET_MODE_MINSIZE, 0)


## بازخورد لمسی فقط روی دستگاه لمسی (§۷ «در صورت پشتیبانی»): در دسکتاپ/CI بی‌صداست.
static func haptics_allowed() -> bool:
	if not DisplayServer.is_touchscreen_available():
		return false
	return bool(SettingsStore.get_value("haptics_enabled"))


static func kick_haptic(ms: int = HAPTIC_MS) -> void:
	if haptics_allowed():
		Input.vibrate_handheld(ms)


## ابزار DoD فاز ۶: هر کنترل قابل‌کلیکِ صحنه باید کفِ لمسی را داشته باشد.
## «قابل‌کلیک» = فهرست صریح کلاس‌ها، تا یک Label با mouse_filter اشتباهی، تست را
## سبز/قرمزِ نامفهوم نکند.
const CLICKABLE: Array[String] = [
	"Button", "TextureButton", "LinkButton", "CheckBox", "CheckButton",
	"HSlider", "VSlider", "OptionButton",
]


static func audit_touch_targets(root: Node, out: Array[String] = []) -> Array[String]:
	for child: Node in root.get_children():
		if child is Control and CLICKABLE.has(child.get_class()):
			var ctrl := child as Control
			var effective := ctrl.size
			if effective.x < MIN_TOUCH_PX or effective.y < MIN_TOUCH_PX:
				effective = ctrl.custom_minimum_size
			if not touch_floor(effective):
				out.append("%s: %s × %s < %s (کفِ لمسی §۷)" % [
					str(root.get_path()), str(effective.x), str(effective.y),
					str(MIN_TOUCH_PX)])
		audit_touch_targets(child, out)
	return out
