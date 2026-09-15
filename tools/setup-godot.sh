#!/usr/bin/env bash
# ===========================================================================
# NEXUS — tools/setup-godot.sh
# دانلود/نصب نسخه‌ی Godot قفل‌شده برای توسعه‌ی محلی (تسک ۰.۲ + توصیه‌ی
# docs/00-START-HERE.md «نسخه را قفل کن»).
#
#   ./tools/setup-godot.sh            → نصب اَدیتور دسکتاپ + هدهلس در .tools/
#   ./tools/setup-godot.sh templates  → به‌علاوه export templates (~1.3GB، فقط برای export لازم است)
#
# همه‌چیز داخل `.tools/` می‌نشیند که در .gitignore است؛ ریپو هرگز سنگین نمی‌شود.
# اگر شبکه‌ی شما release asset های GitHub را مسدود کرده (مثل این سندباکس)،
# بررسی Godot فقط در CI انجام می‌شود: .github/workflows/ci.yml
# ===========================================================================
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
TAG="${GODOT_VERSION}-stable"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_ROOT/.tools"
BIN="$DEST/godot"
WITH_TEMPLATES="${1:-}"

ASSET_EDITOR="Godot_v${TAG}_linux.x86_64.zip"
ASSET_TPL="Godot_v${TAG}_export_templates.tpz"

mkdir -p "$DEST"

fetch() {  # $1=filename → prints url list, tries mirrors in order
  local file="$1"
  local urls=(
    "https://github.com/godotengine/godot/releases/download/${TAG}/${file}"
    "https://downloads.godotengine.org/release/${TAG}/${file}"
    "https://download.tuxfamily.org/godot/${GODOT_VERSION}/${TAG}/${file}"
  )
  for u in "${urls[@]}"; do
    echo "  ↳ امتحان: $u" >&2
    if curl -fL --retry 2 --max-time 900 -o "$DEST/$file" "$u"; then return 0; fi
  done
  echo "✖ دانلود $file از هیچ mirror ممکن نبود. Godot $GODOT_VERSION را دستی نصب کن و" >&2
  echo "  متغیر محیطی GODOT_BIN=$PWD/.tools/godot را ست کن (یا در IDE همان فایل را انتخاب کن)." >&2
  return 1
}

if [[ -x "$BIN" ]]; then
  echo "· Godot از قبل نصب است: $BIN ($("$BIN" --version 2>/dev/null || echo '?'))"
else
  echo "→ دانلود Godot ${TAG} (لینوکس x86_64)"
  fetch "$ASSET_EDITOR"
  unzip -qo "$DEST/$ASSET_EDITOR" -d "$DEST"
  mv -f "$DEST/Godot_v${TAG}_linux.x86_64" "$BIN"
  chmod +x "$BIN"
  rm -f "$DEST/$ASSET_EDITOR"
  echo "✔ نصب شد: $BIN"
fi

if [[ "$WITH_TEMPLATES" == "templates" ]]; then
  echo "→ دانلود export templates (~1.3GB)"
  fetch "$ASSET_TPL"
  TPL_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
  mkdir -p "$TPL_DIR"
  unzip -qo "$DEST/$ASSET_TPL" -d "$DEST/tpl"
  cp -r "$DEST/tpl/templates/." "$TPL_DIR/"
  rm -rf "$DEST/tpl" "$DEST/$ASSET_TPL"
  echo "✔ templates → $TPL_DIR"
fi

"$BIN" --version
cat <<EOF

نکته‌ی اجرایی:
  • تست headless :  ${BIN} --headless --path game -s addons/gut/gut_cmdln.gd -gut_config_file=res://.gutconfig.json -gexit
  • ایمپورت      :  ${BIN} --headless --path game --import
  • اجرای بازی   :  ${BIN} --path game
  • lint         :  gdlint  (pip install gdtoolkit==4.5.0)
  • داده‌ها       :  python3 tools/validate_levels.py
EOF
