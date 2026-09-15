extends Node
# ===========================================================================
# DifficultyEngine — «بعدی کدام سطح باشد؟» (تسک ۴.۴ | docs/07 §۵)
# --------------------------------------------------------------------------
# دو کار می‌کند و فقط همان دو کار:
#  ۱) بعد از هر سطح، رتبه‌ی مهارتِ مرتبط با `concept_tags` را با **امتیاز وزن‌دار**
#     به‌روز می‌کند (وزن را ErrorClassifier می‌دهد — نکته‌ی §۳ سند داده‌ها).
#  ۲) سطح بعدی را انتخاب می‌کند: نزدیک‌ترین `difficulty_elo` به رتبه‌ی بازیکن،
#     با قفل روایت (Tier باز نشده ≠ کاندید) و سقف‌های ضددیوارِ §۵.
#
# چرا `level_completed` را *نوشنود*؟ چون payload همان سیگنال باید `score` و
# `final_elo_delta` را داشته باشد؛ اگر رتبه بعد از emit به‌روز شود، صفر publish می‌شود
# و اگر قبلش هم شنود شود، یک نتیجه دو بار اعمال می‌شود. پس LevelController
# **قبل از emit** صراحتاً `apply_level_result()` را صدا می‌زند (ADR-038).
#
# انتخاب سطح عمداً در یک تابع **pure** (`choose_next`) است: ورودی‌اش فهرست کاندید و
# چند فلگ است، نه دیسک/مدل. این‌طور می‌توان ۳۰ سطح شبیه‌سازی‌شده را در CI بدون
# فایل‌سازی دوید (DoD §۴.۴) و قوانین GDD عدد‌به‌عدد تست شدند.
# ===========================================================================

const TAG := "DifficultyEngine"

## §۵: «اگر بازیکن ۲ بار پشت‌سرهم در یک سطح شکست خورد → سطح بعدی ساده‌تر (همان Tier)»
const STRUGGLE_ATTEMPTS := 2
## §۵: «اگر ۳ سطح بدون راهنما → ۱ سطح پریدن مجاز است»
const MASTERY_STREAK := 3
## §۵: «حداکثر ۱ سطح تازه‌ی سخت در هر ۳ سطح» (ضد دیوار)
const HARD_WINDOW := 3
## «سخت» یعنی چند Elo بالاتر از رتبه‌ی فعلی بازیکن؛ همان فاصله هم آستانه‌ی
## جلوپریدنِ بازیکنِ ready-تر از نردبان است (مقیاس K=32 ⇒ ۶۰ ≈ دو تا سه سطحِ کامل).
const HARD_ELO_GAP := 60.0
## حداکثر فاصله‌ی جابه‌جایی رو به جلو: **یک** سطح. §۵ «پریدن» را فقط با streak سه‌تایی
## مجاز می‌داند، پس تطبیقِ Elo هرگز بیشتر از یک پله از نردبان جلو نمی‌زند
## (درحالی‌که همان یک پله باعث می‌شود بازیکنِ آماده در صفِ سطوح آسان گیر نکند).
const MAX_SWAP_AHEAD := 1

## تصمیم‌های اخیر (لاگ/تست) و نتیجه‌ی سطوح اخیر — پنجره‌ی §۵ روی این دومی حساب می‌شود
var _history: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _remediation_used: bool = false
var _no_hint_streak: int = 0
## kill-switch: اگر روزی تطبیق آزاردهنده شد، با false به ترتیب خطی برمی‌گردیم
@export var adaptive_selection: bool = true


func _ready() -> void:
	# اتصال به seam فاز ۳ (ADR-035): LevelLoader «بعدی» را از ما می‌پرسد.
	LevelLoader.next_selector = pick_next_level_id
	set_process(false)


## §۴.۴: نزدیک‌ترین رتبه به بازیکن، با قفل روایت و سقف‌های §۵.
## kill-switch (تسک ۱۰.۵ / پلی‌تست): اگر تطبیق آزاردهنده شد، ترتیب خطیِ نردبان.
func pick_next_level_id(current_id: String) -> String:
	if not adaptive_selection:
		return LevelLoader.next_of(current_id)
	var chosen := next_level(current_id)
	return str(chosen.get("level_id", ""))


func next_level(current_id: String) -> Dictionary:
	var model: PlayerModel = GameState.active_model
	var open_tier: int = current_tier_of(current_id)
	var candidates := build_candidates(open_tier, model, false, current_id)
	if candidates.is_empty():
		# Tier تمام شده: Tier بعدی فقط اگر حداقل یک سطحش باز باشد (قفل روایت §۵)
		open_tier += 1
		candidates = build_candidates(open_tier, model, false, current_id)
	var struggle: bool = GameState.level_attempts >= STRUGGLE_ATTEMPTS and not _remediation_used
	if struggle:
		# §۵ «۲ بار شکست → سطح بعدی از همان Tier و ساده‌تر»: نردبانِ هر Tier با قانون
		# validator (docs/05 §۳، پرش >۱۲۰ ممنوع) صعودی است، پس «ساده‌تر» یعنی
		# **بازگشت به یک سطحِ تمام‌شده‌ی همان Tier** (تمرینِ مجدّد، نه گم‌کردن مسیر).
		candidates = build_candidates(open_tier, model, true, current_id)
	var flags := selection_flags(open_tier, candidates, struggle)
	var picked := choose_next(player_elo_for(current_id), candidates, flags)
	var reason: String = str(picked.get("reason", ""))
	_remediation_used = reason == "struggle_practice_rerun"
	_history.append({
		"from": current_id,
		"to": str(picked.get("level_id", "")),
		"reason": reason,
		"player_elo": player_elo_for(current_id),
	})
	while _history.size() > HARD_WINDOW * 4:
		_history.pop_front()
	return picked


# --------------------------------------------------------------------------
# کاندیدسازی از روی دیسک + مدل
# --------------------------------------------------------------------------
## سطح‌های همین Tier، در ترتیب نردبان. `include_completed=true` سطح‌های تمام‌شده را هم
## می‌آورد (برای «پله‌ی عقب» §۵) — و `skip_id` همیشه حذف می‌شود (تکرارِ بی‌معنیِ همان
## سطحی که بازیکن همین حالا باخت/برد).
func build_candidates(tier: int, model: PlayerModel = null, include_completed: bool = false,
		skip_id: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if tier < 1 or tier > 5:
		return out
	var index: int = 0
	for id: String in LevelLoader.levels_for_tier(tier):
		if id == skip_id:
			continue
		var lv: LevelData = LevelLoader.load_level(id)
		if lv == null:
			continue
		var done: bool = model != null and model.is_level_completed(id)
		if done and not include_completed:
			continue
		out.append({
			"id": id, "elo": float(lv.difficulty_elo), "tier": lv.tier,
			"index": index, "completed": done,
		})
		index += 1
	return out


func current_tier_of(level_id: String) -> int:
	if not level_id.is_empty() and LevelLoader.is_valid_id_format(level_id):
		var lv: LevelData = LevelLoader.load_level(level_id)
		if lv != null:
			return lv.tier
	return clampi(GameState.current_tier, 1, 5)


func player_elo_for(level_id: String) -> float:
	var model: PlayerModel = GameState.active_model
	if model == null:
		return SkillRating.ELO_START
	var tags := tags_of(LevelLoader.load_config(level_id))
	return model.average_skill_elo(tags)


func tags_of(config: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var raw: Variant = config.get("concept_tags", [])
	if raw is Array:
		for item: Variant in (raw as Array):
			var tag: String = str(item)
			if not tag.is_empty() and not out.has(tag):
				out.append(tag)
	if out.is_empty():
		out.append("general")
	return out


func selection_flags(open_tier: int, candidates: Array[Dictionary], struggle: bool = false) -> Dictionary:
	var hard_used_recently: bool = false
	# §۵: «حداکثر ۱ سطح تازه‌ی سخت در هر ۳ سطح» → پنجره روی نتیجه‌های واقعیِ بازی
	for i: int in range(maxi(0, _results.size() - HARD_WINDOW), _results.size()):
		if bool((_results[i] as Dictionary).get("served_hard", false)):
			hard_used_recently = true
			break
	return {
		"struggle": struggle,
		"mastery_jump": _no_hint_streak >= MASTERY_STREAK,
		"hard_used_recently": hard_used_recently,
		"current_tier": open_tier,
		"candidate_count": candidates.size(),
	}


# --------------------------------------------------------------------------
# هسته‌ی تصمیم (pure)
# --------------------------------------------------------------------------
## candidates: [{id, elo, tier, index}] (مرتب‌شده بر اساس ترتیب نردبان، بدون
## تکمیل‌شده‌ها). flags: {struggle, mastery_jump, hard_used_recently, current_tier}.
## خروجی: {level_id, reason} — reason برای لاگ/تحلیل و برای تست همان قاعده است.
static func choose_next(player_elo: float, candidates: Array[Dictionary],
		flags: Dictionary = {}) -> Dictionary:
	if candidates.is_empty():
		return {"level_id": "", "reason": "no_candidates"}
	var allowed: Array[Dictionary] = _filter_tier_lock(candidates, int(flags.get("current_tier", 5)))
	if allowed.is_empty():
		return {"level_id": "", "reason": "tier_locked"}
	var base: Dictionary = allowed[0]
	if bool(flags.get("struggle", false)):
		var easier := _easiest_completed_in_tier(allowed, int(base.get("tier", 1)))
		if not easier.is_empty():
			return {"level_id": str(easier.get("id", "")), "reason": "struggle_practice_rerun"}

	var pick: Dictionary = base
	var reason := "ladder_order"
	# ۱) بازیکن از همین پله جلو زده: رتبه‌اش حداقل HARD_ELO_GAP بالاتر از سطح بعدیِ
	# نردبان است → یک پله جابه‌جایی (نه بیشتر).
	if allowed.size() > MAX_SWAP_AHEAD:
		var nxt: Dictionary = allowed[MAX_SWAP_AHEAD]
		if float(nxt.get("elo", 0.0)) <= player_elo - HARD_ELO_GAP and _closer(nxt, base, player_elo):
			pick = nxt
			reason = "elo_lead"
	# ۲) «۳ سطح بدون راهنما → ۱ سطح پریدن مجاز» (§۵) — اگر جابه‌جایی رخ نداده باشد
	if str(pick.get("id", "")) == str(base.get("id", "")) and bool(flags.get("mastery_jump", false)) \
			and allowed.size() > 1:
		pick = allowed[1]
		reason = "mastery_jump"
	# ۳) سقف دیوار (§۵): «حداکثر ۱ سطح تازه‌ی سخت در هر ۳ سطح» → همان سطحِ ساده‌ترِ
	# بازمانده‌ی همین Tier جایگزین می‌شود (نه پرش به Tier دیگر).
	if bool(flags.get("hard_used_recently", false)) \
			and float(pick.get("elo", 0.0)) > player_elo + HARD_ELO_GAP:
		var softer := _easiest_in_tier(allowed, int(pick.get("tier", 1)))
		if float(softer.get("elo", 0.0)) < float(pick.get("elo", 0.0)) - 0.0001:
			pick = softer
			reason = "hard_capped"
	return {"level_id": str(pick.get("id", "")), "reason": reason}


## «آیا کاندید به رتبه‌ی بازیکن نزدیک‌تر است؟» — همان معیار §۴.۴ (نزدیک‌ترین Elo).
static func _closer(candidate: Dictionary, current: Dictionary, player_elo: float) -> bool:
	return absf(float(candidate.get("elo", 0.0)) - player_elo) \
		< absf(float(current.get("elo", 0.0)) - player_elo)


static func _filter_tier_lock(candidates: Array[Dictionary], max_tier: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in candidates:
		if int(c.get("tier", 1)) <= max_tier:
			out.append(c)
	return out


## ساده‌ترین سطحی که بازیکن **قبلاً** تمام کرده (کاندیدِ بازمانده‌ای ساده‌تر از نردبان
## نیست، چون validator صعودی‌بودن Elo درون Tier را اجبار می‌کند).
static func _easiest_completed_in_tier(candidates: Array[Dictionary], tier: int) -> Dictionary:
	var best: Dictionary = {}
	for c: Dictionary in candidates:
		if int(c.get("tier", 1)) != tier or not bool(c.get("completed", false)):
			continue
		if best.is_empty() or float(c.get("elo", 0.0)) < float(best.get("elo", 0.0)):
			best = c
	return best


static func _easiest_in_tier(candidates: Array[Dictionary], tier: int) -> Dictionary:
	var best: Dictionary = {}
	for c: Dictionary in candidates:
		if int(c.get("tier", 1)) != tier:
			continue
		# `<` (نه `<=`): در تساویِ Elo، اولین سطحِ نردبان می‌ماند → ترتیب نویسنده حفظ است
		if best.is_empty() or float(c.get("elo", 0.0)) < float(best.get("elo", 0.0)):
			best = c
	return best if not best.is_empty() else candidates[0]


# --------------------------------------------------------------------------
# به‌روزرسانی رتبه (فراخوانِ مستقیم از LevelController — ADR-038)
# --------------------------------------------------------------------------
## {score, elo_delta, player_elo, skill_keys, difficulty_elo}
func apply_level_result(config: Dictionary, did_succeed: bool) -> Dictionary:
	var hints: int = int(GameState.hints_used_this_level)
	var attempts: int = int(GameState.level_attempts)
	var score: float = ErrorClassifier.success_score(hints, attempts)
	var difficulty: float = float(config.get("difficulty_elo", SkillRating.ELO_START))
	var tags := tags_of(config)
	var model: PlayerModel = GameState.active_model
	var before: float = model.average_skill_elo(tags) if model != null else SkillRating.ELO_START
	var total_delta: float = 0.0
	if model != null:
		for tag: String in tags:
			var rating := model.ensure_skill(tag)
			# وزن‌دهی فقط برای بُرد معنا دارد؛ باخت همان ۰.۰ است (§۳ سند داده‌ها)
			total_delta += rating.apply_result(difficulty, did_succeed, score if did_succeed else -1.0)
		if did_succeed and hints == 0:
			_no_hint_streak += 1
		else:
			_no_hint_streak = 0
		SaveSystem.request_save()
	var mean_delta: float = total_delta / float(maxi(1, tags.size()))
	_results.append({
		"level_id": str(config.get("level_id", "")),
		"served_hard": did_succeed and difficulty > before + HARD_ELO_GAP,
		"score": score,
		"elo_delta": mean_delta,
	})
	while _results.size() > HARD_WINDOW * 4:
		_results.pop_front()
	return {
		"score": score,
		"elo_delta": mean_delta,
		"player_elo": model.average_skill_elo(tags) if model != null else SkillRating.ELO_START,
		"skill_keys": Array(tags),
		"difficulty_elo": difficulty,
	}


## وضعیت انباشته (برای تست و داشبورد والدین در فاز ۶)
func no_hint_streak() -> int:
	return _no_hint_streak


func history_size() -> int:
	return _history.size()


func last_reason() -> String:
	if _history.is_empty():
		return ""
	return str((_history[_history.size() - 1] as Dictionary).get("reason", ""))


## §۴.۴: «سطح بعدی بر اساس نزدیک‌ترین Elo، نه ترتیب خطی فایل‌ها» — با kill-switch
func is_adaptive() -> bool:
	return adaptive_selection


## برای تست: شمارنده‌ها و نتیجه‌های اخیر
func results_size() -> int:
	return _results.size()


func used_remediation() -> bool:
	return _remediation_used


func was_last_served_hard() -> bool:
	if _results.is_empty():
		return false
	return bool((_results[_results.size() - 1] as Dictionary).get("served_hard", false))


func reset_state() -> void:
	_history.clear()
	_results.clear()
	_no_hint_streak = 0
	_remediation_used = false
