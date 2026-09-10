extends GutTest
# ===========================================================================
# تسک ۳.۲ — LevelLoader: DoD «load_level(...) صحنه‌ی بازی قابل‌بازی می‌سازد»
# + DoD فاز ۳: «منحنی difficulty_elo افزایشی» (همان چیزی که در Python هم چک می‌شود
#   تا داده‌ی تازه از هیچ‌کدام از دو طرف فرار نکند).
# ===========================================================================

const ELO_JUMP_LIMIT: int = 120


func test_path_for_maps_id_to_file() -> void:
	assert_eq(LevelLoader.path_for("tier1_level_01"), "res://data/levels/tier1/level_1_01.json")
	assert_eq(LevelLoader.path_for("tier3_level_07"), "res://data/levels/tier3/level_3_07.json")
	assert_eq(LevelLoader.path_for("tier5_level_10"), "res://data/levels/tier5/level_5_10.json")


func test_path_for_rejects_bad_ids() -> void:
	for bad: String in ["", "level_1", "tier0_level_01", "tier6_level_01", "tier1_level_1",
		"tier1_level_011", "tier1_level_ab", "Tier1_level_01"]:
		assert_eq(LevelLoader.path_for(bad), "", "باید رد می‌شد: %s" % bad)
		assert_false(LevelLoader.is_valid_id_format(bad))


func test_level_ids_are_discovered_sorted() -> void:
	var ids: Array[String] = LevelLoader.level_ids()
	assert_gt(ids.size(), 4, "پنج سطح Tier 1 نوشته شده است")
	assert_true(ids.has("tier1_level_01"))
	assert_true(ids.has("tier1_level_05"))
	var sorted_ids: Array[String] = ids.duplicate()
	sorted_ids.sort()
	assert_eq(ids, sorted_ids, "ترتیب = Tier سپس شماره (قفل روایت GDD §۵)")
	assert_eq(ids[0], "tier1_level_01")


## شمارش از **دیسک** گرفته می‌شود، نه از عددِ دست‌نویس: هر سطحِ تازه‌ای که در فاز ۷
## نوشته شود، بدون ویرایش این فایل سنجیده می‌شود (عددِ ثابت یعنی «تستی که باید یادمان
## بیاید به‌روز شود» — همان دامی که یک بار در فاز ۵ گرفتیم ✗).
func _files_on_disk(tier: int) -> int:
	var dir: DirAccess = DirAccess.open("res://data/levels/tier%d" % tier)
	if dir == null:
		return 0
	var count: int = 0
	for file: String in dir.get_files():
		if file.ends_with(".json") and file.begins_with("level_"):
			count += 1
	return count


func test_levels_for_tier_filters() -> void:
	var tier1: Array[String] = LevelLoader.levels_for_tier(1)
	assert_eq(tier1.size(), _files_on_disk(1), "موتور باید همان تعدادِ فایلِ Tier 1 را ببیند")
	for id: String in tier1:
		assert_true(id.begins_with("tier1_"))
	assert_eq(LevelLoader.levels_for_tier(2).size(), _files_on_disk(2),
		"Tier 2 در فاز ۷ نوشته می‌شود؛ گارد باید با دیسک بخواند، نه با صفرِ ثابت")
	assert_gte(LevelLoader.levels_for_tier(2).size(), 1, "فاز ۷: Tier 2 خالی نماند")


## `tier` از **پیشوندِ id** و پوشه مثلث‌سنجی می‌شود (فاز ۳ فرض می‌کرد همه‌چیز Tier 1 است ✗✓
## ⇒ با اولین Tierِ تازه، آن `assert_eq(lv.tier, 1)` می‌شد «تستی که داده را ممنوع می‌کند»).
func _tier_of(id: String) -> int:
	return id.trim_prefix("tier").split("_")[0].to_int()


func _files_on_disk_all() -> int:
	var total: int = 0
	for tier: int in range(1, 6):
		total += _files_on_disk(tier)
	return total


func test_every_authored_level_loads_and_validates() -> void:
	var previous_elo: int = -1
	var previous_tier: int = -1
	var loaded: int = 0
	for id: String in LevelLoader.level_ids():
		var lv: LevelData = LevelLoader.load_level(id, false)
		assert_not_null(lv, "%s باید خوانده شود (خطا: %s)" % [id, LevelLoader.last_error])
		if lv == null:
			continue
		assert_eq(lv.validate().size(), 0, "%s داده‌ی ناسازگار دارد: %s" % [id, str(lv.validate())])
		assert_eq(lv.level_id, id)
		assert_eq(lv.tier, _tier_of(id), "%s: فیلد `tier` با پیشوندِ `level_id` نمی‌خواند" % id)
		assert_true(id.begins_with("tier%d_" % lv.tier), "%s: id زیرِ Tier خودش نیست" % id)
		assert_gt(lv.available_count(), 0, "%s سینی خالی ندارد" % id)
		if previous_elo >= 0 and lv.tier == previous_tier:
			# نردبانِ **داخل** هر Tier؛ رابطه‌ی بین Tierها را test_all_content_playable
			# می‌سنجد (مرز Tier مجاز است ۱ پله بالا برود ⇒ اینجا چک‌کردنش خطای ساختگی بود ✗)
			var jump: int = lv.difficulty_elo - previous_elo
			assert_true(jump >= 0 and jump <= ELO_JUMP_LIMIT,
				"منحنی دشواری باید افزایشی و بدون پرش باشد (%d→%d)" % [previous_elo, lv.difficulty_elo])
	previous_elo = lv.difficulty_elo
	previous_tier = lv.tier
	loaded += 1
	assert_eq(loaded, _files_on_disk_all(), "هر فایلِ روی دیسک باید بارگذاری شود")
	assert_eq(LevelLoader.last_error, "", "هیچ مسیری نباید خطا رد کند")


func test_cache_returns_the_same_instance_until_cleared() -> void:
	LevelLoader.clear_cache()
	var a: LevelData = LevelLoader.load_level("tier1_level_01")
	var b: LevelData = LevelLoader.load_level("tier1_level_01")
	assert_not_null(a)
	assert_same(a, b, "بار دوم باید از کش بیاید (بازی آفلاین = فایل ثابت)")
	LevelLoader.clear_cache()
	var c: LevelData = LevelLoader.load_level("tier1_level_01")
	assert_not_same(a, c, "clear_cache() باید نسخه‌ی تازه بدهد")


func test_missing_level_is_reported_without_crashing() -> void:
	watch_signals(LevelLoader)
	# هیچ‌کدام از این مسیرها push_error نمی‌زنند (ADR-023)؛ اگر می‌زدند GUT fail می‌کرد
	assert_null(LevelLoader.load_level("nonsense"))
	assert_true(LevelLoader.last_error.contains("نامعتبر"), str(LevelLoader.last_error))
	assert_null(LevelLoader.load_level("tier5_level_77"))
	assert_true(LevelLoader.last_error.contains("وجود ندارد"), str(LevelLoader.last_error))
	assert_eq(LevelLoader.load_config("tier5_level_77"), {})
	assert_signal_emitted(LevelLoader, "level_load_failed")


func test_load_config_gives_the_controller_shape() -> void:
	var cfg: Dictionary = LevelLoader.load_config("tier1_level_01")
	assert_eq(cfg.get("level_id"), "tier1_level_01")
	assert_true(cfg.has("scales"))
	assert_true(cfg.has("available_orbs"))


func test_create_level_scene_builds_from_data() -> void:
	var scene: LevelController = LevelLoader.create_level_scene("tier1_level_02") as LevelController
	assert_not_null(scene, "خطا: %s" % LevelLoader.last_error)
	if scene == null:
		return
	scene.attempt_settle_sec = 0.05
	add_child_autofree(scene)
	assert_eq(scene.level_id, "tier1_level_02")
	assert_eq(scene.scales[0].left_weight(), 6.0, "4 + 2 از JSON")
	assert_eq(scene.scales[0].right_weight(), 0.0)
	assert_eq(scene.tray_orbs.size(), 14, "8 تا ۱، 4 تا ۲، 2 تا ۳")
	assert_ne(scene.intro_label.text, "")


func test_create_level_scene_returns_null_for_bad_id() -> void:
	assert_null(LevelLoader.create_level_scene("tier1_level_99"))
	assert_ne(LevelLoader.last_error, "")


func test_pending_config_is_consumed_once() -> void:
	LevelLoader.clear_pending_config()
	assert_eq(LevelLoader.take_pending_config(), {}, "اول باید خالی باشد")
	LevelLoader.pending_config = {
		"level_id": "injected_from_loader",
		"tier": 1,
		"tolerance": 0.0,
		"scales": [{"id": "main", "left_orbs": [{"type": "number", "value": 2.0}]}],
		"available_orbs": [{"type": "number", "value": 2.0, "count": 1}],
	}
	var scene: LevelController = load("res://scenes/gameplay/LevelScene.tscn").instantiate() as LevelController
	scene.attempt_settle_sec = 0.05
	add_child_autofree(scene)
	assert_eq(scene.level_id, "injected_from_loader",
		"LevelScene باید config را از صفِ LevelLoader در _ready بگیرد (تسک ۳.۲)")
	assert_eq(scene.scales[0].left_weight(), 2.0)
	assert_eq(LevelLoader.take_pending_config(), {}, "مصرف‌شده باید پاک شود")


func test_first_unfinished_and_next_of_use_the_real_order() -> void:
	var ids: Array[String] = LevelLoader.level_ids()
	var model := PlayerModel.new()
	autofree(model)
	assert_eq(LevelLoader.first_unfinished_id(model), ids[0], "هیچ سطحی حل نشده → اولی")
	model.mark_level_completed(ids[0], 12.0, 0)
	assert_eq(LevelLoader.first_unfinished_id(model), ids[1], "بعد از حل اولی → دومی")
	assert_eq(LevelLoader.next_of(ids[0]), ids[1])
	assert_eq(LevelLoader.next_of(ids[ids.size() - 1]), "", "آخرین سطح سطح بعدی ندارد")
	assert_eq(LevelLoader.next_of("tier1_level_42"), "", "id ناشناخته")
