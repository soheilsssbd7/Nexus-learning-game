class_name ParentGate
extends Control
# ===========================================================================
# ParentGate — «سؤال ریاضی بزرگسال» قبل از داشبورد (تسک ۶.۵)
# ---------------------------------------------------------------------------
# هدف §۶.۵ دقیقاً همین است: «تا کودک به‌طور تصادفی وارد نشود» ⇒ این یک قفل
# امنیتی نیست (ADR-047) و ادعای امنیتی هم نمی‌کند؛ فقط هزینه‌ی تصادفی‌بودن را
# بالا می‌برد. سه قاعده‌ی طراحی:
#   • جواب هیچ‌جا نوشته نمی‌شود: نه در برچسب، نه در لاگ، نه در `describe()`
#     (اگر پاسخ روی صفحه یا در لاگ باشد، قفل بی‌معنی است).
#   • سه بار اشتباه ⇒ قفلِ نشست تا خروج از صحنه؛ نه «راهنمایی»، نه نمایش جواب.
#   • ارقام فارسی و لاتین هر دو پذیرفته می‌شوند: صفحه‌کلید فارسیِ Android رقم
#     لاتین تولید نمی‌کند و کودک نباید فکر کند چیزی خراب است.
# ===========================================================================

const TAG := "ParentGate"
const MIN_FACTOR := 10
const MAX_FACTOR := 99
const MAX_ATTEMPTS := 3

signal passed
signal rejected
signal left

@export var build_on_ready: bool = true
## برای تست: seed ثابت ⇒ سؤال قابل‌تکرار (بدون این، شکستِ تست در CI غیرقابل‌بازتولید است).
@export var question_seed: int = -1

var question_label: Label = null
var answer_field: LineEdit = null
var status_label: Label = null
var attempts: int = 0
var _answer: int = 0
var _locked: bool = false


func _ready() -> void:
	if build_on_ready:
		_build()
		new_question()


func _build() -> void:
	UIKit.anchor_full(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(Palette.DEEP_INDIGO, 0.95)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	UIKit.anchor_full(dim)
	add_child(dim)

	var panel := UIKit.make_panel(0.97, UIKit.MARGIN * 1.5)
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(700.0, 0.0)
	add_child(panel)
	var box := UIKit.make_vbox(UIKit.GAP)
	box.name = "Rows"
	panel.add_child(box)

	box.add_child(UIKit.make_label("gate.title", UIKit.TITLE_FONT_PX - 6))
	question_label = UIKit.make_label("gate.question", UIKit.TITLE_FONT_PX - 10)
	question_label.name = "Question"
	box.add_child(question_label)

	answer_field = LineEdit.new()
	answer_field.name = "Answer"
	answer_field.placeholder_text = Loc.t("gate.answer")
	answer_field.alignment = Loc.alignment()
	answer_field.text_direction = Loc.text_direction()
	answer_field.custom_minimum_size = Vector2(420.0, UIKit.MIN_TOUCH_PX)
	answer_field.add_theme_font_size_override("font_size", UIKit.TITLE_FONT_PX - 8)
	answer_field.focus_mode = Control.FOCUS_ALL
	box.add_child(answer_field)

	status_label = UIKit.make_label("gate.denied", UIKit.DIALOG_FONT_PX, Palette.WARM_CORAL)
	status_label.name = "Status"
	status_label.visible = false
	box.add_child(status_label)

	var enter: Button = UIKit.make_button("gate.enter", "gold")
	enter.name = "EnterButton"
	enter.pressed.connect(submit)
	box.add_child(enter)
	var retry: Button = UIKit.make_button("gate.retry", "cloud")
	retry.name = "RetryButton"
	retry.pressed.connect(_on_retry)
	box.add_child(retry)
	var leave: Button = UIKit.make_button("gate.leave", "stone")
	leave.name = "LeaveButton"
	leave.pressed.connect(_on_leave)
	box.add_child(leave)
	answer_field.text_submitted.connect(_on_submitted)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE, 0)
	UIKit.apply_flow(self)


## سؤال: ضرب دو عدد دو رقمی (§۶.۵ «مثلاً»). `seed >= 0` ⇒ قطعی (تست).
static func make_question(seed: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	var a: int = rng.randi_range(MIN_FACTOR, MAX_FACTOR)
	var b: int = rng.randi_range(MIN_FACTOR, MAX_FACTOR)
	return {"a": a, "b": b, "answer": a * b}


func new_question(seed: int = -1) -> void:
	var q: Dictionary = make_question(seed if seed >= 0 else question_seed)
	_answer = int(q["answer"])
	attempts = 0
	_locked = false
	if question_label != null:
		question_label.text = "%s  ×  %s" % [Loc.digits(str(q["a"])), Loc.digits(str(q["b"]))]
	if status_label != null:
		status_label.visible = false
	if answer_field != null:
		answer_field.text = ""
		answer_field.editable = true


## ارقام فارسی/عربی → لاتین؛ هر نویسه‌ی دیگر بی‌اعتبار است (نه تصحیح خودکار:
## «۱۲a۳» نباید بی‌صدا ۱۲۳ شود، چون کودک می‌فهمد چیزی را غلط زده).
static func normalize_digits(text: String) -> String:
	var out := ""
	for i: int in range(text.length()):
		var code: int = text.unicode_at(i)
		if code >= 48 and code <= 57:
			out += str(code - 48)
		elif code >= 1776 and code <= 1785:  # ۰..۹ فارسی
			out += str(code - 1776)
		elif code >= 1632 and code <= 1641:  # ۰..۹ عربی
			out += str(code - 1632)
		elif text[i] in [" ", "\t", "\n", "\r"]:
			continue
		elif text[i] == "‑" or text[i] == "-":
			continue
		else:
			return ""
	return out


func is_locked() -> bool:
	return _locked


func accepts_input() -> bool:
	return not _locked


## پاسخِ کاربر: تهی/غیرعددی = بی‌اثر (نه «اشتباه»)، تا کودک با یک Enter خالی
## از سه حقش یکی را از دست ندهد.
func submit(text: String = "") -> bool:
	if _locked:
		return false
	var raw: String = text if not text.is_empty() else (
		answer_field.text if answer_field != null else "")
	var digits: String = normalize_digits(raw.strip_edges())
	if digits.is_empty():
		if answer_field != null:
			answer_field.grab_focus()
		return false
	if not digits.is_valid_int():
		return _wrong()
	if int(digits) == _answer:
		_locked = false
		attempts = 0
		if answer_field != null:
			answer_field.editable = false
		if status_label != null:
			status_label.visible = false
		passed.emit()
		return true
	return _wrong()


func _wrong() -> bool:
	attempts += 1
	if status_label != null:
		status_label.visible = true
		status_label.text = Loc.t("gate.denied")
	if answer_field != null:
		answer_field.text = ""
	if attempts >= MAX_ATTEMPTS:
		_locked = true
		if answer_field != null:
			answer_field.editable = false
		rejected.emit()
	return false


func _on_submitted(text: String) -> void:
	submit(text)


func _on_leave() -> void:
	left.emit()


func _on_retry() -> void:
	if _locked:
		rejected.emit()
		return
	new_question()


## برای تست/دیباگ: هیچ‌جا پاسخ نیست.
func describe() -> String:
	return "attempts=%d locked=%s" % [attempts, str(_locked)]
