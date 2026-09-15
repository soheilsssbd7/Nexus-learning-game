#!/usr/bin/env python3
"""سایتِ محصول (تسک ۱۲.۴ · GitHub Pages) — یک‌سازِ `site/**` و `index.html` ✓✓

چرا *تولیدشده و commit‌شده* و نه «ساخته‌شده در CI»؟ ✗✓ چون Pagesِ این ریپو روی
`build_type: legacy` + `source: {branch, path:"/"}` تنظیم شده ✓✗ یعنی **خودِ برانچ** منتشر
می‌شود؛ پس فایل‌های html باید در مخزن باشند ✓ و برای اینکه دو نسخه (سورسِ مخزن ↔ منتشرشده)
از هم دور نیفتند، گیتِ `check_site()` همین اسکریپت را با `--check` اجرا می‌کند و هر اختلافِ
بایتی را قرمز می‌کند ✓✓ (ساخت‌در-CI هم می‌شد ولی آن‌وقت «سایتِ روی Pages» با «سایتِ روی دیسک»
یکی نبود ✗ و دروازهٔ لینک‌شکسته بی‌معنی می‌شد ✓)

اصلِ دوم: **سایت هیچ متنِ مستقلی ندارد که با سندِ خودش در تناقض بیفتد** ✓✗ سیاستِ حریم‌خصوصی
مستقیماً از `docs/privacy-policy-{fa,en}.md` رندر می‌شود ✓✓ (تک‌منبع ⇒ «صفحهٔ وب» و «سند»
هیچ‌وقت دوشاخه نمی‌شوند ✗ که دقیقاً همان چیزی است که Play در Data Safety دنبالش است ✓)

`--check` ⇒ اختلاف را چاپ می‌کند و exit 1 ✓ | بدون آرگومان ⇒ می‌سازد ✓
"""
from __future__ import annotations

import html as _html
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "site"
SRC = ROOT / "site_src"
DOCS = ROOT / "docs"
VERSION = (ROOT / "VERSION").read_text(encoding="utf-8").strip() if (ROOT / "VERSION").exists() else "0"


def facts() -> dict[str, str]:
    """عددِ صفحه‌های سایت **تولید می‌شود**، تایپ نمی‌شود ✓✓ (بیماریِ «عددِ منجمد در متن» ✓
    همان دلیلی که `docs/00` هم شمارۀ ADR را از متن حذف کرد): اگر تست/سطح/گیت عوض شود،
    `--check` می‌گوید سایت کهنه است ✗✓ و Pages عددِ دروغ نمی‌بیند ✓"""
    tests = gates = levels = 0
    for f in sorted((ROOT / "game" / "tests").rglob("test_*.gd")) if (ROOT / "game" / "tests").exists() else []:
        tests += len(re.findall(r"^\s*func test_", f.read_text(encoding="utf-8"), re.M))
    v = ROOT / "tools" / "validate_levels.py"
    if v.exists():
        gates = len(re.findall(r"^def check_", v.read_text(encoding="utf-8"), re.M))
    ld = ROOT / "game" / "data" / "levels"
    if ld.exists():
        levels = len(list(ld.rglob("level_*.json")))
    return {"VERSION": VERSION, "TESTS": str(tests), "GATES": str(gates), "LEVELS": str(levels)}


def fill(text: str) -> str:
    for k, v in facts().items():
        text = text.replace("{{" + k + "}}", v)
    if "{{" in text:
        bad = sorted(set(re.findall(r"\{\{([A-Z_]+)\}\}", text)))
        raise SystemExit(f"build_site: متغیرِ ناشناخته در منبع ✗ {bad} (مجاز: VERSION/TESTS/GATES/LEVELS)")
    return text

MARK = ("<!-- ⚠ تولیدشده با `tools/build_site.py` از {src} ✓✗ ویرایشِ دستِ این فایل "
        "بی‌معنی است (گیتِ `check_site` اختلاف را قرمز می‌کند) -->")

# پالت از §۲ کتاب هنری ✓✗ همان رنگ‌های بازی در سایت هم استفاده می‌شود (قاعدهٔ «یک منبع، دو مصرف»
# ✓ ADR-058) و گیت هم همین فهرست را از docs/02 می‌خواند ⇒ اگر پالت عوض شود، سایت قرمز می‌شود ✓
PALETTE = {
    "gold": "#F4C95D",
    "indigo": "#2B2F77",
    "coral": "#FF7A5C",
    "teal": "#4FD1C5",
    "cloud": "#FBF9F4",
    "stone": "#8A8FA3",
    "violet": "#B79CED",
}

PAGES = {  # فایلِ منبع → (خروجی، زبان، جهت) ✓ `docs/` = منبعِ بیرونیِ همان سند ✓
    "index.md": ("index.html", "fa", "rtl"),
    "index-en.md": ("index-en.html", "en", "ltr"),
    "parents.md": ("parents.html", "fa", "rtl"),
    "support.md": ("support.html", "fa", "rtl"),
    "feedback.md": ("feedback.html", "fa", "rtl"),
    "game.md": ("game.html", "fa", "rtl"),
    "404.md": ("404.html", "fa", "rtl"),
}
POLICIES = {
    "../docs/privacy-policy-fa.md": ("privacy.html", "fa", "rtl", "سیاست حریم خصوصی — NEXUS"),
    "../docs/privacy-policy-en.md": ("privacy-en.html", "en", "ltr", "Privacy Policy — NEXUS"),
}


def inline(text: str) -> str:
    """`**bold**` و ``code`` و [لینک](هدف) ✓✗ بدونِ HTML خام ✓ (ورودیِ ما از مخزن است، نه از کاربر ✓)"""
    out = _html.escape(text, quote=False)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)", _link, out)
    return out


def _link(m: re.Match) -> str:
    label, href = m.group(1), m.group(2)
    ext = ' rel="noopener"' if href.startswith(("http", "mailto:")) else ""
    return f'<a href="{href}"{ext}>{label}</a>'


def render_md(text: str) -> str:
    """مارک‌داونِ *محدود* ✓✗ دقیقاً به اندازهٔ چیزی که در `docs/` و `site_src/` نوشته‌ایم؛
    هیچ‌وقت یک پیاده‌سازِ کاملِ CommonMark نیست (و گیتِ `check_site` مطمئن می‌شود که هیچ
    بلوکِ پشتیبانی‌نشده‌ای — مثلاً جدول — واردِ صفحاتِ منتشرشده نشده ✓✗ وگرنه جدول به‌صورت
    متنِ خامِ زشت روی Pages می‌افتاد و کسی تا بازبینیِ انسانی نمی‌فهمید ✓)"""
    lines = text.splitlines()
    out: list[str] = []
    para: list[str] = []
    mode = ""  # "" | "ul" | "ol"
    open_item: str | None = None

    def flush_para() -> None:
        if para:
            out.append("<p>" + inline(" ".join(para)).strip() + "</p>")
            para.clear()

    def flush_list() -> None:
        # `open_item` باید **پیش از** </ul> بسته شود ✓✗ قبلاً ادامۀ سطرِ یک آیتم به <p>
        # جدا تبدیل می‌شد و بیرونِ لیست می‌نشست ⇒ رندرِ شکسته روی Pages + flagِ گمراه‌کننده ✓✓
        nonlocal mode, open_item
        if open_item is not None:
            out.append("<li>" + open_item + "</li>")
            open_item = None
        if mode:
            out.append(f"</{mode}>")
            mode = ""

    for raw in lines:
        line = raw.rstrip()
        if not line.strip():
            flush_para()
            flush_list()
            continue
        if line.startswith("<!--"):  # کامنتِ مارک‌داون در سندِ منبع ⇒ در HTML هم بماند ✓ (راهنمای ویرایش)
            flush_para(); flush_list()
            out.append(line)
            continue
        m = re.match(r"^(#{1,4})\s+(.*)$", line)
        if m:
            flush_para(); flush_list()
            lvl = len(m.group(1))
            out.append(f"<h{lvl}>{inline(m.group(2))}</h{lvl}>")
            continue
        if re.match(r"^\s*\|", line):
            raise SystemExit(f"build_site: جدول در منبعِ منتشرشده پشتیبانی نمی‌شود ✗ ({line[:40]}) "
                             "(جدول را به `docs/` ببرید که روی Pages رندر نمی‌شود ✓)")
        if re.match(r"^\s*</?(?:div|section|aside|details|summary|figure|span)\b", line):
            # بلوک‌های چیدمانِ `site_src` ✓✗ فقط در *منبعِ سایت* مجازند (سندِ `docs/` تمیز است ✓)
            # و هیچ‌وقت ورودیِ بیرونی نیستند ⇒ تزریقِ HTML ممکن نیست، چون همه‌چیز از مخزن می‌آید ✓
            flush_para(); flush_list()
            raw = line.strip()
            raw = re.sub(r"`([^`]+)`", r"<code>\1</code>", raw)
            raw = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", raw)
            out.append(raw)
            continue
        m = re.match(r"^\s*[-*]\s+(.*)$", line)
        if m:
            flush_para()
            if mode != "ul":
                flush_list()
                out.append("<ul>")
                mode = "ul"
            open_item = inline(m.group(1))
            continue
        if mode and open_item is not None and line[:1].isspace():
            # سطرِ ادامهٔ همان آیتم است ✓✗ نه پاراگرافِ جدید
            open_item += " " + inline(line.strip())
            continue
        m = re.match(r"^\s*(\d+)\.\s+(.*)$", line)
        if m:
            flush_para()
            if mode != "ol":
                flush_list()
                out.append("<ol>")
                mode = "ol"
            open_item = inline(m.group(2))
            continue
        m = re.match(r"^\s*>\s?(.*)$", line)
        if m:
            flush_para(); flush_list()
            out.append(f"<blockquote><p>{inline(m.group(1))}</p></blockquote>")
            continue
        para.append(line.strip())
    flush_para()
    flush_list()
    return "\n".join(out)


def read_src(path: Path) -> tuple[dict[str, str], str]:
    """front-matterِ اختیاری (`---` … `---`) + بدن ✓✗ `docs/*` front-matter ندارد ⇒ پیش‌فرض ✓"""
    text = path.read_text(encoding="utf-8")
    meta: dict[str, str] = {}
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if m:
        for line in m.group(1).splitlines():
            if ":" in line:
                k, v = line.split(":", 1)
                meta[k.strip()] = v.strip()
        text = text[m.end():]
    return meta, text


def page(title: str, body: str, lang: str, direction: str, desc: str, src: str,
         rel: str = "") -> str:
    nav = [
        ("index.html", "خانه", "Home"),
        ("privacy.html", "حریم خصوصی", "Privacy"),
        ("parents.html", "راهنمای والدین", "For parents"),
        ("support.html", "پشتیبانی", "Support"),
        ("feedback.html", "بازخورد", "Feedback"),
        ("game.html", "نسخۀ وب", "Web build"),
    ]
    cur = rel
    links = " ".join(
        f'<a href="{cur}{f}"{" class=on" if f == cur else ""}>{fa if lang == "fa" else en}</a>'
        for f, fa, en in nav
    )
    alt = "index-en.html" if lang == "fa" else "index.html"
    return f"""<!doctype html>
<html lang="{lang}" dir="{direction}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{_html.escape(title)}</title>
<meta name="description" content="{_html.escape(desc)}">
<link rel="stylesheet" href="{cur}assets/site.css">
<link rel="alternate" hreflang="{('en' if lang == 'fa' else 'fa')}" href="{cur}{alt}">
{MARK.format(src=src)}
</head>
<body>
<header class="top">
  <a class="brand" href="{cur}index.html">
    <span class="bal" aria-hidden="true"></span>
    <span class="name">NEXUS<span class="sub"> Balance Realm</span></span>
  </a>
  <nav class="links">{links} <a class="alt" href="{cur}{alt}">{"EN" if lang == "fa" else "فا"}</a></nav>
</header>
<main class="{direction}">
{body}
</main>
<footer class="foot">
  <p>{_html.escape("NEXUS: Balance Realm")} · v{VERSION} ·
     <a href="{cur}privacy.html">{"سیاست حریم خصوصی" if lang == "fa" else "Privacy policy"}</a> ·
     <a href="{cur}support.html">{"پشتیبانی و حذف داده" if lang == "fa" else "Support & data deletion"}</a></p>
  <p class="small">{"بدون تبلیغات، بدون خرید درون‌اپ، بدون SDK شخص ثالث — و این ادعا را گیت‌های CI می‌سنجند، نه فقط این سطر." if lang == "fa"
   else "No ads, no in-app purchases, no third-party SDK — and that claim is checked by CI gates, not just written here."}</p>
  <p class="small">{"فونت" if lang == "fa" else "Font"}: <a href="https://github.com/rastikerdar/vazirmatn">Vazirmatn</a>
     (SIL OFL 1.1 ✓ <code>game/assets/fonts/OFL.txt</code>) · {("پالت رنگ از §۲ کتاب هنری ✓") if lang == "fa" else "palette from §2 of the Art Bible ✓"}</p>
</footer>
</body>
</html>
"""


def build(check_only: bool = False) -> int:
    wanted: dict[str, str] = {}
    css = (SRC / "assets" / "site.css").read_text(encoding="utf-8")
    wanted["assets/site.css"] = css

    for src_name, (out_name, lang, direction) in PAGES.items():
        f = SRC / src_name
        if not f.exists():
            raise SystemExit(f"build_site: منبع نیست ✗ {f}")
        meta, body = read_src(f)
        title = meta.get("title") or out_name
        wanted[out_name] = page(fill(title), render_md(fill(body)), lang, direction,
                                fill(meta.get("description", "")), f"site_src/{src_name}",
                                rel="")

    for src_rel, (out_name, lang, direction, title) in POLICIES.items():
        f = (SRC / src_rel).resolve()
        if not f.exists():
            raise SystemExit(f"build_site: سند سیاست نیست ✗ {f} (تسک ۱۱.۱)")
        _, body = read_src(f)
        wanted[out_name] = page(title, render_md(fill(body)), lang, direction,
                                "Privacy policy for NEXUS: Balance Realm" if lang == "en"
                                else "سیاست حریم خصوصیِ بازی NEXUS برای والدین",
                                str(f.relative_to(ROOT)), rel="")

    # `game.html` در صورتِ وجودِ بیلدِ وب، iframe می‌چیند ✓✗ اگر نبود، صفحه همان «چرا نیست» را
    # می‌گوید ✓ (بدونِ جعلِ اسکرین‌شات و بدونِ «به‌زودی»های بی‌تاریخ ✓)
    embed = SITE / "game" / "index.html"
    if embed.exists():
        wanted["game-embed.html"] = (
            f"{MARK.format(src='game build')}\n"
            '<!doctype html>\n<html lang="fa" dir="rtl">\n<head><meta charset="utf-8">'
            '<title>NEXUS — وب</title><link rel="stylesheet" href="assets/site.css"></head>\n'
            '<body class="play"><iframe src="game/index.html" title="NEXUS"></iframe></body>\n</html>\n'
        )

    wanted[".nojekyll"] = "# Pages بدون Jekyll ✓✗ (ما فایلِ htmlِ آماده commit می‌کنیم؛ هیچ پردازشی لازم نیست)\n"
    wanted["robots.txt"] = "User-agent: *\nAllow: /\n"
    urls = "\n".join(
        f"<url><loc>https://soheilsssbd7.github.io/Nexus-learning-game/{n}</loc></url>"
        for n in sorted(wanted) if n.endswith(".html")
    )
    wanted["sitemap.xml"] = (
        '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
        f"\n{urls}\n</urlset>\n"
    )
    # ریشۀ مخزن = ریشۀ Pages (source path "/") ✓⇒ یک صفحۀ *ناحیهٔ ورودِ باریک*: هیچ متنِ تکراری
    # ندارد، فقط همین لینک‌ها ✓✗ تا «دو نسخه از یک جمله» در مخزن نپوسد ✓
    wanted["../index.html"] = (
        f"<!doctype html>\n<html lang=\"fa\" dir=\"rtl\">\n<head>\n<meta charset=\"utf-8\">\n"
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
        f"<title>NEXUS: Balance Realm — {VERSION}</title>\n"
        '<meta http-equiv="refresh" content="0; url=site/index.html">\n'
        f'<link rel="canonical" href="site/index.html">\n{MARK.format(src="site_src/index.md")}\n'
        "</head>\n<body>\n<p>NEXUS: Balance Realm — "
        '<a href="site/index.html">خانه / Home</a> · '
        '<a href="site/privacy.html">سیاست حریم خصوصی</a> · '
        '<a href="site/privacy-en.html">Privacy policy</a></p>\n</body>\n</html>\n'
    )

    if check_only:
        drift: list[str] = []
        for name, content in wanted.items():
            path = (SITE / name) if not name.startswith("../") else (ROOT / name[3:])
            if not path.exists():
                drift.append(f"نیست ✗ {path.relative_to(ROOT)}")
            elif path.read_text(encoding="utf-8") != content:
                drift.append(f"دور افتاده ✗ {path.relative_to(ROOT)} (باید `python3 tools/build_site.py` اجرا شود)")
        extra = []
        for f in sorted(SITE.rglob("*")):
            if f.is_file():
                rel = str(f.relative_to(SITE))
                if rel not in wanted and not rel.startswith(("game/", "assets/icons/", "assets/art/")):
                    extra.append(rel)
        if drift or extra:
            for d in drift + [f"فایلِ بیرونِ تولید ✓ در site: {e}" for e in extra]:
                print(f"check_site: {d}")
            return 1
        print(f"check_site: {len(wanted)} فایلِ سایت با مخزن یکی است ✓✓ (VERSION={VERSION})")
        return 0

    SITE.mkdir(exist_ok=True)
    (SITE / "assets").mkdir(exist_ok=True)
    for name, content in wanted.items():
        path = (SITE / name) if not name.startswith("../") else (ROOT / name[3:])
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.exists() or path.read_text(encoding="utf-8") != content:
            path.write_text(content, encoding="utf-8")
    # آیکون‌های واقعیِ بازی ✓✗ کپی نمی‌شوند: symlink هم نه ⇒ کپی با اطمینان از وجود منبع ✓
    icons_src = ROOT / "game" / "assets" / "art" / "icons"
    icons_dir = SITE / "assets" / "icons"
    icons_dir.mkdir(exist_ok=True)
    for f in sorted(icons_src.glob("*.svg")):
        (icons_dir / f.name).write_text(f.read_text(encoding="utf-8"), encoding="utf-8")
    print(f"build_site: {len(wanted)} فایل نوشته شد ✓ + {len(list(icons_dir.glob('*.svg')))} آیکون از بازی ✓")
    return 0


if __name__ == "__main__":
    sys.exit(build("--check" in sys.argv))
