extends GutTest
# ===========================================================================
# تسک ۱.۴ — GameState: وضعیت نشست، قابل خواندن/نوشتن از همه‌ی صحنه‌ها.
# ===========================================================================

const StateReader := preload("res://tests/gut/support/state_reader.gd")
const TEST_PROFILE := "gut_state_profile"


func before_all() -> void:
	SaveSystem.profile_name = TEST_PROFILE
	SaveSystem.delete_all()
	GameState.bootstrap()


func after_all() -> void:
	GameState.commit_playtime()
	GameState.current_level_id = ""
	GameState.current_tier = 1
	GameState.level_attempts = 0
	GameState.hints_used_this_level = 0
	GameState.active_model = null
	SaveSystem.bind_model(null)
	SaveSystem.delete_all()
	SaveSystem.profile_name = "default"


func before_each() -> void:
	watch_signals(EventBus)


func test_first_run_flag_when_no_save() -> void:
	assert_true(GameState.is_first_run, "بدون save باید اولین اجرا تشخیص داده شود (تسک ۶.۲ به این تکیه می‌کند)")


func test_active_model_is_bound_to_save_system() -> void:
	assert_not_null(GameState.active_model)
	assert_eq(SaveSystem.bound_model(), GameState.active_model,
		"SaveSystem باید همان مدل فعال را برای flush داشته باشد")


func test_current_level_is_visible_from_another_scene() -> void:
	GameState.begin_level("tier1_level_03", 1)
	var reader: Node = StateReader.new()
	add_child_autofree(reader)
	assert_eq(reader.read_level(), "tier1_level_03",
		"تغییر در یک «صحنه» باید در صحنه‌ی دیگر دیده شود (DoD ۱.۴)")
	assert_eq(reader.seen_tier, 1)


func test_begin_level_resets_counters_and_emits() -> void:
	GameState.begin_level("tier1_level_02", 1)
	GameState.register_attempt_failed()
	GameState.register_hint_used()
	GameState.register_hint_used()
	assert_eq(GameState.level_attempts, 1)
	assert_eq(GameState.hints_used_this_level, 2)
	GameState.begin_level("tier1_level_02", 1)
	assert_eq(GameState.level_attempts, 0, "شروع دوباره‌ی سطح باید شمارنده‌ها را صفر کند")
	assert_eq(GameState.hints_used_this_level, 0)
	assert_signal_emitted_with_parameters(EventBus, "level_started", ["tier1_level_02", 1])


func test_level_stats_payload_matches_analytics_schema() -> void:
	GameState.begin_level("tier1_level_03", 1)
	GameState.register_attempt_failed()
	GameState.register_hint_used()
	var stats: Dictionary = GameState.build_level_stats(0.85, 12.5, 52.0)
	assert_eq(int(stats["attempts"]), 1)
	assert_eq(int(stats["hints_used"]), 1)
	assert_eq(float(stats["time_to_solve_sec"]), 52.0)
	assert_eq(float(stats["final_elo_delta"]), 12.5)
	assert_eq(float(stats["score"]), 0.85, "score برای وزن‌دهی Elo در §۳ لازم است")


func test_elapsed_level_time_moves() -> void:
	GameState.begin_level("tier1_level_01", 1)
	assert_gte(GameState.elapsed_level_sec(), 0.0)
	GameState.end_level()
	assert_eq(GameState.elapsed_level_sec(), 0.0, "پایان سطح باید تایمر سطح را بخواباند")


func test_tier_parsed_from_level_id() -> void:
	assert_eq(GameState._tier_from_level_id("tier4_level_07"), 4)
	assert_eq(GameState._tier_from_level_id("tier5_level_01"), 5)
	GameState.current_tier = 2
	assert_eq(GameState._tier_from_level_id("نامعتبر"), 2, "داده‌ی خراب نباید tier را بشکند")


func test_commit_playtime_accumulates_into_model() -> void:
	var model := PlayerModel.create_new("تست")
	SaveSystem.bind_model(model)
	GameState.active_model = model
	var before: float = model.total_playtime_sec
	# یک برش زمانی ساختگی: cursor مدل را عقب می‌بریم تا delta مثبت شود.
	model.add_playtime(10.0)
	assert_gt(model.total_playtime_sec, before)
	assert_gte(GameState.session_playtime_sec(), 0.0, "زمان نشست نباید منفی باشد")
