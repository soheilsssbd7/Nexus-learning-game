#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ===========================================================================
# NEXUS — tools/build_web_preview.py  (پیش‌نمایشِ وبِ فوری؛ تسک ۱۲.۴ / ADR-069)
# ---------------------------------------------------------------------------
# چیست: ساختِ یک بستهٔ وبِ **قابل‌اجرا** از بازی بدونِ دسترسی به باینریِ Godot
# (سندباکس فقط به github.com/pypi/npm دسترسی دارد؛ release assets بسته‌اند).
#
# چطور (هر سه قطعه در اسکریپت شفاف است، هیچ جادویی نیست):
#   ۱. قالبِ wasm/js وبِ Godot یکسانِ 4.7.2 از پکیج npm می‌آید
#      (`@ringozz/godot-web-wasm32@4.7.2-626` — فایل‌های `godot.web.template_
#      release.wasm32.nothreads.*`؛ threads خاموش ⇒ روی Pages/هر هاستِ استاتیک
#      بدونِ هدر COOP/COEP کار می‌کند ✓ و همین، تنها نیازی بود که export template
#      رسمی تأمین می‌کرد). رشته‌های داخل wasm تأیید شده: TextServerAdvanced/ICU
#      (شکل‌دهیِ فارسی ✓)، thorvg (SVG در زمان اجرا ✓)، FreeType (TTF در زمان
#      اجرا ✓)، کامپایلر GDScript ✓.
#   ۲. `.pck` با فرمت V2ِ سندِ `core/io/file_access_pack.cpp` دست‌ساز می‌شود.
#      تنها داراییِ نیازمندِ ایمپورتِ کل پروژه = دو فونت ttf و ۴ SVG آیکون است؛
#      برای همین دو ترانسفورمِ شفاف روی نسخهٔ کپی (نه ریپو!) اعمال می‌شود:
#        • `scripts/devel/PreviewBoot.gd` (اولین autoload) فونت را با
#          `FontFile.load_dynamic_font` در زمان اجرا بار می‌کند و در ThemeDB
#          می‌نشاند — پاسخِ «نبودِ import cache».
#        • `UIKit.icon_texture` اگر آرتفکتِ ایمپورت نبود، SVG را با
#          `Image.load_svg_from_buffer` در زمان اجرا راستریز می‌کند.
#      `.godot/global_script_class_cache.cfg` هم از روی اسکنِ `class_name`
#      تولید می‌شود (بدونِ آن ۳۵ کلاسِ سراسری در قالبِ release resolve نمی‌شوند).
#   ۳. `index.html` = همان shell رسمیِ `misc/dist/html/full-size.html` با
#      پوستهٔ RTL/فارسی و پالتِ §۲، پلاس‌GO.T_CONFIG دقیقِ خروجیِ export واقعی.
#
# خروجی (build/web/) کاملاً استاتیک است: python3 -m http.server کافی است.
# ⚠ این مسیرِ «پیش‌نمایش» است؛ build رسمیِ انتشار همان export templates رسمی در
# CI است (android-export.yml / بعداً web-export.yml). مسیرِ preview جایگزینِ
# «تأییدِ CI با Godot واقعی» نیست — ادعای اضافه نمی‌کنیم (قاعدهٔ ADR-067).
# ===========================================================================
"""Build a playable static web preview of NEXUS without a Godot binary."""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import shutil
import struct
import sys
import tarfile
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GAME_DIR = REPO_ROOT / "game"
DEFAULT_OUT = REPO_ROOT / "build" / "web"
TEMPLATE_CACHE = REPO_ROOT / ".tools" / "web-templates" / "4.7.2"

# قالبِ wasm یکسانِ موتورِ قفل‌شده (pins شدن = بازتولیدپذیری؛ دستکاری‌ناشدن با sha256 سنجیده نمی‌شود
# چون امضای ناشر ندارد — برای همین مسیرِ رسمیِ انتشار در CI با قالبِ رسمی است، نه این‌جا).
NPM_TGZ_URL = (
    "https://registry.npmjs.org/@ringozz/godot-web-wasm32/-/"
    "godot-web-wasm32-4.7.2-626.tgz"
)
NPM_PREFIX_FILES = {
    "godot.web.template_release.wasm32.nothreads.js": "runtime.js",
    "godot.web.template_release.wasm32.nothreads.wasm": "index.wasm",
    "audio.worklet.js": "index.audio.worklet.js",
    "audio.position.worklet.js": "index.audio.position.worklet.js",
}
# پکیج npm فقط runtime خامِ emscripten را دارد؛ کلاسِ `Engine` (wrapper رسمی) در
# سورسِ godotengine/godot است (misc/dist/html/: platform/web/js/engine/*.js) و از
# codeload — که در سندباکس باز است — کش می‌شود. همان چهار فایلِ بدون تغییر ✓
GODOT_SRC_TARBALL = "https://codeload.github.com/godotengine/godot/tar.gz/refs/tags/4.7.2-stable"
ENGINE_JS_FILES = ("config.js", "features.js", "preloader.js", "engine.js")

# ---------------------------------------------------------------------------
# بخش ۱) جمع‌آوری فایل‌های پروژه — دقیقاً همان چیزی که بازی می‌خواند، نه بیشتر
# ---------------------------------------------------------------------------
EXCLUDE_DIRS = {"addons", "tests", "android", ".godot"}
EXCLUDE_SUFFIXES = {".import", ".uid"}


def collect_project_files() -> dict[str, bytes]:
    """همه‌ی فایل‌های res:// که بازی در زمان اجرا می‌خواند (بدون ابزار/تست)."""
    files: dict[str, bytes] = {}
    for path in sorted(GAME_DIR.rglob("*")):
        rel = path.relative_to(GAME_DIR)
        if any(part in EXCLUDE_DIRS for part in rel.parts):
            continue
        if path.is_dir():
            continue
        if path.suffix in EXCLUDE_SUFFIXES or path.name in {".gutconfig.json", "export_presets.cfg"}:
            continue
        files["res://" + rel.as_posix()] = path.read_bytes()
    return files


# ---------------------------------------------------------------------------
# بخش ۲) ترانسفورم‌های شفاف (فقط روی نسخهٔ داخل بسته)
# ---------------------------------------------------------------------------
PREVIEW_BOOT_GD = '''extends Node
# PreviewBoot — فقط در بستهٔ وب (tools/build_web_preview.py)؛ در ریپو نیست.
# این بسته بدونِ پایپ‌لاینِ ایمپورت ساخته شده؛ پس فونت Vazirmatn این‌جا در زمانِ
# اجرا بار می‌شود. بدونِ آن، فارسی با فونتِ جایگزینِ لاتینِ موتور رندر می‌شد.
func _ready() -> void:
	# رندر: پیش‌فرضِ ریپو «mobile» است (برای وب = WebGPU که روی iOS/Safari شکننده است
	# و برای بازیِ دوبعدیِ Control هیچ سودی ندارد) ⇒ فقط در این بستهٔ پیش‌نمایش،
	# به gl_compatibility (WebGL2) برمی‌گردیم تا روی همهٔ مرورگرها سالم بمانیم.
	# ریپو دست‌نخورده می‌ماند (خروجی رسمیِ CI همان رِندرِ mobile را می‌سازد ✓✗).
	ProjectSettings.set_setting("rendering/renderer/rendering_method", "gl_compatibility")
	ProjectSettings.set_setting("rendering/renderer/rendering_method.web", "gl_compatibility")
	var medium := FontFile.new()
	if medium.load_dynamic_font("res://assets/fonts/Vazirmatn-Medium.ttf") != OK:
		push_error("PreviewBoot: Vazirmatn-Medium بارگذاری نشد")
		return
	ThemeDB.set_fallback_font(medium)
	ThemeDB.set_fallback_font_size(28)
	var theme := ThemeDB.get_project_theme()
	if theme != null:
		theme.default_font = medium
	set_process(true)


# قالبِ npm سرورِ پیشرفتهٔ متن ندارد ⇒ فارسی را به ترتیب/شکلِ بصری می‌چینیم تا
# متصل نشان داده شود (در قالبِ رسمیِ CI این بخش می‌پیچد و کاری نمی‌کند ✓✗).
const Shaper := preload("res://preview/PersianShaper.gd")

var _shape_acc := 0.0


func _process(delta: float) -> void:
	_shape_acc += delta
	if _shape_acc < 0.4:
		return
	_shape_acc = 0.0
	_reshape_tree(get_tree().root)


func _reshape_tree(node: Node) -> void:
	if node is Label or node is Button:
		var c := node as Control
		var src: String = c.text
		var shaped: String = Shaper.visual(src)
		var last: String = str(node.get_meta("sh_vis_last", ""))
		if src == last:
			pass  # قبلاً همین متن شکل خورده بود (قبل + به shape برگشتیم)
		else:
			if node.get_meta("sh_orig", "") != "" and src == Shaper.visual(str(node.get_meta("sh_orig"))):
				pass
			else:
				node.set_meta("sh_orig", src)
				var vis := Shaper.visual(src)
				node.set_meta("sh_vis_last", vis)
				if vis != src:
					c.text = vis
	for child in node.get_children():
		_reshape_tree(child)
'''

# ---------------------------------------------------------------------------
# PersianShaper.gd — فارسی را به ترتیب/شکلِ بصری می‌برد برای TextServerٔ Fallback
# فقط-بستهٔ-وب: قالبِ npm سرورِ متنِ پیشرفته ندارد ⇒ فارسی حروفِ منفصل+به‌هم‌ریخته
# می‌شد. پاسخ: join با «فرم‌های ارائهٔ یونیکد» + چینشِ runها به ترتیبِ بصری، با همان
# فونت و همان رندر. (مسیرِ رسمی = TextServerAdvanced در tpz ✓✗)
# جدولِ FRIMها: isolated/final/initial/medial از بلوک «Arabic Presentation Forms-B»
# + کلاس join (D=دوطرفه، R=راست‌جوین). R_JOINERS از ترکیبی‌نامه‌های استاندارد.
# ---------------------------------------------------------------------------
_SHAPING_ROWS = """\
0621,FE80,,,
0622,FE81,FE82,,
0623,FE83,FE84,FE83,FE84
0624,FE85,FE86,,
0625,FE87,FE88,,
0626,FE89,FE8A,,
0672,FE87,FE88,,
0627,FE8D,FE8E,,
0628,FE8F,FE90,FE91,FE92
067E,FB56,FB57,FB58,FB59
062A,FE95,FE96,FE97,FE98
062B,FE99,FE9A,FE9B,FE9C
062C,FE9D,FE9E,FE9F,FEA0
0686,FB7A,FB7B,FB7C,FB7D
062D,FEA1,FEA2,FEA3,FEA4
062E,FEA5,FEA6,FEA7,FEA8
062F,FEA9,FEAA,,
0630,FEAB,FEAC,,
0631,FEAD,FEAE,,
0632,FEAF,FEB0,,
0698,FB8A,FB8B,,
0633,FEB1,FEB2,FEB3,FEB4
0634,FEB5,FEB6,FEB7,FEB8
0635,FEB9,FEBA,FEBB,FEBC
0636,FEBD,FEBE,FEBF,FEC0
0637,FEC1,FEC2,FEC3,FEC4
0638,FEC5,FEC6,FEC7,FEC8
0639,FEC9,FECA,FECB,FECC
063A,FECD,FECE,FECF,FED0
0641,FED1,FED2,FED3,FED4
0642,FED5,FED6,FED7,FED8
0643,FED9,FEDA,FEDB,FEDC
06A9,FB8E,FB8F,FB90,FB91
06AF,FB92,FB93,FB94,FB95
0644,FEDD,FEDE,FEDF,FEE0
0645,FEE1,FEE2,FEE3,FEE4
0646,FEE5,FEE6,FEE7,FEE8
0647,FEE9,FEEA,FEEB,FEEC
0648,FEED,FEEE,,
06CC,FBFC,FBFD,FBFE,FBFF
0649,FBE8,FBE9,,
064A,FEF1,FEF2,FEF3,FEF4
0640,0640,0640,0640,0640
"""

# حروفِ راست‌جوین (فقط به حرفِ قبل می‌چسبند — به حرفِ بعد نه)
_R_JOINERS = {0x0621, 0x0622, 0x0623, 0x0624, 0x0625, 0x0626, 0x0627, 0x062F, 0x0630,
              0x0631, 0x0632, 0x0698, 0x0648, 0x0649}

_PERSIAN_SHAPER_GD = """extends RefCounted
# PersianShaper — فقط در بستهٔ وب. فارسی را به ترتیب/شکلِ بصری می‌برد (Fallback server).
# منبع: بازی ترازوی تعادل فارسی‌زبان است و قالبِ npm TextServerAdvanced ندارد.

const FORMS: Dictionary = {
__FORMS__
}

const _RTL_START := 0x0600
const _RTL_END := 0x06FF
const _ZWNJ := 0x200C
const _ZERO_WIDTH := 0x200D
const _TATWEEL := 0x0640
const _PRESENT_LO := 0xFB50
const _PRESENT_HI := 0xFEFF


static func _is_rtl(cp: int) -> bool:
	if cp >= 0xFB50 and cp <= 0xFEFC:
		return true  # فرم‌های ارائه: خودشان RTL‌اند (حروفِ شکل‌یافته)
	if cp >= _RTL_START and cp <= _RTL_END:
		return cp != _ZWNJ and cp != _TATWEEL
	if cp >= 0x0750 and cp <= 0x077F:
		return true
	if cp >= 0x08A0 and cp <= 0x08FF:
		return true
	if cp >= 0xFB1E and cp <= 0xFB4F:
		return true
	if cp in range(0x06F0, 0x06FA):  # ارقام فارسی ۰..۹ — راست‌به‌چپ در متنِ فارسی ✓
		return true
	# توجه: ZWNJ/ZWJ عمداً غیر-RTL‌اند تا run جدا کنند و بی‌نمایش خودشان حفظ شوند ✓
	return false


## حرفِ پایهٔ قبل/بعد در run مشخص می‌کند کدام فرم انتخاب شود.
static func _form_of(cp: int, prev_cp: int, next_cp: int) -> int:
	if not FORMS.has(cp):
		return cp
	var row: Array = FORMS[cp]
	var joins_prev := false
	var joins_next := false
	if prev_cp == _TATWEEL:
		joins_prev = int(row[1]) != 0
	elif prev_cp != 0 and FORMS.has(prev_cp):
		var prow: Array = FORMS[prev_cp]
		joins_prev = int(prow[4]) == 0 and int(row[1]) != 0
	if next_cp == _TATWEEL:
		joins_next = int(row[4]) == 0 and int(row[2]) != 0
	elif next_cp != 0 and FORMS.has(next_cp):
		var nrow: Array = FORMS[next_cp]
		joins_next = int(row[4]) == 0 and int(row[2]) != 0 and int(nrow[1]) != 0
	if joins_prev and joins_next and int(row[3]) != 0:
		return int(row[3])   # medial
	if joins_prev and int(row[1]) != 0:
		return int(row[1])   # final
	if joins_next and int(row[2]) != 0:
		return int(row[2])   # initial
	return int(row[0])       # isolated




## ریشهٔ run: حروفِ متصل را با فرم‌ها می‌نویسد و ترتیب را برمی‌گرداند.
static func _process_rtl_run(run_text: String) -> String:
	# ZWNJ را جداژو می‌کند و انتشار فرم نمی‌دهد
	var src := run_text.replace(String.chr(_ZWNJ), "")
	var n := src.length()
	var cps := PackedInt32Array()
	cps.resize(n)
	for i in range(n):
		cps[i] = src.unicode_at(i)
	var shaped := PackedInt32Array()
	shaped.resize(n)
	for i in range(n):
		var prev_cp := 0
		var next_cp := 0
		if i > 0:
			prev_cp = cps[i - 1]
		if i < n - 1:
			next_cp = cps[i + 1]
		# ZWNJ غایب است؛ استارتاެ٠“¯prou: prev_cp/next_cp با TATWEEL مثل join دوقطبی می‌روند
		shaped[i] = _form_of(cps[i], prev_cp, next_cp)
	var out := ""
	for i in range(n - 1, -1, -1):
		out += String.chr(shaped[i])
	return out


## متن را به run تقسیم می‌کند و به ترتیبِ بصری برمی‌گرداند.
static func visual(text: String) -> String:
	if text.is_empty():
		return text
	var has_rtl := false
	for i in range(text.length()):
		if _is_rtl(text.unicode_at(i)):
			has_rtl = true
			break
	if not has_rtl:
		return text
	# فاصله در RTL هم جزو run همان side است (Visual join طبیعی)
	var runs: Array = []
	var cur := ""
	var cur_rtl := false
	for i in range(text.length()):
		var cp := text.unicode_at(i)
		var is_rtl_ch := _is_rtl(cp)
		# فاصله/نقطه‌ویرگول/کاما/دو‌نقطه: در runِ فعلی حفظ می‌مانند (frame inter-line)
		if cp == 0x20 or cp == 0x2E or cp == 0x3A or cp == 0x2C or cp == 0x061B or cp == 0x060C or cp == 0x061F or cp == 0x0021:
			cur += String.chr(cp)
			continue
		if runs.is_empty() and cur.is_empty():
			cur_rtl = is_rtl_ch
			cur = String.chr(cp)
			continue
		if is_rtl_ch == cur_rtl:
			cur += String.chr(cp)
		else:
			runs.append([cur, cur_rtl])
			cur = String.chr(cp)
			cur_rtl = is_rtl_ch
	if not cur.is_empty():
		runs.append([cur, cur_rtl])
	# چینش بصری: اگر متن از راست شروع شد یا همه‌اش RTL بود، کل runها سروار می‌شوند
	if bool(runs[0][1]):
		runs.reverse()
	var out := ""
	for r: Array in runs:
		if bool(r[1]):
			out += _process_rtl_run(String(r[0]))
		else:
			out += String(r[0])
	return out
"""


def _shaper_content() -> str:
    """فرم‌ها را از _SHAPING_ROWS می‌سازد و داخل قالبِ GDScript می‌نشتاند."""
    entries: list[str] = []
    for raw in _SHAPING_ROWS.strip().splitlines():
        base, iso, fin, ini, med = [x.strip() for x in raw.split(",")]
        base_cp = int(base, 16)
        row = [
            int(iso, 16) if iso else base_cp,
            int(fin, 16) if fin else 0,
            int(ini, 16) if ini else 0,
            int(med, 16) if med else 0,
            1 if base_cp in _R_JOINERS else 0,
        ]
        entries.append(f"\t0x{base}: [{row[0]}, {row[1]}, {row[2]}, {row[3]}, {row[4]}],")
    return _PERSIAN_SHAPER_GD.replace("__FORMS__", "\n".join(entries))


# --- مرجعِ پایتونیِ همان الگوریتم — فقط برای self-test (smoke probe) ---------------
def _py_forms() -> dict:
    forms = {}
    for raw in _SHAPING_ROWS.strip().splitlines():
        base, iso, fin, ini, med = [x.strip() for x in raw.split(",")]
        forms[int(base, 16)] = [
            int(iso, 16) if iso else int(base, 16),
            int(fin, 16) if fin else 0,
            int(ini, 16) if ini else 0,
            int(med, 16) if med else 0,
            1 if int(base, 16) in _R_JOINERS else 0,
        ]
    return forms


def _py_is_rtl(cp: int) -> bool:
    if 0xFB50 <= cp <= 0xFEFC:
        return True
    if 0x0600 <= cp <= 0x06FF:
        return cp not in (0x200C, 0x0640)
    if 0x0750 <= cp <= 0x077F or 0x08A0 <= cp <= 0x08FF:
        return True
    if 0x06F0 <= cp < 0x06FA:
        return True
    return False


def _py_form_of(cp, prev_cp, next_cp, forms):
    if cp not in forms:
        return cp
    row = forms[cp]
    joins_prev = False
    joins_next = False
    if prev_cp == 0x0640:
        joins_prev = row[1] != 0
    elif prev_cp > 0 and prev_cp in forms:
        joins_prev = forms[prev_cp][4] == 0 and row[1] != 0
    if next_cp == 0x0640:
        joins_next = row[4] == 0 and row[2] != 0
    elif next_cp > 0 and next_cp in forms:
        joins_next = row[4] == 0 and row[2] != 0 and forms[next_cp][1] != 0
    if joins_prev and joins_next and row[3] != 0:
        return row[3]
    if joins_prev and row[1] != 0:
        return row[1]
    if joins_next and row[2] != 0:
        return row[2]
    return row[0]


def _py_visual(text: str) -> str:
    """دقیقاً همان الگوریتمِ PersianShaper.visual به پایتون — برای self-test."""
    if not text:
        return text
    if not any(_py_is_rtl(ord(c)) for c in text):
        return text
    forms = _py_forms()
    neutrals = (0x20, 0x2E, 0x3A, 0x2C, 0x061B, 0x060C, 0x061F, 0x21)
    runs = []
    cur = ""
    cur_rtl = False
    for c in text:
        cp = ord(c)
        is_rtl = _py_is_rtl(cp)
        if cp in neutrals:
            cur += c
            continue
        if not runs and not cur:
            cur_rtl = is_rtl
            cur = c
            continue
        if is_rtl == cur_rtl:
            cur += c
        else:
            runs.append([cur, cur_rtl])
            cur = c
            cur_rtl = is_rtl
    if cur:
        runs.append([cur, cur_rtl])
    if runs[0][1]:
        runs.reverse()
    out = ""
    for text_run, is_rtl_run in runs:
        if not is_rtl_run:
            out += text_run
            continue
        src = text_run.replace("‌", "")
        cps = [ord(c) for c in src]
        shaped = []
        for i, cp in enumerate(cps):
            prev_cp = cps[i - 1] if i > 0 else -1
            next_cp = cps[i + 1] if i < len(cps) - 1 else -1
            shaped.append(_py_form_of(cp, prev_cp, next_cp, forms))
        out += "".join(chr(cp) for cp in reversed(shaped))
    return out


_SHAPER_PROBES = ["سلام دنیا", "ترازو", "نمرهٔ ۱۸۰", "شبكهٔ مهارت‌ها",
                  "چیدنِ کره‌ها روی کفهٔ راست", "کیفیتِ شکلِ بصری"]


# جایگزینیِ دقیقِ بدنهٔ icon_texture — بلوکِ قدیم باید **حتماً** یافت شود (assert)،
# تا اگر UIKit تغییر کرد، این ابزار بی‌صدایِ ناآگاه نیفتد (قاعدهٔ نوشتاریِ ریپو).
# ماژول regex در قالبِ nothreadsِ npm کامپایل نشده (RegEx class غایب است) — برای همین
# دو نقطهٔ استفادهٔ RegExِ بازی (LEVEL_ID_PATTERN در LevelLoader.path_for و
# LEVEL_ID_PATTERN/TRIGGER_PATTERN در LevelData._matches) فقط داخل بستهٔ وب با تجزیهٔ
# دستیِ معنابرابر جایگزین می‌شود. ریپو دست‌نخورده می‌ماند؛ مسیرِ رسمی (tpz) کدِ اصلی
# را اجرا می‌کند ✓✗.
_LL_OLD = '''static func path_for(level_id: String) -> String:
\tvar re := RegEx.new()
\tif re.compile(ID_PATTERN) != OK:
\t\treturn ""
\tvar m: RegExMatch = re.search(level_id)
\tif m == null:
\t\treturn ""
\tvar tier: int = int(m.get_string(1))
\tvar num: String = m.get_string(2)
\treturn "%s/%s%d/level_%d_%s.json" % [LEVELS_ROOT, TIER_DIR_PREFIX, tier, tier, num]'''
_LL_NEW = '''static func path_for(level_id: String) -> String:
\t# فقط-بستهٔ-وب: قالبِ این بیلد ماژولِ regex ندارد ⇒ تجزیهٔ دستیِ همان الگوی
\t# ^tier([1-5])_level_([0-9]{2})$ (معنابرابر×سریع‌تر) — ریپو دست‌نخورده می‌ماند ✓
\tif level_id.length() != 14 or not level_id.begins_with("tier"):
\t\treturn ""
\tvar tier_ch := level_id.substr(4, 1)
\tif tier_ch < "1" or tier_ch > "5" \\
\t\tor level_id.substr(5, 7) != "_level_" \\
\t\tor not _all_ascii_digits(level_id.substr(12, 2)):
\t\treturn ""
\tvar tier := tier_ch.to_int()
\tvar num: String = level_id.substr(12, 2)
\treturn "%s/%s%d/level_%d_%s.json" % [LEVELS_ROOT, TIER_DIR_PREFIX, tier, tier, num]


## کاراکترها دقیقاً [0-9] باشند ✓ (is_valid_int خطا/علامت هم می‌گرفت ✗✓)
static func _all_ascii_digits(text: String) -> bool:
\tif text.is_empty():
\t\treturn false
\tfor i: int in range(text.length()):
\t\tvar c := text.substr(i, 1)
\t\tif c < "0" or c > "9":
\t\t\treturn false
\treturn true'''
_LD_OLD = '''static func _matches(text: String, pattern: String) -> bool:
\tvar re := RegEx.new()
\tif re.compile(pattern) != OK:
\t\treturn false
\treturn re.search(text) != null'''
_LD_NEW = '''static func _matches(text: String, pattern: String) -> bool:
\t# فقط-بستهٔ-وب: قالبِ این بیلد ماژولِ regex ندارد ⇒ همان دو الگوی واقعیِ بازی
\t# (LEVEL_ID_PATTERN و TRIGGER_PATTERN) بدون RegEx با همان معنا ✓✗ الگوی تازه‌ای که
\t# این‌جا نباشد false برمی‌گردد (سکوتِ خطا نداریم — تست‌ها همین را می‌گیرند)
\tif pattern == LEVEL_ID_PATTERN:
\t\t# ^tier[1-5]_level_[0-9]{2}$ — همان تجزیهٔ LevelLoader.path_for (بدون ارجاع چرخه‌ای)
\t\tif text.length() != 14 or not text.begins_with("tier"):
\t\t\treturn false
\t\tvar tier_ch := text.substr(4, 1)
\t\treturn tier_ch >= "1" and tier_ch <= "5" \\
\t\t\tand text.substr(5, 7) == "_level_" \\
\t\t\tand _all_ascii_digits(text.substr(12, 2))
\tif pattern == TRIGGER_PATTERN:
\t\t# ^(idle_[0-9]+s|fail_[0-9]+x|help_requested|first_wrong_attempt)$
\t\tif text == "help_requested" or text == "first_wrong_attempt":
\t\t\treturn true
\t\tif text.begins_with("idle_") and text.ends_with("s") and text.length() >= 7:
\t\t\treturn _all_ascii_digits(text.substr(5, text.length() - 6))
\t\tif text.begins_with("fail_") and text.ends_with("x") and text.length() >= 7:
\t\t\treturn _all_ascii_digits(text.substr(5, text.length() - 6))
\t\treturn false
\treturn false


## (همان معنای [0-9] — نسخهٔ نمایشیِ LevelData؛ قرارداد را TriggerSystem هم می‌گوید ✓)
static func _all_ascii_digits(text: String) -> bool:
\tif text.is_empty():
\t\treturn false
\tfor i: int in range(text.length()):
\t\tvar c := text.substr(i, 1)
\t\tif c < "0" or c > "9":
\t\t\treturn false
\treturn true'''


_UIKIT_OLD = '''\tvar path: String = String(ICON_PATHS.get(name, ""))
\tif path == "" or not ResourceLoader.exists(path):
\t\treturn null
\treturn load(path) as Texture2D'''
_UIKIT_NEW = '''\tvar path: String = String(ICON_PATHS.get(name, ""))
\tif path == "":
\t\treturn null
\tif ResourceLoader.exists(path):
\t\treturn load(path) as Texture2D
\t# مسیرِ فقط-بستهٔ-وب: بدونِ آرتفکت ایمپорт، SVG را در زمان اجرا راستریز کن ✓
\tif FileAccess.file_exists(path):
\t\tvar img := Image.new()
\t\tif img.load_svg_from_buffer(FileAccess.get_file_as_bytes(path), 2.0) == OK:
\t\t\treturn ImageTexture.create_from_image(img)
\treturn null'''


# ---- پچِ فیزیکِ دوبعدی (فقط-بستهٔ-وب؛ ریپو دست‌نخورده) ------------------------
# قالبِ npm با PHYSICS_2D_DISABLED ساخته شده: Area2D/CircleShape2D/… به‌عنوانِ
# base-class وجود ندارند و سطح قابل‌اینستانس نیست. بازی فیزیک را فقط برایِ
# «برخورد/پیکِ اشاره‌گر» استفاده می‌کند (هیچ کوئریِ direct_space در کل کد نیست)؛
# پس شبه‌کلاس‌های هم‌نام با همان APIِ استفاده‌شده را در بسته تزریق می‌کنیم:
#   Area2D          → Node2D + پخشِ دستیِ input (ObjectInputFilter/غیرفعال در
#                     smoke — کلاس با یک assert مشخص عوض می‌شود؛ ورودیِ وب به
#                     World2D غایب dispatch نمی‌شود، همان نقشی که Area2D داشت)
#   CollisionShape2D→ حاملِ سادهٔ shape (position/scale ارثی — والد را می‌پوشاند)
#   Circle/Rectangle→ رکوردِ shape با رفتارِ collision روی Surface (contains_point
#                     هم دستی می‌ماند — بازی همین را می‌کند ✓)
# منطقِ ترازو/درگ/سطوح همان کدِ اصلی می‌ماند؛ مسیرِ رسمی (CI + tpz رسمی) فیزیکِ
# حقیقی را دارد ✓✗ — این فقط بازتولیدِ پیش‌نمایش بدونِ سکوت است.
_PHYSICS_POLYFILL_GD = """\
extends Node2D
class_name Area2D

## [پلی‌فیل وب] Area2D — فقط برای پیش‌نمایش؛ ریپو دست‌نخورده است.
## بازی از Area2D فقط برای پیکِ اشاره‌گر و contains_point استفاده می‌کند.

var input_pickable: bool = true

func _input_event(_viewport: Node, _event: InputEvent, _shape_idx: int) -> void:
	pass


## میان‌برِ جایفیل سروِر فیزیکِ دوبعدی: رویدادهای اشاره‌گر را دستی dispatch می‌کنیم.
## در بیلدِ کاملِ رسمی، Area2D نیتیو این کار را با PhysicsServer2D انجام می‌دهد؛
## این‌جا چون picking به‌جایِ solver با contains_point همان نتیجه را می‌دهد ✓
## (قدمِ کلیک/لمس فقط به بالاترین Area2D زیرِ اشاره‌گر می‌رسد — _unhandled_input
## بعد از مصرفِ UI اجرا می‌شود، پس توقف روی دکمه‌های HUD هم حفظ می‌شود ✓).
func _unhandled_input(event: InputEvent) -> void:
	if not input_pickable or not is_inside_tree():
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion \
			or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	# هر چهار کلاسِ رویدادِ بالا `.position` دارند (مختصاتِ درگاه) → به جهان:
	var world_pos: Vector2 = get_canvas_transform().affine_inverse() * event.position
	if point_inside(world_pos):
		_input_event(get_viewport(), event, 0)



func point_inside(world_point: Vector2) -> bool:
	var local := to_local(world_point)
	for child in get_children():
		if child is CollisionShape2D:
			var cs := child as CollisionShape2D
			if cs.point_inside(local):
				return true
	return false
"""


_POLYFILL_COLLISION_SHAPE2D = """\
extends Node2D
class_name CollisionShape2D

## [پلی‌فیل وب] CollisionShape2D — حاملِ shape (collision لازم نیست؛ contain دستی است).
## نکته: Shape2D نیتیو هم در این بیلد غایب است ⇒ نوعِ property را Resource می‌گذاریم
## و زیرکلاس‌های پلی‌فیل (CircleShape2D/RectangleShape2D) از کشِ کلاس‌ها می‌آیند.

@export var shape: Resource = null


func point_inside(local_point: Vector2) -> bool:
	if shape == null:
		return false
	var p: Vector2 = local_point - position
	if shape is CircleShape2D:
		var c := shape as CircleShape2D
		return p.length() <= c.radius
	if shape is RectangleShape2D:
		var r := shape as RectangleShape2D
		return absf(p.x) <= r.size.x * 0.5 and absf(p.y) <= r.size.y * 0.5
	return false
"""


_POLYFILL_CIRCLE_SHAPE2D = """\
extends Resource
class_name CircleShape2D

## [پلی‌فیل وب] دایره — فقط شعاع (برخورد را بازی دستی حساب می‌کند ✓).

@export var radius: float = 32.0
"""


_POLYFILL_RECTANGLE_SHAPE2D = """\
extends Resource
class_name RectangleShape2D

## [پلی‌فیل وب] مستطیل — فقط اندازه (برخورد را بازی دستی حساب می‌کند ✓).

@export var size: Vector2 = Vector2(64.0, 40.0)
"""

_POLYFILL_FILES = {
    "res://scripts/polyfill/Area2D.gd": _PHYSICS_POLYFILL_GD,
    "res://scripts/polyfill/CollisionShape2D.gd": _POLYFILL_COLLISION_SHAPE2D,
    "res://scripts/polyfill/CircleShape2D.gd": _POLYFILL_CIRCLE_SHAPE2D,
    "res://scripts/polyfill/RectangleShape2D.gd": _POLYFILL_RECTANGLE_SHAPE2D,
}


def _patch_weight_orb_scene(files: dict[str, bytes]) -> None:
    """WeightOrb.tscn را برای بیلدِ بدون فیزیک آماده می‌کند (assertِ دقیقِ هر بلاک)."""
    path = "res://scenes/gameplay/WeightOrb.tscn"
    raw = files[path].decode("utf-8")
    # ۱) دو ext_resource در سکشنِ هدر (پیش از nodeها — قواعدِ TSCN).
    raw = _replace_once(
        raw,
        '[ext_resource type="Script" path="res://scripts/gameplay/OrbVisual.gd" id="2_visual"]',
        '[ext_resource type="Script" path="res://scripts/gameplay/OrbVisual.gd" id="2_visual"]\n'
        '[ext_resource type="Script" path="res://scripts/polyfill/CircleShape2D.gd" '
        'id="3_circle"]\n'
        '[ext_resource type="Script" path="res://scripts/polyfill/CollisionShape2D.gd" '
        'id="4_cs"]',
        path,
    )
    raw = _replace_once(raw, "[gd_scene load_steps=4 format=3]",
                        "[gd_scene load_steps=6 format=3]", path)
    # ۲) ساب‌ریسورسِ نیتیو CircleShape2D ⇒ Resource + اسکریپتِ پلی‌فیل.
    raw = _replace_once(
        raw,
        '[sub_resource type="CircleShape2D" id="CircleShape2D_orb"]\nradius = 44.0',
        '[sub_resource type="Resource" id="CircleShape2D_orb"]\n'
        'script = ExtResource("3_circle")\nradius = 44.0',
        path,
    )
    # ۳) گره‌های Area2D/CollisionShape2D ⇒ Node2D (+چسباندنِ اسکریپتِ پلی‌فیل به CS).
    raw = _replace_once(
        raw,
        '[node name="WeightOrb" type="Area2D"]\ninput_pickable = true',
        '[node name="WeightOrb" type="Node2D"]\ninput_pickable = true',
        path,
    )
    raw = _replace_once(
        raw,
        '[node name="CollisionShape2D" type="CollisionShape2D" parent="."]\n'
        'shape = SubResource("CircleShape2D_orb")',
        '[node name="CollisionShape2D" type="Node2D" parent="."]\n'
        'script = ExtResource("4_cs")\nshape = SubResource("CircleShape2D_orb")',
        path,
    )
    files[path] = raw.encode("utf-8")
    print("  · TSCN پچ شد: پلی‌فیل Area2D/CollisionShape2D/CircleShape2D درگرفت")


def _replace_once(text: str, old: str, new: str, where: str) -> str:
    if old not in text:
        raise SystemExit(f"✖ بلوکِ موردانتظار در {where} یافت نشد — ابزار را به‌روز کن")
    return text.replace(old, new, 1)


def apply_preview_transforms(files: dict[str, bytes], with_smoke: bool = False) -> None:
    """دو پچِ متنی + تزریق PreviewBoot + autoload + کشِ کلاس‌های سراسری."""
    # ۱) آیکون‌های SVG در زمان اجرا
    uikit_path = "res://scripts/ui/UIKit.gd"
    uikit = files[uikit_path].decode("utf-8")
    files[uikit_path] = _replace_once(uikit, _UIKIT_OLD, _UIKIT_NEW, uikit_path).encode("utf-8")

    # ۱ب) جایگزینیِ بی‌RegEx (ماژول regex در قالبِ این بیلد نیست ✓ فقط-بسته-وب)
    ll_path = "res://scripts/autoload/LevelLoader.gd"
    ll = files[ll_path].decode("utf-8")
    files[ll_path] = _replace_once(ll, _LL_OLD, _LL_NEW, ll_path).encode("utf-8")
    ld_path = "res://scripts/data/LevelData.gd"
    ld = files[ld_path].decode("utf-8")
    files[ld_path] = _replace_once(ld, _LD_OLD, _LD_NEW, ld_path).encode("utf-8")

    # ۱ج) در بسته‌ی npm هنوز import cacheِ FontFile نداریم؛ تمِ پروژه اگر به
    # ExtResource فونت اشاره کند پیش از اجرای PreviewBoot خطای resource loader می‌دهد.
    # فقط در کپیِ بسته، آن reference را برمی‌داریم تا PreviewBoot همان فونت را با
    # load_dynamic_font نصب کند؛ build رسمی Godot و فایلِ اصلی دست‌نخورده می‌مانند.
    theme_path = "res://themes/Nexus.tres"
    if theme_path in files:
        theme = files[theme_path].decode("utf-8")
        theme = re.sub(r'^\[ext_resource type="FontFile".*?\n', "", theme, flags=re.M)
        theme = theme.replace('default_font = ExtResource("1_medium")\n', "")
        files[theme_path] = theme.encode("utf-8")

    # ۲) PreviewBoot به‌عنوان اولین autoload
    files["res://preview/PreviewBoot.gd"] = PREVIEW_BOOT_GD.encode("utf-8")
    proj_key = "res://project.godot"
    proj = files[proj_key].decode("utf-8")
    anchor = "[autoload]\n"
    if anchor not in proj:
        raise SystemExit("✖ سکشن [autoload] در project.godot یافت نشد")
    proj = proj.replace(
        anchor, anchor + 'PreviewBoot="*res://preview/PreviewBoot.gd"\n', 1
    )
    # این artifact یک خروجی Web است، نه تنظیمات native: پنجره‌ی Pages/preview
    # معمولاً landscape است، پس باید portrait را کامل contain کند، نه اینکه با
    # `expand` ارتفاع منوی native را crop کند. Compatibility هم باید پیش از
    # راه‌اندازی renderer در project.godot باشد؛ set_setting در PreviewBoot برای
    # انتخاب renderer دیر است و باعث می‌شد 3D در Web بی‌صدا ناپدید شود.
    proj = proj.replace(
        'window/stretch/aspect="expand"',
        'window/stretch/aspect="keep"',
        1,
    )
    proj = proj.replace(
        'renderer/rendering_method="mobile"',
        'renderer/rendering_method="gl_compatibility"',
        1,
    )
    proj = proj.replace(
        'renderer/rendering_method.mobile="mobile"',
        'renderer/rendering_method.web="gl_compatibility"',
        1,
    )
    files[proj_key] = proj.encode("utf-8")

    # ۲ب) شِیپرِ فارسی — فقط-بستهٔ-وب (قالب npm TextServerAdvanced ندارد)
    files["res://preview/PersianShaper.gd"] = _shaper_content().encode("utf-8")

    # ۲ب) پلی‌فیل فیزیک دوبعدی — قبل از اسکنِ کش تا class_name «Area2D»/… ثبت شود
    for poly_path, poly_src in _POLYFILL_FILES.items():
        files[poly_path] = poly_src.encode("utf-8")
    _patch_weight_orb_scene(files)

    # ۳) کشِ کلاس‌های سراسری (فرمتِ دقیقِ خروجیِ ConfigFile موتور)
    classes: dict[str, dict] = {}
    for res_path, blob in files.items():
        if not res_path.endswith(".gd") or res_path.startswith("res://preview/"):
            continue
        src = blob.decode("utf-8")
        m = re.search(r"^class_name\s+([A-Za-z_]\w*)", src, re.M)
        if not m:
            continue
        ext = re.search(r"^extends\s+([^\s#]+)", src, re.M)
        base = ext.group(1).strip('"') if ext else "RefCounted"
        classes[m.group(1)] = {
            "base": base,
            "path": res_path,
            "is_tool": bool(re.search(r"^@tool\b", src, re.M)),
        }
    # اگر base خودش یک کلاسِ پروژه باشد، به baseِ همان ارجاع بده (رفعِ زنجیره).
    for cls in classes.values():
        seen = set()
        while cls["base"] in classes and cls["base"] not in seen:
            seen.add(cls["base"])
            cls["base"] = classes[cls["base"]]["base"]
    entries = []
    for name in sorted(classes):
        c = classes[name]
        entries.append(
            '{\n"base": &"%s",\n"class": &"%s",\n"icon": "",\n'
            '"is_abstract": false,\n"is_tool": %s,\n"language": &"GDScript",\n'
            '"path": "%s"\n}' % (c["base"], name, str(c["is_tool"]).lower(), c["path"])
        )
    cache = "list=Array[Dictionary]([%s])\n" % ", ".join(entries)
    files["res://.godot/global_script_class_cache.cfg"] = cache.encode("utf-8")
    print(f"  · کشِ کلاس‌ها: {len(classes)} ورودی")

    if with_smoke:
        files["res://preview/SmokeWeb.gd"] = SMOKE_WEB_GD.encode("utf-8")
        print("  · اسکریپت SmokeWeb.gd تزریق شد (res://preview/SmokeWeb.gd)")


# SmokeWeb — تستِ دودِ درون‌موتوری روی **خودِ بستهٔ وب** (رانتایم واقعی، در Node با
# درایورِ headless): autoloadها، فونتِ زمان‌اجراشده، ۴۵ سطح، MainMenu واقعی، و بردنِ
# سطحِ اول با `solution_spec.intended` — یعنی همان باتِ محتوا، این‌بار روی خروجیِ نهایی.
SMOKE_WEB_GD = '''extends SceneTree
# SmokeWeb (فقط با --smoke در بستهٔ وب) — اثباتِ «این فایل‌ها واقعاً بازی را بالا می‌آورند».

var _frame := 0
var _started := false


func _initialize() -> void:
	print("[SMOKE] SceneTree started")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 8 and not _started:
		_started = true
		_run()
	return false


func _fail(msg: String) -> void:
	printerr("[SMOKE][FAIL] ", msg)
	quit(2)


func _run() -> void:
	# ۱) autoloadها (از جمله PreviewBoot تزریقی)
	var names := PackedStringArray()
	for child: Node in root.get_children():
		names.append(str(child.name))
	print("[SMOKE] root children: ", names)
	for expected: String in ["EventBus", "GameState", "SaveSystem", "LevelLoader", "AudioManager", "AnalyticsManager", "PreviewBoot"]:
		if not names.has(expected):
			_fail("autoload اینجا نیست: " + expected)
			return

	# ۲) فونتِ فارسی در زمان اجرا (PreviewBoot)
	if ThemeDB.get_fallback_font() == null:
		_fail("fallback font تهی است — PreviewBoot کار نکرد")
		return
	print("[SMOKE] fallback font OK")

	probe_sanity()

	# ۲ب) پروبِ قابلیتِ موتور (گزارش، نه گیت): TextServer/RegEx/HarfBuzz — پلی‌فیلِ
	# فعلی از این‌ها مستقل است اما اگر قالبِ رسمی آمد، این پروب باید سبز شود.
	var ts_name: String = TextServerManager.get_primary_interface().get_name()
	print("[SMOKE][PROBE] text server = ", ts_name)
	print("[SMOKE][PROBE] RegEx module = ", ClassDB.class_exists("RegEx"),\n		" TextServerAdvanced class = ", ClassDB.class_exists("TextServerAdvanced"))

	# ۳) کشفِ سطح‌ها با حلقهٔ انتقال (script-بوت به autoload دیرتر از UI دست می‌یابد)
	var ids: Array = []
	for try_n: int in range(40):
		var ll: Object = root.get_node_or_null("LevelLoader")
		if ll != null:
			ids = ll.call("level_ids") as Array
			if ids.size() == 45:
				break
		await process_frame
	print("[SMOKE] levels discovered: ", ids.size())
	if ids.size() != 45:
		_fail("انتظارِ ۴۵ سطح، شد " + str(ids.size()))
		return
	var loader: Object = root.get_node("LevelLoader")

	# ۴) هر ۴۵ سطح در موتور لود می‌شوند
	for lid: String in ids:
		if loader.call("load_level", lid) == null:
			_fail("load_level null برگرداند: " + lid)
			return
	print("[SMOKE] 45/45 load_level OK")

	# ۵) MainMenu واقعی (تم/RTL/فونت روی کنترل‌ها اعمال می‌شود)
	var menu_ps := load("res://scenes/main/MainMenu.tscn") as PackedScene
	if menu_ps == null:
		_fail("MainMenu.tscn لود نشد")
		return
	root.add_child(menu_ps.instantiate())
	await process_frame
	await process_frame
	print("[SMOKE] MainMenu instantiated")

	# ۶) بردنِ سطحِ اول با solution_spec.intended (باتِ محتوا روی بستهٔ نهایی)
	ids.sort()
	var lid := str(ids[0])
	var cfg: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(str(loader.call("path_for", lid)))) as Dictionary
	var spec: Dictionary = cfg.get("solution_spec", {}) as Dictionary
	var intended: Dictionary = spec.get("intended", {}) as Dictionary
	var rows: Array = []
	for v: Variant in intended.get("right_orbs", []) as Array:
		if v is Dictionary:
			var d: Dictionary = v as Dictionary
			rows.append({"value": float(d.get("value", 0.0)), "scale": int(d.get("scale", 0))})
		else:
			rows.append({"value": float(v), "scale": 0})
	if rows.is_empty():
		_fail("solution_spec.intended خالی است: " + lid)
		return
	print("[SMOKE] winning ", lid, " with ", rows.size(), " orb(s)")
	loader.call("clear_pending_config")
	var scene: Node = loader.call("create_level_scene", lid) as Node
	if scene == null:
		_fail("create_level_scene null: " + lid)
		return
	scene.set("report_progress", false)
	scene.set("attempt_settle_sec", 0.05)
	root.add_child(scene)
	await process_frame
	await process_frame
	var tray: Array = scene.get("tray_orbs") as Array
	print("[SMOKE] add_child done: cfg keys=", scene.get("config").keys(),
		" build_on_ready=", bool(scene.get("build_on_ready")),
		" _built=", bool(scene.get("_built")), " tray=", tray.size())
	for extra: int in range(10):
		if tray.size() > 0:
			break
		await process_frame
		tray = scene.get("tray_orbs") as Array
	print("[SMOKE] بعد از انتظار: tray=", tray.size())
	var used := {}
	for row: Dictionary in rows:
		var want := float(row["value"])
		var chosen: Object = null
		for orb: Object in tray:
			if used.has(orb.get_instance_id()) or bool(orb.get("is_placed")):
				continue
			if abs(float(orb.call("weight")) - want) < 0.001:
				chosen = orb
				used[orb.get_instance_id()] = true
				break
		if chosen == null:
			var ws := PackedStringArray()
			for orb2: Object in tray:
				ws.append("%s(placed=%s)" % [str(float(orb2.call("weight"))), str(bool(orb2.get("is_placed")))])
			printerr("[SMOKE][DBG] want=", want, " tray weights=", ws)
			_fail("کرهٔ سینی برای وزنِ " + str(want) + " پیدا نشد")
			return
		# place_on_right آرایهٔ تایپ‌دار Array[WeightOrb] می‌خواهد. duplicate() روی
		# tray_orbs تایپِ همان آرایه را حفظ می‌کند ⇒ clear + push همان‌نوع می‌سازد
		# (سازندهٔ ران‌تایم با script=null در marshal خالی می‌شد ✗✓ دفعهٔ قبل).
		var bucket: Array = tray.duplicate()
		bucket.clear()
		bucket.push_back(chosen)
		scene.call("place_on_right", bucket, int(row["scale"]))
		await process_frame
	var won := false
	for i: int in range(600):
		await process_frame
		if bool(scene.call("is_won")):
			won = true
			break
	if not won:
		var snap: Dictionary = scene.call("pan_snapshot", 0)
		printerr("[SMOKE][DBG] pan_snapshot(0)=", snap)
		printerr("[SMOKE][DBG] total_placed=", scene.call("total_placed"),
			" _won=", bool(scene.get("_won")), " _built=", bool(scene.get("_built")),
			" report_progress=", bool(scene.get("report_progress")))
		_fail("حلِ قصدمند در سطحِ اول برنده نشد")
		return
	print("[SMOKE][WIN] ", lid, " won with intended solution")
	print("[SMOKE][PASS] all checks green")
	quit(0)


func probe_sanity() -> void:
	var script_ref: GDScript = load("res://preview/PersianShaper.gd") as GDScript
	if script_ref == null:
		_fail("PersianShaper.gd لود نشد")
		return
	var probes: Array = [["سلام دنیا", "ﺎﯿﻧﺩ ﻡﺎﻠﺳ"], ["ترازو", "ﻭﺯﺍﺮﺗ"], ["نمرهٔ ۱۸۰", "۰۸۱ ٔﻩﺮﻤﻧ"], ["شبكهٔ مهارت‌ها", "ﺎﻫ‌ﺕﺭﺎﻬﻣ ٔﻪﻜﺒﺷ"], ["چیدنِ کره‌ها روی کفهٔ راست", "ﺖﺳﺍﺭ ٔﻪﻔﮐ ﯼﻭﺭ ﺎﻫ‌ﻩﺮﮐ ِﻥﺪﯿﭼ"], ["کیفیتِ شکلِ بصری", "ﯼﺮﺼﺑ ِﻞﮑﺷ ِﺖﯿﻔﯿﮐ"]]
	for pair: Array in probes:
		var src_text: String = pair[0]
		var expected: String = pair[1]
		var got: String = script_ref.call("visual", src_text)
		if got != expected:
			var gb := got.to_utf8_buffer()
			var eb := expected.to_utf8_buffer()
			printerr("[SMOKE][DBG] got=", gb.hex_encode(), " exp=", eb.hex_encode())
			_fail("PersianShaper mismatch on «" + src_text + "»")
			return
	print("[SMOKE] PersianShaper probe OK")
'''


# ---------------------------------------------------------------------------
# بخش ۳) PCK v2 — آیینهٔ PackedSourcePCK::try_open_pack (file_access_pack.cpp)
# ---------------------------------------------------------------------------
PCK_MAGIC = 0x43504447  # "GDPC"
PCK_VERSION = 2
GODOT_MAJOR, GODOT_MINOR, GODOT_PATCH = 4, 7, 2


def build_pck(files: dict[str, bytes]) -> bytes:
    paths = sorted(files)
    header = bytearray()
    header += struct.pack("<IIIIIIQ", PCK_MAGIC, PCK_VERSION, GODOT_MAJOR,
                          GODOT_MINOR, GODOT_PATCH, 0, 0)  # flags=0, file_base=0
    header += b"\0" * 64  # 16×u32 reserved (V2: directory بلافصل بعد از هدر)
    dir_blob = bytearray(struct.pack("<I", len(paths)))
    ofs = len(header) + 4 + sum(4 + len(p.encode()) + 8 + 8 + 16 + 4 for p in paths)
    for p in paths:
        data = files[p]
        if ofs % 4:
            ofs += 4 - ofs % 4
        enc = p.encode("utf-8")
        dir_blob += struct.pack("<I", len(enc)) + enc
        dir_blob += struct.pack("<QQ", ofs, len(data))
        dir_blob += hashlib.md5(data).digest()
        dir_blob += struct.pack("<I", 0)
        ofs += len(data)
    out = bytearray(header + dir_blob)
    for p in paths:
        data = files[p]
        pad = (-len(out)) % 4
        out += b"\0" * pad
        assert len(out) % 4 == 0
        out += data
    _verify_pck(bytes(out), len(paths))
    return bytes(out)


def _verify_pck(blob: bytes, expect_count: int) -> None:
    """خواندنِ دوباره با همان منطقِ موتور — هر فایل: آفست/اندازه/md5 باید بخواند."""
    magic, version, *_ = struct.unpack_from("<IIIIII", blob, 0)
    assert magic == PCK_MAGIC and version == PCK_VERSION, "هدر PCK بد نوشته شد"
    pos = 4 + 4 + 12 + 4 + 8 + 64
    (count,) = struct.unpack_from("<I", blob, pos)
    pos += 4
    assert count == expect_count, "شمارِ فایل‌ها در دایرکتوری PCK غلط است"
    names = set()
    for _ in range(count):
        (ln,) = struct.unpack_from("<I", blob, pos)
        pos += 4
        path = blob[pos:pos + ln].decode("utf-8")
        pos += ln
        ofs, size = struct.unpack_from("<QQ", blob, pos)
        pos += 8 + 8
        md5 = blob[pos:pos + 16]
        pos += 16 + 4
        assert ofs + size <= len(blob), f"آفستِ بیرون‌برِ {path} در PCK"
        assert hashlib.md5(blob[ofs:ofs + size]).digest() == md5, f"md5 نامتطابق در {path}"
        names.add(path)
    assert "res://project.godot" in names
    assert "res://.godot/global_script_class_cache.cfg" in names
    assert "res://scenes/main/MainMenu.tscn" in names
    assert "res://preview/PreviewBoot.gd" in names
    print(f"  · PCK خود-آزموده شد: {count} فایل، md5ِ همه تطبیق ✓")


# ---------------------------------------------------------------------------
# بخش ۴) پوستهٔ HTML (shell رسمی + RTL/فارسی + @font-face وزیرمتن)
# ---------------------------------------------------------------------------
INDEX_HTML = """<!DOCTYPE html>
<html lang="fa" dir="rtl">
\t<head>
\t\t<meta charset="utf-8">
\t\t<meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0, viewport-fit=cover">
\t\t<title>NEXUS — Balance Realm</title>
\t\t<style>
@font-face {
\tfont-family: 'Vazirmatn';
\tsrc: url('Vazirmatn-Medium.ttf') format('truetype');
\tfont-weight: 400 700;
\tfont-display: swap;
}
html, body {
\twidth: 100%;
\theight: 100%;
\tmargin: 0;
\tpadding: 0;
\tborder: 0;
}
body {
\tcolor: white;
\tbackground-color: #1B1D3B;
\toverflow: hidden;
\ttouch-action: none;
\tfont-family: 'Vazirmatn', 'Noto Sans', Tahoma, sans-serif;
\tdisplay: flex;
\talign-items: center;
\tjustify-content: center;
}
#canvas {
\tdisplay: block;
\t/* بازی portrait است؛ در iframe landscape باید contain شود، نه اینکه
\t   با عرض کامل کشیده شود و نیمه‌ی پایینِ Controlها crop شود. */
\twidth: min(100vw, 56.25vh) !important;
\theight: min(100vh, 177.7777778vw) !important;
\tmax-width: 100vw;
\tmax-height: 100vh;
\taspect-ratio: 9 / 16;
}
#canvas:focus {
\toutline: none;
}
#status, #status-splash, #status-progress {
\tposition: absolute;
\tleft: 0;
\tright: 0;
}
#status, #status-splash {
\ttop: 0;
\tbottom: 0;
}
#status {
\tbackground-color: #2B2F77;
\tdisplay: flex;
\tflex-direction: column;
\tjustify-content: center;
\talign-items: center;
\tgap: 1.25rem;
\tvisibility: hidden;
}
#status-splash {
\tmax-height: 34vh;
\tmax-width: 70vw;
}
#status-progress {
\twidth: min(60%, 22rem);
\theight: 0.5rem;
\tborder-radius: 999px;
\toverflow: hidden;
\tappearance: none;
}
#status-progress::-webkit-progress-bar { background: rgba(255,255,255,0.15); }
#status-progress::-webkit-progress-value { background: #F4C95D; border-radius: 999px; }
#status-progress::-moz-progress-bar { background: #F4C95D; border-radius: 999px; }
#status-title {
\tcolor: #FBF9F4;
\tfont-size: 1.6rem;
\tfont-weight: 700;
\tletter-spacing: 0;
}
#status-sub {
\tcolor: #4FD1C5;
\tfont-size: 1.05rem;
}
#progress-note, #status-notice { display: none; }
#status-notice {
\tbackground-color: #5b3943;
\tborder-radius: 0.5rem;
\tborder: 1px solid #9b3943;
\tcolor: #e0e0e0;
\tline-height: 1.6;
\tmargin: 0 2rem;
\toverflow: hidden;
\tpadding: 1rem;
\ttext-align: center;
\tz-index: 1;
\tdirection: ltr;
}
\t\t</style>
\t\t<link rel="icon" type="image/svg+xml" href="icon.svg">
\t</head>
\t<body>
\t\t<canvas id="canvas">
\t\t\tمرورگر شما canvas را پشتیبانی نمی‌کند.
\t\t</canvas>
\t\t<noscript>
\t\t\tبرای اجرای NEXUS به JavaScript نیاز است.
\t\t</noscript>
\t\t<div id="status">
\t\t\t<img id="status-splash" src="icon.svg" alt="NEXUS">
\t\t\t<div id="status-title">NEXUS — دنیای ترازو</div>
\t\t\t<div id="status-sub">در حال آماده‌سازی… با آریا چراغ را روشن کن ✨</div>
\t\t\t<progress id="status-progress"></progress>
\t\t\t<div id="status-notice"></div>
\t\t</div>
\t\t<script>
\t\t// گاردِ خطای بوت ✓✗ اگر ماژولِ موتور بالا نیاید یا کرش کند، صفحه بی‌صدا سیاه نمی‌ماند:
\t\t// پیام روی همان اورلیِ وضعیت می‌نشیند (بدون این گارد، خطای import روی مرورگرِ قدیمی = «هیچی» ✗✓)
\t\t// فقط در پیش‌نمایشِ sandbox (هاستِ e2b.app) بیکن به سرورِ محلی می‌رود تا لاگ خوانا باشد ✓
\t\t// روی Pages هیچ شبکه‌ای صدا نمی‌شود — همان سیاستِ «هیچ شخص ثالثی» ✓✓
\t\t(function () {
\t\t\tfunction report(msg) {
\t\t\t\tvar s = document.getElementById("status");
\t\t\t\tvar n = document.getElementById("status-notice");
\t\t\t\tif (s && n) {
\t\t\t\t\ts.style.visibility = "visible";
\t\t\t\t\tn.style.display = "block";
\t\t\t\t\tn.textContent = "خطا در اجرای بازی: " + msg;
\t\t\t\t}
\t\t\t\tif (location.hostname.slice(-8) === ".e2b.app") {
\t\t\t\t\ttry { fetch("/__booterr?m=" + encodeURIComponent(String(msg).slice(0, 200))); } catch (_) {}
\t\t\t\t}
\t\t\t}
\t\t\twindow.addEventListener("error", function (e) {
\t\t\t\tif (e.message) { report(e.message + (e.filename ? " @" + e.filename.split("/").pop() + ":" + e.lineno : "")); }
\t\t\t\telse if (e.target && (e.target.src || e.target.href)) { report("بارگیریِ منبع ناموفق: " + (e.target.src || e.target.href).split("/").pop()); }
\t\t\t}, true);
\t\t\twindow.addEventListener("unhandledrejection", function (e) {
\t\t\t\tvar r = e.reason;
\t\t\t\treport((r && r.message) ? r.message : String(r));
\t\t\t});
\t\t}());
\t\t</script>
\t\t<script type="module" src="engine_bundle.mjs"></script>
\t</body>
</html>
"""

# منطقِ boot دقیقاً همان shell رسمی است (هم ids هم رفتار) — فقط متنِ خطا فارسی شده.
# در ماژولِ bundle، `Godot` (import از runtime.js) و `Engine` (از engine.js) هر دو
# در دید هستند؛ engine.js خودش window.Engine را هم می‌سازد.
BOOTSTRAP_JS = """
// ---------------------------------------------------------------------------
// bootstrap (اقتباسِ shell رسمی misc/dist/html/full-size.html با متنِ فارسی)
// ---------------------------------------------------------------------------
const GODOT_CONFIG = __GODOT_CONFIG__;
const engine = new Engine(GODOT_CONFIG);
// threads خاموش (قالبِ nothreads) ⇒ هیچ هدر COOP/COEP لازم نیست.
(function () {
\tconst statusOverlay = document.getElementById('status');
\tconst statusProgress = document.getElementById('status-progress');
\tconst statusNotice = document.getElementById('status-notice');
\tlet initializing = true;
\tlet statusMode = '';
\tfunction setStatusMode(mode) {
\t\tif (statusMode === mode || !initializing) { return; }
\t\tif (mode === 'hidden') { statusOverlay.remove(); initializing = false; return; }
\t\tstatusOverlay.style.visibility = 'visible';
\t\tstatusProgress.style.display = mode === 'progress' ? 'block' : 'none';
\t\tstatusNotice.style.display = mode === 'notice' ? 'block' : 'none';
\t\tstatusMode = mode;
\t}
\tfunction setStatusNotice(text) {
\t\twhile (statusNotice.lastChild) { statusNotice.removeChild(statusNotice.lastChild); }
\t\ttext.split('\\n').forEach((line) => {
\t\t\tstatusNotice.appendChild(document.createTextNode(line));
\t\t\tstatusNotice.appendChild(document.createElement('br'));
\t\t});
\t}
\tfunction displayFailureNotice(err) {
\t\tconsole.error(err);
\t\tif (err instanceof Error) { setStatusNotice(err.message); }
\t\telse if (typeof err === 'string') { setStatusNotice(err); }
\t\telse { setStatusNotice('خطای ناشناخته در اجرای بازی.'); }
\t\tsetStatusMode('notice');
\t\tinitializing = false;
\t}
\tconst missing = Engine.getMissingFeatures({ threads: false });
\tif (missing.length !== 0) {
\t\tdisplayFailureNotice('مرورگر شما امکانات لازم برای NEXUS را ندارد:\\n' + missing.join('\\n'));
\t} else {
\t\tsetStatusMode('progress');
\t\tengine.startGame({
\t\t\t'onProgress': function (current, total) {
\t\t\t\tif (current > 0 && total > 0) {
\t\t\t\t\tstatusProgress.value = current;
\t\t\t\t\tstatusProgress.max = total;
\t\t\t\t} else {
\t\t\t\t\tstatusProgress.removeAttribute('value');
\t\t\t\t\tstatusProgress.removeAttribute('max');
\t\t\t\t}
\t\t\t},
\t\t}).then(() => {
\t\t\tsetStatusMode('hidden');
\t\t}, displayFailureNotice);
\t}
}());
"""


def write_shell(tpl_dir: Path, out_dir: Path, sizes: dict[str, int],
                engine_dir: Path | None = None) -> None:
    if engine_dir is None:
        engine_dir = tpl_dir / "engine"
    config = {
        "canvasResizePolicy": 1,
        "experimentalVK": False,
        "focusCanvas": True,
        "gdextensionLibs": [],
        "executable": "index",
        "mainPack": "index.pck",
        "args": [],
        "fileSizes": sizes,
        "ensureCrossOriginIsolationHeaders": False,
        "godotPoolSize": 0,
        "emscriptenPoolSize": 0,
    }
    bootstrap = BOOTSTRAP_JS.replace(
        "__GODOT_CONFIG__", json.dumps(config, ensure_ascii=False)
    )
    bundle = ["import Godot from './runtime.js';\n",
              "// فایل‌های رسمی wrapper موتور (godotengine/godot@4.7.2-stable)\n"]
    for name in ENGINE_JS_FILES:
        bundle.append((engine_dir / name).read_text(encoding="utf-8"))
        bundle.append("\n")
    bundle.append(bootstrap)
    (out_dir / "engine_bundle.mjs").write_text("".join(bundle), encoding="utf-8")
    (out_dir / "index.html").write_text(INDEX_HTML, encoding="utf-8")


# ---------------------------------------------------------------------------
# بخش ۵) قالب‌های wasm/js (کش + fetch از npm mirror)
# ---------------------------------------------------------------------------
def ensure_templates() -> Path:
    need_npm = [n for n in NPM_PREFIX_FILES if not (TEMPLATE_CACHE / n).exists()]
    TEMPLATE_CACHE.mkdir(parents=True, exist_ok=True)
    if need_npm:
        print(f"  · دریافت قالبِ وب از npm: {NPM_TGZ_URL}")
        try:
            with urllib.request.urlopen(NPM_TGZ_URL, timeout=300) as resp:
                payload = resp.read()
        except OSError as exc:
            raise SystemExit(f"✖ دریافت قالب شکست خورد: {exc}") from exc
        with tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz") as tar:
            for member in tar.getmembers():
                name = Path(member.name).name
                if name in NPM_PREFIX_FILES:
                    src = tar.extractfile(member)
                    if src is None:
                        continue
                    (TEMPLATE_CACHE / name).write_bytes(src.read())
    engine_dir = TEMPLATE_CACHE / "engine"
    need_engine = [n for n in ENGINE_JS_FILES if not (engine_dir / n).exists()]
    if need_engine:
        print(f"  · دریافت wrapper رسمی Engine از سورس: {GODOT_SRC_TARBALL}")
        engine_dir.mkdir(parents=True, exist_ok=True)
        try:
            with urllib.request.urlopen(GODOT_SRC_TARBALL, timeout=600) as resp:
                payload = resp.read()
        except OSError as exc:
            raise SystemExit(f"✖ دریافت سورس شکست خورد: {exc}") from exc
        with tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz") as tar:
            for member in tar.getmembers():
                parts = Path(member.name).parts
                if len(parts) == 6 and parts[-3:-1] == ("js", "engine") and \
                        parts[-1] in ENGINE_JS_FILES:
                    src = tar.extractfile(member)
                    if src is not None:
                        (engine_dir / parts[-1]).write_bytes(src.read())
    missing = [n for n in NPM_PREFIX_FILES if not (TEMPLATE_CACHE / n).exists()]
    missing += [f"engine/{n}" for n in ENGINE_JS_FILES if not (engine_dir / n).exists()]
    if missing:
        raise SystemExit(f"✖ فایل‌های قالب ناقص‌اند: {missing}")
    print(f"  · قالب → {TEMPLATE_CACHE}")
    return TEMPLATE_CACHE


# ---------------------------------------------------------------------------
# اصلی
# ---------------------------------------------------------------------------
def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=str(DEFAULT_OUT), help="پوشهٔ خروجی استاتیک")
    parser.add_argument("--smoke", action="store_true",
                        help="تزریق SmokeWeb.gd برای تستِ دودِ درون‌موتوری (headless)")
    parser.add_argument("--template-dir", default=None,
                        help="پوشهٔ جایگزین قالب (wasm+glue جفتِ یکسان — مثلاً بیلدِ کامل با فیزیک دوبعدی)")
    args = parser.parse_args()
    out_dir = Path(args.out)

    print("۱) جمع‌آوری فایل‌های بازی…")
    files = collect_project_files()
    print(f"  · {len(files)} فایل، {sum(len(v) for v in files.values()) / 1e6:.2f} MB خام")

    print("۲) ترانسفورم‌های پیش‌نمایش…")
    apply_preview_transforms(files, with_smoke=args.smoke)

    print("۳) ساخت index.pck (V2)…")
    pck = build_pck(files)  # خودش md5/آفست را دوباره می‌خواند و بررسی می‌کند ✓

    print("۴) قالب‌های وب…")
    if args.template_dir:
        tpl = Path(args.template_dir)
        missing = [n for n in NPM_PREFIX_FILES if not (tpl / n).exists()]
        if missing:
            raise SystemExit(f"✖ قالبِ جایگزین ناقص است: {missing}")
        print(f"  · قالبِ جایگزین → {tpl}")
    else:
        tpl = ensure_templates()

    print("۵) نوشتنِ خروجی…")
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True)
    for src_name, out_name in NPM_PREFIX_FILES.items():
        shutil.copyfile(tpl / src_name, out_dir / out_name)
    (out_dir / "index.pck").write_bytes(pck)
    shutil.copyfile(GAME_DIR / "icon.svg", out_dir / "icon.svg")
    shutil.copyfile(
        GAME_DIR / "assets" / "fonts" / "Vazirmatn-Medium.ttf",
        out_dir / "Vazirmatn-Medium.ttf",
    )
    engine_dir = tpl / "engine"
    if not engine_dir.is_dir():
        engine_dir = ensure_templates() / "engine"  # wrapper رسمی همیشه از کش
    write_shell(tpl, out_dir, {"index.wasm": (out_dir / "index.wasm").stat().st_size,
                               "index.pck": len(pck)}, engine_dir=engine_dir)

    total = sum(f.stat().st_size for f in out_dir.iterdir())
    print("—" * 60)
    print(f"✔ آماده: {out_dir}  (کل: {total / 1e6:.1f} MB)")
    for f in sorted(out_dir.iterdir(), key=lambda p: -p.stat().st_size):
        print(f"    {f.name:38s} {f.stat().st_size / 1e6:8.2f} MB")
    print("اجرا: python3 -m http.server 8080 --bind 0.0.0.0 --directory", out_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
