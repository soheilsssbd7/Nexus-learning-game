class_name MainMenu
extends Control
# ===========================================================================
# MainMenu — ورودی بازی (تسک ۶.۱)
# ---------------------------------------------------------------------------
# DoD سند ۰۴: «ناوبری از منو به بازی و بازگشت بدون کرش». سه چیز اینجا تصمیم‌ساز است:
#   ۱) اولین اجرا ≠ اجرای بعدی: اگر Onboarding تمام نشده، دکمه‌ی اصلی به Onboarding
#      می‌رود (§۶.۲) وگرنه به سطح؛ «ادامه» همان سطحِ ناتمامِ `PlayerModel` است.
#   ۲) انتخاب سطح از `DifficultyEngine.pick_next_level_id` می‌آید — پس kill-switch
#      والدین (تسک ۶.۵) روی «ادامه» هم اثر دارد، نه فقط روی دکمه‌ی «بعدی».
#   ۳) داشبورد والدین **خودش** قفل دارد (تسک ۶.۵)؛ منو فقط مسیر می‌فرستد، تا
#      نتوان با ساختن یک صحنه‌ی دیگر از قفل رد شد.
# صحنه در کد ساخته می‌شود (ADR-043): فایل `.tscn` فقط ریشه + اسکریپت است.
# ===========================================================================

const TAG := "MainMenu"
const SCENE_PATH := "res://scenes/main/MainMenu.tscn"
const ONBOARDING_PATH := "res://scenes/main/Onboarding.tscn"
const SETTINGS_PATH := "res://scenes/ui/SettingsMenu.tscn"
const PARENT_DASHBOARD_PATH := "res://scenes/ui/ParentDashboard.tscn"
const ARIA_PATH := "res://scenes/characters/Aria.tscn"

signal play_requested(mode: String)
signal map_requested
signal settings_requested
signal parent_dashboard_requested
signal quit_requested

## false = سیگنال بده، صحنه را عوض نکن (تست‌ها درخت GUT را نمی‌شکنند — ADR-035).
@export var allow_scene_change: bool = true
## روی Android خروج مجاز است؛ در تست/هدلس نه (`get_tree().quit()` نیمه‌کاره می‌گذارد).
@export var allow_quit: bool = true
## آواتار Aria در منو: بی‌متن، فقط «حالت آرام» §۳ — اگر صحنه نبود، منو نباید خراب شود.
@export var show_aria: bool = true

var buttons: Array[Button] = []
var primary_button: Button = null
var title_label: Label = null


func _ready() -> void:
	# §۷ + ADR-045: تنظیمات/زبان/صدا پیش از ساختن هر متنی اعمال می‌شوند، وگرنه
	# اولین فریم با locale و صدای پیش‌فرضِ موتور رندر می‌شود.
	SettingsStore.apply_at_boot()
	if GameState.active_model == null:
		GameState.bootstrap()
	custom_minimum_size = Vector2(1080.0, 1920.0)
	_build()
	refresh()


func _build() -> void:
	_build_clay_showcase()
	var bg := ColorRect.new()
	bg.name = "Background"
	# این لایه فقط کنتراستِ متن را نگه می‌دارد؛ ویترینِ سه‌بعدی باید زیر آن دیده شود.
	bg.color = Color(Palette.DEEP_INDIGO, 0.34)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = 1
	UIKit.anchor_full(bg)
	add_child(bg)

	var eyebrow := UIKit.make_label("main.eyebrow", UIKit.DIALOG_FONT_PX, Palette.AELORIA_GOLD, true)
	eyebrow.name = "Eyebrow"
	eyebrow.modulate.a = 0.95
	title_label = UIKit.make_label("main.title", UIKit.TITLE_FONT_PX, Palette.CLOUD_WHITE, true)
	title_label.name = "Title"
	var tagline := UIKit.make_label("main.tagline", UIKit.DIALOG_FONT_PX, Palette.CLOUD_WHITE)
	tagline.name = "Tagline"
	tagline.modulate.a = 0.84

	var hero := UIKit.make_panel(0.76, 28.0)
	hero.name = "HeroCard"
	hero.custom_minimum_size = Vector2(760.0, 226.0)
	var hero_flow := UIKit.make_vbox(8.0)
	hero_flow.add_child(UIKit.make_label("main.hero", 36, Palette.CLOUD_WHITE, true))
	hero_flow.add_child(UIKit.make_label("main.hero_hint", 25, Palette.MUTED_TEXT))
	var chapter := UIKit.make_label("main.chapter", 25, Palette.AELORIA_GOLD, true)
	chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_flow.add_child(chapter)
	hero_flow.add_child(UIKit.make_label("main.safe", 22, Palette.MUTED_TEXT))
	hero.add_child(hero_flow)

	var box := UIKit.make_vbox(UIKit.GAP)
	box.name = "Buttons"
	box.add_theme_constant_override("separation", int(UIKit.GAP * 1.5))
	add_child(box)

	primary_button = _add(box, "menu.play", "gold")
	_add(box, "menu.settings", "cloud")
	_add(box, "menu.parents", "cloud")
	_add(box, "menu.quit", "stone")

	box.add_child(eyebrow)
	box.add_child(hero)
	box.add_child(title_label)
	box.move_child(title_label, 0)
	box.add_child(tagline)
	box.move_child(tagline, 1)
	box.move_child(eyebrow, 2)
	box.move_child(hero, 3)
	# چیدمان: VBox وسطِ صفحه، با حاشیه‌ی §۷ از لبه‌ها
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 0)
	box.offset_left = UIKit.MARGIN
	box.offset_right = -UIKit.MARGIN
	box.offset_top = 620.0
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.z_index = 10

	if show_aria:
		var packed: PackedScene = load(ARIA_PATH)
		if packed != null:
			var aria: Node = packed.instantiate()
			if aria != null:
				aria.name = "Aria"
				add_child(aria)
				if aria is Node2D:
					(aria as Node2D).position = Vector2(880.0, 360.0)
		else:
			Log.warn(TAG, "صحنه‌ی Aria بارگذاری نشد — منو بی‌آواتار ساخته می‌شود")
	UIKit.apply_flow(self)


## ویترین سه‌بعدی در یک SubViewport مستقل می‌نشیند تا UI واقعیِ Control روی آن
## overlay شود و در صورت خاموش‌بودن renderer هم fallbackِ پس‌زمینه‌ی رنگی بماند.
func _build_clay_showcase() -> void:
	var host := SubViewportContainer.new()
	host.name = "ClayShowcase"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.stretch = true
	host.z_index = 0
	UIKit.anchor_full(host)
	var viewport := SubViewport.new()
	viewport.name = "ClayViewport"
	viewport.size = Vector2i(1080, 1920)
	viewport.transparent_bg = false
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)
	var world := ClayWorldStage3D.new()
	world.name = "ClayWorld"
	viewport.add_child(world)
	add_child(host)
	move_child(host, 0)


func _add(box: VBoxContainer, key: String, tone: String) -> Button:
	var btn: Button = UIKit.make_button(key, tone)
	btn.pressed.connect(_on_pressed.bind(key))
	box.add_child(btn)
	buttons.append(btn)
	return btn


## برچسبِ دکمه‌ی اصلی از وضعیت واقعی مدل می‌آید، نه از حدس: «ادامه» فقط وقتی که
# واقعاً چیزی برای ادامه باشد.
func refresh() -> void:
	if primary_button == null:
		return
	var mode: String = primary_action()
	var key: String = "menu.play"
	if mode == "onboarding":
		key = "onboarding.start"
	elif mode == "continue":
		key = "menu.continue"
	# کلید را در **متا** می‌نویسیم، نه متن را: `retranslate()` همین متا را می‌خواند و
	# اگر مستقیم متن ست می‌شد، سطرِ بعد پاکش می‌کرد (باگی که «ادامه‌ی بازی» را به
	# «شروع بازی» برمی‌گرداند) ✓ و با عوض‌شدن زبان هم برچسب درست می‌ماند.
	primary_button.set_meta(&"loc_key", key)
	UIKit.retranslate(self)
	for btn: Button in buttons:
		if btn.name == "menu_quit":
			# در تست/هدلس دکمه هست ولی بی‌اثر (`quit_game()` خارج می‌شود) ⇒ «کرش ندادن»
			# در DoD یعنی حتی یک فشارِ تصادفی هم بازی را نیمه‌کاره نبندد.
			btn.disabled = not allow_quit


func has_progress() -> bool:
	var model: PlayerModel = GameState.active_model
	if model == null:
		return false
	return not model.levels_completed.is_empty() or not model.current_level.is_empty()


func needs_onboarding() -> bool:
	# ترتیب عمدی: **رکورد** مقدم بر پرچم است. `is_first_run` فقط «ذخیره‌ای نبود» را
	# می‌گوید؛ اگر رکورد اتمام نوشته شده باشد همان منبع حقیقتِ پایدار است و کودک
	# نباید دوباره پشت آموزش برود (`finish()` هر دو را با هم می‌نویسد ✓).
	if bool(SettingsStore.get_value("onboarding_done")):
		return false
	return GameState.is_first_run


func primary_action() -> String:
	if needs_onboarding():
		return "onboarding"
	return "continue" if has_progress() else "new"


## سطحی که «ادامه» باید باز کند: `current_level` اگر هنوز تمام نشده، وگرنه انتخاب
## موتور دشواری (با kill-switch والدین = ترتیب روایی).
func next_level_id() -> String:
	var model: PlayerModel = GameState.active_model
	if model != null and not model.current_level.is_empty() \
			and not model.is_level_completed(model.current_level):
		return model.current_level
	var from_engine: String = DifficultyEngine.pick_next_level_id(GameState.current_level_id)
	if not from_engine.is_empty():
		return from_engine
	var ids: Array[String] = LevelLoader.level_ids()
	return ids[0] if not ids.is_empty() else ""


# --------------------------------------------------------------------------
# اکشن‌ها (از بیرون هم قابل‌فراخوانی‌اند: تست، HUD، دکمه‌ی بازگشت)
# --------------------------------------------------------------------------
func play() -> void:
	var mode: String = primary_action()
	play_requested.emit(mode)
	if not allow_scene_change:
		return
	if mode == "onboarding":
		_go_to(ONBOARDING_PATH)
		return
	var id: String = next_level_id()
	if id.is_empty():
		_go_to(LevelLoader.WORLD_MAP_PATH)
		return
	if not LevelLoader.start_level(id):
		Log.warn(TAG, "سطح %s باز نشد: %s" % [id, LevelLoader.last_error])
		_go_to(LevelLoader.WORLD_MAP_PATH)


func goto_map() -> void:
	map_requested.emit()
	if not allow_scene_change:
		return
	if not LevelLoader.goto_map():
		Log.warn(TAG, "بازگشت به نقشه نشد: " + LevelLoader.last_error)


func goto_settings() -> void:
	settings_requested.emit()
	if allow_scene_change:
		_go_to(SETTINGS_PATH)


func goto_parent_dashboard() -> void:
	parent_dashboard_requested.emit()
	if allow_scene_change:
		_go_to(PARENT_DASHBOARD_PATH)


func quit_game() -> void:
	quit_requested.emit()
	if not allow_quit:
		return
	GameState.commit_playtime()
	SaveSystem.flush()
	get_tree().quit()


func _go_to(path: String) -> void:
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		# صحنه‌ی فازهای بعد هنوز نساخته شده؟ منو نباید صفحه‌ی سیاه بدهد.
		Log.warn(TAG, "رفتن به %s شکست خورد (خطای %d)" % [path, err])


func _on_pressed(key: String) -> void:
	match key:
		"menu.play":
			play()
		"menu.settings":
			goto_settings()
		"menu.parents":
			goto_parent_dashboard()
		"menu.quit":
			quit_game()
		_:
			Log.debug(TAG, "دکمه‌ی بدون اکشن: " + key)
