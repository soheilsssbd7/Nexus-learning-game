extends GutTest
# ===========================================================================
# تسک ۶.۳ — SettingsMenu: اثر فوری روی موتور، نه «متن ذخیره شد»
# ---------------------------------------------------------------------------
# هر اسلایدر/دکمه باید سه جا هم‌زمان درست باشد: `SettingsStore` (دیسک)، موتور
# (AudioServer/Loc/DifficultyEngine) و خودِ ویجت (refresh). تست‌ها هر سه را می‌خوانند؛
# جالب‌ترین‌شان تعویض **زندهٔ زبان** است: «i18n placeholder» یعنی برچسب‌های همین
# صحنه‌ی باز، وسط اجرا، عوض شوند.
# ===========================================================================

const SETTINGS_SCENE := "res://scenes/ui/SettingsMenu.tscn"
const TMP := "user://test_settings_menu.json"

var _saved_model: PlayerModel = null


func before_each() -> void:
	_saved_model = GameState.active_model
	SettingsStore.reset_for_tests()
	SettingsStore.load_from(TMP)


func after_each() -> void:
	GameState.active_model = _saved_model
	SettingsStore.reset()
	SettingsStore.apply_audio()
	Loc.set_locale(Loc.default_locale())
	SettingsStore.reset_for_tests()
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(TMP.get_file()):
		dir.remove(TMP.get_file())


func _make() -> SettingsMenu:
	var packed: PackedScene = load(SETTINGS_SCENE)
	assert_not_null(packed, "SettingsMenu.tscn باید بارگذاری شود")
	var menu: SettingsMenu = packed.instantiate() as SettingsMenu
	assert_not_null(menu, "ریشه باید SettingsMenu باشد")
	menu.allow_scene_change = false
	add_child_autofree(menu)
	return menu


func test_the_widgets_exist_and_are_touch_ready() -> void:
	var menu := _make()
	assert_not_null(menu.music_slider, "§۶.۳: موسیقی")
	assert_not_null(menu.sfx_slider, "§۶.۳: جلوه‌ها")
	assert_not_null(menu.haptics_toggle)
	assert_eq(menu.locale_buttons.size(), 2, "fa + en (placeholderِ چندزبانه)")
	assert_true(UIKit.audit_touch_targets(menu).is_empty(),
		str(UIKit.audit_touch_targets(menu)))


func test_the_widgets_show_what_is_stored() -> void:
	assert_true(SettingsStore.set_value("music_volume", 0.3))
	assert_true(SettingsStore.set_value("haptics_enabled", false))
	var menu := _make()
	assert_almost_eq(menu.music_slider.value, 0.3, 0.001,
		"اولین بازکردن تنظیمات باید واقعیت را نشان بدهد، نه پیش‌فرض را")
	assert_false(menu.haptics_toggle.button_pressed)
	menu.music_slider.grab_focus()  # بی‌ضرر: focus_mode=NONE است و نباید حالت را عوض کند
	assert_eq(menu.music_slider.focus_mode, Control.FOCUS_NONE)


func test_moving_a_slider_changes_the_bus_and_the_file() -> void:
	var menu := _make()
	watch_signals(menu)
	menu.music_slider.value = 0.0
	assert_almost_eq(float(SettingsStore.get_value("music_volume")), 0.0, 0.001)
	var music_bus: int = SettingsStore.bus_index(SettingsStore.BUS_MUSIC)
	assert_gte(music_bus, 1)
	assert_true(AudioServer.is_bus_mute(music_bus), "صفر یعنی بی‌صدا، همان‌جا")
	menu.sfx_slider.value = 0.55
	assert_almost_eq(float(SettingsStore.get_value("sfx_volume")), 0.55, 0.001)
	assert_false(AudioServer.is_bus_mute(SettingsStore.bus_index(SettingsStore.BUS_SFX)))
	assert_signal_emitted(menu, "value_changed")
	# روی دیسک هم نشسته (نه فقط در حافظه) — فردا که بازی بسته شد صدای کودک می‌ماند
	var f := FileAccess.open(TMP, FileAccess.READ)
	assert_not_null(f, "تنظیمات باید در فایل خودش نوشته شود، نه در PlayerModel")
	if f != null:
		var raw: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		assert_true(raw is Dictionary, str(raw))
		if raw is Dictionary:
			assert_almost_eq(float((raw as Dictionary).get("music_volume", -1.0)), 0.0, 0.001)
			assert_false((raw as Dictionary).has("levels_completed"),
				"فایل تنظیمات نباید به دادهٔ بازی دست بزند (ADR-045)")


func test_language_switch_is_live_in_the_open_panel() -> void:
	var menu := _make()
	var title: Label = menu.get_node("Panel/Rows/settings_title") as Label
	assert_not_null(title)
	if title == null:
		return
	assert_eq(title.text, Loc.t("settings.title"))
	assert_eq(title.text, "تنظیمات")
	var en: Button = menu.locale_buttons[1]
	assert_eq(str(en.get_meta(&"locale_code")), "en")
	en.pressed.emit()
	assert_eq(Loc.locale(), "en", "locale از تنظیمات به Loc می‌رسد")
	assert_eq(title.text, Loc.t("settings.title"), "برچسبِ همان صحنه‌ی باز عوض شد")
	assert_eq(title.text, "Settings")
	assert_true(en.disabled, "دکمهٔ زبانِ فعال غیرفعال است تا دوباره فشار داده نشود")
	var fa: Button = menu.locale_buttons[0]
	assert_false(fa.disabled)
	fa.pressed.emit()
	assert_eq(Loc.locale(), "fa")
	assert_eq(title.text, "تنظیمات")
	assert_eq(str(SettingsStore.get_value("locale")), "fa", "انتخاب زبان ذخیره هم می‌شود")


func test_restore_defaults_touches_preferences_not_progress() -> void:
	var model := PlayerModel.create_new("آزمون")
	model.mark_level_completed("tier1_level_01", 40.0, 1)
	GameState.active_model = model
	var menu := _make()
	menu.music_slider.value = 0.15
	assert_true(bool(SettingsStore.set_value("onboarding_done", true)))
	menu.restore_defaults()
	assert_almost_eq(float(SettingsStore.get_value("music_volume")), 0.8, 0.001)
	assert_false(bool(SettingsStore.get_value("onboarding_done")),
		"پیش‌فرضِ تنظیمات یعنی «آموزش دیده نشده» هم برمی‌گردد")
	assert_eq(model.levels_completed.size(), 1,
		"«بازگردانی پیش‌فرض» نباید بازی کودک را پاک کند — آن یک عمل ویرانگر است")


func test_the_parent_kill_switch_is_not_in_the_child_menu() -> void:
	# §۶.۵: «پیشرفت خودکار» تصمیم والد است و پشت parent-gate می‌ماند؛ اگر روزی این‌جا
	# یک کنترل برای ساخته شود، کودک می‌تواند سختی بازی را خاموش کند.
	var menu := _make()
	var found: Array[String] = []
	for child: Node in menu.find_children("*", "Control", true, false):
		if child is Button and (child as Object).has_meta(&"loc_key"):
			var key: String = str((child as Object).get_meta(&"loc_key"))
			if key.begins_with("settings.adaptive"):
				found.append(key)
	assert_true(found.is_empty(), "کنترل والدین در منوی کودک: " + str(found))
	# توضیحش برای کودک هست (فقط فهماند)، ولی هیچ ورودی‌ای ندارد
	var hint: Label = menu.get_node_or_null("Panel/Rows/settings_adaptive_hint") as Label
	assert_not_null(hint, "متنِ توضیحی باید بماند تا والد بداند کجاست")


func test_close_in_embedded_mode_only_hides() -> void:
	var menu := _make()
	menu.embedded = true
	watch_signals(menu)
	menu.close()
	assert_signal_emitted(menu, "closed")
	assert_true(is_instance_valid(menu), "overlay سوارشده را free نمی‌کنیم (PauseMenu به آن ارجاع دارد)")
	assert_false(menu.visible)
