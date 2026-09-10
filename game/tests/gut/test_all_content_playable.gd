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
## ورودی `solution_spec.*.right_orbs` دو شکل دارد (ADR-055): عددِ ساده برای سطحِ تک‌کفه،
## و `{"value": 4, "scale": 1}` برای چندکفه ⇒ اینجا هر دو به `[{value, scale}]` تبدیل
## می‌شوند تا تست‌ها یک مسیر داشته باشند ✗✓ (دو مسیرِ مجزا در تست = نیمی از ادعا).
func _orb_rows(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (raw is Array):
		return out
	for v: Variant in (raw as Array):
		if v is Dictionary:
			var d: Dictionary = v as Dictionary
			out.append({"value": float(d.get("value", 0.0)), "scale": int(d.get("scale", 0))})
		else:
			out.append({"value": float(v), "scale": 0})
	return out


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var raw: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	return parsed as Dictionary if parsed is Dictionary else {}


## صحنهٔ واقعیِ سطح، با bookkeepingِ خاموش ✗✓ (ADR-050: «تستِ محتوا نباید آمارِ کودک
## را آلوده کند») و `attempt_settle_sec` کوتاه، تا هر کره در همان فریم settle شود.
## coroutine است، پس هر فراخوانی‌اش `await` می‌خواهد — Godot خطای parse می‌دهد و فایل
## را اصلاً load نمی‌کند ✗✓ (دقیقاً همان «سبزِ توخالی» که نباید تکرار شود).
func _scene_for(level_id: String) -> LevelController:
	LevelLoader.clear_pending_config()
	var scene: LevelController = LevelLoader.create_level_scene(level_id) as LevelController
	assert_not_null(scene, "صحنهٔ `%s` ساخته نشد" % level_id)
	if scene == null:
		return null
	scene.report_progress = false
	scene.attempt_settle_sec = 0.05
	add_child_autofree(scene)
	await get_tree().process_frame
	return scene


## کره‌های سینی با همان وزنِ علامت‌دار (`WeightOrb.weight()` ⇒ NegativeOrb منفی و
## GhostOrb برابر `hidden_value` ✓)؛ `used` با instance_id نگه داشته می‌شود تا دو کرهٔ
## هم‌وزن، یک کره را دو بار «مصرف» نکنند ✗✓ (با ۱۰ ردیفِ `count` در سینی، این دامِ واقعی است).
func _pick_orb(scene: LevelController, value: float, used: Dictionary) -> WeightOrb:
	for orb: WeightOrb in scene.tray_orbs:
		if orb == null or used.has(orb.get_instance_id()) or orb.is_placed:
			continue
		if is_equal_approx(orb.weight(), value):
			used[orb.get_instance_id()] = true
			return orb
	return null


## ردیف‌های `solution_spec` را به کره‌های واقعیِ سینی وصل می‌کند. `ok=false` یعنی داده
## کره‌ای را می‌خواهد که در سینی نیست ⇒ **فریاد** در تست، نه `continue` بی‌صدا ✗✓
## (بی‌صدا رد کردن یعنی «سطح تست شد» درحالی‌که هیچ‌چیز چیده نشده — همان دامِ فایلِ
## load‌نشده در فاز ۷).
func _resolve_rows(scene: LevelController, rows: Array[Dictionary]) -> Dictionary:
	var used: Dictionary = {}
	var pairs: Array[Dictionary] = []
	for r: Dictionary in rows:
		var orb: WeightOrb = _pick_orb(scene, float(r["value"]), used)
		if orb == null:
			return {"ok": false, "pairs": pairs, "wanted": rows.size()}
		pairs.append({"orb": orb, "scale": int(r["scale"])})
	return {"ok": true, "pairs": pairs, "wanted": rows.size()}


## چیدمانِ کره‌به‌کره روی کفه‌ی مقصدش؛ `after_each` یعنی بعد از هر کره یک callback
## می‌گیرد (تستِ «هیچ پیشوندی نبَرَد» از همین استفاده می‌کند ✗✓ یک مسیر برای دو ادعا).
func _place_pairs(scene: LevelController, pairs: Array) -> void:
	# `Array` بی‌تایپ + `as Dictionary` داخل حلقه: `as Array[Dictionary]` در GDScript 4
	# castِ معتبری نیست و هدلس همان لحظهٔ load می‌شکند ✗✓ (تایپِ واقعی در خودِ
	# `_resolve_rows` حفظ می‌شود؛ اینجا فقط از راهِ Dictionary برمی‌گردیم).
	for pair: Variant in pairs:
		var d: Dictionary = pair as Dictionary
		var one: Array[WeightOrb] = [d["orb"] as WeightOrb]
		scene.place_on_right(one, int(d["scale"]))


func test_the_intended_solution_wins_on_every_level() -> void:
	var checked: int = 0
	for lid: String in _ids:
		var cfg: Dictionary = _read_json(LevelLoader.path_for(lid))
		var spec: Dictionary = cfg.get("solution_spec") if cfg.get("solution_spec") is Dictionary else {}
		var intended: Dictionary = spec.get("intended") if spec.get("intended") is Dictionary else {}
		var rows: Array[Dictionary] = _orb_rows(intended.get("right_orbs"))
		if rows.is_empty():
			continue
		var scene: LevelController = await _scene_for(lid)
		if scene == null:
			continue
		var resolved: Dictionary = _resolve_rows(scene, rows)
		assert_true(bool(resolved["ok"]),
			"`%s`: هر کرهٔ `intended.right_orbs` باید در سینی با همان علامت پیدا شود" % lid)
		for pair: Dictionary in (resolved["pairs"] as Array):
			_place_pairs(scene, [pair])
			await get_tree().process_frame
		assert_true(scene.is_won(),
			"`%s`: حلِ قصدمندِ نوشته‌شده در موتور برنده نشد ⇒ داده یا موتور یکی‌شان غلط است" % lid)
		if rows.size() > 1:
			# ترتیبِ چیدن نباید حالتِ «باخته» بسازد ✗✓ (کودک هر ترتیبی می‌چیند؛ اگر فقط
			# یک ترتیبِ خاص ببرد، سطح عملاً «حدسِ ترتیب» شده نه ریاضی — ADR-055)
			var scene2: LevelController = await _scene_for(lid)
			var rev: Array[Dictionary] = []
			for i: int in range(rows.size() - 1, -1, -1):
				rev.append(rows[i])
			var r2: Dictionary = _resolve_rows(scene2, rev)
			if bool(r2["ok"]):
				_place_pairs(scene2, r2["pairs"] as Array)
				await get_tree().process_frame
				assert_true(scene2.is_won(), "`%s`: همان حلِ قصدمند با ترتیبِ معکوس هم باید ببرد ✗" % lid)
		checked += 1
	assert_gte(checked, 1, "هیچ سطحی `solution_spec.intended` نداشت ⇒ این تست چیزی نمی‌سنجد")
	assert_eq(checked, _ids.size(), "همهٔ سطح‌ها باید حلِ قصدمندِ تست‌شدنی داشته باشند")


func test_the_documented_wrong_move_never_wins() -> void:
	# `solution_spec.wrong_ops.right_orbs` = حرکتِ «اشتباهِ آموزشی» همان سطح ✗ اگر آن
	# هم ببرد، سطح چیزی یاد نمی‌دهد (و ErrorClassifier هیچ خطایی تولید نمی‌کند) ⇒
	# داده باید «نزدیکِ غلط» باشد، نه «غلطِ تصادفی» (ADR-053) ✓
	for lid: String in _ids:
		var cfg: Dictionary = _read_json(LevelLoader.path_for(lid))
		var spec: Dictionary = cfg.get("solution_spec") if cfg.get("solution_spec") is Dictionary else {}
		var wrong: Dictionary = spec.get("wrong_ops") if spec.get("wrong_ops") is Dictionary else {}
		var rows: Array[Dictionary] = _orb_rows(wrong.get("right_orbs"))
		if rows.is_empty():
			continue
		var scene: LevelController = await _scene_for(lid)
		if scene == null:
			continue
		var resolved: Dictionary = _resolve_rows(scene, rows)
		if not bool(resolved["ok"]):
			continue  # کره‌ها در سینی نیستند؛ قاعدهٔ داده‌ای در validator آن را می‌گیرد ✓
		# کره‌ها یکی‌یکی می‌نشینند و **هیچ پیشوندی** نباید ببرد ✗✓ اگر همه را یک‌جا
		# بگذاریم و برد در موتور latch شده باشد، ترتیبِ داده می‌تواند «باختن» را وانمود
		# کند؛ این حلقه همان را در موتور سنجید و قاعدهٔ «هیچ زیرمجموعه‌ای تراز نکند» در
		# validator آن را برای همهٔ ترتیب‌ها در داده می‌بندد ✓✓ دو لایه، یک ادعا.
		for k: int in range((resolved["pairs"] as Array).size()):
			_place_pairs(scene, [(resolved["pairs"] as Array)[k] as Dictionary])
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
