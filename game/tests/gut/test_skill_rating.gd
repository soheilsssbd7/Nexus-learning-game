extends GutTest
# ===========================================================================
# تسک ۴.۱ — SkillRating (docs/03-DATA-SCHEMAS.md §۳ + ADR-015)
# --------------------------------------------------------------------------
# DoD سند ۰۴: «تست GUT با چند سناریوی برد/باخت، مقدار Elo طبق فرمول تغییر می‌کند».
# همه‌ی اعداد دستی از فرمول §۳ آمده‌اند (نه از کپی‌کردن کد):
#   expected = 1/(1+10^((D-C)/400)) ، C' = clamp(C + 32*(score-expected), 400, 2000)
# GUT 9.7.1 `assert_approx_eq` ندارد، پس یک helper محلی برای مقایسه‌ی شبه‌ای داریم.
# ===========================================================================

const EPS := 0.000001


func _near(got: float, expected: float, text: String = "", tol: float = EPS) -> void:
	var label := text
	if label.is_empty():
		label = "expected %f, got %f" % [expected, got]
	assert_true(absf(got - expected) <= tol, label)


func test_formula_matches_the_hand_computed_value_on_equal_ratings() -> void:
	# C = D = 1000 → expected = 0.5 → برد = 1016، باخت = 984 (دقیقاً §۳)
	_near(SkillRating.update_elo(1000.0, 1000.0, true), 1016.0)
	_near(SkillRating.update_elo(1000.0, 1000.0, false), 984.0)
	_near(SkillRating.expected_success(1000.0, 1000.0), 0.5)


func test_expected_success_moves_the_right_way() -> void:
	# رتبه‌ی بالاتر نسبت به دشواری سطح → احتمال موفقیتِ پیش‌بینی‌شده بیشتر
	assert_gt(SkillRating.expected_success(1200.0, 1000.0), 0.5, "قوی‌تر از سطح = شانس > ۰.۵")
	assert_lt(SkillRating.expected_success(1000.0, 1200.0), 0.5, "ضعیف‌تر از سطح = شانس < ۰.۵")
	_near(SkillRating.expected_success(1200.0, 1000.0), 0.7597469266, "q5+", 0.0001)
	_near(SkillRating.expected_success(1000.0, 1200.0), 0.2402530733, "q5-", 0.0001)
	assert_gt(SkillRating.expected_success(1400.0, 1000.0), SkillRating.expected_success(1100.0, 1000.0))


func test_underdog_gain_is_larger_than_favourite_gain() -> void:
	# بازیکن ضعیفی که سطح سخت را می‌بَرَد باید بیشتر از بازیکن قوی امتیاز بگیرد
	var weak_gain: float = SkillRating.update_elo(900.0, 1200.0, true) - 900.0
	var strong_gain: float = SkillRating.update_elo(1300.0, 1200.0, true) - 1300.0
	_near(weak_gain, 27.1686, "برد غریب", 0.001)
	assert_gt(weak_gain, strong_gain, "Elo آنتروپی ذاتی را جبران می‌کند (منحنی §۳)")
	assert_lt(strong_gain, SkillRating.K_FACTOR, "بردِ موردانتظار هرگز به سقف K نمی‌رسد")


func test_losing_an_easy_level_hurts_more_than_losing_a_hard_one() -> void:
	var careless: float = SkillRating.update_elo(1100.0, 900.0, false) - 1100.0
	var challenger: float = SkillRating.update_elo(900.0, 1200.0, false) - 900.0
	assert_lt(careless, challenger, "«باید می‌بُردی» تنبیه سنگین‌تری دارد")
	_near(careless, -24.3119, "تنبیه بی‌احتیاطی", 0.001)


func test_weighted_score_from_the_hint_note_is_applied() -> void:
	# نکته‌ی §۳: «اگر با ۳ راهنما حل کرد، actual_score کامل نباشد (مثلاً 0.7)»
	var unweighted: float = SkillRating.update_elo(1000.0, 1000.0, true)
	var weighted: float = SkillRating.update_elo(1000.0, 1000.0, true, 0.7)
	_near(weighted, 1000.0 + 32.0 * (0.7 - 0.5))
	assert_lt(weighted, unweighted, "حل‌کردن با راهنما «مهارت» کامل نیست (ADR-015)")
	# امتیاز صفر = باختِ واقعی، حتی وقتی did_succeed=true تزریق شده باشد
	_near(SkillRating.update_elo(1000.0, 1000.0, true, 0.0), 984.0)
	# امتیاز بیرون از ۰..۱ نباید رتبه را منفجر کند (clamp داخل تابع)
	assert_lte(SkillRating.update_elo(1000.0, 1000.0, true, 4.0), unweighted + EPS)


func test_clamp_bounds_400_and_2000() -> void:
	_near(SkillRating.update_elo(400.0, 400.0, false), SkillRating.ELO_MIN, "کف رتبه ۴۰۰ (§۳)")
	_near(SkillRating.update_elo(2000.0, 2000.0, true), SkillRating.ELO_MAX, "سقف رتبه ۲۰۰۰ (§۳)")
	# سقف با «بردِ کلان» بسته می‌شود، نه با پشت‌سرهم بردنِ سطح آسان: منحنیِ انتظار
	# هر بردِ بعدی را کوچک‌تر می‌کند (ویژگیِ خودِ Elo)، پس ۸۰ بردِ آسان هیچ‌وقت
	# به ۲۰۰۰ نمی‌رسد — این باگ نیست، همان چیزی است که §۳ می‌خواهد.
	_near(SkillRating.update_elo(1995.0, 2600.0, true), SkillRating.ELO_MAX,
		"بردِ غیرمنتظره در سطحی خیلی سخت‌تر، روی ۲۰۰۰ قفل می‌شود")
	var v: float = 1000.0
	for i: int in range(40):
		v = SkillRating.update_elo(v, 400.0, true)
	assert_true(v > 1000.0 and v < SkillRating.ELO_MAX,
		"بردِ پیاپیِ سطح آسان رتبه را بالا می‌برد اما به سقف نمی‌چسباند (got %f)" % v)


func test_confidence_shrinks_with_attempts() -> void:
	_near(SkillRating.compute_confidence(0), 0.0)
	_near(SkillRating.compute_confidence(int(SkillRating.CONFIDENCE_HALF_ATTEMPTS)), 0.5,
		"ADR-015: با ۱۲ تلاش اطمینان ۰.۵")
	assert_gt(SkillRating.compute_confidence(50), 0.8)
	assert_lt(SkillRating.compute_confidence(10000), 1.0,
		"هرگز به ۱ نمی‌رسیم: ادعای قطعیت کامل درباره‌ی کودک نمی‌کنیم")


func test_apply_result_updates_rating_and_returns_delta() -> void:
	var r := SkillRating.new()
	_near(r.elo, SkillRating.ELO_START, "رتبه‌ی شروع ۱۰۰۰")
	var delta := r.apply_result(1000.0, true)
	_near(delta, 16.0, "apply_result باید delta را بدهد (برای final_elo_delta)")
	_near(r.elo, 1016.0)
	assert_eq(r.attempts, 1)
	_near(r.confidence, SkillRating.compute_confidence(1))
	var re := RegEx.new()
	assert_eq(re.compile("^\\d{4}-\\d{2}-\\d{2}$"), OK)
	assert_true(re.search(r.last_seen) != null, "last_seen باید تاریخ ISO باشد (§۲): " + r.last_seen)
	assert_lt(r.apply_result(1000.0, false), 0.0, "باخت رتبه را پایین می‌آورد")
	assert_eq(r.attempts, 2, "هر نتیجه = یک تلاش ثبت‌شده (مبنای confidence و داشبورد والدین)")


func test_dict_roundtrip_is_stable_through_the_json_path() -> void:
	var r := SkillRating.new()
	r.apply_result(1040.0, true, 0.7)
	var d: Dictionary = r.to_dict()
	for key: String in ["elo", "confidence", "attempts", "last_seen"]:
		assert_true(d.has(key), "§۲ این کلید را در `skills.<tag>` می‌خواهد: " + key)
	var back := SkillRating.from_dict(d)
	_near(back.elo, r.elo, "quantize باید دورِ ذخیره/بارگذاری عدد را عوض نکند")
	_near(back.confidence, r.confidence)
	assert_eq(back.attempts, r.attempts)
	assert_eq(back.last_seen, r.last_seen)


func test_garbage_from_disk_degrades_to_safe_defaults() -> void:
	# دیسک می‌تواند داده‌ی نسخه‌ی قدیمی/دست‌کاری‌شده داشته باشد → هرگز crash نه
	var broken := SkillRating.from_dict({"elo": 99999.0, "attempts": -4, "confidence": 5.0})
	_near(broken.elo, SkillRating.ELO_MAX, "clamp در خواندن هم لازم است")
	_near(broken.confidence, 1.0)
	assert_eq(broken.attempts, 0, "شمارنده‌ی منفی معنایی ندارد → صفر")
	_near(SkillRating.from_dict({}).elo, SkillRating.ELO_START, "فیلد غایب = رتبه‌ی شروع")


func test_player_model_skill_bookkeeping_uses_the_same_object() -> void:
	var model := PlayerModel.create_new("آزمون")
	_near(model.skill_elo("addition_basic"), SkillRating.ELO_START, "مهارت نا‌شناخته = رتبه‌ی شروع")
	var r := model.ensure_skill("addition_basic")
	r.apply_result(900.0, true)
	assert_gt(model.skill_elo("addition_basic"), SkillRating.ELO_START,
		"ensure_skill باید همان نمونه‌ی داخل model.skills را بدهد، نه کپی")
	var keys := PackedStringArray(["addition_basic", "ghost_algebra"])
	_near(model.average_skill_elo(keys), model.skill_elo("addition_basic"),
		"کلیدِ ناشناس در میانگین حساب نمی‌شود (وگرنه ۱۰۰۰ِ ساختگی رتبه‌ی بازیکن را به عقب "
		+ "می‌کشید و انتخاب سطح را خراب می‌کرد)")
	var both := PackedStringArray(["addition_basic"])
	_near(model.average_skill_elo(both), model.skill_elo("addition_basic"),
		"یک مهارت = خودِ همان مهارت")
