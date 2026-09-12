#!/usr/bin/env python3
"""
NEXUS — tools/ci_annotate.py
============================
چند خط از لاگ را به «annotation» تبدیل می‌کند تا شکستِ CI بدون دسترسی به لاگ‌های
GitHub (artifact/log در محیط‌های sandboxed ممکن نیست) از طریق API قابل‌خواندن باشد:

    gh api repos/<owner>/<repo>/check-runs/<id>/annotations --jq '.annotations[].message'

استفاده در workflow:
    - name: Annotate failures
      if: failure()
      run: python3 tools/ci_annotate.py gut.log --title "GUT"

قوانین استخراج: خطاهای Godot/GUT، خط‌های `at line`، خلاصه‌ی نتایج، و هر
خطِ «✖/✗/FAIL/error» — حداکثر MAX_ANNOTATIONS بسته، هر بسته MAX_LEN نویسه (و جزئیات
خطا از خط‌های بعد از `[Failed]` هم برداشته می‌شود).
"""

from __future__ import annotations

import argparse
import re
import sys

MAX_ANNOTATIONS = 16  # GitHub تا ۵۰ annotation برای هر check-run نگه می‌دارد
MAX_LEN = 2400
LINES_PER_ANNOTATION = 8
## وقتی هیچ خطای شناختی نیست: چند خط آخر لاگ را بفرست (قدیم MAX_ANNOTATIONS بود → NameError)
MAX_LINES = 60

PATTERNS = [
    re.compile(r"\[Failed\]", re.I),
    re.compile(r"failing tests", re.I),
    re.compile(r"SCRIPT ERROR", re.I),
    re.compile(r"Parse Error", re.I),
    re.compile(r"^ERROR:", re.I),
    re.compile(r"at line (\d+)", re.I),
    re.compile(r"\borphan\b", re.I),
    re.compile(r"\bFAILED\b", re.I),
]
## `✗/✖` عمداً الگو **نیست** ✓✗ پیام‌های تستِ ما (`assert_true(x, "... ✗✓")`) این علامت‌ها را
## دارند، پس هر `[Passed]` هم «خطا» حساب می‌شد: در ۸.۴ دقیقاً همین، ۱۰ انوتیشنِ اول را با
## سطرهای Passed پُر کرد و نامِ ۴ تستِ شکسته هیچ‌وقت دیده نشد ✗✗ (دو دور CI سوخت ✓✓).
NOISE = re.compile(r"^\[Passed\]|^\[Reset\]", re.I)
SERIOUS = re.compile(r"\[Failed\]|SCRIPT ERROR|Parse Error|^ERROR:", re.I)

AT_LINE = re.compile(r"at line (\d+)", re.I)


def _context_for(lines: list[str], idx: int) -> list[str]:
    """خط نامِ تستِ بالایی را هم بردار تا معلوم باشد کدام test شکسته است."""
    out: list[str] = []
    j = idx - 1
    while j >= 0 and len(out) < 2:
        prev = lines[j].strip()
        if re.match(r"^(\*|[-\u2022])\s*test_", prev) or prev.startswith("* "):
            out.insert(0, prev)
            break
        j -= 1
    return out


def _trailing(lines: list[str], idx: int, limit: int = 5) -> list[str]:
    """جزئیاتی که GUT **بعد از** خطِ `[Failed]` می‌نویسد.

    بی‌این، انوتیشن فقط `- test_the_widgets_show_what_is_stored / Unexpected Errors:`
    را می‌داد و هیچ‌کس نمی‌فهمید کدام ERROR مقصر است؛ یعنی یک دور CI کامل برای
    «خواندنِ خطا» سوخت ✓ (خطای واقعیِ همین فاز، همین بود: سه دور برای دو سطر.)
    """
    out: list[str] = []
    j = idx + 1
    while j < len(lines) and len(out) < limit:
        nxt = lines[j].strip()
        if not nxt or nxt.startswith("[Passed]") or nxt.startswith("----") \
                or re.match(r"^\*\s+test_", nxt):
            break
        out.append(nxt)
        j += 1
    return out


def annotate(text: str, title: str, path: str) -> int:
    lines = text.splitlines()
    picked: list[tuple[int, str]] = []
    for i, raw in enumerate(lines):
        s = raw.strip()
        if not s or NOISE.search(s):
            continue
        if any(p.search(s) for p in PATTERNS):
            for ctx in _context_for(lines, i):
                if ctx not in [c for _, c in picked]:
                    picked.append((i + 1, ctx))
            picked.append((i + 1, s))
            if s.endswith(":") and "error" in s.lower():
                for nxt in _trailing(lines, i):
                    picked.append((i + 1, nxt))
            elif s.startswith("SCRIPT ERROR") or s.startswith("ERROR:"):
                # Godot محل خطا را در خطِ **بعد** می‌نویسد: `at: f (res://x.gd:12)` ✗ بدون
                # آن «یک چیز crash کرد» هیچ آدرسی ندارد.
                for nxt in _trailing(lines, i, limit=1):
                    if nxt.startswith("at:"):
                        picked.append((i + 1, nxt))
    # خط‌های «at line N» را با fail قبلی ادغام کن تا آدرس فایل/خط مشخص بماند
    merged: list[tuple[int, str]] = []
    for lineno, s in picked:
        if AT_LINE.search(s) and merged:
            prev_line, prev = merged[-1]
            merged[-1] = (prev_line, f"{prev} {s}")
        elif merged and merged[-1][1] == s:
            continue
        else:
            merged.append((lineno, s))
    # GitHub از مسیر `::error::` تنها **۱۰** انوتیشن را نگه می‌دارد ⇒ هرچه جدی‌تر،
    # زودتر ✓ (قبلاً به ترتیبِ لاگ بود و سطرهای پر‌سروصدا جلوی خطای واقعی را می‌گرفتند ✗✓)
    merged.sort(key=lambda t: 0 if SERIOUS.search(t[1]) else 1)
    if not merged:
        tail = lines[-MAX_LINES:] if lines else [f"{title}: لاگی یافت نشد"]
        merged = [(len(lines) - len(tail) + i + 1, t) for i, t in enumerate(tail)]

    def esc(x: str) -> str:
        return x.replace("%", "%25").replace("\r", "").replace("\n", "%0A")

    # بسته‌بندی: چند خط در هر annotation (GitHub هر check-run را به ۵۰ تا محدود می‌کند،
    # API همه را برمی‌گرداند → با batch، ۳۵ fail هم کامل خوانده می‌شود)
    batches: list[tuple[int, list[str]]] = []
    for lineno, s in merged:
        if batches and len(batches[-1][1]) < LINES_PER_ANNOTATION and \
                sum(len(x) for x in batches[-1][1]) + len(s) < MAX_LEN:
            batches[-1][1].append(s)
        else:
            batches.append((lineno, [s]))
    for i, (lineno, batch) in enumerate(batches[:MAX_ANNOTATIONS]):
        body = f"{title} (بخش {i + 1}/{min(len(batches), MAX_ANNOTATIONS)}):\n" + "\n".join(batch)
        print(f"::error file={path},line={lineno}::{esc(body[:MAX_LEN + 200])}")
    if len(batches) > MAX_ANNOTATIONS:
        print(f"::error file={path},line=1::{esc(f'{title}: و {len(batches) - MAX_ANNOTATIONS} بخش دیگر (لاگ کامل در run)')}")
    return len(merged)


def main() -> int:
    ap = argparse.ArgumentParser(description="Godot/GUT log -> GitHub annotations")
    ap.add_argument("logs", nargs="+", help="مسیر فایل(های) لاگ")
    ap.add_argument("--title", default="CI")
    ap.add_argument("--path", default=".github/workflows/ci.yml", help="مسیری که در annotation نمایش داده می‌شود")
    args = ap.parse_args()

    total = 0
    for log in args.logs:
        try:
            with open(log, encoding="utf-8", errors="replace") as f:
                total += annotate(f.read(), args.title, log if log != "-" else args.path)
        except FileNotFoundError:
            print(f"::error::{args.title}: فایل لاگ {log} پیدا نشد (step قبل از اجرا fail شده؟)")
            total += 1
    # خروجی کامل هم چاپ شود تا در لاگ‌های قابل‌دسترس باشد
    for log in args.logs:
        try:
            print(f"\n----- {log} (tail 60) -----")
            with open(log, encoding="utf-8", errors="replace") as f:
                print("\n".join(f.read().splitlines()[-60:]))
        except FileNotFoundError:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
