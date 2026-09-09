extends GutTest
# ===========================================================================
# تسک ۳.۱ — DoD: «فایل JSON نمونه پارس می‌شود، تمام فیلدها صحیح می‌خوانند»
# ===========================================================================

const SAMPLE_PATH := "res://data/levels/tier1/level_1_01.json"
const LEVEL_SCENE := "res://scenes/gameplay/LevelScene.tscn"


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, "فایل نمونه باید در پروژه باشد: %s" % path)
	if f == null:
		return ""
	var text: String = f.get_as_text()
	f.close()
	return text


func test_every_schema_field_is_read() -> void:
	var result: Dictionary = LevelData.from_json_text(_read(SAMPLE_PATH), SAMPLE_PATH)
	assert_true(bool(result["ok"]), "sample باید بدون خطا پارس شود: %s" % str(result["error"]))
	var lv: LevelData = result["level"]
	assert_eq(lv.level_id, "tier1_level_01")
	assert_eq(lv.tier, 1)
	assert_eq(lv.world, "balance_realm")
	assert_eq(lv.concept_tags.size(), 2)
	# ADR-039: کلید مهارت باید با `docs/07-GDD-BALANCE-REALM.md` §۴ هم‌نام باشد، پس
	# «addition» شد «addition_basic» — نمونه‌ی §۱ سند ۰۳ فقط *ساختار* را تعریف می‌کند.
	assert_true(lv.concept_tags.has("addition_basic"), str(lv.concept_tags))
	assert_gt(lv.narrative_intro.length(), 10)
	assert_eq(lv.left_fixed_orbs.size(), 2)
	assert_eq(lv.left_weight(), 8.0, "3 + 5")
	assert_true(lv.has_target)
	assert_eq(lv.target_value, 8.0)
	assert_eq(lv.right_fixed_orbs.size(), 0)
	assert_eq(lv.available_orbs.size(), 3)
	assert_eq(lv.available_count(), 18, "10 تا ۱، 5 تا ۲، 3 تا ۵")
	assert_eq(lv.tolerance, 0.0)
	assert_eq(lv.hint_sequence.size(), 3)
	assert_eq(lv.expected_solve_time_sec, 40.0)
	assert_eq(lv.difficulty_elo, 900)
	assert_true(lv.solution_spec.has("intended"), "solution_spec از ADR-006 باید خوانده شود")
	assert_eq(lv.required_right_weight(), 8.0)


func test_int_and_float_json_values_are_coerced() -> void:
	# JSON «1» را int و «1.0» را float می‌دهد؛ هر دو باید به نوع اعلان‌شده برسند (درس فاز ۱)
	var lv: LevelData = LevelData.from_dict({
		"level_id": "tier1_level_02",
		"tier": 1.0,
		"difficulty_elo": 940.0,
		"tolerance": 0,
		"world": "balance_realm",
		"concept_tags": ["addition"],
		"narrative_intro": "یک جمله‌ی روایی به‌اندازه‌ی مجاز.",
		"left_side": {"fixed_orbs": [{"type": "number", "value": 6}]},
		"right_side": {"target_value": 6, "available_orbs": [{"type": "number", "value": 2, "count": 3}]},
		"hint_sequence": [{"trigger": "idle_45s", "hint_id": "gentle_nudge_01"}],
	})
	assert_eq(lv.tier, 1)
	assert_true(typeof(lv.tier) == TYPE_INT, "tier باید int باشد نه float")
	assert_eq(lv.difficulty_elo, 940)
	assert_eq(lv.target_value, 6.0)
	assert_true(typeof(lv.target_value) == TYPE_FLOAT)
	assert_eq(lv.validate().size(), 0, "داده‌ی سالم باید بدون خطا باشد: %s" % str(lv.validate()))


func test_to_config_dict_gives_the_adr028_contract() -> void:
	var lv: LevelData = LevelData.from_json_text(_read(SAMPLE_PATH), SAMPLE_PATH).get("level")
	var cfg: Dictionary = lv.to_config_dict()
	assert_eq(cfg.get("level_id"), "tier1_level_01")
	assert_eq(cfg.get("tier"), 1)
	assert_true(cfg.get("scales") is Array, "کلید scales (قرارداد ADR-028)")
	var scale: Dictionary = (cfg["scales"] as Array)[0]
	assert_eq(scale.get("id"), "main")
	assert_eq((scale.get("left_orbs") as Array).size(), 2)
	assert_eq(scale.get("target_value"), 8.0)
	assert_eq((cfg.get("available_orbs") as Array).size(), 3)
	# آرک‌تایپ ۲ (docs/07 §۴): کفه‌ی راست هم می‌تواند از قبل کره داشته باشد
	for key: String in ["right_orbs", "right_ghost_orbs"]:
		assert_true(scale.has(key), "contract باید `%s` را داشته باشد" % key)
	assert_eq((scale.get("right_orbs") as Array).size(), 0)
	# افزوده‌های فاز ۴/۵ از همین‌جا عبور می‌کنند (LevelController آن‌ها را نمی‌خواند)
	for key: String in ["hint_sequence", "difficulty_elo", "solution_spec", "concept_tags"]:
		assert_true(cfg.has(key), "contract باید %s را هم رد کند" % key)


func test_ghosts_live_only_in_the_ghost_keys() -> void:
	# رگرسیون واقعی: اگر ghost هم در left_orbs و هم در left_ghost_orbs بیاید،
	# LevelController وزنش را دو بار روی کفه می‌گذارد.
	var lv := LevelData.from_dict({
		"level_id": "tier3_level_02", "tier": 3,
		"concept_tags": ["unknown_variable"],
		"narrative_intro": "دیوارهای Ghostlight دو ردپای نورانی دارند؛ یکی را خودت پیدا کن.",
		"left_side": {
			"fixed_orbs": [{"type": "number", "value": 2}],
			"ghost_orbs": [{"id": "x1", "type": "ghost", "hidden_value": 5}],
		},
		"right_side": {
			"ghost_orbs": [{"id": "x2", "type": "ghost", "hidden_value": 3}],
			"available_orbs": [{"type": "number", "value": 4, "count": 1}],
		},
		"hint_sequence": [{"trigger": "idle_45s", "hint_id": "gentle_nudge_01"}],
	})
	assert_eq(lv.validate().size(), 0, str(lv.validate()))
	var scale: Dictionary = (lv.to_config_dict()["scales"] as Array)[0]
	assert_eq((scale["left_orbs"] as Array).size(), 1, "شماردها در left_orbs")
	assert_eq((scale["left_ghost_orbs"] as Array).size(), 1)
	assert_eq((scale["right_ghost_orbs"] as Array).size(), 1)
	for entry: Variant in (scale["left_orbs"] as Array):
		assert_ne(str((entry as Dictionary).get("type", "")), "ghost", "ghost نباید دوباره اینجا بیاید")
	var scene: LevelController = load(LEVEL_SCENE).instantiate() as LevelController
	scene.attempt_settle_sec = 0.05
	scene.config = lv.to_config_dict()
	add_child_autofree(scene)
	assert_eq(scene.scales[0].left_weight(), 7.0, "2 + مجهول ۵ (نه ۱۲ دوبله)")
	assert_eq(scene.scales[0].right_weight(), 3.0, "مجهولِ سمت راست هم شمرده می‌شود")
	assert_eq(scene.tray_orbs.size(), 1, "کره‌ی ۴ هنوز در سینی است")
	assert_false(scene.is_won(), "قبل از گذاشتن کره، برد نیست")
	# API قطعیِ فاز ۲ (بدون صف ورودی): ۴ → راست = ۷ = چپ
	var pick: Array[WeightOrb] = [scene.tray_orbs[0]]
	assert_eq(scene.place_on_right(pick), 1, "کره‌ی ۴ روی کفه‌ی راست می‌نشیند")
	await get_tree().process_frame
	assert_eq(scene.scales[0].right_weight(), 7.0)
	assert_true(scene.is_won(), "تعادلِ مجهول‌ها = برد")


func test_config_dict_is_consumable_by_level_controller() -> void:
	var lv: LevelData = LevelData.from_json_text(_read(SAMPLE_PATH), SAMPLE_PATH).get("level")
	var scene: LevelController = load(LEVEL_SCENE).instantiate() as LevelController
	scene.attempt_settle_sec = 0.05
	scene.config = lv.to_config_dict()
	add_child_autofree(scene)
	assert_eq(scene.level_id, "tier1_level_01")
	assert_eq(scene.scales.size(), 1)
	assert_eq(scene.scales[0].left_weight(), 8.0, "چپ از داده‌ی JSON ساخته شد")
	assert_eq(scene.tray_orbs.size(), 18)


func test_weight_rule_matches_the_orb_classes() -> void:
	# قاعده‌ی علامت باید در کدِ داده و کدِ بازی یکی باشد (نه دو پیاده‌سازیِ جدا)
	var neg := NegativeOrb.new()
	autofree(neg)
	neg.set_value(2.0)
	assert_eq(LevelData.orb_weight({"type": "negative", "value": 2.0}), neg.weight())
	var ghost := GhostOrb.new()
	autofree(ghost)
	ghost.set_hidden_value(4.0)
	assert_eq(LevelData.orb_weight({"type": "ghost", "hidden_value": 4.0}), ghost.weight())
	assert_eq(LevelData.side_weight([
		{"type": "number", "value": 3},
		{"type": "ghost", "hidden_value": 4},
		{"type": "negative", "value": 1},
	]), 6.0)


func test_validate_catches_each_broken_shape() -> void:
	var cases: Array[Dictionary] = [
		{"why": "level_id غایب", "data": {}},
		{"why": "level_id بدنام", "data": {"level_id": "level_one"}},
		{"why": "tier خارج از بازه", "data": {"level_id": "tier1_level_01", "tier": 7}},
		{"why": "world ناشناخته", "data": {"level_id": "tier1_level_01", "world": "ice_caves"}},
		{"why": "concept_tags خالی", "data": {"level_id": "tier1_level_01", "concept_tags": []}},
		{"why": "intro کوتاه", "data": {"level_id": "tier1_level_01", "narrative_intro": "بچین"}},
		{"why": "tolerance منفی", "data": {"level_id": "tier1_level_01", "tolerance": -1}},
		{"why": "elo خارج از بازه", "data": {"level_id": "tier1_level_01", "difficulty_elo": 3000}},
		{"why": "ghost در available_orbs", "data": {
			"level_id": "tier1_level_01", "tier": 3,
			"left_side": {"fixed_orbs": [{"type": "number", "value": 4}]},
			"right_side": {"available_orbs": [{"type": "ghost", "hidden_value": 4, "count": 1}]},
			"hint_sequence": [{"trigger": "idle_45s", "hint_id": "h"}],
		}},
		{"why": "count صفر", "data": {
			"level_id": "tier1_level_01",
			"left_side": {"fixed_orbs": [{"type": "number", "value": 4}]},
			"right_side": {"target_value": 4, "available_orbs": [{"type": "number", "value": 2, "count": 0}]},
			"hint_sequence": [{"trigger": "idle_45s", "hint_id": "h"}],
		}},
		{"why": "target با نیاز نمی‌خواند", "data": {
			"level_id": "tier1_level_01",
			"left_side": {"fixed_orbs": [{"type": "number", "value": 8}]},
			"right_side": {"target_value": 7, "available_orbs": [{"type": "number", "value": 1, "count": 7}]},
			"hint_sequence": [{"trigger": "idle_45s", "hint_id": "h"}],
		}},
		{"why": "hint_sequence خالی", "data": {
			"level_id": "tier1_level_01",
			"left_side": {"fixed_orbs": [{"type": "number", "value": 8}]},
			"right_side": {"target_value": 8},
			"hint_sequence": [],
		}},
		{"why": "trigger ناشناخته", "data": {
			"level_id": "tier1_level_01",
			"left_side": {"fixed_orbs": [{"type": "number", "value": 8}]},
			"right_side": {"target_value": 8},
			"hint_sequence": [{"trigger": "whenever_i_say_so", "hint_id": "h"}],
		}},
		{"why": "ghost در Tier 1", "data": {
			"level_id": "tier1_level_01", "tier": 1,
			"left_side": {"ghost_orbs": [{"hidden_value": 4}]},
			"right_side": {"target_value": 4},
			"hint_sequence": [{"trigger": "idle_45s", "hint_id": "h"}],
		}},
		{"why": "solution_spec دروغین", "data": {
			"level_id": "tier1_level_01",
			"left_side": {"fixed_orbs": [{"type": "number", "value": 8}]},
			"right_side": {"target_value": 8, "available_orbs": [{"type": "number", "value": 4, "count": 2}]},
			"hint_sequence": [{"trigger": "idle_45s", "hint_id": "h"}],
			"solution_spec": {"intended": {"right_orbs": [4, 4, 4]}},
		}},
	]
	for case: Dictionary in cases:
		var data: Dictionary = case["data"]
		if data.is_empty():
			assert_gt(LevelData.from_dict(data).validate().size(), 0, case["why"])
			continue
		var lv := LevelData.from_dict(data)
		var errs: Array[String] = lv.validate()
		assert_gt(errs.size(), 0, "باید خطا می‌گرفت: %s" % case["why"])


func test_ghost_discovery_level_without_target_is_valid() -> void:
	var lv := LevelData.from_dict({
		"level_id": "tier3_level_01", "tier": 3,
		"concept_tags": ["unknown_variable"],
		"narrative_intro": "ردپاهای نورانی روی دیوارهای Ghostlight چیزی را پنهان کرده‌اند.",
		"left_side": {
			"fixed_orbs": [{"type": "number", "value": 2}],
			"ghost_orbs": [{"id": "x1", "type": "ghost", "hidden_value": 4}],
		},
		"right_side": {"available_orbs": [{"type": "number", "value": 6, "count": 1}]},
		"hint_sequence": [{"trigger": "idle_45s", "hint_id": "gentle_nudge_01"}],
	})
	assert_eq(lv.validate().size(), 0, "سطح کشف مجهول target لازم ندارد: %s" % str(lv.validate()))
	assert_false(lv.has_target)
	assert_eq(lv.left_weight(), 6.0)


func test_broken_json_is_reported_without_engine_error() -> void:
	# اگر این مسیر push_error می‌زد، GUT خودکار تست را قرمز می‌کرد (ADR-023)
	var bad: Dictionary = LevelData.from_json_text("{ not json at all", "res://tmp/broken.json")
	assert_false(bool(bad["ok"]))
	assert_true(str(bad["error"]).contains("JSON نامعتبر"))
	var not_object: Dictionary = LevelData.from_json_text("[1,2,3]", "res://tmp/arr.json")
	assert_false(bool(not_object["ok"]))
	assert_true(str(not_object["error"]).contains("object"))
