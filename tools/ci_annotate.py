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
خطِ «✖/✗/FAIL/error» — حداکثر ۱۲ مورد، بریده‌شده به ۹۰۰ نویسه.
"""

from __future__ import annotations

import argparse
import re
import sys

MAX_ANNOTATIONS = 12
MAX_LEN = 900

PATTERNS = [
    re.compile(r"\[Failed\]", re.I),
    re.compile(r"failing tests", re.I),
    re.compile(r"SCRIPT ERROR", re.I),
    re.compile(r"Parse Error", re.I),
    re.compile(r"^ERROR:", re.I),
    re.compile(r"at line (\d+)", re.I),
    re.compile(r"\borphan\b", re.I),
    re.compile(r"✖|✗|FAILED", re.I),
]

AT_LINE = re.compile(r"at line (\d+)", re.I)


def annotate(text: str, title: str, path: str) -> int:
    lines = text.splitlines()
    picked: list[tuple[int, str]] = []
    for i, raw in enumerate(lines):
        s = raw.strip()
        if not s:
            continue
        if any(p.search(s) for p in PATTERNS):
            picked.append((i + 1, s))
    # خط‌های «at line N» مربوط به fail قبلی را با آن ادغام کن تا context داشته باشیم
    merged: list[tuple[int, str]] = []
    for lineno, s in picked:
        if AT_LINE.search(s) and merged:
            prev_line, prev = merged[-1]
            merged[-1] = (prev_line, f"{prev} {s}")
        else:
            merged.append((lineno, s))
    if not merged:
        tail = lines[-MAX_ANNOTATIONS:] if lines else [f"{title}: لاگی یافت نشد"]
        merged = [(len(lines) - len(tail) + i + 1, t) for i, t in enumerate(tail)]

    def esc(x: str) -> str:
        return x.replace("%", "%25").replace("\r", "").replace("\n", "%0A")

    for lineno, msg in merged[:MAX_ANNOTATIONS]:
        body = f"{title}: {msg}"[:MAX_LEN]
        print(f"::error file={path},line={lineno}::{esc(body)}")
    # نشانه‌ی «چند مورد دیگر مانده» تا معلوم شود خلاصه شده
    if len(merged) > MAX_ANNOTATIONS:
        print(f"::error file={path},line=1::{esc(f'{title}: و {len(merged) - MAX_ANNOTATIONS} مورد دیگر (لاگ کامل در run)')}")
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
