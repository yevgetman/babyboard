# BabyBoard

A full-screen macOS kiosk app that lets babies safely play with a MacBook. Every interaction produces colorful visuals — and the entire keyboard and system UI is locked down so nothing else can happen. Designed so that the sensory play implicitly builds foundational computer skills (cause-and-effect, targeting, spatial awareness) without feeling like an educational app.

## Features

- **Smooth colorful trails** — mouse movement paints smooth, flowing pastel ribbons that cycle through colors and gently fade out
- **Fun star cursor** — the system cursor is replaced with a large, glowing pastel star that babies can easily track
- **Floating bubbles** — translucent bubbles drift across the screen and pop into a burst of particles when the cursor touches them, teaching targeting
- **Shapes with physics** — clicks and keypresses spawn shapes that fall with soft gravity, bounce off edges, and settle at the bottom before fading
- **Number key counting** — pressing a number key (1-9) spawns that many shapes; 0 spawns 10. Different keys produce different results, building input differentiation
- **Click-and-drag ribbons** — dragging creates elastic, curved ribbons between the start and end points, teaching the drag gesture as distinct from clicking
- **Kiosk mode** — hides the Dock, menu bar, and disables app switching, force quit, and session termination
- **Baby-proof** — all keyboard input is consumed, scroll events are swallowed, and focus is automatically reclaimed if lost
- **Info banner** — on launch, an instruction banner tells the adult how to exit, then auto-dismisses after 60 seconds (or tap the X to close it early)

## How to Exit

Two adult-friendly exit methods are built in (shown in the launch banner):

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
