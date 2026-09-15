extends GutTest
# ===========================================================================
# تسک ۶.۱ — MainMenu: DoD «ناوبری از منو به بازی و بازگشت بدون کرش»
# ---------------------------------------------------------------------------
# صحنه‌ها با allow_scene_change=false ساخته می‌شوند (ADR-035) تا درخت GUT نشکند؛
# چیزی که سنجیده می‌شود «تصمیم منو» + «همه‌ی مسیرها سیگنال دارند» + «§۷ روی صحنه».
# ===========================================================================

const MENU_SCENE := "res://scenes/main/MainMenu.tscn"
const MAP_SCENE := "res://scenes/main/WorldMap.tscn"

var _saved_first_run: bool = true
var _saved_model: PlayerModel = null


func before_each() -> void:
	_saved_first_run = GameState.is_first_run
	_saved_model = GameState.active_model
	SettingsStore.reset_for_tests()
	SettingsStore.load_from()


func after_each() -> void:
	GameState.is_first_run = _saved_first_run
	GameState.active_model = _saved_model
	SettingsStore.reset_for_tests()


func _make() -> MainMenu:
	var packed: PackedScene = load(MENU_SCENE)
	assert_not_null(packed, "MainMenu.tscn باید بارگذاری شود")
	var menu: MainMenu = packed.instantiate() as MainMenu
	assert_not_null(menu, "ریشه‌ی صحنه باید MainMenu باشد")
	menu.allow_scene_change = false
	menu.allow_quit = false
	add_child_autofree(menu)
	return menu


## مدلِ ساختگی، بی‌دست‌زدن روی دیسک: منو فقط از `GameState.active_model` می‌خواند.
func _model_with(levels: Array, current_level: String) -> PlayerModel:
	var m := PlayerModel.create_new("آزمون")
	var ids: Array[String] = []
	ids.append_array(levels)
	m.levels_completed = ids
	m.current_level = current_level
	GameState.active_model = m
	return m


func test_the_scene_is_built_and_touch_ready() -> void:
	var menu := _make()
	assert_gte(menu.buttons.size(), 4, "play/settings/parents/quit")
	for btn: Button in menu.buttons:
		assert_gte(btn.custom_minimum_size.y, UIKit.MIN_TOUCH_PX,
			str(btn.name) + " زیر کفِ لمسی §۷ است")
		assert_false(btn.text.is_empty(), str(btn.name) + " بی‌متن است")
		assert_ne(btn.text, str(btn.name), "متن باید از Loc آمده باشد، نه کلید خام")
		assert_eq(btn.text_direction, Control.TEXT_DIRECTION_RTL)
	assert_true(UIKit.audit_touch_targets(menu).is_empty(),
		"ممیزی DoD: " + str(UIKit.audit_touch_targets(menu)))


func test_first_run_sends_the_child_to_onboarding() -> void:
	var menu := _make()
	GameState.is_first_run = true
	_model_with([], "")
	menu.refresh()
	assert_eq(menu.primary_action(), "onboarding")
	assert_eq(menu.primary_button.text, Loc.t("onboarding.start"))
	watch_signals(menu)
	menu.play()
	# اولین اجرا نباید مستقیم وسط یک سطح پرتاب شود (پارامتر چهارم GUT = index، نه پیام)
	assert_signal_emitted_with_parameters(menu, "play_requested", ["onboarding"])


func test_onboarding_done_is_persisted_and_honoured() -> void:
	var menu := _make()
	GameState.is_first_run = true
	assert_true(menu.needs_onboarding())
	assert_true(SettingsStore.set_value("onboarding_done", true))
	assert_false(menu.needs_onboarding(), "رکوردِ «دیدمش» هم معتبر است، نه فقط اولین اجرا")
	assert_true(SettingsStore.set_value("onboarding_done", false))


func test_continue_label_only_appears_when_there_is_something_to_continue() -> void:
	var menu := _make()
	GameState.is_first_run = false
	SettingsStore.reset_for_tests()
	SettingsStore.set_value("onboarding_done", true)
	assert_false(menu.has_progress(), "مدل خالی = پیشرفتی نیست")
	menu.refresh()
	assert_eq(menu.primary_action(), "new")
	assert_eq(menu.primary_button.text, Loc.t("menu.play"))

	# همه‌ی سطوح تمام شده و سطحِ ناتمامی نیست: «ادامه» یعنی «برو سراغ انتخاب بعدی
	# موتور»، پس برچسب عوض نمی‌شود — کودک نباید فکر کند بازی تمام شده است.
	_model_with(["tier1_level_01"], "tier1_level_01")
	menu.refresh()
	assert_true(menu.has_progress())
	assert_eq(menu.primary_action(), "continue")
	assert_eq(menu.primary_button.text, Loc.t("menu.continue"))

	_model_with(["tier1_level_01"], "tier1_level_02")
	menu.refresh()
	assert_eq(menu.primary_action(), "continue")
	assert_eq(menu.primary_button.text, Loc.t("menu.continue"))


func test_continue_reopens_the_unfinished_level() -> void:
	var menu := _make()
	GameState.is_first_run = false
	SettingsStore.set_value("onboarding_done", true)
	var m: PlayerModel = _model_with(["tier1_level_01"], "tier1_level_03")
	assert_eq(menu.next_level_id(), "tier1_level_03", "«ادامه» یعنی همان‌جا که رها کرد")
	m.mark_level_completed("tier1_level_03", 40.0, 0)
	assert_ne(menu.next_level_id(), "", "بعد از تمام‌شدن، یک سطح دیگر باید انتخاب شود")
	assert_ne(menu.next_level_id(), "tier1_level_03", "سطحِ تمام‌شده نباید دوباره باز شود")


func test_the_other_buttons_route_without_touching_the_tree() -> void:
	var menu := _make()
	watch_signals(menu)
	menu.goto_map()
	menu.goto_settings()
	menu.goto_parent_dashboard()
	menu.quit_game()
	assert_eq(get_signal_emit_count(menu, "map_requested"), 1)
	assert_eq(get_signal_emit_count(menu, "settings_requested"), 1)
	assert_eq(get_signal_emit_count(menu, "parent_dashboard_requested"), 1)
	assert_eq(get_signal_emit_count(menu, "quit_requested"), 1)
	assert_false(get_tree().root.is_queued_for_deletion(),
		"با allow_quit=false خروج نباید صدا شود")


func test_pressing_a_button_uses_the_same_actions() -> void:
	var menu := _make()
	watch_signals(menu)
	var quit_button: Button = menu.get_node("Buttons/menu_quit") as Button
	assert_not_null(quit_button, "نام گره از کلید Loc ساخته می‌شود تا تست بتواند پیدایش کند")
	if quit_button == null:
		return
	assert_true(quit_button.disabled, "در تست quit غیرفعال است ⇒ فشار بی‌اثر")
	quit_button.disabled = false
	quit_button.pressed.emit()
	assert_eq(get_signal_emit_count(menu, "quit_requested"), 1, "پرس = همان اکشن")


func test_the_navigation_targets_exist_and_instantiate() -> void:
	# DoD «ناوبری … بدون کرش» یعنی هر مقصدی که منو وعده می‌دهد باید واقعی باشد.
	for path: String in [MAP_SCENE, MainMenu.SETTINGS_PATH, MainMenu.PARENT_DASHBOARD_PATH,
			MainMenu.ONBOARDING_PATH]:
		var packed: PackedScene = load(path)
		assert_not_null(packed, "صحنه‌ی مقصد نیست: " + path)
		if packed == null:
			continue
		var node: Node = packed.instantiate()
		assert_not_null(node, "اینستانس نشد: " + path)
		if node != null:
			autofree(node)


func test_the_map_can_go_back_to_the_menu() -> void:
	var packed: PackedScene = load(MAP_SCENE)
	assert_not_null(packed)
	if packed == null:
		return
	var map: WorldMap = packed.instantiate() as WorldMap
	map.allow_scene_change = false
	add_child_autofree(map)
	var back: Button = map.get_node_or_null("BackToMenu") as Button
	assert_not_null(back, "§۶.۱: بازگشتِ دوطرفه — نقشه نباید بن‌بست باشد")
	if back == null:
		return
	watch_signals(map)
	back.pressed.emit()
	assert_signal_emitted(map, "menu_requested")
	assert_true(UIKit.audit_touch_targets(map).is_empty(),
		"دکمه‌های نقشه هم زیر کفِ لمسی نباشند: " + str(UIKit.audit_touch_targets(map)))
