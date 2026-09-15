extends GutTest
# ===========================================================================
# تسک ۱.۳ — SaveSystem: save → (بازشدن) → load = همان داده (DoD) + مهاجرت schema
# ===========================================================================

const TMP_PROFILE := "gut_tmp"
const MISSING_PROFILE := "gut_missing_profile"
const BROKEN_PROFILE := "gut_broken_profile"

var _profiles: Array[String] = [TMP_PROFILE, MISSING_PROFILE, BROKEN_PROFILE]


func before_all() -> void:
	_clean_profiles()


func after_all() -> void:
	_clean_profiles()
	SaveSystem.profile_name = "default"
	SaveSystem.bind_model(null)


func _clean_profiles() -> void:
	for p: String in _profiles:
		SaveSystem.profile_name = p
		SaveSystem.delete_all()
		for suffix: String in [".corrupt", ".tmp"]:
			var f: String = SaveSystem.path_for() + suffix
			if FileAccess.file_exists(f):
				DirAccess.remove_absolute(f)
	SaveSystem.profile_name = TMP_PROFILE


func _sample_model() -> PlayerModel:
	var m := PlayerModel.create_new("سارا")
	var r: SkillRating = m.ensure_skill("addition_basic")
	r.elo = 1120.0
	r.attempts = 34
	r.confidence = SkillRating.compute_confidence(34)
	r.last_seen = "2026-09-06"
	m.bump_error_pattern("sign_flip_on_subtraction")
	m.mark_level_completed("tier1_level_01", 42.0, 1)
	m.record_hint_shown("gentle_nudge_01", "tier1_level_02")
	m.total_playtime_sec = 5400.0
	return m


func test_save_then_load_returns_identical_model() -> void:
	SaveSystem.profile_name = TMP_PROFILE
	var model := _sample_model()
	assert_eq(SaveSystem.save_player_model(model), OK, "save باید OK برگرداند")

	# «بستن و باز کردن مجدد» = فراموش کردن حافظه و خواندن از دیسک
	SaveSystem.bind_model(null)
	var loaded := SaveSystem.load_player_model()
	assert_not_null(loaded)
	assert_eq(loaded.display_name, "سارا")
	assert_eq(loaded.player_id, model.player_id)
	assert_eq(loaded.levels_completed.size(), 1)
	assert_eq(loaded.total_playtime_sec, 5400.0)
	assert_eq(loaded.aria_transcript_log.size(), 1)
	assert_eq(float(loaded.skills["addition_basic"].elo), 1120.0)
	assert_eq(loaded.error_patterns[0]["count"], 1)
	assert_eq_deep(loaded.to_dict(), model.to_dict())
	assert_true(SaveSystem.had_save_on_load, "وقتی save هست باید true باشد")


func test_atomic_write_leaves_no_temp_file() -> void:
	SaveSystem.profile_name = TMP_PROFILE
	SaveSystem.save_player_model(_sample_model())
	assert_false(FileAccess.file_exists(SaveSystem.path_for() + ".tmp"),
		"فایل موقت بعد از rename نباید بماند")


func test_missing_save_creates_fresh_profile() -> void:
	SaveSystem.profile_name = MISSING_PROFILE
	assert_false(SaveSystem.has_save(), "پروفایل تازه نباید save داشته باشد")
	SaveSystem.bind_model(null)
	var fresh := SaveSystem.load_player_model()
	assert_not_null(fresh, "DoD: بازی نباید بدون save بشکند")
	assert_false(SaveSystem.had_save_on_load)
	assert_eq(fresh.levels_completed.size(), 0)
	assert_eq(fresh.schema_version, PlayerModel.SCHEMA_VERSION)
	assert_null(SaveSystem.load_player_model(false), "با create_if_missing=false باید null برگردد")


func test_corrupt_save_is_quarantined_not_fatal() -> void:
	SaveSystem.profile_name = BROKEN_PROFILE
	var path: String = SaveSystem.path_for()
	assert_eq(SaveSystem.ensure_dir(path), OK, "پوشه‌ی پروفایل تست باید ساخته شود")
	var f := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(f, "باز کردن فایل برای نوشتن داده‌ی خراب")
	f.store_string("{ this is not json ]")
	f.close()
	var recovered := SaveSystem.load_player_model()
	assert_not_null(recovered, "save خراب نباید بازی را کرش کند")
	assert_true(FileAccess.file_exists(path + ".corrupt"), "نسخه‌ی خراب برای عیب‌یابی نگه داشته می‌شود")
	assert_eq(recovered.schema_version, PlayerModel.SCHEMA_VERSION)


func test_migration_fills_missing_fields_and_bumps_version() -> void:
	# یک save نسخه‌ی ۰ که فقط دو فیلد دارد (تسک ۱.۳: فیلد جدید = مقدار پیش‌فرض)
	SaveSystem.profile_name = TMP_PROFILE
	var path: String = SaveSystem.path_for()
	assert_eq(SaveSystem.ensure_dir(path), OK)
	var f := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(f)
	f.store_string(JSON.stringify({
		"schema_version": 0,
		"display_name": "قدیمی",
		"levels_completed": ["tier1_level_01"],
	}))
	f.close()
	var migrated := SaveSystem.load_player_model()
	assert_eq(migrated.schema_version, PlayerModel.SCHEMA_VERSION, "نسخه باید به روز شود")
	assert_eq(migrated.display_name, "قدیمی", "داده‌ی موجود نباید از بین برود")
	assert_eq(migrated.levels_completed.size(), 1)
	assert_eq(migrated.current_level, "", "فیلد غایب → پیش‌فرض")
	assert_eq(migrated.hint_usage_rate, 0.0)
	assert_true(migrated.skills is Dictionary)
	assert_false(migrated.player_id.is_empty(), "player_id غایب باید تولید شود")
	# و بعد از یک save، ساختار کامل روی دیسک باشد:
	SaveSystem.save_player_model(migrated)
	var again := SaveSystem.load_player_model()
	assert_eq_deep(again.to_dict(), migrated.to_dict())


func test_delete_all_removes_save() -> void:
	SaveSystem.profile_name = TMP_PROFILE
	SaveSystem.save_player_model(_sample_model())
	assert_true(SaveSystem.has_save())
	SaveSystem.delete_all()
	assert_false(SaveSystem.has_save(), "«حذف داده» والدین باید واقعاً فایل را بردارد (ADR-019)")


func test_debounce_flush_writes_once() -> void:
	SaveSystem.profile_name = TMP_PROFILE
	SaveSystem.delete_all()
	var model := _sample_model()
	SaveSystem.bind_model(model)
	model.display_name = "اولین"
	SaveSystem.request_save()
	assert_false(FileAccess.file_exists(SaveSystem.path_for()), "بلافاصله بعد از request نباید نوشته شود (debounce)")
	model.display_name = "نهایی"
	SaveSystem.flush()
	var loaded := SaveSystem.load_player_model()
	assert_eq(loaded.display_name, "نهایی", "flush باید آخرین مقدار را بنویسد")


func test_exported_json_contains_no_pii_fields() -> void:
	# خط‌قرمز محصول: هیچ داده‌ی PII در save/خروجی والدین نباشد (§۲ و §۶ سند داده‌ها).
	SaveSystem.profile_name = TMP_PROFILE
	var model := _sample_model()
	SaveSystem.save_player_model(model)
	SaveSystem.bind_model(model)
	var text: String = SaveSystem.export_json_for_parent()
	for forbidden: String in ["email", "phone", "location", "camera", "contacts", "imei", "aaid", "password"]:
		assert_false(text.to_lower().contains(forbidden), "کلمه‌ی `%s` نباید در save باشد" % forbidden)
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "خروجی والدین باید JSON معتبر باشد")
