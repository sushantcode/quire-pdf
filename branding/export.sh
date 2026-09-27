#!/usr/bin/env bash
# Render the PNG icons the platforms cannot take as SVG, all from logo.svg.
#
# Through headless Chrome rather than rsvg-convert or ImageMagick, because
# neither is installed here and Chrome is. It is also the renderer a web client
# is judged in, so what comes out matches what a browser draws.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$here/.."
chrome="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
iconset="$root/macos/QuirePDF/Assets.xcassets/AppIcon.appiconset"

if [[ ! -x "$chrome" ]]; then
  echo "Chrome not found at $chrome. Set CHROME to its binary." >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$here/dist"

# render <size> <css> <dest>: logo.svg inlined, so the stylesheet reaches the
# artwork. `rx` is a CSS geometry property in modern browsers, which is what
# lets one source file produce both the rounded tile and the square icon.
render() {
  local size="$1" css="$2" dest="$3"
  {
    printf '<!doctype html><meta charset="utf-8"><style>\n'
    printf 'html,body{margin:0;padding:0;background:transparent;width:%spx;height:%spx;overflow:hidden}\n' "$size" "$size"
    printf 'svg{display:block;width:100%%;height:100%%}\n%s\n</style>\n' "$css"
    cat "$here/logo.svg"
  } > "$work/page.html"
  "$chrome" --headless --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 --default-background-color=00000000 \
    --window-size="$size,$size" --screenshot="$dest" \
    "file://$work/page.html" >/dev/null 2>&1
  [[ -s "$dest" ]] || { echo "Chrome wrote nothing to $dest" >&2; exit 1; }
}

# Square-cornered, for platforms that apply their own mask: iOS, Android and
# store listings. A rounded source leaves transparent corners iOS renders black.
square='svg > rect:first-of-type { rx: 0; ry: 0; }'
render 1024 "$square" "$here/dist/icon-1024.png"
render 512 "$square" "$here/dist/icon-512.png"
render 180 "$square" "$here/dist/apple-touch-icon.png"

# The App Store rejects an iOS icon with an alpha channel, and Chrome always
# writes one. Round-tripping through JPEG drops it; the square tile has no
# transparent pixels to lose, and at quality 100 the loss is invisible.
for f in "$here/dist/icon-1024.png" "$here/dist/icon-512.png" "$here/dist/apple-touch-icon.png"; do
  sips -s format jpeg -s formatOptions 100 "$f" --out "$work/flat.jpg" >/dev/null
  sips -s format png "$work/flat.jpg" --out "$f" >/dev/null
  if sips -g hasAlpha "$f" | grep -q 'hasAlpha: yes'; then
    echo "$(basename "$f") still has an alpha channel" >&2
    exit 1
  fi
done

# macOS draws no mask, so its icon is the rounded tile on Apple's grid: an
# 824-pixel tile centred in 1024 with a soft shadow. logo.svg's corner radius,
# 14 of 64, is Apple's ratio (185 of 824), so the tile needs no override.
mac='body{padding:100px;box-sizing:border-box}
svg{filter:drop-shadow(0 10px 12px rgba(0,0,0,.28))}'
render 1024 "$mac" "$here/dist/icon-macos-1024.png"

# Every size macOS needs, and the Contents.json that names them, written
# together so the two cannot drift.
entries=()
for points in 16 32 128 256 512; do
  for scale in 1 2; do
    suffix=""; [[ $scale == 2 ]] && suffix="@2x"
    name="icon_${points}x${points}${suffix}.png"
    sips -z $((points * scale)) $((points * scale)) "$here/dist/icon-macos-1024.png" --out "$iconset/$name" >/dev/null
    entries+=("    { \"filename\" : \"$name\", \"idiom\" : \"mac\", \"scale\" : \"${scale}x\", \"size\" : \"${points}x${points}\" }")
  done
done
{
  printf '{\n  "images" : [\n'
  (IFS=$'\n'; printf '%s\n' "${entries[*]}") | sed '$!s/$/,/'
  printf '  ],\n  "info" : { "author" : "xcode", "version" : 1 }\n}\n'
} > "$iconset/Contents.json"

echo "exported dist/ and the macOS icon set from branding/logo.svg"
