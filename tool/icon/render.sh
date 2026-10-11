#!/bin/sh
# Render icon SVG -> PNG bằng Chrome headless (giữ nền trong suốt).
# Dùng: sh tool/icon/render.sh   (chạy từ thư mục gốc project)
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/out"
CH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
python3 -I "$DIR/make_icon.py" "$OUT"
TMP=$(mktemp -d)
for v in full foreground monochrome; do
  "$CH" --headless=new --disable-gpu --no-first-run --user-data-dir="$TMP" --hide-scrollbars \
    --default-background-color=00000000 --window-size=1024,1024 \
    --screenshot="$OUT/chrome_$v.png" "file://$OUT/icon_$v.svg" >/dev/null 2>&1
done
rm -rf "$TMP"
cp "$OUT/chrome_full.png" "$DIR/icon_full.png"
cp "$OUT/chrome_foreground.png" "$DIR/icon_foreground.png"
# Monochrome (Android 13+ themed icon): chỉ dùng alpha, phần ký hiệu đen thành trong suốt.
magick "$OUT/chrome_monochrome.png" -channel A -fx 'a*(0.2126*r+0.7152*g+0.0722*b)' +channel \
  -fill white -colorize 100 "$DIR/icon_monochrome.png"
# Ảnh nhỏ hiển thị trong màn Giới thiệu.
mkdir -p "$DIR/../../assets/images"
magick "$DIR/icon_full.png" -resize 192x192 -strip -define png:compression-level=9 \
  "$DIR/../../assets/images/app_icon.png"
