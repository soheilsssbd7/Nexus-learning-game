extends GutTest
# ===========================================================================
# تسک ۴.۵ — شبیه‌سازی ۳۰ سطحی (DoD: «منحنی سختی برای بازیکن ضعیف و قوی واگراست»)
# --------------------------------------------------------------------------
# چرا استخر مصنوعی و نه فایل؟ چون `DifficultyEngine.choose_next()` عمداً pure است
# (ورودی‌اش فهرست کاندید + فلگ‌هاست، نه دیسک/مدل). این‌طور ۳۰ سطح در چند میکروثانیه
# در CI دویده می‌شود و لازم نیست ۲۵ فایل JSON صوری به مخ اضافه کنیم.
# حلقه دقیقاً همان کاری را می‌کند که `next_level()` + `apply_level_result()` روی
# بازیِ واقعی: کاندیدسازی (بدون تکمیل‌شده‌ها؛ با تکمیل‌شده‌ها برای «تمرین مجدّد»)،
# محاسبه‌ی فلگ‌ها از ثابت‌های خودِ موتور، و به‌روزرسانی رتبه با `SkillRating`.
# ===========================================================================

const POOL_SIZE := 30
const LEVELS_PER_TIER := 10
const FIRST_ELO := 820.0
const ELO_STEP := 20.0
const OPEN_TIER := 3


func _base_pool() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in range(POOL_SIZE):
		out.append({
			"id": "sim_%02d" % (i + 1),
			"elo": FIRST_ELO + ELO_STEP * float(i),
			"tier": int(float(i) / float(LEVELS_PER_TIER)) + 1,
		})
	return out


func _last_reason_was_remediation(reasons: Array[String]) -> bool:
	return not reasons.is_empty() \
		and reasons[reasons.size() - 1] == "struggle_practice_rerun"


## یک بازیِ کامل: از پله‌ی اول تا ۳۰ سطح. برگشت: ترتیب سطوح، دلایل، رتبه‌ها.
func _run(hints_per_level: int, attempts_per_level: int) -> Dictionary:
	var pool := _base_pool()
	var completed := {}
	var order: Array[String] = []
	var reasons: Array[String] = []
	var elos: Array[float] = []
	var served_hard: Array[bool] = []
	var picked_indices: Array[int] = []
	var elo: float = SkillRating.ELO_START
	var no_hint_streak: int = 0
	for step: int in range(POOL_SIZE):
		var struggle: bool = attempts_per_level >= DifficultyEngine.STRUGGLE_ATTEMPTS \
			and not _last_reason_was_remediation(reasons)
		var skip: String = order[order.size() - 1] if not order.is_empty() else ""
		var cands: Array[Dictionary] = []
		for row: Dictionary in pool:
			var id: String = str(row["id"])
			var done: bool = completed.has(id)
			if id == skip:
				continue
			if done and not struggle:
				continue
			var entry := row.duplicate() as Dictionary
			entry["completed"] = done
			entry["index"] = cands.size()
			cands.append(entry)
		var hard_recently: bool = false
		var from: int = maxi(0, served_hard.size() - DifficultyEngine.HARD_WINDOW)
		for i: int in range(from, served_hard.size()):
			if served_hard[i]:
				hard_recently = true
				break
		var flags := {
			"struggle": struggle,
			"mastery_jump": no_hint_streak >= DifficultyEngine.MASTERY_STREAK,
			"hard_used_recently": hard_recently,
			"current_tier": OPEN_TIER,
		}
		var picked: Dictionary = DifficultyEngine.choose_next(elo, cands, flags)
		var chosen_id: String = str(picked.get("level_id", ""))
		if chosen_id.is_empty():
			break
		var difficulty: float = FIRST_ELO
		var picked_index: int = 0
		for i: int in range(cands.size()):
			var row: Dictionary = cands[i]
			if str(row["id"]) == chosen_id:
				difficulty = float(row["elo"])
				picked_index = i
		order.append(chosen_id)
		reasons.append(str(picked.get("reason", "")))
		picked_indices.append(picked_index)
		served_hard.append(difficulty > elo + DifficultyEngine.HARD_ELO_GAP)
		# نتیجه‌ی واقعی با همان SkillRating بازی (وزن = score از خودِ فاز ۴.۲)
		var score: float = ErrorClassifier.success_score(hints_per_level, attempts_per_level)
		var rating := SkillRating.new()
		rating.elo = elo
		rating.apply_result(difficulty, true, score)
		# هیچ کف‌سازی‌ای نداریم: بازیکنی که روی سطحِ آسان سه راهنما می‌گیرد واقعاً
		# رتبه‌اش پایین می‌آید (این همان «وزن‌دهی» §۵ است، نه تنبیه).
		elo = rating.elo
		elos.append(elo)
		completed[chosen_id] = true  # هر برد (حتی تمرین) در مدل «تمام‌شده» می‌ماند
		no_hint_streak = 0 if hints_per_level > 0 else no_hint_streak + 1
	return {
		"order": order, "reasons": reasons, "elos": elos, "indices": picked_indices,
		"served_hard": served_hard, "final_elo": elo,
	}


# --------------------------------------------------------------------------
func test_the_simulated_ladder_covers_thirty_levels_without_repeats() -> void:
	var strong: Dictionary = _run(0, 1)
	var order: Array = strong["order"] as Array
	assert_eq(order.size(), POOL_SIZE, "بازیکن قوی هر ۳۰ پله را طی می‌کند")
	assert_eq(order.count(order[0]), 1, "یک سطح دو بار به بازیکن قوی داده نمی‌شود")
	var seen := {}
	for id: Variant in order:
		seen[str(id)] = true
	assert_eq(seen.size(), POOL_SIZE, "هیچ تکراری در سی سطحِ بازیکن قوی نیست")


func test_strong_and_weak_players_end_up_on_different_rungs() -> void:
	var weak: Dictionary = _run(3, 5)
	var strong: Dictionary = _run(0, 1)
	var gap: float = float(strong["final_elo"]) - float(weak["final_elo"])
	assert_gt(gap, 100.0,
		"§۵: رتبه‌ی دو بازیکن بعد از ۳۰ سطح باید واگرا شود (فاصله‌ی اندازه‌گیری‌شده %f)" % gap)
	var weak_order: Array = weak["order"] as Array
	var strong_order: Array = strong["order"] as Array
	assert_lt(weak_order.size(), strong_order.size(),
		"بازیکن ضعیف به‌خاطر تمرینِ مجدّد سطحِ تازه‌ی کمتری طی می‌کند")
	var weak_seen := {}
	for id: Variant in weak_order:
		weak_seen[str(id)] = true
	assert_lt(weak_seen.size(), POOL_SIZE, "سطح‌های تازه‌ی کمتری در مسیر بازیکن ضعیف هست")


func test_the_weak_player_gets_practice_instead_of_being_pressed_forward() -> void:
	var weak: Dictionary = _run(3, 5)
	var reasons: Array = weak["reasons"] as Array
	var reruns: int = 0
	for r: Variant in reasons:
		if str(r) == "struggle_practice_rerun":
			reruns += 1
	assert_gt(reruns, 0, "گیرکردنِ مکرر باید به «تمرین مجدّد» برسد، نه به پله‌ی بعدی")
	assert_lt(reruns, reasons.size() / 2, "و نباید کل بازی را به تکرار بگذراند")
	var strong: Dictionary = _run(0, 1)
	assert_eq((strong["reasons"] as Array).count("struggle_practice_rerun"), 0,
		"بازیکنی که یک‌بار درست می‌چیند هرگز به عقب برنمی‌گردد")


## دو نامسه‌ای که «ضددیوار» §۵ واقعاً تضمین می‌کند (و هر دو روی هر چهار سناریو):
##  ۱) هرگز دو سطحِ سخت پشت‌سرهم؛ ۲) موتور حداکثر **یک** پله از نردبان جلو می‌زند.
## چرا «حداکثر ۱ سخت در هر ۳»? چون وقتی کلِ Tier بالاتر از رتبه‌ی بازیکن باشد،
## «ساده‌ترینِ همان Tier» هم هنوز سخت است — موتور در این حالت انتخابِ بدتر ندارد،
## پس ادعای قابل‌تست همان «پشت‌سرهم‌نبودن» است (کپِ واقعیِ کد).
func test_the_anti_wall_caps_hold_for_every_scenario() -> void:
	for scenario: Array in [[0, 1], [1, 2], [2, 4], [3, 5]]:
		var res: Dictionary = _run(int(scenario[0]), int(scenario[1]))
		var hard: Array = res["served_hard"] as Array
		var idxs: Array = res["indices"] as Array
		var label: String = "سناریو hints=%d attempts=%d" % [int(scenario[0]), int(scenario[1])]
		var consec: int = 0
		for i: int in range(1, hard.size()):
			if bool(hard[i]) and bool(hard[i - 1]):
				consec += 1
		assert_eq(consec, 0, "هیچ‌وقت دو سطح سخت پشت‌سرهم نیست (%s)" % label)
		for i: int in range(idxs.size()):
			assert_true(int(idxs[i]) <= DifficultyEngine.MAX_SWAP_AHEAD,
				"حداکثر یک پله جابه‌جایی از نردبان (%s، گام %d)" % [label, i])


func test_rating_stays_inside_the_clamp() -> void:
	for scenario: Array in [[0, 1], [3, 5]]:
		var res: Dictionary = _run(int(scenario[0]), int(scenario[1]))
		var elos: Array = res["elos"] as Array
		assert_false(elos.is_empty(), "رتبه در طول بازی ثبت می‌شود")
		for i: int in range(elos.size()):
			var e: float = float(elos[i])
			assert_true(e >= SkillRating.ELO_MIN and e <= SkillRating.ELO_MAX,
				"Elo داخل clamp می‌ماند (%f)" % e)
		assert_gt(float(res["final_elo"]), SkillRating.ELO_START,
			"سی سطح بی‌راهنما = بازیکنی که واقعاً جلو رفته")


func test_rating_stays_inside_the_clamp_and_moves_monotonically() -> void:
	for scenario: Array in [[0, 1], [3, 5]]:
		var res: Dictionary = _run(int(scenario[0]), int(scenario[1]))
		var elos: Array = res["elos"] as Array
		assert_false(elos.is_empty(), "رتبه در طول بازی ثبت می‌شود")
		for i: int in range(elos.size()):
			var e: float = float(elos[i])
			assert_true(e >= SkillRating.ELO_MIN and e <= SkillRating.ELO_MAX,
				"Elo داخل clamp می‌ماند (%f)" % e)
			if i > 0:
				assert_true(e >= float(elos[i - 1]), "بدون باخت، رتبه عقب نمی‌رود")


func test_the_engine_is_deterministic_for_the_same_player() -> void:
	var a: Dictionary = _run(1, 2)
	var b: Dictionary = _run(1, 2)
	assert_eq(a["order"], b["order"], "همان ورودی = همان ترتیب سطوح (بدون تصادف)")
	assert_eq(a["reasons"], b["reasons"], "و همان دلیل‌ها — تستِ رگرسیونِ قوانین §۵")
