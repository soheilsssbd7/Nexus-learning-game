extends GutTest
# ===========================================================================
# تسک ۴.۲ — ErrorClassifier (docs/04 §۴.۲)
# DoD: «تست GUT برای هر ۴ نوع خطای غیر-idle با سناریوهای دستی».
# هر چهار نوع هم با config دستیِ ایزوله سنجیده می‌شوند و هم با **داده‌ی واقعیِ
# Tier 1** — اگر قانون روی داده‌ی واقعی معنا از دست بدهد، این‌جا روشن می‌شود.
# (GUT 9.7.1 مقایسه‌ی شبه‌ای برای float ندارد → helper محلی `_near`.)
# ===========================================================================

const TOL := 0.000001


func _near(got: float, expected: float, text: String = "") -> void:
	assert_true(absf(got - expected) <= TOL,
		text if not text.is_empty() else "expected %f, got %f" % [expected, got])


func _number(value: float) -> Dictionary:
	return {"type": "number", "value": value}


func _scale(left: Array, right: Array, target: float) -> Dictionary:
	return {
		"id": "main",
		"left_orbs": left,
		"left_ghost_orbs": [],
		"right_orbs": right,
		"right_ghost_orbs": [],
		"target_value": target,
	}


func _left_only_config() -> Dictionary:
	# آرک‌تایپ ۱: چپ ۳+۵ ثابت، راست خالی، نیازِ بازیکن = ۸ (§۱ + ADR-037)
	return {
		"level_id": "tier1_level_01", "tier": 1, "tolerance": 0.0,
		"narrative_intro": "چراغ‌ها را روشن کن",
		"scales": [_scale([_number(3.0), _number(5.0)], [], 8.0)],
		"available_orbs": [{"type": "number", "value": 10.0, "count": 1},
			{"type": "number", "value": 2.0, "count": 5},
			{"type": "number", "value": 5.0, "count": 3}],
	}


func _negative_level_config() -> Dictionary:
	# تفریق/حباب (Tier 2): جواب = ۱۰ و **منهای ۲** → ۸ = چپ
	var cfg := {
		"level_id": "tier2_level_07", "tier": 2, "tolerance": 0.0,
		"narrative_intro": "بدهی هم وزن دارد",
		"scales": [_scale([_number(8.0)], [], 8.0)],
		"available_orbs": [{"type": "number", "value": 10.0, "count": 1},
			{"type": "negative", "value": 2.0, "count": 2}],
		"solution_spec": {"intended": {"right_orbs": [10.0, -2.0], "operations": ["add", "add"]}},
	}
	return cfg


func _two_side_config() -> Dictionary:
	# «هر دو طرف»: ۴ از چپ بردار و ۶ به راست اضافه کن (۱۲−۴ = ۲+۶ = ۸)
	return {
		"level_id": "tier2_level_09", "tier": 2, "tolerance": 0.0,
		"narrative_intro": "دو طرف را با هم ببین",
		"scales": [_scale([_number(12.0)], [_number(2.0)], 6.0)],
		"available_orbs": [{"type": "number", "value": 6.0, "count": 2},
			{"type": "number", "value": 4.0, "count": 1}],
		"solution_spec": {"intended": {
			"right_orbs": [6.0], "removed_orbs": [4.0], "operations": ["remove", "add"],
		}},
	}


# --------------------------------------------------------------------------
# ۱) computation_error — جهت درست، مقدار اشتباه
# --------------------------------------------------------------------------
func test_computation_error_when_direction_is_right() -> void:
	var cfg := _left_only_config()
	# به‌جای ۵+۲+۱ یک ۱۰ گذاشته → راست = ۱۰ ≠ ۸ (جهت درست، ۲ واحد اضافه)
	assert_eq(ErrorClassifier.classify(cfg, [_number(3.0), _number(5.0)], [_number(10.0)]),
		ErrorClassifier.COMPUTATION_ERROR)
	# ۵+۲ = ۷ → کم‌بودنِ مقدار هم محاسبه است، نه جهت
	assert_eq(ErrorClassifier.classify(cfg, [_number(3.0), _number(5.0)],
		[_number(5.0), _number(2.0)]), ErrorClassifier.COMPUTATION_ERROR)


# --------------------------------------------------------------------------
# ۲) wrong_operation — «کم کرده به‌جای اضافه کردن» و برعکس
# --------------------------------------------------------------------------
func test_wrong_operation_when_a_side_moves_against_the_plan() -> void:
	# راست از قبل ۲ دارد و باید ۹ واحد اضافه شود؛ بازیکن همان ۲ را برمی‌دارد
	var cfg := {
		"level_id": "tier1_level_04x", "tier": 1, "tolerance": 0.0, "narrative_intro": "ثابت‌ها را ببین",
		"scales": [_scale([_number(7.0), _number(4.0)], [_number(2.0)], 9.0)],
		"available_orbs": [{"type": "number", "value": 8.0, "count": 1},
			{"type": "number", "value": 2.0, "count": 5},
			{"type": "number", "value": 4.0, "count": 3}],
	}
	var s: Dictionary = ErrorClassifier.state_of(cfg, [_number(7.0), _number(4.0)], [])
	_near(float(s["right_delta"]), -2.0, "برداشتنِ کره‌ی ثابت = دلتای منفی")
	assert_eq(ErrorClassifier.classify(cfg, [_number(7.0), _number(4.0)], []),
		ErrorClassifier.WRONG_OPERATION)
	# برعکسش: جایی که باید از راست برداشته شود (intended منفی)، یک کره اضافه کرده
	var minus := {
		"level_id": "tier2_level_03x", "tier": 2, "tolerance": 0.0, "narrative_intro": "یکی را بردار",
		"scales": [_scale([_number(3.0)], [_number(5.0), _number(4.0)], 0.0)],
		"available_orbs": [{"type": "number", "value": 4.0, "count": 1}],
		"solution_spec": {"intended": {"right_orbs": [-4.0], "operations": ["remove"]}},
	}
	assert_eq(ErrorClassifier.classify(minus, [_number(3.0)],
		[_number(5.0), _number(4.0), _number(4.0)]), ErrorClassifier.WRONG_OPERATION,
		"باید برمی‌داشت، یک ۴ دیگر اضافه کرد")


func test_removing_from_the_left_when_only_the_right_needs_filling() -> void:
	# همان خطای منتظره‌ی `solution_spec.wrong_ops.remove_from_left`، روی داده‌ی واقعی
	var lv: LevelData = LevelLoader.load_level("tier1_level_04")
	assert_not_null(lv, "سطح ۰۴ باید از دیسک خوانده شود")
	if lv == null:
		return
	var cfg: Dictionary = lv.to_config_dict()
	assert_true((cfg.get("solution_spec", {}) as Dictionary).has("wrong_ops"),
		"سطح ۰۴ برای این خطا، `wrong_ops` دارد: " + str(cfg.get("solution_spec")))
	# چپ = ۷+۴ ثابت و راست = ۲ ثابت + ۹ لازم؛ بازیکن ۴ را از چپ برمی‌دارد
	assert_eq(ErrorClassifier.classify(cfg, [_number(7.0)], [_number(2.0)]),
		ErrorClassifier.WRONG_OPERATION,
		"«کم کردن از چپ» وقتی فقط باید راست پر شود، خطای جهت است نه محاسبه")


# --------------------------------------------------------------------------
# ۳) sign_flip_on_subtraction
# --------------------------------------------------------------------------
func test_sign_flip_when_one_inverted_orb_would_balance() -> void:
	var cfg := _negative_level_config()
	var left: Array = [_number(8.0)]
	# چیدمان درست (۱۰ و حبابِ −۲) = تعادل → طبقه‌بندی نمی‌شود
	assert_eq(ErrorClassifier.classify(cfg, left, [_number(10.0), {"type": "negative", "value": 2.0}]),
		"", "چیدمان درست خطا نیست")
	# همان ۲ را **مثبت** گذاشته (جای حباب): راست = ۱۲ و یک وارونگی علامت درستش می‌کند
	assert_eq(ErrorClassifier.classify(cfg, left, [_number(10.0), _number(2.0)]),
		ErrorClassifier.SIGN_FLIP_ON_SUBTRACTION, "یک وارونگی علامت، ترازو را صاف می‌کرد")
	# در سطحی که اصلاً ضد-وزن ندارد، برچسب «علامت» مجاز نیست
	var no_neg := _left_only_config()
	assert_ne(ErrorClassifier.classify(no_neg, [_number(3.0), _number(5.0)], [_number(10.0), _number(2.0)]),
		ErrorClassifier.SIGN_FLIP_ON_SUBTRACTION, "بی‌حباب، توضیحِ «علامت» را نباید بچسبانیم")


# --------------------------------------------------------------------------
# ۴) forgets_both_sides
# --------------------------------------------------------------------------
func test_forgets_both_sides_when_only_one_pan_moved() -> void:
	var cfg := _two_side_config()
	# فقط ۶ را به راست اضافه کرده، ۴ را از چپ برنداشته → ۱۲ ≠ ۸
	assert_eq(ErrorClassifier.classify(cfg, [_number(12.0)], [_number(2.0), _number(6.0)]),
		ErrorClassifier.FORGETS_BOTH_SIDES)
	# فقط چپ را سبک کرده، راست دست‌نخورده → همان خطا، سمتِ دیگر
	assert_eq(ErrorClassifier.classify(cfg, [_number(8.0)], [_number(2.0)]),
		ErrorClassifier.FORGETS_BOTH_SIDES)
	# هر دو طرف = درست (۸ = ۸)
	assert_eq(ErrorClassifier.classify(cfg, [_number(8.0)], [_number(2.0), _number(6.0)]), "")


# --------------------------------------------------------------------------
# مرزها
# --------------------------------------------------------------------------
func test_no_error_label_for_still_or_finished_states() -> void:
	var cfg := _left_only_config()
	assert_eq(ErrorClassifier.classify(cfg, [_number(3.0), _number(5.0)], []), "",
		"هیچ کره‌ای جابه‌جا نشده؛ «بی‌حرکتی» کار HintTimingSystem است")
	assert_eq(ErrorClassifier.classify(cfg, [_number(3.0), _number(5.0)],
		[_number(5.0), _number(2.0), _number(1.0)]), "", "ترازو متعادل شد")
	assert_eq(ErrorClassifier.classify({}, [], []), "", "config خالی نباید crash کند")
	assert_eq(ErrorClassifier.classify({"scales": []}, [_number(1.0)], [_number(9.0)]),
		ErrorClassifier.COMPUTATION_ERROR, "بدون spec هم باید برچسب معقول بدهد")


func test_state_of_reports_the_numbers_the_rules_use() -> void:
	var cfg := _two_side_config()
	var s: Dictionary = ErrorClassifier.state_of(cfg, [_number(12.0)], [_number(2.0), _number(6.0)])
	_near(float(s["left_base"]), 12.0)
	_near(float(s["right_base"]), 2.0)
	_near(float(s["right_delta"]), 6.0)
	_near(float(s["left_delta"]), 0.0)
	_near(float(s["need_right"]), 6.0)
	_near(float(s["intended_left_removed"]), 4.0, "بردارِ `removed_orbs` قدرمطلق است")
	assert_false(bool(s["balanced"]), "۱۲ در برابر ۸ متعادل نیست")
	var fixed_state: Dictionary = ErrorClassifier.state_of(cfg, [_number(8.0)], [_number(2.0), _number(6.0)])
	assert_true(bool(fixed_state["balanced"]), "۸ = ۸ → تعادل")


# --------------------------------------------------------------------------
# امتیاز وزن‌دار (نکته‌ی §۳: محاسبه در ErrorClassifier، نه در SkillRating)
# --------------------------------------------------------------------------
func test_success_score_matches_the_gdd_formula() -> void:
	# docs/07 §۵: score = 1 − 0.15*min(hints,2) − 0.05*min(extra_attempts,4)
	assert_eq(ErrorClassifier.success_score(0, 1), 1.0, "مستقل و یک‌بار = کامل")
	_near(ErrorClassifier.success_score(3, 1), 0.7, "همان مثالِ §۳ سند داده‌ها (۳ راهنما = ۰.۷)")
	_near(ErrorClassifier.success_score(0, 5), 0.8, "چهار تلاشِ از‌دست‌رفته")
	_near(ErrorClassifier.success_score(2, 5), 0.5, "کفِ طبیعی فرمول")
	_near(ErrorClassifier.success_score(9, 99), 0.5, "جریمه سقف دارد: بیشتر از این نمی‌افتد")
	assert_eq(ErrorClassifier.success_score(0, 0), 1.0, "attempts صفر جریمه ندارد")
	# ورودی نامعتبر نباید امتیاز را بیرون از ۰..۱ ببرد
	assert_true(ErrorClassifier.success_score(-3, -9) <= 1.0 + TOL)
	assert_true(ErrorClassifier.success_score(-3, -9) >= 0.0)


func test_error_types_are_stable_for_analytics_and_parent_dashboard() -> void:
	assert_eq(ErrorClassifier.ERROR_TYPES.size(), 4, "چهار نوع خطا (§۴.۲)؛ فهرست را بی‌صدا بزرگ نکن")
	assert_false(ErrorClassifier.ERROR_TYPES.has(ErrorClassifier.IDLE),
		"idle خطا نیست و نباید در `error_patterns` بنشیند")
	assert_true(ErrorClassifier.is_error_type(ErrorClassifier.WRONG_OPERATION))
	assert_false(ErrorClassifier.is_error_type("teleportation"))
	for t: String in ErrorClassifier.ERROR_TYPES:
		assert_true(t.contains("_") or t.length() > 3, "نام پایدار برای JSON: " + t)
	assert_true(ErrorClassifier.ERROR_TYPES.has(
		ErrorClassifier.classify(_left_only_config(), [_number(3.0)], [_number(9.0)])),
		"خروجی classify باید همیشه در همین فهرست باشد")


func test_real_tier1_levels_only_produce_declared_types() -> void:
	var ids: Array[String] = LevelLoader.level_ids()
	assert_gte(ids.size(), 5, "فاز ۳ پنج سطح Tier 1 نوشته است")
	for id: String in ids:
		var lv: LevelData = LevelLoader.load_level(id)
		if lv == null:
			continue
		var cfg: Dictionary = lv.to_config_dict()
		var scale: Dictionary = (cfg["scales"] as Array)[0]
		var left_now: Array = []
		for entry: Variant in (scale["left_orbs"] as Array):
			left_now.append(entry)
		# چیدمان عمداً غلط: یک کره‌ی ۱ روی راست
		var label := ErrorClassifier.classify(cfg, left_now, [_number(1.0)])
		if label.is_empty():
			continue
		assert_true(ErrorClassifier.is_error_type(label), "%s: برچسب ناشناخته `%s`" % [id, label])
