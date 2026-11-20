#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${NYXWATCH_BUILD_DIR:-$SCRIPT_DIR/build}"
APP_BUNDLE="$BUILD_DIR/NyxWatch.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"

rm -rf "$APP_BUNDLE" "$ICONSET_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ICONSET_DIR"

echo "Génération de l'icône NyxWatch AppIcon.icns..."
{
cat "$SCRIPT_DIR/Sources/BrandIcon.swift"
cat << 'SWIFT_ICON'
import AppKit

let outDir = CommandLine.arguments[1]
let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

func renderIcon(size: Int) -> Data? {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(x: s * 0.06, y: s * 0.06, width: s * 0.88, height: s * 0.88)
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: s * 0.22, yRadius: s * 0.22)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.04, green: 0.04, blue: 0.05, alpha: 1.0),
        NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.10, alpha: 1.0)
    ])!
    gradient.draw(in: bgPath, angle: -90)

    NyxWatchBrandIcon.draw(in: NSRect(x: s * 0.18, y: s * 0.18, width: s * 0.64, height: s * 0.64))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

for (sz, name) in sizes {
    if let data = renderIcon(size: sz) {
        try? data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
    }
}
SWIFT_ICON
} | swift - "$ICONSET_DIR"

iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
rm -rf "$ICONSET_DIR"

echo "Compilation de NyxWatch..."
swiftc \
  -target "${NYXWATCH_TARGET:-$(uname -m)-apple-macosx13.0}" \
  -O \
  -framework AppKit \
  -framework CoreBluetooth \
  -framework IOBluetooth \
  -framework IOKit \
  "$SCRIPT_DIR/Sources/BrandIcon.swift" \
  "$SCRIPT_DIR/Sources/FloatingButton.swift" \
  "$SCRIPT_DIR/Sources/Localization.swift" \
  "$SCRIPT_DIR/Sources/Config.swift" \
  "$SCRIPT_DIR/Sources/SettingsStore.swift" \
  "$SCRIPT_DIR/Sources/PowerManager.swift" \
  "$SCRIPT_DIR/Sources/ActivityMonitor.swift" \
  "$SCRIPT_DIR/Sources/Notifier.swift" \
  "$SCRIPT_DIR/Sources/BluetoothMonitor.swift" \
  "$SCRIPT_DIR/Sources/StatusBarController.swift" \
  "$SCRIPT_DIR/Sources/main.swift" \
  -o "$MACOS_DIR/NyxWatch"

cp "$SCRIPT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

echo "Signature ad-hoc..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ Compilé avec succès : $APP_BUNDLE"
echo "Binaire CLI : $MACOS_DIR/NyxWatch"
