<div align="center">
  <img src="../assets/Visora.png" width="112" height="112" alt="Visora Icon" />
  <h1>Visora</h1>
  <p><strong>A native, open-source macOS image viewer · Image-first, quiet UI, and blazingly fast</strong></p>
  <p>
    <a href="https://github.com/sxhjlzl/Visora/actions"><img src="https://img.shields.io/github/actions/workflow/status/sxhjlzl/Visora/ci.yml?branch=main&label=CI" alt="CI Status" /></a>
    <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+" />
    <img src="https://img.shields.io/badge/swift-5.9%2B-orange" alt="Swift 5.9+" />
    <a href="../LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="License: MIT" /></a>
  </p>
  <p>
    <a href="../README.md">简体中文</a> · <strong>English</strong>
  </p>
</div>

---

**Visora** is a lightweight, native macOS image viewer built with AppKit, crafted for an **instant, fluid, and distraction-free** viewing experience. Embracing the **macOS Liquid Glass** design language, its floating controls appear when needed and fade away automatically—keeping the focus entirely on your images.

---

## Highlights

- **Fast Viewing**: Async decoding, neighbor preloading, auto EXIF orientation, long-image mode, and cross-image zoom lock (`L`).
- **Folder Browsing**: Auto-scans sibling images with live folder monitoring, `⌘F` filename filtering, flexible sorting, and optional subfolder recursion.
- **Canvas & Editing**: 4 background styles (`B`: Dark / Checkerboard / Light / Ambient Blur), pixelated zoom (`N`), plus rotate/flip with `⌘S` save-in-place.
- **Built-in Pro Tools**: Live RGB histogram, EXIF inspector (`I`), Vision OCR text panel (`O`), thumbnail grid view (`G`), and floating Pinboard reference windows (`P`).
- **Liquid Glass HUD**: Floating top pill, bottom toolbar, and filmstrip auto-hide when idle and stay visible while hovered.

---

## Keyboard Shortcuts

| Shortcut | Action | Shortcut | Action |
| :--- | :--- | :--- | :--- |
| `⌘O` | Open image | `←` / `→` | Previous / next image |
| `⌘⇧O` | Open folder | `↑` / `↓` | Zoom in / out |
| `⌘⇧V` | Pin clipboard content | `Space` | Toggle Fit to Window / Actual Size |
| `⌘S` | Save rotation / flip changes to file | `Home` / `End` | Jump to top / bottom in long image mode |
| `⌘F` / `/` | Filter folder images by file name | `[` / `]` | Rotate left / right |
| `⌘C` | Copy image bitmap | `H` / `V` | Flip horizontal / vertical |
| `⌘⇧C` | Copy image file | `B` | Cycle background (Dark / Checkerboard / Light / Ambient) |
| `⌘⌥C` | Copy image file path | `N` | Toggle pixelated / smooth zoom |
| `⌘R` | Reveal in Finder | `L` | Lock zoom and pan across images |
| `⌫` | Move to Trash | `O` | Extract text (OCR) in right-side panel |
| `I` | Toggle Info & Histogram panel | `G` / `T` | Toggle Grid mode / Filmstrip |
| `S` / `P` | Toggle Slideshow / Pin current image | `C` / `F` | Toggle Immersive Chrome / Fullscreen |
| `⌘,` | Preferences | `Esc` | Close filter bar, grid, or window |

---

## Supported Formats

Visora natively supports **20+ formats** (individually toggleable in Preferences):

- **Standard & Animated**: `JPEG / JPG`, `PNG`, `APNG` (animated), `GIF` (animated), `WebP` (static & animated), `BMP`, `TIFF / TIF`, `ICO`
- **Next-Gen & HDR**: `HEIC / HEIF`, `AVIF`, `JPEG XL (JXL)`
- **Vector**: `SVG`
- **Camera RAW**: `DNG`, `CR2`, `CR3`, `NEF`, `ARW`, `ORF`, `RAF`, `RW2`

---

## Getting Started

### Requirements
- **OS**: macOS 14.0+ (automatically activates native Liquid Glass effects on macOS 26 / 27+)
- **Toolchain**: Xcode 15+ / Swift 5.9+

### Build & Run from Source

```bash
git clone https://github.com/sxhjlzl/Visora.git
cd Visora

# Build and run
swift run Visora

# Open an image or folder from CLI
swift run Visora /path/to/image.jpg
swift run Visora ~/Pictures

# Run unit tests
swift test
```

### Package as `.app` Bundle

```bash
scripts/build-app.sh
open dist/Visora.app
```

---

## Project Structure

```text
Visora/
├── App/                  # AppDelegate, MainMenu, SceneCoordinator
├── Core/
│   ├── Cache/            # Byte-cost and count-limited memory cache
│   ├── FileSystem/       # Recursive folder scanner & DispatchSource live monitor
│   ├── ImageDecoding/    # ImageIO decoder, EXIF orientation, transform saver, thumbnails
│   ├── Localization/     # Real-time English / Simplified Chinese localization
│   └── Storage/          # Preferences & recent items persistence
├── Domain/               # Settings, sort rules, commands, metadata models
├── Features/
│   ├── Grid/             # Thumbnail grid browser
│   ├── Pinboard/         # Floating reference windows
│   ├── Preferences/      # 5-tab preferences window
│   └── Viewer/           # Main viewer (canvas, welcome view, filmstrip, histogram, OCR panel)
└── UI/
    ├── Brand/            # Brand style & app icon views
    ├── Components/       # macOS 26/27 AdaptiveGlassSurfaceView Liquid Glass components
    └── Window/           # Adaptive viewer window controller
```

---

## Contributing

Issues and Pull Requests are welcome!
- Found a bug or have a feature request? Open a [GitHub Issue](https://github.com/sxhjlzl/Visora/issues).
- Please make sure `swift test` passes before submitting a Pull Request.

---

## License

Released under the [MIT License](../LICENSE).
