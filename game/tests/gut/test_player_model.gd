extends GutTest
# ===========================================================================
# تسک ۱.۲ — PlayerModel: به‌همراه serialisation دقیقاً مطابق docs/03 §۲
# DoD: ساخت مدل → to_dict → from_dict → برابری فیلدها.
# ===========================================================================


func test_round_trip_keeps_every_schema_field() -> void:
	var model := PlayerModel.create_new("آزمون")
	var rating: SkillRating = model.ensure_skill("addition_basic")
	rating.apply_result(900.0, true)
	rating.elo = 1120.0
	rating.attempts = 34
	rating.confidence = SkillRating.compute_confidence(34)
	rating.last_seen = "2026-09-06"
	model.ensure_skill("subtraction_negative").elo = 980.0
	model.bump_error_pattern("sign_flip_on_subtraction")
	model.bump_error_pattern("sign_flip_on_subtraction")
	model.bump_error_pattern("forgets_both_sides")
	model.mark_level_completed("tier1_level_01", 40.0, 1)
	model.record_hint_shown("socratic_operation_01", "tier1_level_01")

	var restored := PlayerModel.from_dict(model.to_dict())
	assert_eq_deep(restored.to_dict(), model.to_dict())  # round-trip باید بدون اختلاف باشد
	assert_eq(restored.error_patterns[0]["count"], 2, "شمارنده‌ی الگوی خطا باید حفظ شود")


func test_json_text_round_trip_preserves_types() -> void:
	# ذخیره روی دیسک JSON است → int‌ها به float تبدیل می‌شوند؛ from_dict باید باز typed کند.
	var model := PlayerModel.create_new()
	model.mark_level_completed("tier1_level_02", 55.0, 2)
	var parsed: Variant = JSON.parse_string(JSON.stringify(model.to_dict()))
	assert_true(parsed is Dictionary, "خروجی باید JSON object باشد")
	var restored := PlayerModel.from_dict(parsed)
	assert_eq(restored.levels_completed.size(), 1)
	assert_eq(restored.levels_completed[0], "tier1_level_02")
	assert_eq(int(restored.schema_version), PlayerModel.SCHEMA_VERSION, "schema_version باید int بماند")
	assert_eq(restored.levels_completed.get_typed_builtin(), TYPE_STRING,
		"levels_completed باید Array[String] بماند")


func test_from_dict_is_tolerant_of_missing_fields() -> void:
	var restored := PlayerModel.from_dict({"display_name": "کودک"})
	assert_eq(restored.display_name, "کودک")
	assert_eq(restored.levels_completed.size(), 0)
	assert_eq(restored.hint_usage_rate, 0.0)
	assert_false(restored.player_id.is_empty(), "اگر player_id غایب بود باید تولید شود")
	assert_true(restored.player_id.begins_with("p_"), "قالب شناسه: p_<hex> (ADR-005)")


func test_player_id_format_and_uniqueness() -> void:
	var seen := {}
	for i: int in range(50):
		var id: String = PlayerModel.generate_player_id()
		assert_eq(id.length(), 14, "p_ + ۱۲ رقم هگز")
		assert_false(seen.has(id), "شناسه‌ها باید یکتا باشند")
		seen[id] = true


func test_error_patterns_accumulate() -> void:
	var model := PlayerModel.create_new()
	model.bump_error_pattern("wrong_operation")
	model.bump_error_pattern("wrong_operation")
	model.bump_error_pattern("wrong_operation")
	model.bump_error_pattern("computation_error")
	assert_eq(model.count_error_pattern("wrong_operation"), 3)
	assert_eq(model.count_error_pattern("computation_error"), 1)
	assert_eq(model.count_error_pattern("idle"), 0, "الگوی ثبت‌نشده = صفر")


func test_transcript_records_and_is_capped() -> void:
	var model := PlayerModel.create_new()
	for i: int in range(PlayerModel.MAX_TRANSCRIPT_ENTRIES + 25):
		model.record_hint_shown("hint_%03d" % i, "tier1_level_01")
	assert_eq(model.aria_transcript_log.size(), PlayerModel.MAX_TRANSCRIPT_ENTRIES,
		"sقف چرخشی transcript (ADR-019) باید رعایت شود")
	var last: Dictionary = model.aria_transcript_log[model.aria_transcript_log.size() - 1]
	for key: String in ["timestamp", "hint_id", "level_id"]:
		assert_true(last.has(key), "ورودی transcript باید `%s` داشته باشد (§۲)" % key)


func test_level_completion_updates_model_stats() -> void:
	var model := PlayerModel.create_new()
	model.mark_level_completed("tier1_level_01", 40.0, 0)
	model.mark_level_completed("tier1_level_02", 60.0, 2)
	assert_eq(model.levels_completed.size(), 2)
	assert_eq(model.current_level, "tier1_level_02")
	assert_gt(model.avg_time_to_solve_sec, 40.0, "EMA باید به ۵۰ نزدیک شود (بین ۴۰ و ۶۰)")
	assert_lt(model.avg_time_to_solve_sec, 60.0)
	assert_gt(model.hint_usage_rate, 0.0, "سطح دوم با راهنما حل شد")


func test_duplicate_completion_does_not_double_count() -> void:
	var model := PlayerModel.create_new()
	model.mark_level_completed("tier1_level_01", 30.0, 0)
	model.mark_level_completed("tier1_level_01", 44.0, 0)
	assert_eq(model.levels_completed.size(), 1, "یک سطح نباید دو بار ثبت شود")
