class_name LevelController
extends Node2D
# ===========================================================================
# LevelController — ارکستراتور یک سطح (تسک ۲.۵ + ۲.۶)
# ---------------------------------------------------------------------------
# تنها چیزی که می‌داند: «چیدمان فعلی ↔ تعادل». هیچ امتیازی محاسبه نمی‌کند،
# هیچ Elo دست نمی‌زند، هیچ دیالوگی انتخاب نمی‌کند (فازهای ۴ و ۵).
#
# قرارداد `config` (ADR-028): دیکشنری ساده‌ای که در فاز ۳ دقیقاً همان چیزی است که
# `LevelData.to_config_dict()` از JSON سطح می‌سازد → کد این فایل در فاز ۳ عوض نمی‌شود.
#
# تسک ۲.۶: `default_config()` همان سطح hardcoded «3 + 5 = ؟» است.
# ===========================================================================

const TAG := "LevelController"
const BalanceScaleScene: PackedScene = preload("res://scenes/gameplay/BalanceScale.tscn")
const WeightOrbScene: PackedScene = preload("res://scenes/gameplay/WeightOrb.tscn")

const TRAY_ORB_RADIUS := 40.0
const TRAY_SPACING := 104.0
const TRAY_ROW_LENGTH := 6

signal level_won(stats: Dictionary)
signal tray_changed(tray_count: int, placed_count: int)

## سطح تستی فاز ۲ (hardcoded، طبق DoD ۲.۶)
@export var config: Dictionary = {}
@export var scales_root: Node2D = null
@export var tray_root: Node2D = null
@export var intro_label: Label = null
## §۳ سند GDD: «تلاش» وقتی شمرده می‌شود که یک چیدمانِ ناپایدار ~۰.۸ ثانیه بماند
@export var attempt_settle_sec: float = 0.8
@export var build_on_ready: bool = true
## حلقه‌ی تسک ۳.۴ (برد → بعدی/نقشه). فاز ۶ HUD این را جایگزین می‌کند.
@export var result_bar_enabled: bool = true
## تسک ۶.۲: آموزش داخل Onboarding **باید همان مکانیک واقعی باشد** (نه یک شبیه‌سازی
## جدا که بعداً واگرا شود)، ولی نباید آمار کودک را بنویسد: بدون این فلگ، یک کشیدنِ
## کره در Onboarding سطح ۰۱ را «تمام‌شده» و رتبه را به‌روز می‌کرد.
## guard: `begin_level`، `attempt_failed`، `error_patterns`، `apply_level_result`،
## `mark_level_completed` و emit `level_completed` — یعنی هر چیزی که در save می‌نشیند.
## سیگنال‌های فیدبک (orb_placed/balance_changed) و `level_won** دست‌نخورده‌اند:
## آموزش باید واقعی به نظر برسد.
@export var report_progress: bool = true
## تسک ۶.۴: HUD داخل صحنهٔ سطح (دکمهٔ راهنما + پیشرفت + Aria + جعبهٔ گفت‌وگو).
## بدهیِ فاز ۵ همین‌جا بسته شد: آن فاز منطق و صحنه‌ها را ساخت، ولی هیچ صحنه‌ای
## آن‌ها را instantiate نمی‌کرد.
@export var hud_enabled: bool = true
## پازِ واقعی (تسک ۶.۳) از همین صحنه: resume یعنی همان درختِ زنده، پس منوی پاز
## فرزندِ صحنه است نه یک صحنهٔ جدا که با change_scene وضعیت را می‌سوزاند.
@export var pause_menu_enabled: bool = true
## نردبان راهنما (تسک ۴.۳): تایمر بی‌حرکتی/شمارش تلاش روی همین سطح. خاموش‌کردنش
## صحنه را به رفتار فاز ۳ برمی‌گرداند (بدون هیچ راهنمای خودکار).
@export var hint_timing_enabled: bool = true
## طبقه‌بندی خطا (تسک ۴.۲). kill-switch: با false هیچ `error_detected` publish نمی‌شود
## و شمارش تلاش دست‌نخورده می‌ماند — «تلاش» مستقل از برچسب خطاست.
@export var error_classification_enabled: bool = true

var result_bar: LevelResultBar = null
var hint_timing: HintTimingSystem = null
var hud: HUD = null
var pause_menu: PauseMenu = null

var level_id: String = ""
var tier: int = 1
var tolerance: float = 0.0
var scales: Array[BalanceScale] = []
var tray_orbs: Array[WeightOrb] = []

var _built: bool = false
var _won: bool = false
var _settle_pending: bool = false
var _settle_elapsed: float = 0.0


func _ready() -> void:
	# ارجاع‌های گره‌ای را خودمان هم resolve می‌کنیم: LevelScene.tscn آن‌ها را با NodePath
	# می‌دهد، اما اگر صحنه‌ای این‌ها را نداشت یا resolve نشد، سطح نباید نصفه بسازد.
	if scales_root == null:
		scales_root = get_node_or_null("Scales") as Node2D
	if tray_root == null:
		tray_root = get_node_or_null("Tray") as Node2D
	if intro_label == null:
		intro_label = get_node_or_null("Intro") as Label
	if config.is_empty():
		# تسک ۳.۲: LevelLoader.start_level() سطح تازه را این‌جا «صف» می‌کند. مصرفِ یک‌باره
		# است، پس اگر کسی start_level نکرده (تست‌های فاز ۲، F5 مستقیم) همان config
		# پیش‌فرض فاز ۲ ساخته می‌شود و صفحه‌ی سفید هیچ‌وقت رخ نمی‌دهد.
		config = LevelLoader.take_pending_config()
	if config.is_empty():
		config = default_config()
	if hint_timing_enabled and hint_timing == null:
		hint_timing = HintTimingSystem.new()
		hint_timing.name = "HintTiming"
		add_child(hint_timing)
	if result_bar_enabled and result_bar == null:
		result_bar = LevelResultBar.new()
		result_bar.name = "ResultBar"
		result_bar.controller = self
		result_bar.allow_scene_change = LevelLoader.change_scene_on_start
		add_child(result_bar)
	if hud_enabled and hud == null:
		hud = HUD.new()
		hud.name = "HUD"
		hud.controller = self
		add_child(hud)
	if pause_menu_enabled and pause_menu == null:
		pause_menu = PauseMenu.new()
		pause_menu.name = "PauseMenu"
		pause_menu.allow_scene_change = LevelLoader.change_scene_on_start
		add_child(pause_menu)
	if build_on_ready:
		build()


static func default_config() -> Dictionary:
	return {
		"level_id": "tier1_level_01",
		"tier": 1,
		"tolerance": 0.0,
		"narrative_intro": "اولین پل شکسته‌ی روستای Sunlit Meadow منتظر توست.",
		"scales": [
			{
				"id": "main",
				"left_orbs": [
					{"type": "number", "value": 3.0},
					{"type": "number", "value": 5.0},
				],
				"target_value": 8.0,
				"ghost_orbs": [],
			},
		],
		"available_orbs": [
			{"type": "number", "value": 1.0, "count": 10},
			{"type": "number", "value": 2.0, "count": 5},
			{"type": "number", "value": 5.0, "count": 3},
		],
	}


## فاز ۳: LevelLoader این را با داده‌ی JSON صدا می‌زند (قبل یا بعد از add_child).
func configure(p_config: Dictionary) -> void:
	config = p_config
	if _built:
		build()


## داده‌ی JSON ممکن است کلید را نباشد یا null باشد؛ هیچ‌وقت روی null iterate نکن.
static func _arr(cfg: Dictionary, key: String) -> Array:
	var raw: Variant = cfg.get(key, [])
	if raw is Array:
		return raw
	return []


func is_won() -> bool:
	return _won


## state فعلیِ کفه‌ها، به‌شکل داده‌ی خام (ADR-028) — همان چیزی که ErrorClassifier
## می‌خواند. عمداً «نمای صافِ dict» است تا لایه‌ی `ai/` به گره‌های صحنه وابسته نشود.
func pan_snapshot(scale_index: int = 0) -> Dictionary:
	var out := {"left": [], "right": []}
	if scale_index < 0 or scale_index >= scales.size():
		return out
	var scale: BalanceScale = scales[scale_index]
	if scale == null:
		return out
	for side: String in ["left", "right"]:
		var pan: BalancePan = scale.left_pan if side == "left" else scale.right_pan
		var entries: Array = []
		if pan != null:
			for orb: WeightOrb in pan.orbs:
				if orb == null:
					continue
				entries.append({"type": _orb_type_name(orb), "value": orb.value,
					"weight": orb.weight()})
		out[side] = entries
	return out


## برچسب خطای همین لحظه ("" یعنی چیزی برای طبقه‌بندی نیست).
func classify_current_error(scale_index: int = 0) -> String:
	var snap: Dictionary = pan_snapshot(scale_index)
	return ErrorClassifier.classify(config, snap["left"], snap["right"], scale_index)


static func _orb_type_name(orb: WeightOrb) -> String:
	match orb.orb_type:
		WeightOrb.OrbType.GHOST:
			return "ghost"
		WeightOrb.OrbType.NEGATIVE:
			return "negative"
		_:
			return "number"


# --------------------------------------------------------------------------
# ساخت / تخلیه
# --------------------------------------------------------------------------
func build() -> void:
	teardown()
	if config.is_empty():
		Log.warn(TAG, "config خالی است — سطحی ساخته نشد")
		return
	level_id = str(config.get("level_id", ""))
	tier = int(config.get("tier", 1))
	tolerance = float(config.get("tolerance", 0.0))
	if intro_label != null:
		intro_label.text = str(config.get("narrative_intro", ""))
	# نردبان راهنمای همین سطح (تسک ۴.۳) از همان config خوانده می‌شود
	if hint_timing != null:
		hint_timing.configure(config)

	for scale_cfg: Variant in _arr(config, "scales"):
		_build_scale(scale_cfg as Dictionary)
	if scales.is_empty():
		Log.warn(TAG, "هیچ ترازویی در config نیست")
		return

	_build_tray()
	_apply_scale_layout()
	_built = true
	# هر وضعیت settle که وسط ساخت روشن شده بی‌اعتبار است (کره‌های ثابتِ سطح)
	_settle_pending = false
	_settle_elapsed = 0.0
	set_process(true)
	if report_progress:
		GameState.begin_level(level_id, tier)
	_layout_tray()


## دو ترازو روی هم نمی‌افتند: برای Tier 4 (Twin Observatory) کنار هم با بازوی کوتاه‌تر.
## عمداً `scale` نود را دست نمی‌زنیم تا هندسه‌ی `contains_point` در مختصات جهانی دقیق بماند.
func _apply_scale_layout() -> void:
	var n: int = scales.size()
	for i: int in range(n):
		var scale: BalanceScale = scales[i]
		if not is_instance_valid(scale):
			continue
		if n > 1:
			scale.arm_length = 140.0
			scale.position = Vector2(-270.0 + 540.0 * float(i), -150.0)
			if scale.left_pan != null:
				scale.left_pan.pan_radius = 96.0
			if scale.right_pan != null:
				scale.right_pan.pan_radius = 96.0
		scale.resync_geometry()


func teardown() -> void:
	_built = false
	_won = false
	_settle_pending = false
	_settle_elapsed = 0.0
	for orb: WeightOrb in tray_orbs.duplicate():
		tray_orbs.erase(orb)
		if is_instance_valid(orb):
			orb.queue_free()
	# یتیم‌ها: کره‌ای که وسط درگ از صحنه خارج شده بود، فرزند این نود است
	for child: Node in get_children():
		if child is WeightOrb:
			child.queue_free()
	for scale: BalanceScale in scales.duplicate():
		if is_instance_valid(scale):
			scale.queue_free()
	scales.clear()
	if tray_root != null:
		for child: Node in tray_root.get_children():
			if child is WeightOrb:
				child.queue_free()


func _build_scale(scale_cfg: Dictionary) -> void:
	var scale: BalanceScale = BalanceScaleScene.instantiate() as BalanceScale
	if scale == null:
		return
	scale.scale_id = str(scale_cfg.get("id", "scale_%d" % (scales.size() + 1)))
	var root_node: Node = scales_root if scales_root != null else self
	root_node.add_child(scale)
	scales.append(scale)
	scale.weights_changed.connect(_on_scale_weights)
	scale.placement_changed.connect(_on_scale_placement)

	for entry: Variant in _arr(scale_cfg, "left_orbs"):
		var orb := _make_orb(entry as Dictionary)
		if orb != null and scale.left_pan != null:
			# add_orb هم والد را درست می‌کند و هم relayout می‌گیرد (تکرار position لازم نیست)
			scale.left_pan.add_orb(orb)
	# ghost orbs روی چپ (Tier 3+): وزن مخفی، بدون نمایش عدد
	for ghost: Variant in _arr(scale_cfg, "left_ghost_orbs"):
		var g := _make_ghost(ghost as Dictionary)
		if g != null and scale.left_pan != null:
			scale.left_pan.add_orb(g)
	# آرک‌تایپ ۲: کفه‌ی راست هم می‌تواند از قبل کره داشته باشد (number/ghost/negative)
	for entry: Variant in _arr(scale_cfg, "right_orbs"):
		var orb := _make_orb(entry as Dictionary)
		if orb != null and scale.right_pan != null:
			scale.right_pan.add_orb(orb)
	for ghost: Variant in _arr(scale_cfg, "right_ghost_orbs"):
		var rg := _make_ghost(ghost as Dictionary)
		if rg != null and scale.right_pan != null:
			scale.right_pan.add_orb(rg)


func _build_tray() -> void:
	var root_node: Node = tray_root if tray_root != null else self
	for entry: Variant in _arr(config, "available_orbs"):
		var spec := entry as Dictionary
		var count: int = int(spec.get("count", 1))
		for i: int in range(count):
			var orb := _make_orb(spec)
			if orb != null:
				_reparent(orb, root_node)
				tray_orbs.append(orb)


func _make_orb(spec: Dictionary) -> WeightOrb:
	if spec.is_empty():
		return null
	var type_name: String = str(spec.get("type", "number")).to_lower()
	match type_name:
		"ghost":
			return _make_ghost(spec)
		"negative":
			var neg := NegativeOrb.new()
			_init_orb(neg, spec)
			return neg
		_:
			var orb := WeightOrbScene.instantiate() as WeightOrb
			if orb == null:
				return null
			_init_orb(orb, spec)
			return orb


func _init_orb(orb: WeightOrb, spec: Dictionary) -> void:
	orb.radius = TRAY_ORB_RADIUS
	orb.set_value(float(spec.get("value", 1.0)))
	orb.drag_began.connect(_on_orb_drag_began)
	orb.drag_ended.connect(_on_orb_drag_ended)


func _make_ghost(spec: Dictionary) -> GhostOrb:
	var g := GhostOrb.new()
	g.radius = TRAY_ORB_RADIUS
	g.hidden_value = float(spec.get("hidden_value", 0.0))
	g.drag_began.connect(_on_orb_drag_began)
	g.drag_ended.connect(_on_orb_drag_ended)
	return g


# --------------------------------------------------------------------------
# سینی (tray) — جایی که کره‌های قابل‌استفاده منتظرند
# --------------------------------------------------------------------------
func _layout_tray() -> void:
	var per_row: int = maxi(1, TRAY_ROW_LENGTH)
	for i: int in range(tray_orbs.size()):
		var orb: WeightOrb = tray_orbs[i]
		if orb == null or not is_instance_valid(orb) or orb.is_placed or orb.is_dragging():
			continue  # کره‌ی وسط درگ را هرگز «خانه» برنگردان
		var col: int = i % per_row
		var row: int = int(float(i) / float(per_row))
		var pos := Vector2(
			(float(col) - float(per_row - 1) * 0.5) * TRAY_SPACING,
			float(row) * TRAY_SPACING * 0.95)
		orb.position = pos
		orb.home_position = pos
	tray_changed.emit(tray_unplaced_count(), total_placed())


func tray_unplaced_count() -> int:
	var n: int = 0
	for orb: WeightOrb in tray_orbs:
		if orb != null and is_instance_valid(orb) and not orb.is_placed:
			n += 1
	return n


func total_placed() -> int:
	var n: int = 0
	for scale: BalanceScale in scales:
		if is_instance_valid(scale):
			n += scale.placed_count()
	return n


# --------------------------------------------------------------------------
# درگ → کفه
# --------------------------------------------------------------------------
func _on_orb_drag_began(orb: WeightOrb) -> void:
	if orb == null:
		return
	# والد را عوض نمی‌کنیم (جابه‌جایی والد وسط درگ، _exit_tree → افتادگی حالت درگ را
	# داشت). به‌جایش top_level تا زمان رهاکردن،transform را از والد مستقل می‌کند.
	orb.top_level = true
	if orb.is_placed and orb.pan != null:
		# برداشتن از کفه بلافاصله تعادل را عوض می‌کند (بازخورد آنی، §۳ GDD)
		orb.pan.remove_orb(orb)


func _on_orb_drag_ended(orb: WeightOrb, world_pos: Vector2) -> void:
	if orb == null:
		return
	var target := _pan_at(world_pos)
	if target != null and target.add_orb(orb):
		orb.top_level = false
		_emit_orb_placed(orb, target, true)
		_layout_tray()
		return
	_return_to_tray(orb)
	_layout_tray()


func _pan_at(world_pos: Vector2) -> BalancePan:
	for scale: BalanceScale in scales:
		if not is_instance_valid(scale):
			continue
		for pan: BalancePan in [scale.left_pan, scale.right_pan]:
			if pan != null and pan.contains_point(world_pos):
				return pan
	return null


func _return_to_tray(orb: WeightOrb) -> void:
	if orb.pan != null and orb.is_placed:
		orb.pan.remove_orb(orb)
	var root_node: Node = tray_root if tray_root != null else self
	var from_global: Vector2 = orb.global_position
	orb.top_level = false
	if orb.get_parent() != root_node:
		_reparent(orb, root_node)
		orb.global_position = from_global
	orb.create_tween().tween_property(orb, "position", orb.home_position, 0.18)
	_emit_orb_placed(orb, null, false)


## تنها راه امن جابه‌جایی نود بین دو والد در Godot: اول remove، بعد add.
func _reparent(node: Node, new_parent: Node) -> void:
	if node == null or new_parent == null or node.get_parent() == new_parent:
		return
	var prev: Node = node.get_parent()
	if prev != null:
		prev.remove_child(node)
	new_parent.add_child(node)


func _emit_orb_placed(orb: WeightOrb, pan: BalancePan, placed: bool) -> void:
	var payload := {
		"orb_type": orb.orb_type,
		"value": orb.value,
		"weight": orb.weight(),
		"is_ghost": orb.is_ghost(),
		"level_id": level_id,
		"placed": placed,
	}
	if pan != null:
		payload["side"] = pan.side
		payload["scale_id"] = pan.scale_ref.scale_id if pan.scale_ref != null else "main"
	if placed:
		EventBus.orb_placed.emit(payload)
	else:
		EventBus.orb_removed.emit(payload)


# --------------------------------------------------------------------------
# تعادل → برد / تلاش (تسک ۲.۵)
# --------------------------------------------------------------------------
func _on_scale_weights(_scale: BalanceScale, _left: float, _right: float, _tilt: float) -> void:
	if _won or not _built:
		return  # وسط ساختِ صحنه هنوز «سطح» تعریف نشده؛ برد معنی ندارد
	if _all_balanced() and total_placed() > 0:
		_win()


func _on_scale_placement(orb: WeightOrb, placed: bool) -> void:
	if _won or not placed or orb == null or not _built:
		return  # چیدمان اولیه‌ی سطح «تلاش بازیکن» نیست
	if not _all_balanced():
		_settle_pending = true
		_settle_elapsed = 0.0


## «بازی متوقف شد» یعنی کره هم نباید جابه‌جا شود (§۶ سند هنری: پاز واقعی، نه فقط
## منوی رویِ صحنه) — و وقتی برقرار شد، همان کره‌ها دوباره قابل‌کشیدن‌اند.
func set_drag_enabled(on: bool) -> void:
	for orb: WeightOrb in tray_orbs:
		if is_instance_valid(orb):
			orb.drag_enabled = on
	for scale: BalanceScale in scales:
		if not is_instance_valid(scale):
			continue
		for pan: BalancePan in [scale.left_pan, scale.right_pan]:
			if pan == null:
				continue
			for placed: WeightOrb in pan.orbs:
				if is_instance_valid(placed):
					placed.drag_enabled = on


func any_orb_draggable() -> bool:
	for orb: WeightOrb in tray_orbs:
		if is_instance_valid(orb) and orb.drag_enabled:
			return true
	for scale: BalanceScale in scales:
		if not is_instance_valid(scale):
			continue
		for pan: BalancePan in [scale.left_pan, scale.right_pan]:
			if pan == null:
				continue
			for placed: WeightOrb in pan.orbs:
				if is_instance_valid(placed) and placed.drag_enabled:
					return true
	return false


func open_pause() -> void:
	if pause_menu != null and is_instance_valid(pause_menu):
		pause_menu.open(self)
		return
	if hud != null and is_instance_valid(hud):
		hud.pause_level()


func close_pause() -> void:
	if pause_menu != null and is_instance_valid(pause_menu):
		pause_menu.resume()


## §۶.۳: بازگشت با دکمهٔ عقبِ Android = پاز، نه خروج از بازی.
func _unhandled_input(event: InputEvent) -> void:
	if not pause_menu_enabled:
		return
	if event.is_action_pressed("ui_cancel"):
		if pause_menu != null and pause_menu.is_open():
			pause_menu.resume()
		else:
			open_pause()
		get_viewport().set_input_as_handled()


func _all_balanced() -> bool:
	if scales.is_empty():
		return false
	for scale: BalanceScale in scales:
		if not is_instance_valid(scale) or not scale.is_balanced(tolerance):
			return false
	return true


func _process(delta: float) -> void:
	if not _settle_pending:
		return
	_settle_elapsed += delta
	if _settle_elapsed < attempt_settle_sec:
		return
	_settle_pending = false
	if _all_balanced():
		return
	# خودِ GameState سیگنال attempt_failed را با شماره‌ی تلاش publish می‌کند (تسک ۱.۱)
	if report_progress:
		GameState.register_attempt_failed()
	# تسک ۴.۲: چه نوع خطایی؟ (کاملاً rule-based — هیچ درخواست شبکه/AI اینجا نیست)
	if error_classification_enabled and report_progress:
		var error_type := classify_current_error()
		if not error_type.is_empty():
			EventBus.error_detected.emit(error_type)
			if GameState.active_model != null:
				GameState.active_model.bump_error_pattern(error_type)


func _win() -> void:
	_won = true
	_settle_pending = false
	if not report_progress:
		# آموزش: کودک برنده شد، ولی هیچ‌چیز در مدل/انجین/سیگنال‌های جهانی نوشته نمی‌شود.
		# `_won` ست شده تا `is_won()` و `level_won` کار کنند (Onboarding همان را می‌شنود).
		for tut_scale: BalanceScale in scales:
			if is_instance_valid(tut_scale):
				tut_scale.refresh(false)
		level_won.emit({})
		return
	var time_sec: float = maxf(0.5, GameState.elapsed_level_sec())
	# تسک ۴.۴/۴.۲: رتبه **قبل از** publish به‌روز می‌شود تا payload همان score و
	# final_elo_delta واقعی را ببرد (ADR-038؛ شنودِ level_completed دو بار اعمال می‌کرد).
	var outcome: Dictionary = DifficultyEngine.apply_level_result(config, true)
	var stats: Dictionary = GameState.build_level_stats(
		float(outcome.get("score", 1.0)), float(outcome.get("elo_delta", 0.0)), time_sec)
	if GameState.active_model != null:
		GameState.active_model.mark_level_completed(level_id, time_sec, GameState.hints_used_this_level)
		GameState.commit_playtime()
	for scale: BalanceScale in scales:
		if is_instance_valid(scale):
			scale.refresh(false)
	EventBus.level_completed.emit(level_id, stats)
	level_won.emit(stats)
	Log.info(TAG, "سطح %s تکمیل شد (تلاش‌ها=%d، راهنما=%d)"
		% [level_id, GameState.level_attempts, GameState.hints_used_this_level])


## کمک برای تست/فاز ۳: همه‌ی کره‌های داده‌شده را روی کفه‌ی راست کفه‌ی اول می‌گذارد.
func place_on_right(orbs_to_place: Array[WeightOrb], scale_index: int = 0) -> int:
	if scale_index >= scales.size():
		return 0
	var scale: BalanceScale = scales[scale_index]
	var placed_count: int = 0
	for orb: WeightOrb in orbs_to_place:
		if orb == null or orb.is_placed:
			continue
		if scale.right_pan.add_orb(orb):
			placed_count += 1
			_emit_orb_placed(orb, scale.right_pan, true)
	_layout_tray()
	return placed_count
