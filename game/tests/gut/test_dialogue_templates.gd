extends GutTest
# ===========================================================================
# تسک ۵.۱/۵.۲ — قالب‌های دیالوگ Aria: پارسر، قوانین §۴ و «قانون طلایی»
# --------------------------------------------------------------------------
# این فایل دو چیز را جدا می‌سنجد: (الف) منطق پارسر روی داده‌ی ساختگی، تا شکل‌های خراب
# هم قابل‌تست باشند؛ (ب) فایل واقعیِ_ship_شده، چون همان چیزی است که بچه می‌خواند.
# ===========================================================================

const SHIPPED := "res://data/dialogue/aria_templates.json"


func _index(text: String) -> Dictionary:
	return DialogueTemplate.index_from_text(text)


func _tpl(dict: Dictionary) -> DialogueTemplate:
	return DialogueTemplate.from_dict(dict)


func _good_json(variants: Array = ["الف", "ب"], min_tier: int = 1,
		max_tier: int = 3, types: Array = ["wrong_operation"]) -> String:
	return JSON.stringify({"hints": [{
		"hint_id": "h1",
		"applies_to_error_types": types,
		"min_tier": min_tier,
		"max_tier": max_tier,
		"text_variants": variants,
	}]})


# --------------------------------------------------------------------------
# الف) منطق پارسر
# --------------------------------------------------------------------------
func test_parses_a_good_template() -> void:
	var res: Dictionary = _index(_good_json())
	assert_true(bool(res["ok"]), "قالب درست نباید خطا بدهد: " + str(res["error"]))
	var by_id: Dictionary = res["by_id"]
	assert_true(by_id.has("h1"))
	var tpl: DialogueTemplate = by_id["h1"]
	assert_eq(tpl.variant_count(), 2)
	assert_eq(tpl.min_tier, 1)
	assert_eq(tpl.max_tier, 3)
	assert_true(tpl.applies_to("wrong_operation"))
	assert_false(tpl.applies_to("idle"))
	assert_true(tpl.covers_tier(2))
	assert_false(tpl.covers_tier(4))


func test_broken_json_never_crashes_and_says_why() -> void:
	# عمداً JSON بی‌اعتبار («{ this is not json ») نمی‌دهیم: خودِ Godot آن را با یک ERROR
	# لاگ می‌کند و GUT هر ERROR را «unexpected» می‌شمارد؛ همان حالت با `load_file` روی
	# مسیر ناموجود سنجیده می‌شود. اینجا «شکلِ بدِ ولی JSONِ درست» مهم است.
	var bad: Dictionary = _index("{\"just\": \"a shape without hints\"}")
	assert_false(bool(bad["ok"]))
	assert_true(str(bad["error"]).contains("hints"), str(bad["error"]))
	assert_false(bool(_index("").ok), "متن خالی")
	assert_false(bool(_index("[]").ok), "ریشه باید object باشد")
	assert_false(bool(_index("{\"hints\": []}").ok), "hints خالی")
	assert_false(bool(_index("{\"hints\": 3}").ok), "hints باید آرایه باشد")
	var missing_file: Dictionary = DialogueTemplate.load_file("res://data/dialogue/nope.json")
	assert_false(bool(missing_file["ok"]), "فایل نبود → ok=false، نه crash")
	assert_true(str(missing_file["error"]).contains("پیدا نشد"), str(missing_file["error"]))


func test_one_variant_is_rejected() -> void:
	# §۴: «چرخشی نه تصادفی» با یک واریانت بی‌معنی است
	var res: Dictionary = _index(_good_json(["فقط یکی"]))
	assert_false(bool(res["ok"]))
	assert_true(str(res["error"]).contains("text_variant"))


func test_bad_ranges_and_unknown_error_types_are_reported() -> void:
	assert_true(str(_index(_good_json(["ا", "ب"], 3, 1))["error"]).contains("min_tier"))
	assert_true(str(_index(_good_json(["ا", "ب"], 0, 3))["error"]).contains("min_tier"))
	assert_true(str(_index(_good_json(["ا", "ب"], 1, 9))["error"]).contains("min_tier"))
	var unknown: Dictionary = _index(_good_json(["ا", "ب"], 1, 3, ["telepathy"]))
	assert_false(bool(unknown["ok"]))
	assert_true(str(unknown["error"]).contains("telepathy"))
	assert_false(bool(_index(_good_json(["ا", ""], 1, 3))["ok"]), "واریانت خالی ممنوع")


func test_long_text_is_flagged_as_overflow_risk() -> void:
	var long_text: String = ""
	for i: int in range(40):
		long_text += "کلمه‌ای‌برای"
	assert_gt(long_text.length(), DialogueTemplate.MAX_TEXT_LEN, "ورودی تست باید بلند باشد")
	assert_false(bool(_index(_good_json([long_text, "کوتاه"]))["ok"]),
		"Art Bible §۷: متن بلندتر از حد، سرریز DialogueBox است")


func test_duplicate_ids_keep_the_first_and_order_is_file_order() -> void:
	var text := JSON.stringify({"hints": [
		{"hint_id": "a", "applies_to_error_types": ["idle"], "min_tier": 1,
			"max_tier": 5, "text_variants": ["a1", "a2"]},
		{"hint_id": "a", "applies_to_error_types": ["idle"], "min_tier": 1,
			"max_tier": 5, "text_variants": ["b1", "b2"]},
		{"hint_id": "c", "applies_to_error_types": ["idle"], "min_tier": 1,
			"max_tier": 5, "text_variants": ["c1", "c2"]},
	]})
	var res: Dictionary = _index(text)
	var order: PackedStringArray = res["order"]
	assert_eq(order.size(), 2, "id تکراری دوباره فهرست نمی‌شود")
	assert_eq(str(order[0]), "a")
	var by_id: Dictionary = res["by_id"]
	assert_eq(str((by_id["a"] as DialogueTemplate).text_for(0)), "a1",
		"اولین تعریف برنده است (ترتیب نویسنده محترم است)")


# --------------------------------------------------------------------------
# ب) انتخاب: چرخشی و خطابنیان
# --------------------------------------------------------------------------
func test_rotation_wraps_and_never_repeats_the_same_variant_twice() -> void:
	var tpl := _tpl({
		"hint_id": "x", "applies_to_error_types": ["idle"], "min_tier": 1,
		"max_tier": 5, "text_variants": ["v1", "v2", "v3"],
	})
	var seen: Array[String] = []
	for i: int in range(7):
		seen.append(tpl.text_for(i))
	assert_eq(seen[0], "v1")
	assert_eq(seen[2], "v3")
	assert_eq(seen[3], "v1", "بعد از آخری از اول (چرخشی، نه تصادفی)")
	for i: int in range(1, seen.size()):
		assert_ne(seen[i], seen[i - 1], "هیچ واریانتی پشت‌سرهم تکرار نمی‌شود")
	assert_eq(tpl.text_for(-1), "v2", "شمارنده‌ی منفی به قدرمطلق می‌چرخد (قرقره ندارد)")
	var empty := _tpl({"hint_id": "e", "applies_to_error_types": ["idle"],
		"min_tier": 1, "max_tier": 1, "text_variants": []})
	assert_eq(empty.text_for(4), "", "قالب بی‌متن نباید crash کند")


func test_match_error_respects_the_tier_window() -> void:
	var res: Dictionary = _index(JSON.stringify({"hints": [
		{"hint_id": "tier3_only", "applies_to_error_types": ["computation_error"],
			"min_tier": 3, "max_tier": 5, "text_variants": ["a", "b"]},
		{"hint_id": "any_tier", "applies_to_error_types": ["computation_error"],
			"min_tier": 1, "max_tier": 5, "text_variants": ["c", "d"]},
	]}))
	var by_id: Dictionary = res["by_id"]
	var order: PackedStringArray = res["order"]
	assert_eq(DialogueTemplate.match_error(by_id, order, "computation_error", 2), "any_tier",
		"قالبِ Tier ۳+ برای Tier ۲ انتخاب نمی‌شود")
	assert_eq(DialogueTemplate.match_error(by_id, order, "computation_error", 4), "tier3_only",
		"اولین انطباقِ فایل برنده است")
	assert_eq(DialogueTemplate.match_error(by_id, order, "idle", 4), "",
		"بی‌ربط = رشته‌ی خالی (نه crash، نه حدس)")


# --------------------------------------------------------------------------
# پ) فایل واقعی
# --------------------------------------------------------------------------
func test_the_shipped_file_is_valid_and_covers_the_plan() -> void:
	assert_true(FileAccess.file_exists(SHIPPED), "فاز ۵ باید فایل را بسازد: " + SHIPPED)
	var res: Dictionary = DialogueTemplate.load_file(SHIPPED)
	assert_true(bool(res["ok"]), "خطای §۴: " + str(res["error"]))
	var by_id: Dictionary = res["by_id"]
	assert_gte(by_id.size(), 15, "تسک ۵.۲: حداقل ۱۵ hint_id")
	var total: int = DialogueTemplate.count_variants(by_id)
	assert_gte(total, by_id.size() * DialogueTemplate.MIN_VARIANTS,
		"هر قالب حداقل دو واریانت")
	var id: String = "gentle_nudge_01"
	assert_true(by_id.has(id), "این id را داده‌ی سطح ۰۱ صدا می‌زند")
	var tpl: DialogueTemplate = by_id[id]
	assert_gt(tpl.variant_count(), 1)
	assert_eq(tpl.text_for(0), tpl.text_for(tpl.variant_count()),
		"چرخش کامل = همان متن، پس UI هیچ‌وقت رشته‌ی تهی نمی‌گیرد")


func test_no_hint_text_contains_any_digit() -> void:
	# «قانون طلایی» §۴ در GUT هم نگه داشته می‌شود (نسخه‌ی پایتونِ tools آن را سطح‌به‌سطح
	# با عددِ جواب می‌سنجد؛ این نسخه ساده‌تر و مستقل‌تر است): هیچ رقمه‌ای، فارسی یا لاتین،
	# در متن راهنما مجاز نیست — چون جواب این بازی همیشه یک عدد است.
	var res: Dictionary = DialogueTemplate.load_file(SHIPPED)
	var by_id: Dictionary = res["by_id"]
	var offenders: Array[String] = []
	for id: Variant in by_id.keys():
		var tpl: DialogueTemplate = by_id[id]
		for text: String in tpl.text_variants:
			for i: int in range(text.length()):
				var c: String = text[i]
				if (c >= "0" and c <= "9") or (c >= "۰" and c <= "۹"):
					offenders.append("%s: %s" % [str(id), text])
					break
	assert_true(offenders.is_empty(), "متن‌های دارای رقم: %s" % str(offenders))


func test_every_hint_id_used_by_the_levels_exists() -> void:
	var res: Dictionary = DialogueTemplate.load_file(SHIPPED)
	var by_id: Dictionary = res["by_id"]
	var checked: int = 0
	for tier: int in range(1, 6):
		for id: String in LevelLoader.levels_for_tier(tier):
			var lv: LevelData = LevelLoader.load_level(id)
			if lv == null:
				continue
			for entry: Variant in lv.hint_sequence:
				if not (entry is Dictionary):
					continue
				var hint_id: String = str((entry as Dictionary).get("hint_id", ""))
				assert_true(by_id.has(hint_id),
					"%s: قالب دیالوگِ `%s` غایب است" % [id, hint_id])
				checked += 1
	assert_gt(checked, 0, "سطح‌ها باید دست‌کم یک راهنما داشته باشند")
