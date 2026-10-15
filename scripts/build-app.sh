#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="release"
SHOULD_OPEN=0

while (($# > 0)); do
    case "$1" in
        debug|release)
            CONFIGURATION="$1"
            ;;
        --open)
            SHOULD_OPEN=1
            ;;
        *)
            echo "Usage: scripts/build-app.sh [debug|release] [--open]" >&2
            exit 1
            ;;
    esac
    shift
done

APP_NAME="Visora"
if [[ "$CONFIGURATION" == "debug" ]]; then
    APP_NAME="Visora Debug"
fi

APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/$CONFIGURATION/Visora" "$MACOS_DIR/Visora"
cp "$ROOT_DIR/packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/packaging/Visora.icns" "$RESOURCES_DIR/Visora.icns"
cp "$ROOT_DIR/assets/Visora.png" "$RESOURCES_DIR/Visora.png"

chmod +x "$MACOS_DIR/Visora"
echo "Created $APP_DIR"

if [[ "$SHOULD_OPEN" -eq 1 ]]; then
    open "$APP_DIR"
fi
