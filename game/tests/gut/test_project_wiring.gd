extends GutTest
# ===========================================================================
# نگهبان «سازماندهی پروژه» — خروجی مستقیم دو باگ واقعی فاز ۲/۳ که L1 نمی‌گرفت:
#   ۱) `#` در project.godot (فرمت INI فقط `;` می‌شناسد) → کلیدهای بعد از آن، از
#      جمله خودِ autoload، بی‌صدا دور ریخته می‌شوند: CI سبز بود ولی `LevelLoader`
#      در هیچ اسکریپتی resolve نمی‌شد و چهار فایل تست کاملاً اجرا نشدند.
#   ۲) ثبت autoload در پروژه ≠ بارگذاری آن؛ پس هم نام در root هست، هم کلاس.
# ===========================================================================

const PROJECT_FILE := "res://project.godot"


func test_project_godot_has_no_hash_comments() -> void:
	assert_true(FileAccess.file_exists(PROJECT_FILE), "پروژه باید project.godot داشته باشد")
	var f := FileAccess.open(PROJECT_FILE, FileAccess.READ)
	if f == null:
		return
	var text: String = f.get_as_text()
	f.close()
	var lines: Array[String] = text.split("\n")
	for i: int in range(lines.size()):
		var line: String = lines[i].strip_edges()
		assert_false(line.begins_with("#"),
			"سطر %d: کامنت project.godot فقط با ';' مجاز است (`%s`)" % [i + 1, line.left(48)])


func test_every_registered_autoload_exists_in_the_tree() -> void:
	var keys: String = ""
	for prop: Dictionary in ProjectSettings.get_property_list():
		var pname: String = str(prop.get("name", ""))
		if pname.begins_with("autoload/"):
			keys += pname.trim_prefix("autoload/") + "\n"
	assert_gt(keys.length(), 0, "حداقل یک autoload ثبت شده باشد")
	var expected: Array[String] = []
	for name: String in keys.split("\n"):
		if not name.strip_edges().is_empty():
			expected.append(name.strip_edges())
	assert_true(expected.has("EventBus"), "EventBus باید autoload باشد (تسک ۱.۱)")
	assert_true(expected.has("Log"))
	assert_true(expected.has("SaveSystem"))
	assert_true(expected.has("GameState"))
	assert_true(expected.has("LevelLoader"), "LevelLoader در فاز ۳ ثبت می‌شود (تسک ۳.۲)")
	var root_node: Node = get_tree().root
	for name: String in expected:
		assert_not_null(root_node.get_node_or_null(NodePath(name)),
			"autoload `%s` در پروژه هست ولی در درخت ساخته نشد — پروژه خراب است" % name)


func test_main_scene_exists_and_is_instantiable() -> void:
	var main: String = str(ProjectSettings.get_setting("application/run/main_scene"))
	assert_false(main.is_empty(), "main_scene باید تنظیم شده باشد (فاز ۳: WorldMap)")
	assert_true(ResourceLoader.exists(main), "main_scene به فایلی اشاره نمی‌کند: %s" % main)
	if not ResourceLoader.exists(main):
		return
	var packed: PackedScene = load(main)
	assert_not_null(packed)
	var instance: Node = packed.instantiate()
	assert_not_null(instance)
	if instance != null:
		autofree(instance)


func test_phase_2_and_3_scene_files_are_loadable() -> void:
	for path: String in [
		"res://scenes/gameplay/LevelScene.tscn",
		"res://scenes/gameplay/BalanceScale.tscn",
		"res://scenes/gameplay/WeightOrb.tscn",
		"res://scenes/main/WorldMap.tscn",
	]:
		assert_true(ResourceLoader.exists(path), "صحنه‌ی لازم غایب است: %s" % path)
		var inst: Node = load(path).instantiate()
		assert_not_null(inst, "%s باید instantiate شود" % path)
		if inst != null:
			autofree(inst)
