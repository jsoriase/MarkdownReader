#!/bin/bash
# Builds MarkdownReader and assembles the .app bundle.
#   ./Scripts/build_app.sh              -> build/Markdown Reader.app (release)
#   ./Scripts/build_app.sh --debug      -> debug build
#   ./Scripts/build_app.sh --universal  -> arm64 + x86_64 binary
#   ./Scripts/build_app.sh --install    -> also copies it to /Applications
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG=release
INSTALL=0
ARCH_FLAGS=()

for arg in "$@"; do
  case "$arg" in
    --debug) CONFIG=debug ;;
    --release) CONFIG=release ;;
    --install) INSTALL=1 ;;
    --universal) ARCH_FLAGS=(--arch arm64 --arch x86_64) ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

APP_NAME="Markdown Reader"
APP="$ROOT/build/$APP_NAME.app"

echo "==> Building ($CONFIG)"
ARCHS=("${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}")
swift build -c "$CONFIG" ${ARCHS[@]+"${ARCHS[@]}"}
BIN="$(swift build -c "$CONFIG" ${ARCHS[@]+"${ARCHS[@]}"} --show-bin-path)/MarkdownReader"

if [ ! -f "$ROOT/AppResources/AppIcon.icns" ]; then
  echo "==> Generating icon"
  swift "$ROOT/Scripts/make_icon.swift" "$ROOT/AppResources/AppIcon.iconset" >/dev/null
  iconutil -c icns "$ROOT/AppResources/AppIcon.iconset" -o "$ROOT/AppResources/AppIcon.icns"
fi

echo "==> Assembling $APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MarkdownReader"
cp "$ROOT/AppResources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/AppResources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
for lproj in "$ROOT"/AppResources/*.lproj; do
  [ -d "$lproj" ] && cp -R "$lproj" "$APP/Contents/Resources/"
done
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Signing (ad-hoc)"
codesign --force --sign - --identifier com.haumealabs.MarkdownReader "$APP" >/dev/null

if [ "$INSTALL" = "1" ]; then
  echo "==> Installing into /Applications"
  rm -rf "/Applications/$APP_NAME.app"
  cp -R "$APP" "/Applications/$APP_NAME.app"
  APP="/Applications/$APP_NAME.app"
fi

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" || true

echo "==> Done: $APP"
