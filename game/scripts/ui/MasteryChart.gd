class_name MasteryChart
extends Control
# ===========================================================================
# MasteryChart — نمودار میله‌ای تسلط هر مهارت (تسک ۶.۵)
# ---------------------------------------------------------------------------
# §۶.۵ می‌گوید «نمودار میله‌ای تسلط هر مهارت (از PlayerModel.skills)». سه تصمیم:
#   • میله‌ها از `skills.keys()` ساخته می‌شوند، نه از فهرست hardcode ⇒ هر مفهوم
#     تازه در فاز ۷ خودکار در داشبورد می‌نشیند (و `validate_levels.py` مواظب است
#     که برچسب والدینش `skill.<tag>` تعریف شده باشد).
#   • قدِ میله = رتبه در بازه‌ی Elo (۴۰۰..۲۰۰۰)، رنگِ نوارِ داخلی = `confidence`
#     (§۳ سند ۰۷: اطمینان، نه خودِ تسلط) ⇒ والد «۸۰٪ با سه تلاش» را از
#     «۸۰٪ با سی تلاش» تشخیص می‌دهد.
#   • هر رقمی که روی نمودار نوشته می‌شود از همان `SkillRating` می‌آید؛ تست با
#     دادهٔ ساختگی عددِ متن را با عددِ مدل مقایسه می‌کند (DoD ۶.۵).
# ===========================================================================

const TAG := "MasteryChart"
const BAR_HEIGHT := 96.0
const GAP_Y := 22.0
const LABEL_WIDTH := 300.0
const VALUE_WIDTH := 210.0
const MIN_ELO: float = SkillRating.ELO_MIN
const MAX_ELO: float = SkillRating.ELO_MAX

var rows: Array[Dictionary] = []
var title_label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(1032.0, 160.0)
	if title_label == null:
		title_label = UIKit.make_label("dashboard.mastery", UIKit.DIALOG_FONT_PX + 4)
		title_label.name = "Title"
		add_child(title_label)


## فقط خواندن؛ هیچ عددی اینجا ساخته نمی‌شود (تضمینِ DoD: داشبورد = مدل).
func refresh(model: PlayerModel) -> void:
	rows.clear()
	if model == null:
		custom_minimum_size = Vector2(1032.0, 160.0)
		queue_redraw()
		return
	var keys: Array = model.skills.keys()
	keys.sort()
	for key: Variant in keys:
		var rating: SkillRating = model.skills[key] as SkillRating
		if rating == null:
			continue
		var elo: float = float(rating.elo)
		var span: float = maxf(1.0, MAX_ELO - MIN_ELO)
		rows.append({
			"skill": str(key),
			"label": Loc.t("skill." + str(key)),
			"elo": elo,
			"confidence": clampf(float(rating.confidence), 0.0, 1.0),
			"attempts": int(rating.attempts),
			"fill": clampf((elo - MIN_ELO) / span, 0.0, 1.0),
		})
	custom_minimum_size = Vector2(1032.0,
		maxf(160.0, 96.0 + float(rows.size()) * (BAR_HEIGHT + GAP_Y)))
	queue_redraw()


func row_count() -> int:
	return rows.size()


func row_text(index: int) -> String:
	if index < 0 or index >= rows.size():
		return ""
	var row: Dictionary = rows[index]
	return "%s · %s · %s %s" % [str(row["label"]), Loc.percent(float(row["confidence"])),
		Loc.digits(str(int(row["elo"]))), Loc.t("dashboard.attempts_short") + " "
		+ Loc.digits(str(int(row["attempts"])))]


func _draw() -> void:
	var top: float = 56.0
	if rows.is_empty():
		draw_string(Palette.ui_font(), Vector2(0.0, top + 40.0),
			Loc.t("dashboard.no_data"), HORIZONTAL_ALIGNMENT_LEFT, size.x - 8.0,
			UIKit.DIALOG_FONT_PX, Palette.MUTED_TEXT)
		return
	for i: int in range(rows.size()):
		var row: Dictionary = rows[i]
		var y: float = top + float(i) * (BAR_HEIGHT + GAP_Y)
		var track := Rect2(LABEL_WIDTH, y, size.x - LABEL_WIDTH - VALUE_WIDTH, BAR_HEIGHT * 0.42)
		draw_rect(track, Color(Palette.CLOUD_WHITE, 0.14))
		var filled := Rect2(track.position, Vector2(track.size.x * float(row["fill"]), track.size.y))
		draw_rect(filled, Palette.AELORIA_GOLD if float(row["confidence"]) >= 0.5
			else Palette.SOFT_TEAL)
		# نوار اطمینان: همان ارتفاع، عرضِ confidence ⇒ والد می‌بیند رتبه «چقدر خون‌است»
		var conf_bar := Rect2(track.position.x, track.position.y + track.size.y + 6.0,
			track.size.x * float(row["confidence"]), 8.0)
		draw_rect(conf_bar, Color(Palette.SOFT_TEAL, 0.7))
		var f: Font = Palette.ui_font()  # §۷ خانوادهٔ Vazirmatn ✓✗ fallback جعبه می‌دهد
		draw_string(f, Vector2(0.0, y + 30.0), str(row["label"]),
			HORIZONTAL_ALIGNMENT_LEFT, LABEL_WIDTH - 12.0, UIKit.DIALOG_FONT_PX + 2,
			Palette.CLOUD_WHITE)
		draw_string(f, Vector2(track.end.x + 12.0, y + 30.0), row_text(i),
			HORIZONTAL_ALIGNMENT_LEFT, VALUE_WIDTH, UIKit.DIALOG_FONT_PX - 2,
			Palette.MUTED_TEXT)
