extends GutTest
# ===========================================================================
# تسک ۴.۴ — DifficultyEngine (docs/07 §۵، docs/03 §۳ نکته، ADR-038/039)
# --------------------------------------------------------------------------
# دو نیمه‌ی تست:
#  الف) `choose_next` pure است → قوانین §۵ تک‌تک با استخر ساختگی سنجیده می‌شوند
#  ب) نیمه‌ی چسبناک (مدل/دیسک/payload) با داده‌ی واقعیِ Tier 1
# ===========================================================================

const EPS := 0.001

var _model: PlayerModel = null


## GUT 9.7.1 هیچ مقایسه‌ی شبه‌ای برای float ندارد (`assert_approx_eq` هم نیست) → helper محلی.
func _near(got: float, expected: float, text: String = "", tol: float = EPS) -> void:
	var label := text
	if label.is_empty():
		label = "expected %f ± %f, got %f" % [expected, tol, got]
	assert_true(absf(got - expected) <= tol, label)


func before_each() -> void:
	_model = PlayerModel.create_new("موتور")
	GameState.active_model = _model
	SaveSystem.bind_model(_model)
	DifficultyEngine.reset_state()
	LevelLoader.change_scene_on_start = false
	GameState.begin_level("tier1_level_01", 1)
	GameState.level_attempts = 0
	GameState.hints_used_this_level = 0


func after_each() -> void:
	DifficultyEngine.adaptive_selection = true
	DifficultyEngine.reset_state()
	GameState.end_level()


func _cand(id: String, elo: float, tier: int = 1, completed: bool = false, index: int = -1) -> Dictionary:
	return {
		"id": id, "elo": elo, "tier": tier, "completed": completed,
		"index": index if index >= 0 else int(id.right(2)),
	}


func _pool() -> Array[Dictionary]:
	return [
		_cand("l01", 940.0, 1, false, 0), _cand("l02", 980.0, 1, false, 1),
		_cand("l03", 1020.0, 1, false, 2), _cand("l04", 1060.0, 1, false, 3),
	]


# --------------------------------------------------------------------------
# الف) قوانین §۵ روی استخر ساختگی
# --------------------------------------------------------------------------
func test_fresh_player_gets_the_next_rung_of_the_ladder() -> void:
	var picked: Dictionary = DifficultyEngine.choose_next(1000.0, _pool(), {})
	assert_eq(str(picked["level_id"]), "l01", "رتبه‌ی نزدیک‌تر به ۱۰۰۰ درِ Tier است، ولی")
	assert_eq(str(picked["reason"]), "ladder_order",
		"بی‌دلیل از نردبان جابه‌جا نمی‌شویم (قفل روایت §۵)")
	assert_eq(str(DifficultyEngine.choose_next(1000.0, [], {})["reason"]), "no_candidates")


func test_overqualified_player_swaps_forward_exactly_one_step() -> void:
	# رتبه‌ی ۱۱۰۰ vs پله‌ی بعدی ۹۴۰ → «آماده‌ی بیشتر» است؛ §۵ فقط **یک** پله اجازه می‌دهد
	var picked: Dictionary = DifficultyEngine.choose_next(1100.0, _pool(), {})
	assert_eq(str(picked["level_id"]), "l02", "یک پله جلو")
	assert_eq(str(picked["reason"]), "elo_lead")
	# حتی با رتبه‌ی سقفی هم دو پله جلو نمی‌رود (پرشِ گیج‌کننده ممنوع)
	assert_eq(str(DifficultyEngine.choose_next(2000.0, _pool(), {})["level_id"]), "l02",
		"سقف جابه‌جایی = MAX_SWAP_AHEAD=1")


func test_struggle_serves_a_practice_rerun_of_the_easiest_finished_level() -> void:
	var pool: Array[Dictionary] = [
		_cand("l01", 900.0, 1, true, 0), _cand("l02", 940.0, 1, true, 1),
		_cand("l03", 980.0, 1, false, 2), _cand("l04", 1020.0, 1, false, 3),
	]
	var picked: Dictionary = DifficultyEngine.choose_next(980.0, pool, {"struggle": true})
	assert_eq(str(picked["level_id"]), "l01", "§۵: بعد از ۲ بار گیرکردن، ساده‌تر (همان Tier)")
	assert_eq(str(picked["reason"]), "struggle_practice_rerun")
	# و اگر هنوز هیچ سطحی تمام نشده، «ساده‌تر» یعنی همان پله — نه پرش به جای دیگر
	var fresh: Array[Dictionary] = [
		_cand("l01", 940.0, 1, false, 0), _cand("l02", 980.0, 1, false, 1),
	]
	assert_eq(str(DifficultyEngine.choose_next(900.0, fresh, {"struggle": true})["level_id"]), "l01")
	assert_eq(str(DifficultyEngine.choose_next(900.0, fresh, {"struggle": true})["reason"]),
		"ladder_order", "بدون سابقه، تمرین مجدّدی وجود ندارد")


func test_three_hintless_levels_allow_exactly_one_jump() -> void:
	var flags := {"mastery_jump": true}
	var picked: Dictionary = DifficultyEngine.choose_next(1000.0, _pool(), flags)
	assert_eq(str(picked["level_id"]), "l02", "§۵: «۱ سطح پریدن مجاز است»")
	assert_eq(str(picked["reason"]), "mastery_jump")
	# استخر تک‌نفره: پرشی نیست، بی‌خطر همان را می‌دهد
	assert_eq(str(DifficultyEngine.choose_next(1000.0, [_cand("l01", 940.0)], flags)["level_id"]), "l01")


func test_anti_wall_cap_replaces_a_second_hard_level() -> void:
	# پله‌ی بعدی ۱۰۲۰ برای بازیکن ۹۰۰ = «تازه‌ی سخت»؛ اگر یکی تازه داده‌ایم، ساده‌ترش کن
	var pool: Array[Dictionary] = [
		_cand("l01", 1020.0, 1, false, 0), _cand("l02", 980.0, 1, true, 1),
		_cand("l03", 1060.0, 1, false, 2),
	]
	var picked: Dictionary = DifficultyEngine.choose_next(
		900.0, pool, {"hard_used_recently": true})
	assert_eq(str(picked["level_id"]), "l02", "حداکثر ۱ سطح تازه‌ی سخت در هر ۳ سطح (§۵)")
	assert_eq(str(picked["reason"]), "hard_capped")
	# بدون فلگ، همان دیوار مجاز است (ترتیب نویسنده محترم است)
	assert_eq(str(DifficultyEngine.choose_next(900.0, pool, {})["level_id"]), "l01")


func test_tier_lock_is_absolute() -> void:
	var pool: Array[Dictionary] = [_cand("l01", 940.0, 1, false, 0), _cand("t2", 960.0, 2, false, 5)]
	var picked: Dictionary = DifficultyEngine.choose_next(2000.0, pool, {"current_tier": 1})
	assert_eq(str(picked["level_id"]), "l01", "هیچ سطحی از Tier بازنشده ظاهر نمی‌شود (§۵)")
	var only_locked: Array[Dictionary] = [_cand("t2", 960.0, 2, false, 5)]
	var none: Dictionary = DifficultyEngine.choose_next(2000.0, only_locked, {"current_tier": 1})
	assert_eq(str(none["level_id"]), "")
	assert_eq(str(none["reason"]), "tier_locked")


# --------------------------------------------------------------------------
# ب) نیمه‌ی چسبناک: کاندید از دیسک، رتبه در مدل، seam در LevelLoader
# --------------------------------------------------------------------------
func test_engine_registers_itself_as_the_loader_selector() -> void:
	# همان چیزی که اگر autoload ثبت نمی‌شد (دام فاز ۳) بی‌صدا از دست می‌رفت
	assert_true(LevelLoader.next_selector.is_valid(),
		"DifficultyEngine در _ready خودش را به LevelLoader وصل می‌کند")
	assert_true(ProjectSettings.has_setting("autoload/DifficultyEngine"))


func test_build_candidates_uses_the_real_tier1_ladder() -> void:
	var fresh: Array[Dictionary] = DifficultyEngine.build_candidates(1, _model, false, "")
	assert_eq(fresh.size(), 5, "فاز ۳ پنج سطح نوشته است")
	assert_eq(str(fresh[0]["id"]), "tier1_level_01")
	assert_eq(float(fresh[0]["elo"]), 900.0)
	assert_eq(float(fresh[4]["elo"]), 1060.0, "منحنی Elo همان چیزی است که validator الزام می‌کند")
	assert_false(bool(fresh[0]["completed"]))
	_model.mark_level_completed("tier1_level_01", 20.0, 0)
	var after: Array[Dictionary] = DifficultyEngine.build_candidates(1, _model, false, "")
	assert_eq(after.size(), 4, "سطح تمام‌شده از استخرِ عادی بیرون می‌ماند")
	var with_done: Array[Dictionary] = DifficultyEngine.build_candidates(1, _model, true, "")
	assert_eq(with_done.size(), 5, "با include_completed برای «پله‌ی عقب» برگردانده می‌شود")
	assert_true(bool(with_done[0]["completed"]))
	var skipped: Array[Dictionary] = DifficultyEngine.build_candidates(1, _model, true, "tier1_level_01")
	assert_eq(skipped.size(), 4)
	assert_ne(str(skipped[0]["id"]), "tier1_level_01", "تکرارِ بی‌معنیِ همان سطح حذف است")
	assert_eq(DifficultyEngine.build_candidates(9, _model, false, "").size(), 0, "Tier نامعتبر = تهی")


func test_apply_level_result_updates_every_tag_of_the_level() -> void:
	var cfg: Dictionary = LevelLoader.load_config("tier1_level_01")
	assert_eq(Array(cfg["concept_tags"])[0], "addition_basic",
		"کلید مهارت = tag اولِ سطح (ADR-039؛ معیار خروج Tier در docs/07 §۴)")
	GameState.hints_used_this_level = 0
	GameState.level_attempts = 1
	var before: float = _model.skill_elo("addition_basic")
	var outcome: Dictionary = DifficultyEngine.apply_level_result(cfg, true)
	_near(float(outcome["score"]), 1.0, "بدون راهنما و با یک تلاش = امتیاز کامل", EPS)
	# عدد را از خودِ SkillRating می‌گیریم (نه از محاسبه‌ی دستی): موتور باید همان
	# فرمول را به‌کار ببرد؛ اگر روزی K یا منحنی انتظار عوض شد، این تست «رابطه» را
	# می‌سنجد نه یک عددِ یخ‌زده در متن تست.
	var probe := SkillRating.new()
	probe.elo = SkillRating.ELO_START
	var expected_delta: float = probe.apply_result(float(cfg["difficulty_elo"]), true, 1.0)
	assert_gt(expected_delta, 0.0, "سطح آسان‌تر از رتبه = سودِ مثبت اما کوچک")
	assert_lt(expected_delta, SkillRating.K_FACTOR, "هرگز به سقف K نمی‌رسد (فاصله ۱۰۰ Elo)")
	_near(float(outcome["elo_delta"]), expected_delta,
		"deltaِ موتور = deltaِ SkillRating برای همان (difficulty, score)", 0.001)
	assert_gt(_model.skill_elo("addition_basic"), before)
	assert_gt(_model.skill_elo("concrete_numbers"), SkillRating.ELO_START,
		"همه‌ی tags یک سطح به‌روز می‌شوند (§۴.۴)")
	assert_eq(_model.skills.size(), 2)
	assert_eq(DifficultyEngine.results_size(), 1, "هر نتیجه یک بار ثبت می‌شود")
	_near(float(_model.skills["addition_basic"].elo), before + expected_delta, "", 0.001)


func test_hints_shrink_the_gain_and_reset_the_streak() -> void:
	var cfg: Dictionary = LevelLoader.load_config("tier1_level_01")
	GameState.hints_used_this_level = 3
	GameState.level_attempts = 1
	# اول یک بردِ تمیز، تا «سقفِ سودِ همین لحظه» معلوم شود
	var clean: Dictionary = DifficultyEngine.apply_level_result(cfg, true)
	GameState.hints_used_this_level = 3
	var outcome: Dictionary = DifficultyEngine.apply_level_result(cfg, true)
	_near(float(outcome["score"]), 0.7, "§۳ نکته: سه راهنما = ۰.۷", EPS)
	# §۵ «وزن‌دهی» یعنی سودِ کوچک‌تر، نه تنبیه: سطح آسانِ حل‌شده با سه راهنما
	# همچنان کمی بالا می‌رود (K=32 و انتظار ~۰.۶۴)، اما زیرِ بردِ تمیز می‌ماند.
	assert_gt(float(outcome["elo_delta"]), 0.0, "رتبه سقوط نمی‌کند")
	assert_lt(float(outcome["elo_delta"]), float(clean["elo_delta"]),
		"سه راهنما سودِ همان سطح را می‌خورد")
	assert_eq(DifficultyEngine.no_hint_streak(), 0, "راهنما streak را می‌شکند")
	# سه بردِ پشت‌سرهمِ بی‌راهنما = مجوز «یک پله پرش» (§۵) — بردِ تمیزِ بالا که
	# قبل از این راهنماها بود بشکننده‌ی streak حساب شد، پس شمارش از صفر است.
	GameState.hints_used_this_level = 0
	DifficultyEngine.apply_level_result(cfg, true)
	DifficultyEngine.apply_level_result(cfg, true)
	DifficultyEngine.apply_level_result(cfg, true)
	assert_eq(DifficultyEngine.no_hint_streak(), 3, "سه سطح بدون راهنما = مجوز پرش (§۵)")


func test_level_completed_signal_alone_does_not_move_the_rating() -> void:
	# ADR-038: موتور `level_completed` را نمی‌شنود؛ اگر می‌شنید، یک برد دو بار اعمال می‌شد
	var cfg: Dictionary = LevelLoader.load_config("tier1_level_01")
	var outcome: Dictionary = DifficultyEngine.apply_level_result(cfg, true)
	var elo_after_first: float = _model.skill_elo("addition_basic")
	EventBus.level_completed.emit("tier1_level_01", outcome)
	_near(_model.skill_elo("addition_basic"), elo_after_first, "emitِ تنها نباید رتبه را جابه‌جا کند", EPS)
	assert_eq(DifficultyEngine.results_size(), 1)


func test_pick_next_for_a_fresh_player_stays_the_linear_rung() -> void:
	var cfg: Dictionary = LevelLoader.load_config("tier1_level_01")
	DifficultyEngine.apply_level_result(cfg, true)
	_model.mark_level_completed("tier1_level_01", 18.0, 0)
	assert_eq(DifficultyEngine.pick_next_level_id("tier1_level_01"), "tier1_level_02",
		"جریان فاز ۳ (نقشه→برد→بعدی) با موتور نو هم همان یک سطح است")
	assert_eq(str(DifficultyEngine.next_level("tier1_level_01").get("reason", "")), "ladder_order")


func test_kill_switch_returns_to_the_authored_order() -> void:
	DifficultyEngine.adaptive_selection = false
	assert_false(DifficultyEngine.is_adaptive())
	assert_eq(DifficultyEngine.pick_next_level_id("tier1_level_01"),
		LevelLoader.next_of("tier1_level_01"), "خاموش‌کردن تطبیق = ترتیب فایل‌ها")
	DifficultyEngine.adaptive_selection = true


## «دیگر سطحي نیست» را **می‌سازیم** (آخرین Tierِ نوشته‌شده را تمام می‌کنیم) ✗✓ فرضِ
## فاز ۳ («Tier 2 خالی است») با اولین محتوای فاز ۷ ترکید و همان تست، رفتارِ درستِ
## موتور را «باگ» گزارش می‌کرد — خطرناک‌ترین نوع تستِ کهنه ✓✓ حالا با هر تعداد Tier
## که نوشته شود سنجش درست است.
func test_finished_tier_with_no_next_files_ends_cleanly() -> void:
	var last_tier: int = 0
	for tier: int in range(1, 6):
		if not LevelLoader.levels_for_tier(tier).is_empty():
			last_tier = tier
	assert_gte(last_tier, 1, "دست‌کم یک Tier باید روی دیسک باشد")
	var ids: Array[String] = LevelLoader.levels_for_tier(last_tier)
	for id: String in LevelLoader.level_ids():
		_model.mark_level_completed(id, 20.0, 0)
	var last: String = ids[ids.size() - 1]
	var picked: Dictionary = DifficultyEngine.next_level(last)
	assert_eq(str(picked["level_id"]), "",
		"پایانِ آخرین Tierِ نوشته‌شده (Tier %d) = «بعدی نیست»، نه crash" % last_tier)
	assert_eq(str(picked["reason"]), "no_candidates")
	assert_eq(DifficultyEngine.pick_next_level_id(last), "", "seam هم تهی می‌دهد تا ResultBar به نقشه برود")


func test_remediation_is_not_repeated_twice_in_a_row() -> void:
	# بعد از یک «تمرین مجدّد»، نوبت نردبان است — وگرنه بازیکن در حلقه می‌افتد
	var cfg: Dictionary = LevelLoader.load_config("tier1_level_01")
	_model.mark_level_completed("tier1_level_01", 30.0, 1)
	_model.mark_level_completed("tier1_level_02", 30.0, 1)
	GameState.level_attempts = 4  # «۲ بار پشت‌سرهم» (§۵) → struggle
	var first: Dictionary = DifficultyEngine.next_level("tier1_level_02")
	assert_eq(str(first["reason"]), "struggle_practice_rerun")
	assert_true(DifficultyEngine.used_remediation(), "حالتِ پله‌ی عقب ثبت شد")
	DifficultyEngine.apply_level_result(cfg, true)
	var second: Dictionary = DifficultyEngine.next_level("tier1_level_01")
	assert_ne(str(second["reason"]), "struggle_practice_rerun",
		"دو تمرین پشت‌سرهم یعنی بن‌بست؛ §۵ یک پله می‌دهد، نه دو تا")
