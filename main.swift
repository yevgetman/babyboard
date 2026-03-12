import Cocoa
import SwiftUI

// MARK: - Models

struct TrailDot: Identifiable {
    let id = UUID()
    let position: CGPoint
    let color: Color
    let size: CGFloat
    let born: Date
}

struct BabyShape: Identifiable {
    let id = UUID()
    let position: CGPoint
    let color: Color
    let kind: Int // 0=circle, 1=roundedRect, 2=triangle
    let size: CGFloat
    let born: Date
}

// MARK: - State

final class AppState: ObservableObject {
    @Published var dots: [TrailDot] = []
    @Published var shapes: [BabyShape] = []
    @Published var exitProgress: Double = 0

    private var colorIndex = 0

    static let palette: [Color] = [
        Color(red: 0.95, green: 0.76, blue: 0.76), // soft pink
        Color(red: 0.76, green: 0.85, blue: 0.95), // light blue
        Color(red: 0.78, green: 0.89, blue: 0.78), // sage green
        Color(red: 0.85, green: 0.76, blue: 0.95), // lavender
        Color(red: 0.95, green: 0.93, blue: 0.76), // pale yellow
        Color(red: 0.95, green: 0.85, blue: 0.76), // peach
    ]

    static let dotFade: TimeInterval = 2.0
    static let shapeFade: TimeInterval = 3.0

    func addDot(at p: CGPoint) {
        let c = Self.palette[colorIndex % Self.palette.count]
        colorIndex += 1
        dots.append(TrailDot(position: p, color: c, size: .random(in: 10...18), born: Date()))
        if dots.count > 150 { dots.removeFirst(dots.count - 150) }
    }

    func addShape(at p: CGPoint? = nil) {
        let sz = NSScreen.main?.frame.size ?? CGSize(width: 1440, height: 900)
        let pos = p ?? CGPoint(
            x: .random(in: 60...(sz.width - 60)),
            y: .random(in: 60...(sz.height - 60))
        )
        shapes.append(BabyShape(
            position: pos,
            color: Self.palette.randomElement()!,
            kind: .random(in: 0...2),
            size: .random(in: 40...90),
            born: Date()
        ))
        if shapes.count > 20 { shapes.removeFirst() }
    }

    func prune() {
        let now = Date()
        dots.removeAll { now.timeIntervalSince($0.born) > Self.dotFade }
        shapes.removeAll { now.timeIntervalSince($0.born) > Self.shapeFade }
    }

    func dotAlpha(_ d: TrailDot, _ now: Date) -> Double {
        max(0, 1 - now.timeIntervalSince(d.born) / Self.dotFade)
    }

    func shapeAlpha(_ s: BabyShape, _ now: Date) -> Double {
        max(0, 1 - now.timeIntervalSince(s.born) / Self.shapeFade)
    }

    func requestExit() {
        NotificationCenter.default.post(name: .babyBoardExit, object: nil)
    }
}

extension Notification.Name {
    static let babyBoardExit = Notification.Name("babyBoardExit")
}

// MARK: - View

struct BabyView: View {
    @ObservedObject var state: AppState
    @State private var showExitConfirm = false
    private let bg = Color(red: 0.98, green: 0.97, blue: 0.95)

    var body: some View {
        ZStack {
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let now = tl.date

                    // Background
                    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(bg))

                    // Shapes (drawn first, behind trail)
                    for s in state.shapes {
                        let a = state.shapeAlpha(s, now)
                        guard a > 0.01 else { continue }
                        ctx.opacity = a
                        let r = CGRect(
                            x: s.position.x - s.size / 2,
                            y: s.position.y - s.size / 2,
                            width: s.size, height: s.size
                        )
                        switch s.kind {
                        case 0:
                            ctx.fill(Path(ellipseIn: r), with: .color(s.color))
                        case 1:
                            ctx.fill(
                                Path(roundedRect: r, cornerRadius: s.size * 0.2),
                                with: .color(s.color)
                            )
                        default:
                            var p = Path()
                            p.move(to: CGPoint(x: r.midX, y: r.minY))
                            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
                            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
                            p.closeSubpath()
                            ctx.fill(p, with: .color(s.color))
                        }
                    }

                    // Trail dots (drawn on top)
                    for d in state.dots {
                        let a = state.dotAlpha(d, now)
                        guard a > 0.01 else { continue }
                        ctx.opacity = a
                        let r = CGRect(
                            x: d.position.x - d.size / 2,
                            y: d.position.y - d.size / 2,
                            width: d.size, height: d.size
                        )
                        ctx.fill(Path(ellipseIn: r), with: .color(d.color))
                    }

                    ctx.opacity = 1

                    // Exit progress indicator (tiny bar, top-right)
                    if state.exitProgress > 0 {
                        let w: CGFloat = 100, h: CGFloat = 4
                        let x = size.width - w - 16, y: CGFloat = 16
                        ctx.fill(
                            Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: 2),
                            with: .color(.gray.opacity(0.25))
                        )
                        ctx.fill(
                            Path(roundedRect: CGRect(x: x, y: y, width: w * state.exitProgress, height: h), cornerRadius: 2),
                            with: .color(.gray.opacity(0.5))
                        )
                    }
                }
            }
            .ignoresSafeArea()

            // Hidden exit button: 5 rapid clicks in top-right corner
            VStack {
                HStack {
                    Spacer()
                    ExitTapZone(state: state, showConfirm: $showExitConfirm)
                        .frame(width: 44, height: 44)
                }
                Spacer()
            }
            .ignoresSafeArea()

            if showExitConfirm {
                ExitConfirmOverlay(
                    onExit: { state.requestExit() },
                    onCancel: { showExitConfirm = false }
                )
            }
        }
    }
}

// MARK: - Hidden Exit Tap Zone

struct ExitTapZone: View {
    @ObservedObject var state: AppState
    @Binding var showConfirm: Bool
    @State private var tapCount = 0
    @State private var lastTap: Date = .distantPast

    private let requiredTaps = 5
    private let tapWindow: TimeInterval = 2.0

    var body: some View {
        // Invisible tap target
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                let now = Date()
                if now.timeIntervalSince(lastTap) > tapWindow {
                    tapCount = 0
                }
                tapCount += 1
                lastTap = now
                if tapCount >= requiredTaps {
                    tapCount = 0
                    showConfirm = true
                }
            }
    }
}

struct ExitConfirmOverlay: View {
    let onExit: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Exit BabyBoard?")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                HStack(spacing: 16) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .frame(width: 100, height: 36)
                    }
                    .buttonStyle(.bordered)
                    Button(action: onExit) {
                        Text("Exit")
                            .frame(width: 100, height: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThickMaterial)
            )
        }
    }
}

// MARK: - Window

class KioskWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: KioskWindow!
    let state = AppState()

    var escDown = false
    var exitTimer: Timer?
    var exitStart: Date?
    var pruneTimer: Timer?
    var lastMouse: Date = .distantPast
    var allowTermination = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let scr = NSScreen.main!.frame

        window = KioskWindow(
            contentRect: scr,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isOpaque = true
        window.hasShadow = false
        window.acceptsMouseMovedEvents = true
        window.contentView = NSHostingView(rootView: BabyView(state: state))
        window.makeKeyAndOrderFront(nil)

        // Kiosk mode: hide everything, block system shortcuts
        NSApp.presentationOptions = [
            .hideDock,
            .hideMenuBar,
            .disableProcessSwitching,
            .disableForceQuit,
            .disableSessionTermination,
            .disableHideApplication,
        ]

        NSApp.activate()

        setupMonitors()

        // Periodic cleanup of expired dots/shapes
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.state.prune()
        }

        // If app somehow loses focus, reclaim it
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil, queue: .main
        ) { _ in
            NSApp.activate()
        }

        // Listen for UI-triggered exit
        NotificationCenter.default.addObserver(
            forName: .babyBoardExit,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.performExit()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        allowTermination ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSApp.presentationOptions = []
    }

    func performExit() {
        allowTermination = true
        NSApp.presentationOptions = []
        NSApp.terminate(nil)
    }

    // MARK: Event Monitors

    func setupMonitors() {
        // Mouse movement -> trail dots
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]) { [weak self] e in
            self?.onMouse(e)
            return e
        }

        // Mouse clicks -> shape at click location
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] e in
            let h = NSScreen.main!.frame.height
            self?.state.addShape(at: CGPoint(x: e.locationInWindow.x, y: h - e.locationInWindow.y))
            return e
        }

        // Keyboard -> shapes (and exit combo detection)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            self?.onKeyDown(e)
            return nil // consume all keys
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] e in
            if e.keyCode == 53 { // Escape released
                self?.escDown = false
                self?.cancelExit()
            }
            return nil
        }

        // Consume scroll events so they don't leak through
        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { _ in nil }
    }

    func onMouse(_ e: NSEvent) {
        let now = Date()
        guard now.timeIntervalSince(lastMouse) > 0.016 else { return } // ~60fps
        lastMouse = now
        let h = NSScreen.main!.frame.height
        state.addDot(at: CGPoint(x: e.locationInWindow.x, y: h - e.locationInWindow.y))
    }

    func onKeyDown(_ e: NSEvent) {
        if e.keyCode == 53 { // Escape
            if !escDown {
                escDown = true
                startEscapeHold()
            }
            return
        }
        guard !e.isARepeat else { return }
        state.addShape()
    }

    // MARK: Exit: hold Escape for 3 seconds

    func startEscapeHold() {
        guard exitTimer == nil else { return }
        exitStart = Date()
        exitTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let start = self.exitStart else { return }
            let p = min(1, Date().timeIntervalSince(start) / 3.0)
            self.state.exitProgress = p
            if p >= 1 {
                self.performExit()
            }
        }
    }

    func cancelExit() {
        exitTimer?.invalidate()
        exitTimer = nil
        exitStart = nil
        state.exitProgress = 0
    }
}

// MARK: - Entry Point

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
