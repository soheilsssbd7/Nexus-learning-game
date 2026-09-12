class_name WorldMap
extends Node2D
# ===========================================================================
# WorldMap — انتخاب سطح (تسک ۳.۴؛ placeholder تا HUD/منوی واقعی فاز ۶)
# ---------------------------------------------------------------------------
# قانون قفل (از سند ۰۴): سطح i باز است اگر i==0 یا سطح قبلی در PlayerModel
# تکمیل شده باشد. یعنی «ترتیب روایی» حفظ می‌شود و هیچ سطحی از Tier باز نشده
# ظاهر نمی‌شود (GDD §۵). فهرست سطوح از فایل‌ها می‌آید، نه از const — پس فاز ۷
# فقط JSON اضافه می‌کند و این صحنه دست‌نخورده می‌ماند.
#
# درخت در کد ساخته می‌شود (ADR-032) تا ادیتور و هدلس یک رفتار داشته باشند؛
# صحنه‌ی .tscn فقط ریشه + اسکریپت است.
# ===========================================================================

const TAG := "WorldMap"
## قانون دست‌رسپذیری §۷ سند هنری: حداقل ۴۸dp؛ بوم ۱۰۸۰px روی ۳۶۰dp ⇒ هر dp = 3px ⇒ ۱۴۴px.
## (قبلاً ۱۳۶ بود؛ `UIKit.audit_touch_targets` همین را در فاز ۶ گرفت — ADR-049.)
const NODE_HEIGHT: float = 144.0
const NODE_SIZE := Vector2(NODE_HEIGHT, NODE_HEIGHT)
const TOP_Y: float = 300.0
const BOTTOM_Y: float = 1560.0
const MEANDER_X: float = 190.0
## کفِ فاصلهٔ عمودیِ دو نود = اندازهٔ نود + ۶۰px تنفس ✗✓ نود را نمی‌توان کوچک کرد
## (کفِ لمسی ۱۴۴px §۷ سند هنری)، پس تنها راهِ درستِ جا دادن ۴۵ سطح، **صفحه‌بندی** است.
const MIN_PITCH: float = NODE_HEIGHT + 60.0
const MAX_TIERS: int = 5
## سقفِ باند (نه عددِ دست‌نویسِ دیگری): با یک نود، فاصله معنایی ندارد.
const MAX_PITCH: float = BOTTOM_Y - TOP_Y


## سقفِ نودِ هر صفحه از باندِ واقعیِ همین صفحه حساب می‌شود، نه از عددِ دست‌نویس: با
## عوض‌شدنِ بوم یا کفِ لمسی، تعداد صفحه‌ها خودکار درست می‌ماند (تکرارِ عدد = باگِ فردا ✗✓).
## تابع است نه `const`: در GDScript ثابت فقط عملگر می‌پذیرد (نه `int()`، نه عضوِ `Vector2`)
## ⇒ و تستِ محتوا هم همین تابع را می‌خواند تا یک منبعِ حقیقت بماند ✓.
static func page_max() -> int:
	return int((BOTTOM_Y - TOP_Y) / MIN_PITCH) + 1

signal level_requested(level_id: String)
signal level_blocked(level_id: String, reason: String)
## تسک ۶.۱: بازگشت به منو (قبلاً نقشه یک بن‌بست بود — از منو می‌آمدی و برنمی‌گشتی).
signal menu_requested

@export var build_on_ready: bool = true
## برای تست/ویرایشگر: اگر خالی باشد از LevelLoader خوانده می‌شود.
@export var level_ids_override: Array[String] = []
## false = فقط درخواست بفرست (تست‌ها صحنه را خودشان می‌سازند تا درخت GUT به‌هم نریزد).
@export var allow_scene_change: bool = true

var buttons: Array[Button] = []
var level_ids: Array[String] = []
## ایندکس‌های **سراسریِ** هر صفحه. تا فاز ۷ نقشه همه‌ی سطوح را در یک باند ۱۲۶۰px می‌چید؛
## با ۱۵ سطح گامِ نودها ۹۰px شد (کمتر از ارتفاعِ نود) ⇒ نودها روی هم افتادند ✗✗ و با
## ۴۵ سطح فاجعه می‌شد — `test_world_map.gd` (برخوردِ مستطیل‌ها) همان را در CI گرفت ✓
## صفحه‌بندی **هیچ‌وقت وسطِ یک Tier نمی‌شکند** (هر Tier خودش صفحه‌بندی می‌شود) تا
## «جهان» همیشه یک‌تکه دیده شود (GDD §۵).
var pages: Array = []
var current_page: int = 0
var _backdrop: RegionBackdrop = null  ## §۵ | تسک ۸.۳: نقشهٔ جهان هم «Hub زنده» دارد ✓



func _ready() -> void:
	if build_on_ready:
		rebuild()
	# برد در LevelController با `level_completed` اعلام می‌شود → همین‌جا قفل‌ها باز می‌شوند
	EventBus.level_completed.connect(_on_level_completed)


func rebuild() -> void:
	_clear_nodes()
	level_ids = level_ids_override.duplicate()
	if level_ids.is_empty():
		level_ids = _level_ids_grouped_by_tier()
	if level_ids.is_empty():
		Log.warn(TAG, "هیچ سطحی در data/levels پیدا نشد — نقشه خالی است (فاز ۳/۷)")
		return
	_ensure_menu_button()
	_ensure_page_controls()
	pages = _build_pages()
	current_page = clampi(_page_of(_first_open_index()), 0, pages.size() - 1)
	_build_page_nodes()
	_sync_page_controls()
	_ensure_backdrop()
	_refresh_backdrop(false)
	refresh_locks()


## ترتیبِ LevelLoader را حفظ می‌کند ولی **Tier‌به‌Tier** می‌چیند؛ اگر یک روز folder
## با پیشوندِ id نخواند، همین‌جا معلوم می‌شود (تستِ فاز ۷ همان را می‌سنجد) ✗✓
func _level_ids_grouped_by_tier() -> Array[String]:
	var out: Array[String] = []
	for tier: int in range(1, MAX_TIERS + 1):
		for id: String in LevelLoader.levels_for_tier(tier):
			out.append(id)
	return out


func _tier_of_index(index: int) -> int:
	return level_ids[index].trim_prefix("tier").split("_")[0].to_int()


## صفحاتِ **متوازن**: ۹ سطح ⇒ ۵+۴ نه ۸+۱ (صفحه‌ی تک‌نودی برای کودک ۹ ساله بی‌معنا است ✗).
func _build_pages() -> Array:
	var out: Array = []
	var start: int = 0
	while start < level_ids.size():
		var tier: int = _tier_of_index(start)
		var count: int = 0
		while start + count < level_ids.size() and _tier_of_index(start + count) == tier:
			count += 1
		var page_count: int = int(ceil(float(count) / float(page_max())))
		var per_page: int = int(ceil(float(count) / float(page_count)))
		for page_no: int in range(page_count):
			var chunk: Array = []
			for k: int in range(mini(per_page, count - page_no * per_page)):
				chunk.append(start + page_no * per_page + k)
			if not chunk.is_empty():
				out.append(chunk)
		start += count
	return out


func _page_of(index: int) -> int:
	for page_no: int in range(pages.size()):
		for v: Variant in (pages[page_no] as Array):
			if int(v) == index:
				return page_no
	return 0


## صفحه‌ای باز می‌شود که «کارِ» کودک در آن است: اولین سطحِ بازِ تمام‌نشده ✗✓ با ۴۵ سطح،
## فرود همیشگی روی صفحهٔ ۱ یعنی هر بار دنبالِ سطحِ خودت بگردی ✗
func _first_open_index() -> int:
	var model: PlayerModel = GameState.active_model
	for i: int in range(level_ids.size()):
		if not is_unlocked(i):
			continue
		if model == null or not model.is_level_completed(level_ids[i]):
			return i
	return maxi(0, level_ids.size() - 1)


func _clear_nodes() -> void:
	for b: Button in buttons:
		if is_instance_valid(b):
			# `remove_child` قبل از `queue_free` لازم است: تا پایانِ فریم، نودِ در صفِ حذف
			# هنوز همان اسم را نگه می‌دارد ⇒ نودِ تازه با نامِ تکراری، خودکار
			# «@Button@1372» می‌شود ✗✓ (این را تستِ اسمِ نودها در CI گرفت).
			remove_child(b)
			b.queue_free()
	buttons.clear()


func _build_page_nodes() -> void:
	_clear_nodes()
	if pages.is_empty():
		return
	var page: Array = pages[current_page]
	var count: int = page.size()
	var step: float = MAX_PITCH
	if count > 1:
		step = maxf(MIN_PITCH, minf(MAX_PITCH, (BOTTOM_Y - TOP_Y) / float(count - 1)))
	# صفحه‌ی کم‌جمعیت در وسطِ باند می‌نشیند، نه چسبیده به سقف ✗
	var first_y: float = TOP_Y + ((BOTTOM_Y - TOP_Y) - step * float(count - 1)) * 0.5
	for i: int in range(count):
		var global_index: int = page[i]
		# فازِ مارپیچ از ایندکسِ سراسری می‌آید ⇒ مسیر بین صفحه‌ها پیوسته به‌نظر می‌رسد ✓
		var center := Vector2(540.0 + MEANDER_X * sin(float(global_index) * 1.05),
				first_y + step * float(i))
		var btn := Button.new()
		btn.name = "Level_%02d" % (global_index + 1)
		btn.custom_minimum_size = NODE_SIZE
		btn.position = center - NODE_SIZE * 0.5
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 40)
		btn.pressed.connect(request_level.bind(global_index))
		add_child(btn)
		buttons.append(btn)


func _ensure_page_controls() -> void:
	if has_node("PageControls"):
		return
	var host := Control.new()
	host.name = "PageControls"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)
	var prev_btn: Button = UIKit.make_button("common.previous", "stone",
			Vector2(168.0, NODE_SIZE.y))
	prev_btn.name = "PagePrev"
	prev_btn.position = Vector2(60.0, BOTTOM_Y + 140.0)
	prev_btn.pressed.connect(_goto_relative.bind(-1))
	host.add_child(prev_btn)
	var next_btn: Button = UIKit.make_button("common.next", "stone",
			Vector2(168.0, NODE_SIZE.y))
	next_btn.name = "PageNext"
	next_btn.position = Vector2(1020.0 - 168.0 - 60.0, BOTTOM_Y + 140.0)
	next_btn.pressed.connect(_goto_relative.bind(1))
	host.add_child(next_btn)
	var label := Label.new()
	label.name = "PageCounter"
	label.add_theme_font_size_override("font_size", 44)
	label.custom_minimum_size = Vector2(220.0, NODE_SIZE.y)
	label.position = Vector2(430.0, BOTTOM_Y + 140.0)
	host.add_child(label)


func _sync_page_controls() -> void:
	if not has_node("PageControls"):
		return
	# هرچه از `get_node` می‌آید با `as` تایپ می‌شود: `Node` خاصیت‌های `visible/.disabled/
	# .text` را ندارد و GDScript 4 دسترسیِ تایپ‌نشده را در همان صحنه‌ی load می‌شکند ✗✓
	var host: Control = get_node("PageControls") as Control
	var multi: bool = pages.size() > 1
	host.visible = multi
	if not multi:
		return
	var prev: Button = get_node("PageControls/PagePrev") as Button
	var next_btn: Button = get_node("PageControls/PageNext") as Button
	var counter: Label = get_node("PageControls/PageCounter") as Label
	if prev != null:
		prev.disabled = current_page <= 0
	if next_btn != null:
		next_btn.disabled = current_page >= pages.size() - 1
	if counter != null:
		# فقط رقم، بدون واژه ⇒ رشته‌ی تازه در `ui_strings.json` لازم نشد؛ «۲ / ۳» با دو
		# فلشِ کنارش خوانا است و رقم‌ها از `Loc.digits` فارسی می‌شوند (§۷) ✓✓
		counter.text = Loc.digits("%d / %d" % [current_page + 1, pages.size()])


## «برو به صفحهٔ i» (عمومی: هم دکمه‌ها، هم تست، هم بازگشت از سطح).
## دلتا در زمانِ کلیک خوانده می‌شود ✗✓ `bind(current_page - 1)` مقدار را در لحظه‌ی
## `connect` منجمد می‌کرد ⇒ از صفحه‌ی دوم به بعد، «قبلی» همیشه به صفحه‌ی صفر می‌رفت
## (باگِ کلاسیِ bind با state ✗✓ و تستِ صفحه‌ها همان را می‌گیرد).
func _goto_relative(delta: int) -> void:
	goto_page(current_page + delta)


func goto_page(page: int) -> void:
	if pages.is_empty():
		return
	current_page = clampi(page, 0, pages.size() - 1)
	_build_page_nodes()
	_sync_page_controls()
	refresh_locks()
	_refresh_backdrop(true)


func _ensure_menu_button() -> void:
	if has_node("BackToMenu"):
		return
	var btn: Button = UIKit.make_button("common.back", "stone", Vector2(240.0, UIKit.MIN_TOUCH_PX))
	btn.name = "BackToMenu"
	btn.position = Vector2(60.0, 60.0)
	btn.pressed.connect(_on_menu_pressed)
	add_child(btn)


func _on_menu_pressed() -> void:
	menu_requested.emit()
	if not allow_scene_change:
		return
	if not LevelLoader.goto_main_menu():
		Log.warn(TAG, "بازگشت به منو نشد: " + LevelLoader.last_error)


func is_unlocked(index: int) -> bool:
	if index <= 0:
		return true
	if index >= level_ids.size():
		return false
	var model: PlayerModel = GameState.active_model
	if model == null:
		return true
	return model.is_level_completed(level_ids[index - 1])


## متن/قفل دکمه‌ها را از PlayerModel بازسازی می‌کند (دکمه‌ی غیرفعال = قفل، نه پنهان).
func refresh_locks() -> void:
	var model: PlayerModel = GameState.active_model
	if pages.is_empty() or current_page >= pages.size():
		return
	var page: Array = pages[current_page]
	for i: int in range(mini(buttons.size(), page.size())):
		var btn: Button = buttons[i]
		if not is_instance_valid(btn):
			continue
		var index: int = page[i]
		var id: String = level_ids[index]
		var done: bool = model != null and model.is_level_completed(id)
		var open: bool = is_unlocked(index)
		btn.disabled = not open
		btn.text = str(index + 1) + (" ✓" if done else "")
		btn.tooltip_text = id if open else "%s — قفل (اول سطح %d را تمام کن)" % [id, index]
		btn.add_theme_color_override("font_color", Palette.CLOUD_WHITE if open else Palette.STONE_GREY)
		btn.add_theme_color_override("font_disabled_color", Palette.STONE_GREY)


func level_count() -> int:
	return level_ids.size()


## ورودی عمومی «این سطح را باز کن» — هم کلیک، هم تست (بدون تزریق InputEvent).
func request_level(index: int) -> void:
	if index < 0 or index >= level_ids.size():
		return
	var id: String = level_ids[index]
	if not is_unlocked(index):
		level_blocked.emit(id, "locked")
		Log.info(TAG, "سطح %s قفل است" % id)
		return
	level_requested.emit(id)
	if not allow_scene_change:
		# تست/پیش‌نمایش: ناوبری با صحنه را مسئول بیرونی می‌گذاریم
		LevelLoader.pending_config = LevelLoader.load_config(id)
		return
	if not LevelLoader.start_level(id):
		Log.warn(TAG, "بازکردن سطح %s ممکن نشد: %s" % [id, LevelLoader.last_error])


func _on_level_completed(_level_id: String, _stats: Dictionary) -> void:
	refresh_locks()
	# §۵ | هر برد باید در دنیا دیده شود ⇒ همان Tier یک پل جلو می‌آید ✓
	_refresh_backdrop(true)


## تسک ۸.۳ | یک Node2Dِ خالص پشتِ کنترل‌ها (بدونِ `Control` ✗✓ همان درسی که از فازِ ۷.۴
## گرفتیم: گرهٔ بک‌گراند اگر Control باشد کلیک‌های بچه‌ها را می‌خورد ✗✗ ⇒ `z_index = -30`
## و نوعِ Node2D ✓✓). صفحهٔ ۰ = Hub (میانگینِ کلِ پادشاهی ✓) و صفحهٔ n = منطقۀ Tier n ✓
func _ensure_backdrop() -> void:
	if _backdrop != null and is_instance_valid(_backdrop):
		return
	_backdrop = RegionBackdrop.new()
	_backdrop.name = "Backdrop"
	add_child(_backdrop)


func _refresh_backdrop(animate: bool) -> void:
	if _backdrop == null or not is_instance_valid(_backdrop):
		return
	if current_page <= 0:
		_backdrop.region = RegionBackdrop.HUB
		_backdrop.set_restoration(GameState.world_restoration(), animate)
		return
	_backdrop.region = RegionBackdrop.region_for_tier(current_page)
	_backdrop.set_restoration(GameState.tier_restoration(current_page), animate)
