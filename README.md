# BabyBoard

A full-screen macOS kiosk app that lets babies safely play with a MacBook. Every mouse movement leaves a colorful trail of dots, every click or keypress spawns pastel shapes — and the entire keyboard and system UI is locked down so nothing else can happen.

## Features

- **Colorful trails** — mouse movement paints fading dots in a rotating pastel palette
- **Shapes on interaction** — clicks and keypresses spawn circles, rounded rectangles, and triangles that gently fade out
- **Kiosk mode** — hides the Dock, menu bar, and disables app switching, force quit, and session termination
- **Baby-proof** — all keyboard input is consumed, scroll events are swallowed, and focus is automatically reclaimed if lost

## How to Exit

Two adult-friendly exit methods are built in:

1. **Hold Escape for 3 seconds** — a small progress bar appears in the top-right corner. Release to cancel.
2. **Click 5 times rapidly in the top-right corner** — an "Exit BabyBoard?" confirmation dialog appears.

## Requirements

- macOS 14.0+
- Swift compiler (included with Xcode or Xcode Command Line Tools)

## Build & Run

```bash
# Clone the repo
git clone <repo-url> && cd BabyBoard

# Build
swiftc -o BabyBoard.app/Contents/MacOS/BabyBoard main.swift -framework Cocoa -framework SwiftUI

# Run
open BabyBoard.app
```

To install to your Applications folder:

```bash
cp -R BabyBoard.app /Applications/
```

## Project Structure

```
BabyBoard/
  main.swift       # All application source code (single file)
  Info.plist       # App bundle metadata
  AppIcon.icns     # App icon
  BabyBoard.app/   # Compiled app bundle (not tracked in git)
```

## License

MIT
