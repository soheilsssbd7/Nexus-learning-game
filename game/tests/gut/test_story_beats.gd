extends GutTest
# ===========================================================================
# تسک ۷.۵ — «اسکریپت روایت»: `game/data/narrative/story_beats.json`
# ---------------------------------------------------------------------------
# DoD ۷.۵ (docs/04): خواندنِ کاملِ بیت‌ها باید **یک داستان منسجم** بسازد، نه جملاتِ
# پراکنده ⇒ اینجا چیزی را می‌سنجیم که از متن برمی‌آید: قوسِ شروع/نقاطِ عطف/پایان،
# پیوندِ هر بیت با منطقه‌ی هنری‌اش، قانونِ طلاییِ «رقم در دهانِ آریا نیست»، و اینکه
# **هر خط در `DialogueBox` جا می‌شود** ✓✓ (داده‌ای که رندر نشود، محتوای مرده است ✗).
# فایل گم‌شده = شکست، نه skip ✗✓ (درسِ «سبزِ توخالی» در ۷.۱ب/۷.۳: بی‌صدا رد کردن،
# بدترین حالتِ ممکن است چون گزارشِ سبز را بی‌معنا می‌کند).
# ===========================================================================

const SHIPPED := "res://data/narrative/story_beats.json"
const ANCHOR := "ترازوی بنیادین"
const REGION_BY_TIER := {
	1: "Sunlit Meadow", 2: "Whisper Caverns", 3: "Ghostlight Ruins",
	4: "Twin Observatory", 5: "Summit of Equilibrium",
}

var _doc: Dictionary = {}


func before_all() -> void:
	assert_true(FileAccess.file_exists(SHIPPED), "فایل روایت وجود ندارد: %s" % SHIPPED)
	if not FileAccess.file_exists(SHIPPED):
		return
	var text: String = FileAccess.get_file_as_string(SHIPPED)
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "story_beats.json باید object باشد ✗")
	if parsed is Dictionary:
		_doc = parsed


func _beats() -> Array:
	return _doc.get("beats", []) as Array


func _lines_of(beat: Dictionary) -> Array:
	return beat.get("lines", []) as Array


func _beat(id: String) -> Dictionary:
	for b in _beats():
		var d: Dictionary = b as Dictionary
		if str(d.get("beat_id")) == id:
			return d
	return {}


func _text_of(beat: Dictionary) -> String:
	var out: String = ""
	for l in _lines_of(beat):
		out += str((l as Dictionary).get("text", "")) + "\n"
	return out


func test_the_arc_has_one_opening_four_entries_and_one_finale() -> void:
	var beats: Array = _beats()
	assert_eq(beats.size(), 6, "قوسِ ۶ بیتی: افتتاحیه + ورودِ چهار Tier + پایان ✗")
	var starts: int = 0
	var ends: int = 0
	var entries: Array[int] = []
	var ids: Dictionary = {}
	for b in beats:
		var d: Dictionary = b as Dictionary
		var id: String = str(d.get("beat_id"))
		assert_false(ids.has(id), "`beat_id` تکراری: %s ⇒ موتور نمی‌داند کدام را پخش کند ✗" % id)
		ids[id] = true
		match str(d.get("trigger")):
			"game_start":
				starts += 1
				assert_eq(int(d.get("tier")), 1, "افتتاحیه باید روی Tier ۱ باشد ✓")
			"tier_start":
				entries.append(int(d.get("tier")))
			"game_complete":
				ends += 1
				assert_eq(int(d.get("tier")), 5, "پایان باید روی قله باشد ✓ GDD §۵-ب")
			_:
				assert_true(false, "trigger نامعتبر در %s" % id)
	assert_eq(starts, 1, "دقیقاً یک `game_start` (اولین اجرا ✓)")
	assert_eq(ends, 1, "دقیقاً یک `game_complete` (پایانِ قوس ✓)")
	# مقایسهٔ `Array[int]` با array بی‌تایپ به سلیقهٔ نسخه وابسته است ✗✓ ⇒ تک‌تک می‌سنجیم
	assert_eq(entries.size(), 4, "چهار نقطهٔ عطفِ میانی لازم است ✗")
	for want: int in [2, 3, 4, 5]:
		var msg: String = "بیت `tier_start` برای Tier %d نیست ⇒ ورودِ داستانی ندارد ✗" % want
		assert_true(entries.has(want), msg)


func test_aria_never_leaks_a_number_and_never_only_commands() -> void:
	for b in _beats():
		var d: Dictionary = b as Dictionary
		var id: String = str(d.get("beat_id"))
		var asked: bool = false
		var spoken: int = 0
		for l in _lines_of(d):
			var ln: Dictionary = l as Dictionary
			var txt: String = str(ln.get("text", ""))
			for ch in txt:
				assert_false(ch >= "0" and ch <= "9",
					"%s: رقم در متنِ روایی ⇒ لو‌دادنِ وزن/جواب ✗ (GDD §۲)" % id)
			if str(ln.get("speaker")) == "aria":
				spoken += 1
				if txt.strip_edges().ends_with("؟"):
					asked = true
		assert_gt(spoken, 0, "%s: آریا باید حرف بزند، نه فقط راوی ✗" % id)
		# §۵-الف: «آریا سؤال می‌پرسد و جهت می‌دهد؛ هیچ‌وقت جواب نمی‌دهد» ⇒ اگر هیچ
		# پرسشی در بیت نبود، لحن به دستورِ معلمی چرخیده ✗✓ این تنها سنجشِ قابل‌کدِ
		# همان بندِ GDD است و عمداً در لایهٔ موتور هم تکرار شده (دروازهٔ محتوا فراموش‌کار است ✗).
		assert_true(asked, "%s: هیچ پرسشی در خط‌های آریا نیست ⇒ دستور داده شده ✗" % id)


func test_each_beat_points_at_the_art_of_its_own_region() -> void:
	# docs/04 ۷.۵: «هر بیت شامل متن + اشاره به کدام دارایی هنری محیطی لازم است» ✓
	for b in _beats():
		var d: Dictionary = b as Dictionary
		var id: String = str(d.get("beat_id"))
		var tier: int = int(d.get("tier"))
		assert_true(REGION_BY_TIER.has(tier), "%s: Tier نامعتبر %d" % [id, tier])
		assert_eq(str(d.get("ambient_art")), str(REGION_BY_TIER.get(tier, "")),
			"%s: `ambient_art` باید منطقهٔ همان Tier باشد (Art Bible §۵) ✗" % id)
		assert_gt(str(d.get("art_note")).length(), 8,
			"%s: `art_note` لازم است، وگرنه بیت برای فاز ۸ معنای تولیدی ندارد ✗" % id)


func test_every_line_renders_in_the_dialogue_box() -> void:
	var box: DialogueBox = DialogueBox.new()
	add_child_autofree(box)
	var longest: int = 0
	var longest_in: String = ""
	for b in _beats():
		var d: Dictionary = b as Dictionary
		for l in _lines_of(d):
			var ln: Dictionary = l as Dictionary
			var txt: String = str(ln.get("text", ""))
			longest = max(longest, txt.length())
			if txt.length() == longest:
				longest_in = str(d.get("beat_id"))
			box.show_text(txt)
			assert_true(box.is_showing(), "متن نمایش داده نشد در %s ✗" % str(d.get("beat_id")))
			assert_gt(box.visible_text().length(), 0, "جعبه خالی رندر کرد ✗")
	assert_lt(longest, 91, "بلندترین خط (%s, %d) از سقف ۹۰ رد می‌زند ⇒ سرریزِ DialogueBox ✗" % [longest_in, longest])


func test_the_finale_repairs_what_the_opening_broke() -> void:
	# لنگرِ همبستگی: همان چیزی که در افتتاحیه شکسته بود، در پایان ترمیم می‌شود ✓✓
	# بدون این، «شش بیتِ خوش‌ساخت» می‌تواند شش داستانِ جدا باشد ✗ (DoD ۷.۵ = منسجم ✓)
	var opening: Dictionary = _beat("beat_opening")
	var finale: Dictionary = _beat("beat_finale")
	assert_false(opening.is_empty(), "بیت `beat_opening` نیست ✗")
	assert_false(finale.is_empty(), "بیت `beat_finale` نیست ✗")
	assert_true(_text_of(opening).contains(ANCHOR), "افتتاحیه باید `%s` را بشکند ✗" % ANCHOR)
	assert_true(_text_of(finale).contains(ANCHOR), "پایان باید همان `%s` را ترمیم کند ✗" % ANCHOR)
