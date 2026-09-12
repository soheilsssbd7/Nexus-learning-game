#!/usr/bin/env python3
"""
NEXUS — validate_levels.py
==========================
اعتبارسنج خودکار داده‌های محتوا (سطح‌ها + قالب‌های دیالوگ Aria) در برابر
`docs/03-DATA-SCHEMAS.md` (§1 سطح، §4 دیالوگ).

منطق بازی را دوباره پیاده‌سازی **نمی‌کند**؛ فقط داده را می‌سنجد و ثابت می‌کند هر سطح
قابل‌حل است. تنها راه‌حلِ ممکنِ «قابل‌حل بودن» این است که داده را با DP زیرمجموعه
بررسی کنیم، چون DoD فاز ۳/۷ («همه‌ی سطوح قابل‌حل‌اند») با پلی‌تست دستی تضمین‌پذیر نیست.

بررسی‌ها:
  ۱. ساختار/مقادیر مجاز طبق اسکیمای §1 و §4
  ۲. سازگاری حسابی: مجموع چپ == target_value + وزن‌های ثابت راست (وقتی tolerance=0)
  ۳. قابل‌حل بودن: وجود زیرمجموعه‌ای از available_orbs که کفه‌ی راست را به حد تعادل برساند
  ۴. ارجاع‌ها: هر hint_id موجود، هر trigger با الگوی مجاز، هر level_id یکتا و هم‌نام فایل
  ۵. منحنی دشواری Tier: افزایشی و بدون پرش (>۱۲۰ Elo)
  ۶. «قانون طلایی» (§4): هیچ متن راهنمایی که به یک سطح وصل شده، عدد جوابِ همان
     سطح را فاش نکند (target / مجموع چپ / hidden_value کره‌ی روح)

اجرا:
    python3 tools/validate_levels.py                # کل game/data
    python3 tools/validate_levels.py --json report.json

خروج: ۰ سالم، ۱ خطای محتوایی (CI را fail می‌کند).
"""

from __future__ import annotations

import argparse
import itertools
import json
import re
import sys
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "game" / "data"
LEVELS_DIR = DATA / "levels"
DIALOGUE_FILE = DATA / "dialogue" / "aria_templates.json"
NARRATIVE_FILE = DATA / "narrative" / "story_beats.json"
AUDIO_MANIFEST = DATA / "audio" / "audio_assets.json"
GAME = ROOT / "game"
ASSETS = GAME / "assets"

ALLOWED_ORB_TYPES = {"number", "ghost", "negative"}
ALLOWED_WORLDS = {"balance_realm"}
# مفهوم‌های مجاز (گسترش‌دادنی با سند GDD؛ هر مقدار تازه باید اینجا ثبت شود تا
# در PlayerModel.skills هم معنی‌دار باشد — تسک ۴.۴).
ALLOWED_CONCEPTS = {
    # کلیدهای مهارتِ docs/07 §۴ (معیار خروج Tier) — همان‌ها که در PlayerModel.skills
    # می‌نشینند، پس اسمشان در داده و در GDD یکی است (docs/06 ADR-039).
    "addition_basic", "subtraction_negative",
    "addition", "concrete_numbers", "subtraction", "negative_numbers", "debt",
    "unknown_variable", "ghost_algebra", "two_dimensional", "system_balance",
    "word_problem", "multi_step", "fractions", "balance_both_sides", "equality",
}
TRIGGER_RE = re.compile(r"^(idle_\d+s|fail_\d+x|help_requested|first_wrong_attempt)$")
LEVEL_ID_RE = re.compile(r"^tier[1-5]_level_\d{2}$")
ELO_JUMP_LIMIT = 120
MAX_HINT_LEN = 220
MIN_HINT_TEMPLATES = 15
ERROR_TYPES_ALL = {"wrong_operation", "sign_flip_on_subtraction", "forgets_both_sides",
                     "computation_error", "idle"}
MAX_DP_WIDTH = 400_000  # گام‌های ۱/۱۰۰ واحد؛ بزرگ‌تر از این = بررسی دستی


def cents(x) -> int:
    """عدد اسکیمای داده (ممکن است اعشاری باشد) → عدد صحیح «سَنت» تا DP دقیق بماند."""
    try:
        return int((Decimal(str(x)) * 100).to_integral_value())
    except Exception:
        return 0


def load_json(path: Path, errs: list[str] | None = None):
    try:
        with path.open(encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        if errs is not None:
            errs.append(f"{path}: فایل یافت نشد")
    except json.JSONDecodeError as e:
        if errs is not None:
            errs.append(f"{path}: JSON نامعتبر — {e}")
    return None


def orb_weight(orb: dict) -> int:
    """وزن یک کره به واحد داده (سَنت). ghost از hidden_value، negative با علامت منفی (§1)."""
    if orb.get("type") == "ghost":
        return cents(orb.get("hidden_value", 0))
    sign = -1 if orb.get("type") == "negative" else 1
    return sign * cents(orb.get("value", 0))


def side_total(orbs: list) -> int:
    return sum(orb_weight(o) for o in orbs if isinstance(o, dict))


def reachable_sums(available: list, need_cents: int, tol_cents: int):
    """
    DP چندسکه‌ای با بیت‌مپ: آیا زیرمجموعه‌ای از available_orbs مجموعش را به
    [need-tol, need+tol] می‌رساند؟  بازگرداندن True/False/None(نتیجه‌ی نامعلوم)
    """
    pos = neg = 0
    items: list[tuple[int, int]] = []
    for orb in available:
        if not isinstance(orb, dict):
            continue
        w = orb_weight(orb)
        count = int(orb.get("count", 1) or 0)
        if count <= 0 or w == 0:
            continue
        items.append((w, count))
        if w > 0:
            pos += w * count
        else:
            neg += w * count  # منفی

    lo, hi = need_cents - tol_cents, need_cents + tol_cents
    width = pos - neg
    if width <= 0:
        return lo <= 0 <= hi
    if width > MAX_DP_WIDTH:
        return None

    base = -neg  # شاخص ۰ ⇔ مجموع = neg
    bits = 1 << base  # مجموعه‌ی خالی
    for w, count in items:
        shift = abs(w)
        for _ in range(count):
            bits |= (bits << shift) if w > 0 else (bits >> shift)
        limit = 1 << (width + 1)
        bits &= limit - 1

    for s in range(max(0, lo - neg), min(width, hi - neg) + 1):
        if (bits >> (base + s)) & 1:
            return True
    return False


# --------------------------------------------------------------------------- #
# دیالوگ (§4)
# --------------------------------------------------------------------------- #
def load_hints(errs: list[str]) -> dict[str, dict]:
    if not DIALOGUE_FILE.exists():
        return {}
    data = load_json(DIALOGUE_FILE, errs) or {}
    out: dict[str, dict] = {}
    hints = data.get("hints")
    if not isinstance(hints, list) or not hints:
        errs.append(f"aria_templates.json: `hints` خالی یا غایب است (§4)")
        return out

    allowed_err = {"wrong_operation", "sign_flip_on_subtraction", "forgets_both_sides",
                   "computation_error", "idle", "timeout", "help_requested"}
    for i, h in enumerate(hints):
        if not isinstance(h, dict) or not isinstance(h.get("hint_id"), str):
            errs.append(f"aria_templates.json: hints[{i}] باید object با hint_id باشد")
            continue
        hid = h["hint_id"]
        if hid in out:
            errs.append(f"aria_templates.json: hint_id تکراری `{hid}`")
        out[hid] = h

        ets = h.get("applies_to_error_types")
        if not isinstance(ets, list) or not ets:
            errs.append(f"{hid}: applies_to_error_types خالی است")
        else:
            bad = [e for e in ets if e not in allowed_err]
            if bad:
                errs.append(f"{hid}: error_type ناشناخته {bad}")

        mn, mx = h.get("min_tier"), h.get("max_tier")
        if not (isinstance(mn, int) and isinstance(mx, int) and 1 <= mn <= mx <= 5):
            errs.append(f"{hid}: min_tier/max_tier باید ۱..۵ و mn<=mx باشند")

        variants = h.get("text_variants")
        if not isinstance(variants, list) or len(variants) < 2:
            errs.append(f"{hid}: حداقل ۲ text_variant لازم است (تسک ۵.۲)")
            continue
        for j, t in enumerate(variants):
            if not isinstance(t, str) or not t.strip():
                errs.append(f"{hid}: text_variants[{j}] خالی است")
            elif len(t) > MAX_HINT_LEN:
                errs.append(f"{hid}: text_variants[{j}] بیش از {MAX_HINT_LEN} نویسه (ریسک سرریز DialogueBox — تسک ۵.۵)")
    # تسک ۵.۲ (DoD): «حداقل ۱۵ hint_id برای پوشش تمام ترکیب‌های error_type × tier ۱-۲»
    if len(out) < MIN_HINT_TEMPLATES:
        errs.append(f"aria_templates.json: {len(out)} قالب هست ولی حداقل {MIN_HINT_TEMPLATES} لازم است (§4/تسک ۵.۲)")
    covered = set()
    for h in out.values():
        ets = h.get("applies_to_error_types") or []
        mn = h.get("min_tier") if isinstance(h.get("min_tier"), int) else 9
        mx = h.get("max_tier") if isinstance(h.get("max_tier"), int) else 0
        if mn <= 2 and mx >= 1:  # پوشش tier ۱ یا ۲
            covered.update(ets)
    missing = sorted(ERROR_TYPES_ALL - covered)
    if missing:
        errs.append(f"aria_templates.json: این نوع خطا برای Tier ۱-۲ هیچ قالبی ندارد: {missing}")
    return out


def digits_in(text: str) -> set[str]:
    fa = str.maketrans("۰۱۲۳۴۵۶۷۸۹", "0123456789")
    return {tok for tok in re.split(r"[^0-9.]+", text.translate(fa)) if tok}


def fmt(n) -> str:
    """نمایش عددی که در متن فارسی هم عیناً همان‌طور نوشته می‌شود (۸ و 8، نه 8.0)."""
    f = float(n)
    return str(int(f)) if f.is_integer() else ("%g" % f)


def check_answer_leaks(levels: list[dict], hints: dict[str, dict], errs: list[str]) -> None:
    """قانون طلایی (§4): راهنمای وصل‌شده به یک سطح، عدد جواب همان سطح را نگوید."""
    if not hints:
        return
    for lv in levels:
        forbidden = {fmt(n) for n in lv["leak_numbers"]}
        forbidden |= {f.translate(str.maketrans("0123456789", "۰۱۲۳۴۵۶۷۸۹")) for f in forbidden}
        forbidden.discard("")
        forbidden -= {"0"}
        if not forbidden:
            continue
        for trig in lv.get("hint_ids", []):
            hint = hints.get(trig)
            if not hint:
                continue
            for t in hint.get("text_variants") or []:
                if not isinstance(t, str):
                    continue
                hits = digits_in(t) & forbidden
                if hits:
                    errs.append(f"{lv['file']}: قانون طلایی نقض شد — راهنمای `{trig}` عدد {sorted(hits)} را "
                                f"صراحتاً می‌گوید (جواب‌های ممنوع: {sorted(forbidden)})")


# --------------------------------------------------------------------------- #
# سطح (§1)
# --------------------------------------------------------------------------- #
def validate_level(path: Path, errs: list[str], hints: dict[str, dict]) -> dict:
    rel = path.relative_to(ROOT).as_posix()
    raw = load_json(path, errs)
    meta = {"file": rel, "level_id": None, "tier": None, "difficulty_elo": None,
            "solvable": False, "leak_numbers": [], "hint_ids": [], "concept_tags": [],
            "intro": None}
    if not isinstance(raw, dict):
        return meta

    for field in ("level_id", "tier", "world", "concept_tags", "narrative_intro",
                  "left_side", "right_side", "tolerance", "hint_sequence",
                  "expected_solve_time_sec", "difficulty_elo"):
        if field not in raw:
            errs.append(f"{rel}: فیلد لازم `{field}` غایب است (§1)")

    lid = raw.get("level_id")
    meta["level_id"] = lid
    if not isinstance(lid, str) or not LEVEL_ID_RE.match(lid):
        errs.append(f"{rel}: level_id باید الگوی `tier<N>_level_<NN>` بگیرد (نمونه tier1_level_01)")
    tail = re.findall(r"\d+", path.stem)
    if isinstance(lid, str) and tail and tail[-1].lstrip("0") and tail[-1].lstrip("0") not in lid:
        errs.append(f"{rel}: شماره‌ی نام فایل ({path.stem}) با level_id ({lid}) نمی‌خواند")

    tier = raw.get("tier")
    meta["tier"] = tier if isinstance(tier, int) else None
    if not isinstance(tier, int) or not 1 <= tier <= 5:
        errs.append(f"{rel}: tier باید int بین ۱..۵ باشد")
    if raw.get("world") not in ALLOWED_WORLDS:
        errs.append(f"{rel}: world باید {sorted(ALLOWED_WORLDS)} باشد")

    tags = raw.get("concept_tags")
    if isinstance(tags, list):
        meta["concept_tags"] = [x for x in tags if isinstance(x, str)]
    if not isinstance(tags, list) or not tags:
        errs.append(f"{rel}: concept_tags باید آرایه‌ی غیرخالی باشد")
    else:
        unknown = [t for t in tags if t not in ALLOWED_CONCEPTS]
        if unknown:
            errs.append(f"{rel}: concept_tag ثبت‌نشده {unknown} — اگر مفهوم تازه است، این اسکریپت و سند داده‌ها را به‌روز کن")

    intro = raw.get("narrative_intro")
    if not isinstance(intro, str) or len(intro.strip()) < 10:
        errs.append(f"{rel}: narrative_intro کوتاه/خالی است (تسک ۷.x: هر سطح یک بیت روایی منحصربه‌فرد)")
    else:
        meta["intro"] = intro.strip()

    # حلِ قصدمند باید **همان** چیزی باشد که داده طلب کرده، و «اشتباهِ آموزشی» نباید ببرد ✗
    spec = raw.get("solution_spec") if isinstance(raw.get("solution_spec"), dict) else {}
    intended = spec.get("intended") if isinstance(spec.get("intended"), dict) else {}
    if isinstance(intended.get("right_orbs"), list) and intended["right_orbs"]:
        meta["intended_sum"] = sum(_row_values(intended["right_orbs"], errs, f"{rel}: solution_spec.intended.right_orbs"))
    wrong = spec.get("wrong_ops") if isinstance(spec.get("wrong_ops"), dict) else {}
    if isinstance(wrong.get("right_orbs"), list) and wrong["right_orbs"]:
        meta["wrong_orbs"] = _row_values(wrong["right_orbs"], errs, f"{rel}: solution_spec.wrong_ops.right_orbs")
        meta["wrong_sum"] = sum(meta["wrong_orbs"])

    tol = raw.get("tolerance")
    if not isinstance(tol, (int, float)) or tol < 0:
        errs.append(f"{rel}: tolerance باید عدد ≥ 0 باشد")
    est = raw.get("expected_solve_time_sec")
    if not isinstance(est, (int, float)) or not 5 <= est <= 600:
        errs.append(f"{rel}: expected_solve_time_sec باید بین ۵ تا ۶۰۰ ثانیه باشد")
    elo = raw.get("difficulty_elo")
    meta["difficulty_elo"] = elo if isinstance(elo, (int, float)) else None
    if not isinstance(elo, (int, float)) or not 400 <= elo <= 2000:
        errs.append(f"{rel}: difficulty_elo باید در بازه‌ی ۴۰۰..۲۰۰۰ باشد (§3)")

    left = raw.get("left_side") if isinstance(raw.get("left_side"), dict) else {}
    right = raw.get("right_side") if isinstance(raw.get("right_side"), dict) else {}
    for side_name, side in (("left_side", left), ("right_side", right)):
        for key in ("fixed_orbs", "ghost_orbs", "available_orbs"):
            orbs = side.get(key, [])
            if orbs and not isinstance(orbs, list):
                errs.append(f"{rel}: {side_name}.{key} باید array باشد")
                continue
            for i, o in enumerate(orbs if isinstance(orbs, list) else []):
                if not isinstance(o, dict):
                    errs.append(f"{rel}: {side_name}.{key}[{i}] باید object باشد")
                    continue
                if o.get("type") not in ALLOWED_ORB_TYPES:
                    errs.append(f"{rel}: {side_name}.{key}[{i}] type نامعتبر `{o.get('type')}`")
                if o.get("type") == "ghost" and key != "ghost_orbs":
                    # ADR-028: شبح **فقط** در `*_ghost_orbs`؛ اگر در `fixed_orbs` بیاید،
                    # موتور او را یک‌بار به‌عنوان کرهٔ عددی و یک‌بار به‌عنوان شبح می‌گذارد
                    # ⇒ وزنِ دوبل ✗✓ (سطح عملاً غیرقابل‌حل می‌شود و فقط باتِ GUT می‌گیردش)
                    errs.append(f"{rel}: {side_name}.{key}[{i}] کره‌ی شبح است؛ باید در "
                                f"`ghost_orbs` باشد نه `{key}` (وزنِ دوبل ✗ ADR-028)")
                if o.get("type") != "ghost" and key == "ghost_orbs":
                    # برعکسِ همان دام: عددِ معمولی در `ghost_orbs` یعنی موتور `hidden_value`
                    # ندارد ⇒ وزن صفر ✗✓ «تراز» در موتور با داده نمی‌خواند.
                    errs.append(f"{rel}: {side_name}.ghost_orbs[{i}] باید `type: ghost` باشد "
                                f"(وگرنه وزنش صفر حساب می‌شود ✗)")
                if o.get("type") == "ghost":
                    if tier is not None and isinstance(tier, int) and tier < 3:
                        errs.append(f"{rel}: ghost_orbs فقط برای Tier 3+ (§1)")
                    if not isinstance(o.get("hidden_value"), (int, float)):
                        errs.append(f"{rel}: {side_name}.{key}[{i}] کره‌ی روح باید hidden_value عددی داشته باشد")
                elif not isinstance(o.get("value"), (int, float)):
                    errs.append(f"{rel}: {side_name}.{key}[{i}] باید value عددی داشته باشد")
                if key == "available_orbs" and o.get("type") == "ghost":
                    errs.append(f"{rel}: کره‌ی روح نباید در available_orbs باشد (مجهول قابل‌انتخاب نیست)")

    left_total = side_total(list(left.get("fixed_orbs") or []) + list(left.get("ghost_orbs") or []))
    right_fixed = side_total(list(right.get("fixed_orbs") or []) + list(right.get("ghost_orbs") or []))
    available = list(right.get("available_orbs") or [])
    target = right.get("target_value")

    meta["leak_numbers"] = sorted({abs(left_total) / 100, abs(target) / 100 if isinstance(target, (int, float)) else 0} - {0.0})
    hidden = [cents(o.get("hidden_value", 0)) / 100 for o in list(left.get("ghost_orbs") or []) + list(right.get("ghost_orbs") or [])
              if isinstance(o, dict)]
    meta["leak_numbers"] = sorted(set(meta["leak_numbers"] + [h for h in hidden if h]))

    scales_raw = raw.get("scales")
    if isinstance(scales_raw, list) and scales_raw:
        check_multi_scale(raw, scales_raw, rel, tier, tol, meta, errs)
    elif isinstance(target, (int, float)) and isinstance(tol, (int, float)):
        if cents(tol) == 0 and left_total != cents(target) + right_fixed:
            errs.append(f"{rel}: ناسازگاری — مجموع چپ {left_total/100:g} ≠ target {cents(target)/100:g} + ثابتِ راست {right_fixed/100:g}")
        need = left_total - right_fixed
        got = reachable_sums(available, need, cents(tol))
        if got is False:
            errs.append(f"{rel}: غیرقابل‌حل — هیچ ترکیبی از available_orbs کفه‌ی راست را به {need/100:g} (±{cents(tol)/100:g}) نمی‌رساند")
        meta["solvable"] = bool(got)
        if got is None:
            errs.append(f"{rel}: دامنه‌ی DP بزرگ است — قابل‌حل‌بودن دستی بررسی شود")
    elif right.get("ghost_orbs"):
        meta["solvable"] = True  # سطح «کشف مجهول»: معادله با hidden_valueها بسته است و هدف از تعادل می‌آید
    else:
        errs.append(f"{rel}: right_side باید target_value (یا ghost_orbs) داشته باشد")

    single = not (isinstance(scales_raw, list) and scales_raw)
    if single and "intended_sum" in meta and isinstance(target, (int, float)) and isinstance(tol, (int, float)):
        if abs(meta["intended_sum"] - cents(target) / 100) > cents(tol) / 100 + 1e-9:
            errs.append(f"{rel}: `solution_spec.intended.right_orbs` مجموعش {meta['intended_sum']:g} ≠ "
                        f"نیاز کفه‌ی راست {cents(target)/100:g} ⇒ حلِ قصدمند در موتور می‌بازد")
    if single and "wrong_orbs" in meta and isinstance(target, (int, float)) and isinstance(tol, (int, float)):
        need = cents(target) / 100.0
        lim = cents(tol) / 100.0 + 1e-9
        orbs = meta["wrong_orbs"]
        # «اشتباهِ آموزشی» باید در **هر ترتیبی** ببازد ✗✓ اگر فقط *مجموعش* را چک کنیم،
        # [5,5,2,-2] (یعنی حلِ درست + یک کره) سبز می‌شود درحالی‌که کودک با سه تای اول
        # برده است — همین دام، دو سطح از Tier ۲ را در باتِ GUT قرمز کرد ✓
        for size in range(1, len(orbs) + 1):
            bad = [c for c in itertools.combinations(orbs, size) if abs(sum(c) - need) <= lim]
            if bad:
                errs.append(f"{rel}: زیرمجموعه‌ی {list(bad[0])} از `wrong_ops.right_orbs` هم "
                            f"تراز می‌کند ⇒ آن حرکت «اشتباه» نیست و سطح بی‌آموزش شده")
                break

    seq = raw.get("hint_sequence")
    if not isinstance(seq, list) or not seq:
        errs.append(f"{rel}: hint_sequence خالی است — هر سطح دست‌کم یک تریگر راهنما لازم دارد")
    else:
        for i, h in enumerate(seq):
            loc = f"{rel}: hint_sequence[{i}]"
            if not isinstance(h, dict):
                errs.append(f"{loc}: باید object باشد")
                continue
            trig, hid = h.get("trigger"), h.get("hint_id")
            if not isinstance(trig, str) or not TRIGGER_RE.match(trig):
                errs.append(f"{loc}: trigger `{trig}` نامعتبر (مجاز: idle_<n>s | fail_<n>x | help_requested | first_wrong_attempt)")
            if not isinstance(hid, str) or not hid:
                errs.append(f"{loc}: hint_id لازم است")
            else:
                meta["hint_ids"].append(hid)
                if hints and hid not in hints:
                    errs.append(f"{loc}: hint_id `{hid}` در aria_templates.json تعریف نشده")
                elif hints:
                    # قاعدهٔ تازه (تسک ۷.۰): راهنمایی که بازه‌ی Tierش این سطح را پوشش
                    # نمی‌دهد، **نوشته می‌شود ولی هرگز به کودک نمی‌رسد** (فیلتر
                    # `DialogueTemplate` بر پایه‌ی tier کار می‌کند) ⇒ داده‌ی مرده ✗
                    hint = hints[hid]
                    mn = hint.get("min_tier") if isinstance(hint.get("min_tier"), int) else 1
                    mx = hint.get("max_tier") if isinstance(hint.get("max_tier"), int) else 5
                    if isinstance(tier, int) and not (mn <= tier <= mx):
                        errs.append(f"{loc}: قالب `{hid}` برای Tier {tier} فعال نیست "
                                    f"(بازه‌ی خودش {mn}..{mx}) ⇒ راهنما هیچ‌وقت نمایش داده نمی‌شود")
    return meta


def check_concept_labels(metas: list[dict], key_sets: dict[str, list[str]], errs: list[str]) -> None:
    """§۶.۵: نمودار تسلط داشبورد، مهارت‌ها را با `Loc.t("skill.<tag>")` نشان می‌دهد.

    اگر برچسبی برای یک `concept_tag` تازه تعریف نشده باشد، والد «addition_basic»
    می‌بیند؛ قانون: هر tag در **همهٔ** localeها باید `skill.<tag>` داشته باشد.
    (فقط وقتی فایل رشته‌ها موجود باشد سنجیده می‌شود — فاز ۰..۵ بی‌مصرف نمی‌شود.)
    """
    if not key_sets:
        return
    for m in metas:
        for tag in m.get("concept_tags", []):
            for code, keys in sorted(key_sets.items()):
                if f"skill.{tag}" not in keys:
                    errs.append(f"{m['file']}: برچسب والدین `skill.{tag}` در زبان "
                                f"«{code}» تعریف نشده (§۶.۵)")


def _row_values(raw_list, errs: list[str] | None = None, loc: str = "") -> list[float]:
    """`solution_spec.*.right_orbs` دو شکل دارد: عدد (تک‌کفه) یا `{"value","scale"}`
    (چندکفه ✓ ADR-055) ⇒ هر دو به فهرستِ عددی تبدیل می‌شوند تا هیچ شاخه‌ای در
    چک‌های بعدی «نیمه‌کامل» نماند ✗✓."""
    out: list[float] = []
    if not isinstance(raw_list, list):
        return out
    for i, x in enumerate(raw_list):
        if isinstance(x, dict):
            v = x.get("value", 0)
            if not isinstance(v, (int, float)):
                out.append(0.0)
                continue
            v = float(v)
            # `type` در ورودیِ `solution_spec` الزامی نبود؛ ولی اگر آمد، **علامت باید
            # معنای موتور را بدهد** ✗✓ (NegativeOrb در موتور `‎-abs(value)` است و ابزار
            # بی‌علامت، «۴+۳٫۵ = ۷٫۵» را با نیاز ۷٫۵ می‌سنجید ⇒ حلِ دروغین سبز ✗)
            if x.get("type") == "negative":
                v = -abs(v)
            elif x.get("type") == "ghost":
                # شبح هیچ‌وقت چیده نمی‌شود (در `*_ghost_orbsِ` کفه می‌نشیند) ⇒ دیدنش در
                # `solution_spec` یعنی داده «ضربدرِ» دو مدل را نوشته ✗✓ صفر نمی‌گذاریم که
                # مجموع تصادفی درست نشود؛ صریح خطا می‌دهیم.
                if errs is not None:
                    errs.append(f"{loc}[{i}] کره‌ی شبح در `solution_spec` معنا ندارد "
                                f"(چیده نمی‌شود ✗ ADR-028)")
                continue
            out.append(v)
        elif isinstance(x, (int, float)):
            out.append(float(x))
    return out


def _orb_rows(entries, rel: str, key: str, tier, errs: list[str]) -> list[dict]:
    """همان قوانین کره‌ها (نوع/`value`/`hidden_value`/ghost) ولی برای `scales[i]` ✓"""
    out: list[dict] = []
    if entries is None:
        return out
    if not isinstance(entries, list):
        errs.append(f"{rel}.{key} باید array باشد")
        return out
    for i, o in enumerate(entries):
        if not isinstance(o, dict):
            errs.append(f"{rel}.{key}[{i}] باید object باشد")
            continue
        if o.get("type") not in ALLOWED_ORB_TYPES:
            errs.append(f"{rel}.{key}[{i}] type نامعتبر `{o.get('type')}`")
            continue
        if o.get("type") == "ghost" and not key.endswith("ghost_orbs"):
            # همان قاعدهٔ ADR-028 که برای `left_side/right_side` گذاشتیم: در چندکفه هم
            # شبح فقط در `left_ghost_orbs`/`right_ghost_orbs` ✓✓ (یک‌جایِ قانونیِ واحد ⇒
            # هیچ‌وقت وزنِ دوبل یا صفر نمی‌شود ✗)
            errs.append(f"{rel}.{key}[{i}] کره‌ی شبح است؛ باید در `*_ghost_orbs` باشد "
                        f"(وزنِ دوبل ✗ ADR-028)")
        if o.get("type") != "ghost" and key.endswith("ghost_orbs"):
            errs.append(f"{rel}.{key}[{i}] در `*_ghost_orbs` باید `type: ghost` باشد "
                        f"(وگرنه موتور `hidden_value` ندارد ⇒ وزن صفر ✗)")
        if o.get("type") == "ghost":
            if isinstance(tier, int) and tier < 3:
                errs.append(f"{rel}.{key}[{i}] ghost_orbs فقط برای Tier 3+ (§۱)")
            if not isinstance(o.get("hidden_value"), (int, float)):
                errs.append(f"{rel}.{key}[{i}] کره‌ی روح باید hidden_value عددی داشته باشد")
        elif not isinstance(o.get("value"), (int, float)):
            errs.append(f"{rel}.{key}[{i}] باید value عددی داشته باشد")
        out.append(o)
    return out


def check_multi_scale(raw: dict, scales: list, rel: str, tier, tol, meta: dict, errs: list[str]) -> None:
    """سطحِ چندکفه (آرک‌تایپ «Twin Observatory» — تسک ۷.۳، ADR-055).

    سینی **مشترک** است ⇒ «قابل‌حل» یعنی *تقسیمِ* کره‌ها بین کفه‌ها، و DPِ تک‌کفه‌ای اینجا
    معنا ندارد ✗✓ (اگر آن را طوری گسترش دهیم که ۲^k حالت را بشمارد، با ۴۰ کره منفجر
    می‌شود ⇒ `MAX_DP_WIDTH` برای همین هست). پس ادعا را دو لایه می‌سنجیم:
      ۱) این ابزار: هر کفه با `target_value` خودش می‌خواند، حلِ قصدمندِ نوشته‌شده **هر
         کفه را جدا** تراز می‌کند، ظرفیت سینی جواب می‌دهد، و هیچ زیرمجموعه‌ای از
         `wrong_ops`ِ همان کفه تراز نمی‌کند ✓
      ۲) باتِ GUT: همان چیدمان در موتورِ واقعی **بَرَد** ✓✓ (لایهٔ دوم قوی‌تر از DPِ روی
         کاغذ است: علامتِ NegativeOrb، وزنِ GhostOrb و `is_balanced()` موتور را هم می‌بیند).
    """
    if isinstance(raw.get("right_side"), dict) and raw["right_side"].get("target_value") is not None:
        errs.append(f"{rel}: سطحِ چندکفه نباید `right_side.target_value` سطحی داشته باشد "
                    f"— نیاز در هر `scales[i].target_value` نوشته می‌شود (ادعای دوگانه ✗)")

    caps: dict[int, int] = {}
    for o in (raw.get("right_side") or {}).get("available_orbs") or []:
        if isinstance(o, dict) and o.get("type") in ALLOWED_ORB_TYPES and o.get("type") != "ghost":
            caps[orb_weight(o)] = caps.get(orb_weight(o), 0) + int(o.get("count", 1) or 1)
    tray_total = sum(caps.values())

    needs: list[int] = []
    for i, sc in enumerate(scales):
        loc = f"{rel}: scales[{i}]"
        if not isinstance(sc, dict):
            errs.append(f"{loc} باید object باشد")
            needs.append(0)
            continue
        left = _orb_rows(sc.get("left_orbs"), loc, "left_orbs", tier, errs) + \
            _orb_rows(sc.get("left_ghost_orbs"), loc, "left_ghost_orbs", tier, errs)
        right = _orb_rows(sc.get("right_orbs"), loc, "right_orbs", tier, errs) + \
            _orb_rows(sc.get("right_ghost_orbs"), loc, "right_ghost_orbs", tier, errs)
        if not left and not right:
            errs.append(f"{loc}: هر دو کفه خالی است — کفه‌ی بی‌بار معنای آموزشی ندارد")
        need = side_total(left) - side_total(right)
        needs.append(need)
        tv = sc.get("target_value")
        if tv is None:
            errs.append(f"{loc}: `target_value` لازم است (در چندکفه، هر کفه نیازِ خودش را دارد)")
        elif isinstance(tv, (int, float)) and cents(tol) == 0 and cents(tv) != need:
            errs.append(f"{loc}: نیاز کفه {need/100:g} ≠ target_value {cents(tv)/100:g}")
        for o in left + right:
            if isinstance(o, dict) and o.get("type") == "ghost":
                hv = cents(o.get("hidden_value", 0))
                if hv:
                    meta["leak_numbers"].append(abs(hv) / 100)
        meta["leak_numbers"] = sorted({*meta.get("leak_numbers", []), abs(need) / 100})

    # ظرفیت سینی برای هر دو لیستِ حل/اشتباه (هر کفه جدا) ✓
    spec = raw.get("solution_spec") if isinstance(raw.get("solution_spec"), dict) else {}
    for name in ("intended", "wrong_ops"):
        part = spec.get(name) if isinstance(spec.get(name), dict) else {}
        rows = part.get("right_orbs")
        if not isinstance(rows, list) or not rows:
            continue
        per_scale: dict[int, list[float]] = {}
        used: dict[int, int] = {}
        for r in rows:
            if not isinstance(r, dict) or r.get("value") is None:
                # «بی‌scale» در چندکفه یعنی هر دو کفه با یک عدد ببندند ✗✓ همان
                # «مجموعِ کل = ادعای دروغین» که ADR-055 رد می‌کند ⇒ صریح ممنوع.
                errs.append(f"{rel}: `solution_spec.{name}.right_orbs` در سطحِ چندکفه باید "
                            f"object با `value` و `scale` باشد (این: {r!r})")
                return
            val = float(r.get("value", 0))
            sc_i = int(r.get("scale", 0) or 0)
            if sc_i < 0 or sc_i >= len(scales):
                # `place_on_right(…, scale_index)` در موتور فقط کرانِ بالا را چک می‌کند ✗
                # ⇒ ایندکسِ منفی یعنی `scales[-1]` و خطای زمان‌اجرا روی داده ✗✓ اینجا بسته می‌شود.
                errs.append(f"{rel}: `scale` {sc_i} خارج از تعداد کفه‌ها ({len(scales)}) است")
                return
            per_scale.setdefault(sc_i, []).append(val)
            # وزنِ کره با همان قاعده‌ی موتور: negative یعنی ‎-abs(value) ✓ (ADR-028)
            key = orb_weight({"type": "negative" if val < 0 else "number", "value": abs(val)})
            used[key] = used.get(key, 0) + 1
        for v, c in used.items():
            if caps.get(v, 0) < c:
                errs.append(f"{rel}: `solution_spec.{name}` به {c} کره با وزن {v/100:g} نیاز دارد "
                            f"ولی سینی {caps.get(v, 0)} تا دارد ⇒ حلِ نوشته‌شده چیده نمی‌شود ✗")
        if name == "intended":
            ok = True
            for sc_i, vals in per_scale.items():
                if sc_i >= len(needs):
                    errs.append(f"{rel}: `scale` {sc_i} در intended وجود ندارد")
                    continue
                if abs(sum(vals) * 100 - needs[sc_i]) > cents(tol):
                    ok = False
                    errs.append(f"{rel}: intendedِ کفه {sc_i} مجموعش {sum(vals):g} ≠ نیاز "
                                f"{needs[sc_i]/100:g} ⇒ در موتور می‌بازد")
            meta["solvable"] = ok and tray_total > 0
            meta["scales"] = len(scales)
        else:
            for sc_i, vals in per_scale.items():
                if sc_i >= len(needs):
                    continue
                lim = cents(tol) / 100.0 + 1e-9
                for size in range(1, len(vals) + 1):
                    bad = [c for c in itertools.combinations(vals, size)
                           if abs(sum(c) - needs[sc_i] / 100.0) <= lim]
                    if bad:
                        errs.append(f"{rel}: زیرمجموعه‌ی {list(bad[0])} از `wrong_ops`ِ کفه {sc_i} "
                                    f"تراز می‌کند ⇒ آن حرکت «اشتباه» نیست (ADR-053)")
                        break


def check_narrative_uniqueness(metas: list[dict], errs: list[str]) -> None:
    """§۶ سند GDD/تسک ۷.x: هر سطح یک بیت روایی **منحصربه‌فرد** دارد.

    تکرارِ جمله یعنی دو سطح «یکی» به‌نظر کودک می‌آیند و حسِ پیشرفت می‌شکند ✗
    (قبلاً فقط در پیامِ خطای طول‌سنجی وعده داده شده بود و هیچ‌کس نمی‌سنجیدش.)
    """
    seen: dict[str, str] = {}
    for m in metas:
        intro = m.get("intro")
        if not intro:
            continue
        if intro in seen:
            errs.append(f"{m['file']}: narrative_intro عیناً تکرارِ {seen[intro]} است")
        else:
            seen[intro] = m["file"]


def validate_progression(metas: list[dict], errs: list[str]) -> None:
    """DoD فاز ۷: منحنی دشواری داخل هر Tier یکنواخت افزایشی، بدون پرش."""
    by_tier: dict[int, list[dict]] = {}
    for m in metas:
        if m.get("tier") is not None:
            by_tier.setdefault(m["tier"], []).append(m)
    for tier, items in sorted(by_tier.items()):
        items.sort(key=lambda x: x["file"])
        for a, b in zip(items, items[1:]):
            ea, eb = a.get("difficulty_elo"), b.get("difficulty_elo")
            if not (isinstance(ea, (int, float)) and isinstance(eb, (int, float))):
                continue
            if eb < ea - 1:
                errs.append(f"Tier {tier}: دشواری افت کرده در {b['file']} ({eb} < {ea})")
            elif eb - ea > ELO_JUMP_LIMIT:
                errs.append(f"Tier {tier}: پرش دشواری {ea}→{eb} بین {a['file']} و {b['file']} بیش از {ELO_JUMP_LIMIT} است")



L10N_PATH = ROOT / "game" / "data" / "l10n" / "ui_strings.json"
L10N_DEFAULT_MAX = 80


def check_l10n(errs: list[str]) -> dict:
    """بررسی فایل رشته‌های UI (تسک ۶.۳): چندزبانه‌بودن باید واقعی باشد، نه در حد شعار.

    قوانینی که `game/scripts/ui/Loc.gd` هم در GUT می‌سنجد، اینجا به‌صورت محتوایی:
      • `default_locale` باید در `locales` تعریف شده باشد و جدولش خالی نباشد؛
      • هر locale دقیقاً همان مجموعه‌کلیدِ پیش‌فرض را داشته باشد (نه کم، نه زیاد) —
        وگرنه کاربر یک کلید خام روی دکمه می‌بیند؛
      • هیچ رشته‌ای تهی نباشد و از سقف طول (پیش‌فرض ۸۰) عبور نکند (§۷: دیوار ممنوع)؛
      • هیچ رقمی در متن آماده نباشد: اعداد را `Loc.digits()` در زمان اجرا می‌سازد،
        پس اگر رقمی hardcode شود یعنی فرمتِ زبان دیگر شکسته می‌شود؛
      • `rtl_locales` زیرمجموعه‌ی `locales` باشد (جهت از داده می‌آید نه از hardcode).
    """
    summary = {"file": str(L10N_PATH.relative_to(ROOT)), "locales": [], "keys": 0}
    data = load_json(L10N_PATH, errs)
    if not isinstance(data, dict):
        errs.append(f"{summary['file']}: فایل رشته‌های UI نیست یا پارس نشد (تسک ۶.۳)")
        return summary
    locales = data.get("locales")
    strings = data.get("strings")
    default = str(data.get("default_locale", ""))
    if not isinstance(locales, dict) or not locales:
        errs.append(f"{summary['file']}: `locales` باید objectِ غیرخالی باشد")
        return summary
    if not isinstance(strings, dict):
        errs.append(f"{summary['file']}: `strings` باید object باشد")
        return summary
    if default not in locales:
        errs.append(f"{summary['file']}: `default_locale` ({default or 'تهی'}) در `locales` تعریف نشده")
        return summary
    try:
        max_len = int(data.get("max_string_len", L10N_DEFAULT_MAX))
    except (TypeError, ValueError):
        max_len = L10N_DEFAULT_MAX
    ref = strings.get(default)
    if not isinstance(ref, dict) or not ref:
        errs.append(f"{summary['file']}: جدول رشته‌های `{default}` خالی یا object نیست")
        return summary
    summary["locales"] = sorted(locales.keys())
    summary["keys"] = len(ref)
    summary["key_sets"] = {str(code): sorted(table.keys())
                           for code, table in strings.items() if isinstance(table, dict)}

    rtl = data.get("rtl_locales", [])
    if not isinstance(rtl, list):
        errs.append(f"{summary['file']}: `rtl_locales` باید آرایه باشد")
    else:
        for code in rtl:
            if code not in locales:
                errs.append(f"{summary['file']}: `rtl_locales` زبانِ تعریف‌نشده «{code}» را می‌شمارد")

    digit_re = re.compile(r"[0-9۰-۹]")
    for code in sorted(locales.keys()):
        table = strings.get(code)
        if not isinstance(table, dict):
            errs.append(f"{summary['file']}: `strings.{code}` object نیست")
            continue
        missing = sorted(set(ref.keys()) - set(table.keys()))
        extra = sorted(set(table.keys()) - set(ref.keys()))
        if missing:
            errs.append(f"{summary['file']}: {code} این کلیدها را ندارد: {', '.join(missing[:6])}"
                        + (f" (+{len(missing) - 6})" if len(missing) > 6 else ""))
        if extra:
            errs.append(f"{summary['file']}: {code} کلیدهای اضافه دارد: {', '.join(extra[:6])}")
        for key in sorted(table.keys()):
            value = table[key]
            if not isinstance(value, str):
                errs.append(f"{summary['file']}: {code}/{key} رشته نیست")
                continue
            if not value.strip():
                errs.append(f"{summary['file']}: {code}/{key} تهی است")
            elif len(value) > max_len:
                errs.append(f"{summary['file']}: {code}/{key} بلندتر از {max_len} نویسه (§۷)")
            elif digit_re.search(value):
                errs.append(f"{summary['file']}: {code}/{key} رقم hardcode دارد — از Loc.digits() استفاده کن")
    return summary



# ---------------------------------------------------------------- ۷.۵ روایت
MAX_BEAT_LINE = 90   # سقفِ GDD برای `narrative_intro` — همان `DialogueBox` (۳ خط × ۲۴px) ✗✓
MIN_BEAT_LINE = 25   # «جملهٔ پراکنده» نه ✗✓ (DoD ۷.۵: داستان منسجم، نه یادداشت)
COHERENCE_ANCHOR = "ترازوی بنیادین"
REGION_BY_TIER = {
    1: "Sunlit Meadow", 2: "Whisper Caverns", 3: "Ghostlight Ruins",
    4: "Twin Observatory", 5: "Summit of Equilibrium",
}


def check_story_beats(errs: list[str], locales: list[str]) -> int:
    """قاعده‌های `story_beats.json` (docs/04 ۷.۵ + docs/07 §۵-ب + Art Bible §۵).

    چرا این‌ها چک می‌شوند و «قشنگیِ متن» چک نمی‌شود: ساختارِ قوس (افتتاحیه ← سه نقطهٔ عطفِ
    ورودِ Tier ← پایان) و پیوندِ متن با داراییِ هنری، **قابلِ سنجش‌اند** ✗✓ و اگر نشکنند،
    روایت هیچ‌وقت «جملاتِ پراکنده» نمی‌شود ✓ ولی قضاوتِ ادبی با بازیِ واقعی است (فاز ۱۰) ✗
    """
    if not NARRATIVE_FILE.exists():
        errs.append("فایل `game/data/narrative/story_beats.json` نیست (تسک ۷.۵ بسته نشده ✗)")
        return 0
    doc = load_json(NARRATIVE_FILE, errs) or {}
    if not isinstance(doc, dict):
        errs.append("story_beats.json باید object باشد")
        return 0
    if doc.get("schema_version") != 1:
        errs.append("story_beats: `schema_version` باید ۱ باشد")
    arc = str(doc.get("arc_id", ""))
    if not re.fullmatch(r"[a-z0-9_]{3,40}", arc):
        errs.append(f"story_beats: `arc_id` نامعتبر `{arc}`")
    loc = str(doc.get("locale", ""))
    if locales and loc not in locales:
        # جهتِ متن از داده می‌آید نه hardcode ✓ (همان قاعدهٔ `rtl_locales` در l10n ✓)
        errs.append(f"story_beats: `locale` باید یکی از {sorted(locales)} باشد (این: {loc})")

    beats = doc.get("beats")
    if not isinstance(beats, list) or not beats:
        errs.append("story_beats: `beats` خالی است")
        return 0

    seen: set[str] = set()
    starts = [b for b in beats if isinstance(b, dict) and b.get("trigger") == "game_start"]
    ends = [b for b in beats if isinstance(b, dict) and b.get("trigger") == "game_complete"]
    for b in beats:
        if not isinstance(b, dict):
            errs.append("story_beats: هر بیت باید object باشد")
            continue
        bid = str(b.get("beat_id", ""))
        if not re.fullmatch(r"beat_[a-z0-9_]{2,40}", bid):
            errs.append(f"story_beats: `beat_id` نامعتبر `{bid}`")
        elif bid in seen:
            errs.append(f"story_beats: `beat_id` تکراری `{bid}` ⇒ موتورِ روایت کدام را پخش کند؟ ✗")
        seen.add(bid)
        if b.get("trigger") not in ("game_start", "tier_start", "game_complete"):
            errs.append(f"{bid}: `trigger` باید game_start/tier_start/game_complete باشد")
        tier = b.get("tier")
        if not isinstance(tier, int) or not 1 <= tier <= 5:
            errs.append(f"{bid}: `tier` باید ۱..۵ باشد")
            continue
        # پیوندِ متن ↔ هنر (docs/04 ۷.۵): هر بیت **باید** بگوید کدام دارایی محیطی لازم است ✗✓
        # و همان دارایی باید منطقهٔ همان Tier باشد (بیتِ غار با «دشتِ آفتابی» = داراییِ گم‌شده ✓)
        if b.get("ambient_art") != REGION_BY_TIER[tier]:
            errs.append(f"{bid}: `ambient_art` باید `{REGION_BY_TIER[tier]}` باشد "
                        f"(این: `{b.get('ambient_art')}`) — Art Bible §۵")
        if len(str(b.get("art_note", "")).strip()) < 8:
            errs.append(f"{bid}: `art_note` لازم است (چه چیزی از Art Bible §۵ این بیت می‌خواهد ✗)")

        lines = b.get("lines")
        if not isinstance(lines, list) or not 3 <= len(lines) <= 6:
            errs.append(f"{bid}: `lines` باید ۳..۶ خط باشد (نه یادداشت، نه دیوارِ متن ✗)")
            continue
        aria_lines: list[str] = []
        for i, ln in enumerate(lines):
            if not isinstance(ln, dict):
                errs.append(f"{bid}.lines[{i}] باید object باشد")
                continue
            spk = str(ln.get("speaker", ""))
            if spk not in ("aria", "narrator"):
                errs.append(f"{bid}.lines[{i}] `speaker` باید aria/narrator باشد (این: {spk})")
            txt = str(ln.get("text", "")).strip()
            if len(txt) < MIN_BEAT_LINE:
                errs.append(f"{bid}.lines[{i}] کوتاه‌تر از {MIN_BEAT_LINE} نویسه ⇒ جملهٔ پراکنده ✗")
            if len(txt) > MAX_BEAT_LINE:
                errs.append(f"{bid}.lines[{i}] بیش از {MAX_BEAT_LINE} نویسه ⇒ سرریزِ DialogueBox ✗")
            if re.search(r"\d", txt):
                # «Aria هیچ‌وقت عددِ جواب را نمی‌گوید» ✗✓ همین قاعده در روایت هم جاری است،
                # وگرنه یک بیتِ معجزه‌آسا همهٔ سطح‌ها را لو می‌دهد ✓✓
                errs.append(f"{bid}.lines[{i}] رقم دارد ⇒ لو‌دادنِ جواب/وزن ✗ (GDD §۲)")
            if spk == "aria":
                aria_lines.append(txt)
        if not aria_lines:
            errs.append(f"{bid}: بیت بدون خطِ `aria` ⇒ آریا دیگر شخصیت نیست، راوی است ✗")
        if not any(l.strip().endswith("؟") for l in aria_lines):
            # GDD §۵-الف: «Aria سؤال می‌پرسد و جهت می‌دهد» ✓✓ این تنها قاعدهٔ *رفتاری* است
            # که از متن قابل سنجش است ⇒ در هر بیت دست‌کم یک پرسشِ آریا الزامی است ✓
            errs.append(f"{bid}: هیچ خطِ آریا با «؟» تمام نمی‌شود ⇒ دستور داده شده، نه پرسش ✗")

    if len(starts) != 1:
        errs.append(f"story_beats: دقیقاً یک `game_start` لازم است (این: {len(starts)})")
    elif starts[0].get("tier") != 1:
        errs.append("story_beats: صحنهٔ افتتاحیه باید Tier ۱ باشد (ورودِ کودک از دشت ✓)")
    if len(ends) != 1:
        errs.append(f"story_beats: دقیقاً یک `game_complete` لازم است (این: {len(ends)})")
    elif isinstance(ends[0].get("tier"), int) and ends[0]["tier"] != max(
            b.get("tier", 0) for b in beats if isinstance(b, dict)):
        errs.append("story_beats: پایان باید روی بالاترین Tier باشد (قله ✓ GDD §۵-ب)")
    entry = {b.get("tier") for b in beats
             if isinstance(b, dict) and b.get("trigger") == "tier_start"}
    if entry != {2, 3, 4, 5}:
        # «سه نقطهٔ عطفِ میانی + ورودِ قله» ✗✓ اگر ورودِ Tier‌ای بی‌بیت بماند، آن Tier با
        # همان دیالوگِ Tier قبلی شروع می‌شود ⇒ قوس داستانی در میانه می‌شکند ✗
        errs.append(f"story_beats: بیتِ `tier_start` باید دقیقاً Tier های ۲..۵ را بپوشاند "
                    f"(این: {sorted(x for x in entry if isinstance(x, int))}) ✗")
    first_txt = " ".join(str(l.get("text", "")) for l in starts[0].get("lines", []) if isinstance(l, dict)) if starts else ""
    last_txt = " ".join(str(l.get("text", "")) for l in ends[0].get("lines", []) if isinstance(l, dict)) if ends else ""
    if COHERENCE_ANCHOR not in first_txt or COHERENCE_ANCHOR not in last_txt:
        # لنگرِ همبستگی: چیزی که در افتتاحیه شکست، در پایان ترمیم می‌شود ✓✓ بدون این،
        # «۶ بیتِ خوش‌ساخت» می‌تواند شش داستانِ جدا باشد ✗ (DoD ۷.۵ = روایتِ منسجم ✓)
        errs.append(f"story_beats: `{COHERENCE_ANCHOR}` باید هم در افتتاحیه و هم در پایان "
                    f"بیاید ⇒ قوس، نه مجموعه‌ی جملات ✗")
    return len(beats)



# ---------------------------------------------------------------- ۷.۶ صوت
AUDIO_KINDS = {"sfx", "music"}
AUDIO_BUSES = {"SFX", "Music"}
AUDIO_MAX_SEC = 1.4
AUDIO_ID_RE = re.compile(r"^[a-z][a-z0-9_]{2,32}$")


def check_audio_manifest(errs: list[str]) -> int:
    """`data/audio/audio_assets.json` — فهرستِ داراییِ صوتی برای سفارش/تولید ✓

    سه چیز را می‌بندد، چون هر سه «بعداً درست می‌شود» نیست ✗✓:
    ۱) بودجهٔ حجم: اگر روزی فایل‌های واقعی به `assets/audio/` آمدند، مجموعِ آن‌ها سقف
       manifest را نمی‌شکند ✗ (APK روی گوشی ارزان + سقفِ دانلودِ Play = حجم مهم است ✓);
    ۲) `target_bus` باید همان دو باسی باشد که `AudioManager` می‌سازد و `SettingsStore`
       روی آن‌ها volume/mute می‌گذارد ✗✓ باسِ اشتباه = صدایی که اسلایدرِ والدین
       خاموشش نمی‌کند (نقضِ «کنترلِ والد» در §۶.۵ ✗✗ جدی‌ترین نوعِ باگِ این بازی ✓);
    ۳) `when` باید یا `event:<سیگنالِ واقعی EventBus>` باشد یا `manual:<چرا>` ⇒ هیچ
       دارایی‌ای «بعداً وصلش می‌کنیم» باقی نمی‌ماند ✗✓ (هر event باید در EventBus باشد ✓
       وگرنه صامت‌ترین باگِ ممکن: پخش‌کننده‌ای که هیچ‌کس صدا نمی‌زند ✓✓).
    """
    if not AUDIO_MANIFEST.exists():
        errs.append("فایل `game/data/audio/audio_assets.json` نیست (تسک ۷.۶ بسته نشده ✗)")
        return 0
    doc = load_json(AUDIO_MANIFEST, errs) or {}
    if not isinstance(doc, dict):
        errs.append("audio_assets.json باید object باشد")
        return 0
    policy = doc.get("policy") if isinstance(doc.get("policy"), dict) else {}
    if policy.get("commit_binaries") is True:
        errs.append("audio policy: `commit_binaries` باید false باشد ✗ (باینری در گیت نداریم ✓)")
    budget_kb = policy.get("budget_total_kb")
    if not isinstance(budget_kb, (int, float)) or budget_kb <= 0:
        errs.append("audio policy: `budget_total_kb` لازم است ✗ (سقفِ حجمِ فایل‌های نهایی)")
        budget_kb = 0
    audio_dir = ROOT / "game" / "assets" / "audio"
    if audio_dir.exists():
        total = sum(f.stat().st_size for f in audio_dir.rglob("*") if f.is_file() and f.suffix.lower()
                    in (".wav", ".ogg", ".mp3", ".flac"))
        if budget_kb and total > budget_kb * 1024:
            errs.append(f"assets/audio: {total // 1024}KB از سقفِ {int(budget_kb)}KB گذشته ✗ "
                        f"(حجمِ APK روی گوشی ارزان §۹)")

    # سیگنال‌های واقعیِ EventBus ✗✓ (متنِ فایل را خوانده می‌شود؛ اسکریپت‌خوانیِ GDScript
    # در ابزارِ python ممکن نیست ⇒ همین الگوی `TRIGGER_RE` که در سطوح استفاده شده ✓)
    bus_path = ROOT / "game" / "scripts" / "autoload" / "EventBus.gd"
    signals: set[str] = set()
    if bus_path.exists():
        signals = set(re.findall(r"^signal ([a-z_][a-z0-9_]*)", bus_path.read_text(encoding="utf-8"), re.M))

    assets = doc.get("assets")
    if not isinstance(assets, list) or not assets:
        errs.append("audio_assets: `assets` خالی است")
        return 0
    seen: set[str] = set()
    for a in assets:
        if not isinstance(a, dict):
            errs.append("audio_assets: هر مورد باید object باشد")
            continue
        aid = str(a.get("id", ""))
        if not AUDIO_ID_RE.match(aid):
            errs.append(f"audio_assets: `id` نامعتبر `{aid}`")
            continue
        if aid in seen:
            errs.append(f"audio_assets: `id` تکراری `{aid}` ✗")
        seen.add(aid)
        if a.get("kind") not in AUDIO_KINDS:
            errs.append(f"audio_assets.{aid}: `kind` باید {sorted(AUDIO_KINDS)} باشد")
        if a.get("target_bus") not in AUDIO_BUSES:
            errs.append(f"audio_assets.{aid}: `target_bus` باید یکی از {sorted(AUDIO_BUSES)} باشد "
                        f"(باسِ دیگر ⇒ اسلایدرِ والدین بی‌اثر ✗§۶.۵)")
        ms = a.get("max_sec")
        if not isinstance(ms, (int, float)) or ms < 0 or ms > AUDIO_MAX_SEC:
            errs.append(f"audio_assets.{aid}: `max_sec` باید ۰..{AUDIO_MAX_SEC} باشد "
                        f"(صدای بلند = آزارِ حسی در بازیِ کودک ✗)")
        if len(str(a.get("note", "").strip())) < 12:
            errs.append(f"audio_assets.{aid}: `note` لازم است (چرا این صدا، نه آن ✓)")
        when = str(a.get("when", ""))
        if when.startswith("event:"):
            name = when[len("event:"):].split(":")[0]
            if signals and name not in signals:
                errs.append(f"audio_assets.{aid}: `when` به سیگنالِ `{name}` اشاره می‌کند که در "
                            f"EventBus نیست ⇒ پخش‌کنندهٔ بی‌صاحب ✗✓")
        elif not when.startswith("manual:"):
            errs.append(f"audio_assets.{aid}: `when` باید `event:<signal>` یا `manual:<چرا>` باشد")
        if not str(a.get("final_file", "")).startswith("res://assets/audio/"):
            errs.append(f"audio_assets.{aid}: `final_file` باید زیر `res://assets/audio/` باشد")
    return len(assets)

ART_BUDGET_KB = 240          # §۱ سند هنری: «رندر ارزان» ⇒ هنرِ بصری باید تقریباً صفر بایت باشد ✓
ASSETS_BUDGET_KB = 3400      # سقفِ کل `game/assets` (۳۰۰۰KB صوتِ manifest + هنرِ برداری + سرِش‌ها) ✓
RASTER_EXT = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tga", ".exr", ".hdr", ".ktx2"}
SHADER_DIR = ASSETS / "shaders"


def check_art_assets(errs: list[str]) -> dict:
    """ممیزیِ دارایی‌های بصری (تسک ۸.۱ · ADR-007/ADR-058) ✓

    سه قانونی که در CIِ بدون‌رندر شدنی‌اند ✓✗ و اگر نباشند، فاز ۸ «چشمی» می‌سوزد ✗:
    ۱) **هیچ باینریِ تصویری** در `game/assets/art/**` ✗✓ (هنرِ خام = ۱۰MB در APK روی
       گوشی ارزان §۹؛ سیاستِ مخزن: SVG/کد ✓ و گیتِ صوت از فاز ۷ همین را می‌گوید ✓✓)
    ۲) **سقفِ وزنِ `game/assets`** ✓ (همان دلیل: سقفِ دانلودِ Play + بودجهٔ manifest)
    ۳) هر `.gdshader` باید (الف) `shader_type` داشته باشد و (ب) **از کجا به کار رفته**
       باشد ✓✓ «شیدرِ یتیم» یعنی کسی path را عوض کرده و هنر بی‌صدا به fallback رفته ✗
       (دقیقاً همان حالتی که `AriaCore` با `Log.error` می‌گوید ⇒ اینجا هم گیت می‌گذاریم)
    """
    art_dir = ASSETS / "art"
    out = {"files": 0, "kb": 0, "shaders": 0, "svg": 0}
    if not ASSETS.exists():
        errs.append("`game/assets` نیست (ساختارِ فاز ۰ ✗)")
        return out
    total = 0
    for f in sorted(ASSETS.rglob("*")):
        if not f.is_file():
            continue
        suffix = f.suffix.lower()
        if suffix == ".import":
            continue  # فایل‌های کناریِ Godot (generate شده، در گیت نیستند) ✓
        total += f.stat().st_size
        out["files"] += 1
        if suffix in RASTER_EXT:
            rel = f.relative_to(ROOT).as_posix()
            errs.append(f"{rel}: تصویرِ raster در مخزن ✗ (سیاستِ SVG/کد — ADR-007/058؛ "
                        f"خروجیِ AI را commit نکن ✓)")
        if suffix == ".svg":
            out["svg"] += 1
            rel = f.relative_to(ROOT).as_posix()
            body = f.read_text(encoding="utf-8", errors="replace")
            if "<svg" not in body:
                errs.append(f"{rel}: فایل SVG با `<svg` شروع نمی‌شود/بدنش svg نیست ✗")
            if "xmlns" not in body:
                errs.append(f"{rel}: SVG بدون `xmlns` در Godot load نمی‌شود ✗")
    out["kb"] = total // 1024
    if total > ASSETS_BUDGET_KB * 1024:
        errs.append(f"game/assets: {out['kb']}KB از سقفِ {ASSETS_BUDGET_KB}KB گذشته ✗ "
                    f"(حجمِ APK §۹ سند ۰۲)")
    art_total = sum(f.stat().st_size for f in art_dir.rglob("*") if f.is_file()) if art_dir.exists() else 0
    if art_total > ART_BUDGET_KB * 1024:
        errs.append(f"game/assets/art: {art_total // 1024}KB از بودجهٔ هنرِ {ART_BUDGET_KB}KB "
                    f"خارج شده ✗ (§۱ سند هنری: بردار تخت/رندر ارزان)")

    gd_scripts = sorted((GAME / "scripts").rglob("*.gd")) if (GAME / "scripts").exists() else []
    scenes = sorted((GAME / "scenes").rglob("*.tscn")) if (GAME / "scenes").exists() else []
    corpus = ""
    for f in gd_scripts + scenes:
        corpus += f.read_text(encoding="utf-8", errors="replace")
    if SHADER_DIR.exists():
        for sh in sorted(SHADER_DIR.glob("*.gdshader")):
            out["shaders"] += 1
            body = sh.read_text(encoding="utf-8", errors="replace")
            if "shader_type" not in body:
                errs.append(f"{sh.name}: شیدر بدون `shader_type` ✗ (Godot رد می‌کند)")
            if "void fragment" not in body and "void vertex" not in body:
                errs.append(f"{sh.name}: هیچ تابعِ fragment/vertex ندارد ⇒ شیدر بی‌اثر ✗")
            if sh.name not in corpus:
                errs.append(f"{sh.name}: به هیچ اسکریپت/صحنه‌ای وصل نیست ✗ (شیدرِ یتیم ⇒ "
                            f"هنر بی‌صدا به fallback می‌رود؛ ADR-058)")
    # مسیرهای ExtResource در صحنه‌ها باید وجود داشته باشند ✓ (شکستنِ هنرِ فاز ۸ معمولاً
    # با جابه‌جاییِ یک فایل شروع می‌شود و پیامش فقط در لاگِ load دیده می‌شود ✗)
    for sc in scenes:
        body = sc.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r'path="res://([^"]+)"', body):
            target = GAME / m.group(1)
            if not target.exists():
                errs.append(f"{sc.relative_to(ROOT).as_posix()} → `res://{m.group(1)}` نیست ✗ "
                            f"(ExtResource شکسته)")
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="NEXUS content validator")
    ap.add_argument("--json", metavar="OUT", help="نوشتن گزارش JSON (برای آرشیو CI)")
    args = ap.parse_args()

    errs: list[str] = []
    l10n = check_l10n(errs)  # مستقل از وجود سطح: رشته‌های UI از فاز ۶ لازم‌اند
    if not LEVELS_DIR.exists() or not sorted(LEVELS_DIR.glob("tier*/level_*.json")):
        print("· هنوز هیچ game/data/levels/tier*/level_*.json وجود ندارد (طبیعی در فاز ۰..۲) → skip")
        return 0

    hints = load_hints(errs)
    if not hints:
        print("⚠ aria_templates.json موجود/قابل‌پارس نیست (فاز ۵) — بررسی hint_id و قانون طلایی موقتاً skip شد")

    metas: list[dict] = []
    ids: dict[str, str] = {}
    for path in sorted(LEVELS_DIR.glob("tier*/level_*.json")):
        m = validate_level(path, errs, hints)
        metas.append(m)
        if m["level_id"]:
            if m["level_id"] in ids:
                errs.append(f"{m['file']}: level_id تکراری `{m['level_id']}` (تکرارِ {ids[m['level_id']]})")
            ids[m["level_id"]] = m["file"]

    validate_progression(metas, errs)
    check_concept_labels(metas, l10n.get("key_sets", {}), errs)
    check_narrative_uniqueness(metas, errs)
    check_answer_leaks(metas, hints, errs)
    beats = check_story_beats(errs, l10n.get("locales", []))
    audio_items = check_audio_manifest(errs)
    art = check_art_assets(errs)

    total = len(metas)
    solved = sum(1 for m in metas if m["solvable"])
    print(f"سطح بررسی‌شده: {total} · قابل‌حل تأییدشده: {solved}/{total} · قالب دیالوگ: {len(hints)}"
          f" · رشته UI: {l10n['keys']}×{len(l10n['locales'])} · بیت روایت: {beats} · دارایی صوتی: {audio_items} · فایل بصری: {art['files']} ({art['kb']}KB)/شیدر {art['shaders']}")

    if args.json:
        Path(args.json).write_text(json.dumps({"levels": metas, "l10n": l10n, "errors": errs}, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"گزارش JSON → {args.json}")

    if errs:
        print(f"\n✖ {len(errs)} خطای محتوایی:")
        for e in errs:
            print("  - " + e)
        return 1
    print("✔ همه‌ی بررسی‌های محتوایی پاس شد")
    return 0


if __name__ == "__main__":
    sys.exit(main())
