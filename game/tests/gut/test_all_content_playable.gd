extends GutTest
# ===========================================================================
# تسک ۷.۰ — «محتوای تولیدشده باید در موتور حل شود» (قاعده‌ی فاز ۷ در سند ۰۵)
# ---------------------------------------------------------------------------
# `tools/validate_levels.py` با DP ثابت می‌کند هر سطح **روی کاغذ** قابل‌حل است؛ این فایل
# همان ادعا را با **کدِ واقعیِ بازی** می‌سنجد: صحنه ساخته می‌شود، کره‌های
# `solution_spec.intended` سرِ کفه‌ی راست می‌نشینند و `is_won()` باید درست شود.
# چرا هر دو لازم‌اند: اگر روزی دو پیاده‌سازیِ «وزنِ کره» از هم فاصله بگیرند (مثلاً
# علامتِ `negative` در موتور و در ابزار فرق کند) فقط همین تست می‌گیرد ✗✓ و این دقیقاً
# همان کلاسی از باگ است که در داده‌ی انبوه، پلی‌تست انسانی نمی‌بیندش.
# هیچ عددِ دست‌نویسی اینجا نیست: فهرست سطح‌ها از دیسک خوانده می‌شود، پس افزودن سطح
# به Tierهای ۳..۵ بدون ویرایش این فایل پوشش داده می‌شود ✓ (DoD ۷.x).
# ===========================================================================

const LEVELS_ROOT := "res://data/levels"
const DIALOGUE_PATH := "res://data/dialogue/aria_templates.json"

var _ids: Array[String] = []


func before_all() -> void:
	_ids = _discover_level_ids()
	assert_gt(_ids.size(), 0, "کشف سطح از دیسک شکست خورد (مسیر: %s)" % LEVELS_ROOT)


## `_ids` از `res://data/levels/tier<N>/*.json` ساخته می‌شود.
func _discover_level_ids() -> Array[String]:
	var out: Array[String] = []
	for tier: int in range(1, 6):
		var dir_path: String = "%s/tier%d" % [LEVELS_ROOT, tier]
		var dir: DirAccess = DirAccess.open(dir_path)
		if dir == null:
			continue
		for file: String in dir.get_files():
			if file.ends_with(".json") and file.begins_with("level_"):
				var cfg: Dictionary = _read_json("%s/%s" % [dir_path, file])
				var lid: String = str(cfg.get("level_id", ""))
				if not lid.is_empty():
					out.append(lid)
	out.sort()
	return out


## فایلِ **نوشته‌شده** را می‌خوانیم، نه `load_config()`: آن dict نتیجهٔ تبدیل
## `LevelData.to_config_dict()` است و `solution_spec`/`difficulty_eme` در آن نیست ⇒
## سنجشِ محتوا باید با متنِ اصلیِ فایل باشد (وگرنه تست بی‌آنکه بداند هیچی نمی‌سنجد).
func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var raw: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	return parsed as Dictionary if parsed is Dictionary else {}


## کره‌های سینی که وزنشان (با علامت!) برابر مقدارِ خواسته‌شده است؛ هر کره یک بار
## مصرف می‌شود تا سطح‌های چندکره‌ای جوابِ ساختگی نگیرند.
func _pick_orbs(scene: LevelController, wanted: Array, used: Array[WeightOrb]) -> Array[WeightOrb]:
	var out: Array[WeightOrb] = []
	for value: Variant in wanted:
		var found: WeightOrb = null
		for orb: WeightOrb in scene.tray_orbs:
			if orb == null or used.has(orb) or orb.is_placed:
				continue
			if is_equal_approx(orb.weight(), float(value)):
				found = orb
				break
		if found == null:
			return []
		used.append(found)
		out.append(found)
	return out


func _scene_for(level_id: String) -> LevelController:
	LevelLoader.clear_pending_config()
	var scene: LevelController = LevelLoader.create_level_scene(level_id) as LevelController
	assert_not_null(scene, "صحنهٔ `%s` ساخته نشد" % level_id)
	if scene == null:
		return null
	# محتوای تستی نباید آمار کودک را عوض کند (ADR-050 همان درس را در آموزش داد)
	scene.report_progress = false
	scene.attempt_settle_sec = 0.05
	add_child_autofree(scene)
	await get_tree().process_frame
	return scene


func test_every_level_id_on_disk_is_discoverable_by_the_loader() -> void:
	var missing: Array[String] = []
	for lid: String in _ids:
		if not LevelLoader.level_ids().has(lid):
			missing.append(lid)
	assert_true(missing.is_empty(), "این سطح‌ها روی دیسک‌اند ولی `LevelLoader` نمی‌بیند: " + str(missing))
	assert_eq(LevelLoader.level_count(), _ids.size(),
		"شمارش موتور و دیسک باید یکی باشد، وگرنه یک Tier نصفه بارگذاری می‌شود")


func test_the_intended_solution_wins_on_every_level() -> void:
	var checked: int = 0
	for lid: String in _ids:
		var cfg: Dictionary = _read_json(LevelLoader.path_for(lid))
		var intended: Variant = (cfg.get("solution_spec", {}) as Dictionary).get("intended", null)
		if not (intended is Dictionary):
			continue
		var wanted: Variant = (intended as Dictionary).get("right_orbs", [])
		if not (wanted is Array) or (wanted as Array).is_empty():
			continue
		var scene: LevelController = await _scene_for(lid)
		if scene == null:
			continue
		var used: Array[WeightOrb] = []
		var orbs: Array[WeightOrb] = _pick_orbs(scene, wanted as Array, used)
		assert_eq(orbs.size(), (wanted as Array).size(),
			"`%s`: هر کرهٔ `intended.right_orbs` باید در سینی پیدا شود (علامت هم بخشی از مقدار است)" % lid)
		var scale_index: int = int((intended as Dictionary).get("scale_index", 0))
		scene.place_on_right(orbs, scale_index)
		await get_tree().process_frame
		assert_true(scene.is_won(),
			"`%s`: حلِ قصدمندِ نوشته‌شده در موتور برنده نشد ⇒ داده و کد از هم فاصله گرفته‌اند" % lid)
		checked += 1
	assert_gte(checked, 1, "هیچ سطحی `solution_spec.intended` نداشت ⇒ این تست چیزی نمی‌سنجد")
	assert_eq(checked, _ids.size(),
		"همهٔ سطح‌ها باید حلِ قصدمندِ تست‌شدنی داشته باشند (سنجیده‌شده: %d از %d)" % [checked, _ids.size()])


func test_the_documented_wrong_move_never_wins() -> void:
	# `solution_spec.wrong_ops.right_orbs` = حرکتِ «اشتباهِ آموزشی» همان سطح ✗ اگر آن هم
	# ببرد، سطح چیزی یاد نمی‌دهد (هر دو چیدمان درست‌اند) ⇒ داده‌ی بد نوشته شده است.
	for lid: String in _ids:
		var cfg: Dictionary = _read_json(LevelLoader.path_for(lid))
		var wrong: Variant = (cfg.get("solution_spec", {}) as Dictionary).get("wrong_ops", null)
		if not (wrong is Dictionary):
			continue
		var wanted: Variant = (wrong as Dictionary).get("right_orbs", [])
		if not (wanted is Array) or (wanted as Array).is_empty():
			continue
		var scene: LevelController = await _scene_for(lid)
		if scene == null:
			continue
		var used: Array[WeightOrb] = []
		var orbs: Array[WeightOrb] = _pick_orbs(scene, wanted as Array, used)
		if orbs.size() != (wanted as Array).size():
			continue  # کره‌ها در سینی نیستند؛ قاعدهٔ داده‌ای در validator گرفته می‌شود
		# کره‌ها یکی‌یکی می‌نشینند و **هیچ پیشوندی** نباید ببرد ✗✓ اگر همه را یک‌جا بگذاریم
		# و برد در موتور latch شده باشد، ترتیبِ داده می‌تواند «باختن را وانمود کند؛ این
		# حلقه همان را در موتور سنجید و قاعدهٔ «هیچ زیرمجموعه‌ای تراز نکند» در validator آن را
		# در داده (برای همهٔ ترتیب‌ها) می‌بندد ✓✓ دو لایه، یک ادعا. (نمونهٔ واقعی: Tier ۲ دو
		# سطح داشت که `wrong_ops` = حلِ درست + یک کره بود ⇒ با سه تای اول بُرد ✗✓ ADR-053.)
		for k: int in range(orbs.size()):
			scene.place_on_right([orbs[k]])
			await get_tree().process_frame
			assert_false(scene.is_won(),
				"`%s`: «حرکتِ اشتباه» با %d کرهٔ اول تراز می‌کند ⇒ آن حرکت اشتباه نیست" % [lid, k + 1])


func test_every_level_offers_a_hint_that_the_runtime_can_deliver() -> void:
	var table: Dictionary = {}
	for h: Variant in (_read_json(DIALOGUE_PATH).get("hints", []) as Array):
		var d: Dictionary = h as Dictionary
		table[str(d.get("hint_id", ""))] = d
	assert_gte(table.size(), 15, "فایل قالب‌ها خوانده نشد ⇒ این تست کور است")
	var bad: Array[String] = []
	for lid: String in _ids:
		var cfg: Dictionary = _read_json(LevelLoader.path_for(lid))
		var seq: Variant = cfg.get("hint_sequence", [])
		assert_true(seq is Array and not (seq as Array).is_empty(),
			"`%s`: بی‌hint_sequence ⇒ کودکِ گیرکرده هیچ راهنمایی نمی‌گیرد" % lid)
		if not (seq is Array):
			continue
		for step: Variant in (seq as Array):
			var hid: String = str((step as Dictionary).get("hint_id", ""))
			var entry: Dictionary = table.get(hid, {}) as Dictionary
			if entry.is_empty() or (entry.get("text_variants") as Array).is_empty():
				bad.append("%s→%s" % [lid, hid])
	assert_true(bad.is_empty(), "این سطح‌ها به قالبی ارجاع می‌دهند که متن ندارد: " + str(bad))


func test_the_first_level_of_a_tier_continues_the_elo_curve_of_the_previous_one() -> void:
	# رابطه، نه عدد: پرشِ Tier→Tier هم مثل پرشِ داخل Tier مجاز به ۱۲۰ نیست (اسناد ۰۳ §3).
	var by_tier: Dictionary = {}
	for lid: String in _ids:
		var cfg: Dictionary = _read_json(LevelLoader.path_for(lid))
		var tier: int = int(cfg.get("tier", 0))
		var elo: float = float(cfg.get("difficulty_elo", 0.0))
		if not by_tier.has(tier):
			by_tier[tier] = {"min": elo, "max": elo}
		else:
			(by_tier[tier] as Dictionary)["min"] = minf(elo, float((by_tier[tier] as Dictionary)["min"]))
			(by_tier[tier] as Dictionary)["max"] = maxf(elo, float((by_tier[tier] as Dictionary)["max"]))
	var tiers: Array = by_tier.keys()
	tiers.sort()
	for i: int in range(1, tiers.size()):
		var prev: Dictionary = by_tier[tiers[i - 1]] as Dictionary
		var cur: Dictionary = by_tier[tiers[i]] as Dictionary
		assert_gte(float(cur["min"]), float(prev["min"]),
			"Tier %s باید از Tier %s آسان‌تر نباشد" % [str(tiers[i]), str(tiers[i - 1])])
		assert_lte(float(cur["min"]) - float(prev["max"]), 120.0,
			"پشیمانیِ مرز Tier: پرش Elo بیش از ۱۲۰ (=سقفِ داخل Tier) است")
