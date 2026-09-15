extends GutTest
# ===========================================================================
# تسک ۶.۵ — ParentGate: «تا کودک تصادفی وارد نشود»، نه «امنیت»
# ---------------------------------------------------------------------------
# سه ادعایی که ارزش تست دارند: سؤالات قطعی/قابل‌تکرار (وگرنه باگ CI غیرقابل‌بازتولید
# می‌شود)، پاسخ هیچ‌جا روی صفحه/متن‌ها لو نمی‌رود، و سه بار اشتباه = قفلِ نشست بدون
# راهنمایی. §۶.۵ صراحتاً «قفل ساده» می‌گوید؛ ما هم همان را ادعا می‌کنیم (ADR-047).
# ===========================================================================

func _make(seed: int = 4) -> ParentGate:
	var gate := ParentGate.new()
	gate.question_seed = seed
	add_child_autofree(gate)
	return gate


func test_question_is_two_digit_times_two_digit_and_reproducible() -> void:
	var a: Dictionary = ParentGate.make_question(4)
	var b: Dictionary = ParentGate.make_question(4)
	assert_eq(a, b, "با seed یکسان سؤال باید یکسان باشد (تستِ قطعی)")
	assert_gte(int(a["a"]), ParentGate.MIN_FACTOR)
	assert_lte(int(a["a"]), ParentGate.MAX_FACTOR)
	assert_gte(int(a["b"]), ParentGate.MIN_FACTOR)
	assert_lte(int(a["b"]), ParentGate.MAX_FACTOR)
	assert_eq(int(a["answer"]), int(a["a"]) * int(a["b"]),
		"§۶.۵: ضرب دو عدد دو رقمی ⇒ نتیجه‌ی چهاررقمی برای بچهٔ ۹ ساله سخت است")


func test_different_seeds_do_not_get_stuck_on_one_question() -> void:
	var seen := {}
	for seed: int in range(6):
		seen[str(ParentGate.make_question(seed))] = true
	assert_gte(seen.size(), 2, "همهٔ seedها یک سؤال ندهند (وگرنه قفل فقط یک جواب دارد)")


func test_the_answer_is_written_nowhere_on_screen() -> void:
	var gate := _make(4)
	var answer: int = int(ParentGate.make_question(4)["answer"])
	var found: Array[String] = []
	var labels: Array[Node] = gate.find_children("*", "Label", true, false)
	for label: Node in labels:
		if str((label as Label).text).contains(str(answer)):
			found.append(str((label as Label).name))
	for node: Node in gate.find_children("*", "Button", true, false):
		if str((node as Button).text).contains(str(answer)):
			found.append(str((node as Node).name))
	assert_true(found.is_empty(), "پاسخ روی صفحه هست: " + str(found))
	assert_true(gate.question_label.text.contains("×"), gate.question_label.text)
	assert_false(gate.question_label.text.contains("="), "معادله کامل نشان داده نمی‌شود")
	assert_false(gate.describe().contains(str(answer)), "لاگ/دیباگ هم پاسخ ندارد")


func test_persian_and_arabic_digits_are_accepted_and_junk_is_not() -> void:
	assert_eq(ParentGate.normalize_digits("۱۲۳"), "123")
	assert_eq(ParentGate.normalize_digits("١٢٣"), "123")
	assert_eq(ParentGate.normalize_digits("  42 "), "42")
	assert_eq(ParentGate.normalize_digits("۱۲a"), "",
		"یک نویسهٔ مزاحم نباید بی‌صدا پاک شود: کودک باید دوباره بنویسد")
	assert_eq(ParentGate.normalize_digits("چهل و دو"), "")
	var gate := _make(4)
	var answer: int = int(ParentGate.make_question(4)["answer"])
	watch_signals(gate)
	# با همان رقم‌های فارسی بنویس ⇒ قبول (صفحه‌کلید فارسی Android لاتین تولید نمی‌کند)
	assert_true(gate.submit(Loc.digits(str(answer))), "پاسخ فارسی باید کار کند")
	assert_signal_emitted(gate, "passed")


func test_three_wrong_answers_lock_the_session() -> void:
	var gate := _make(9)
	watch_signals(gate)
	for i: int in range(ParentGate.MAX_ATTEMPTS):
		assert_false(gate.submit("1"))
		assert_eq(gate.attempts, i + 1)
		assert_true(gate.status_label.visible, "بازخورد ملایم هست، راهنمایی نه")
	assert_true(gate.is_locked())
	assert_signal_emitted(gate, "rejected")
	assert_false(gate.submit("1"), "بعد از قفل، حدس زدنِ بعدی هم پذیرفته نمی‌شود")
	assert_false(gate.accepts_input())
	# «سؤال دیگر» بعد از قفل، فرصت تازه نمی‌دهد (وگرنه قفل بی‌معنی است)
	var retry: Button = gate.get_node("Panel/Rows/RetryButton") as Button
	assert_not_null(retry)
	if retry != null:
		retry.pressed.emit()
		assert_true(gate.is_locked(), "قفلِ نشست با دکمهٔ «سؤال دیگر» باز نمی‌شود")


func test_empty_submit_does_not_cost_an_attempt() -> void:
	var gate := _make(3)
	gate.answer_field.text = "   "
	assert_false(gate.submit())
	assert_eq(gate.attempts, 0, "Enter خالی نباید یک «اشتباه» حساب شود")
	gate.answer_field.text = "0"
	assert_false(gate.submit())
	assert_eq(gate.attempts, 1, "عددِ غلط اما حساب می‌شود")


func test_retry_resets_and_the_gate_is_touch_ready() -> void:
	var gate := _make(2)
	var before: String = gate.question_label.text
	for i: int in range(ParentGate.MAX_ATTEMPTS - 1):
		gate.submit("1")
	gate.new_question(11)
	assert_eq(gate.attempts, 0)
	assert_false(gate.is_locked())
	assert_ne(gate.question_label.text, before, "سؤال تازه باید تازه باشد")
	assert_true(UIKit.audit_touch_targets(gate).is_empty(), str(UIKit.audit_touch_targets(gate)))
	var field: LineEdit = gate.answer_field
	assert_gte(field.custom_minimum_size.y, UIKit.MIN_TOUCH_PX, "فیلد پاسخ هم لمسی است")
