import Cocoa
import SwiftUI

// MARK: - Models

struct TrailPoint {
    let position: CGPoint
    let color: Color
    let born: Date
}

class BabyShape: Identifiable {
    let id = UUID()
    var position: CGPoint
    let color: Color
    let kind: Int // 0=circle, 1=roundedRect, 2=triangle
    let size: CGFloat
    let born: Date
    var velocity: CGPoint
    var settled = false
    var settledTime: Date? = nil

    init(position: CGPoint, color: Color, kind: Int, size: CGFloat) {
        self.position = position
        self.color = color
        self.kind = kind
        self.size = size
        self.born = Date()
        self.velocity = CGPoint(x: .random(in: -60...60), y: .random(in: -80...0))
    }
}

class Bubble: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    let color: Color
    let radius: CGFloat

    init(screenSize: CGSize) {
        self.radius = .random(in: 28...55)
        // Spawn from a random edge
        let edge = Int.random(in: 0...3)
        switch edge {
        case 0: position = CGPoint(x: -radius, y: .random(in: radius...(screenSize.height - radius)))
        case 1: position = CGPoint(x: screenSize.width + radius, y: .random(in: radius...(screenSize.height - radius)))
        case 2: position = CGPoint(x: .random(in: radius...(screenSize.width - radius)), y: -radius)
        default: position = CGPoint(x: .random(in: radius...(screenSize.width - radius)), y: screenSize.height + radius)
        }
        let speed: CGFloat = .random(in: 20...45)
        let angle = CGFloat.random(in: 0...(2 * .pi))
        self.velocity = CGPoint(x: cos(angle) * speed, y: sin(angle) * speed)
        self.color = AppState.palette.randomElement()!
    }
}

struct BubbleParticle {
    let position: CGPoint
    let velocity: CGPoint
    let color: Color
    let size: CGFloat
    let born: Date
}

struct Ribbon: Identifiable {
    let id = UUID()
    let startPoint: CGPoint
    let endPoint: CGPoint
    let control1: CGPoint
    let control2: CGPoint
    let color: Color
    let width: CGFloat
    let born: Date
}

// MARK: - State

final class AppState: ObservableObject {
    @Published var trail: [TrailPoint] = []
    @Published var shapes: [BabyShape] = []
    @Published var bubbles: [Bubble] = []
    @Published var bubbleParticles: [BubbleParticle] = []
    @Published var ribbons: [Ribbon] = []
    @Published var exitProgress: Double = 0
    @Published var cursorPosition: CGPoint? = nil
    @Published var dragStart: CGPoint? = nil
    @Published var dragCurrent: CGPoint? = nil
    @Published var showBanner = true

    private var colorIndex = 0
    private var lastTick: Date = Date()
    private var prevCursorPos: CGPoint? = nil
    private var cursorVelocity: CGPoint = .zero

    static let palette: [Color] = [
        Color(red: 0.95, green: 0.76, blue: 0.76), // soft pink
        Color(red: 0.76, green: 0.85, blue: 0.95), // light blue
        Color(red: 0.78, green: 0.89, blue: 0.78), // sage green
        Color(red: 0.85, green: 0.76, blue: 0.95), // lavender
        Color(red: 0.95, green: 0.93, blue: 0.76), // pale yellow
        Color(red: 0.95, green: 0.85, blue: 0.76), // peach
    ]

    static let trailFade: TimeInterval = 2.0
    static let shapeFade: TimeInterval = 3.0
    static let ribbonFade: TimeInterval = 4.0
    static let bubbleParticleFade: TimeInterval = 0.6
    static let maxBubbles = 8

    // MARK: Trail

    func addTrailPoint(at p: CGPoint) {
        // Smooth incoming position toward the previous point to dampen kinks
        let smoothed: CGPoint
        if let last = trail.last {
            let k: CGFloat = 0.4 // 0 = fully smoothed, 1 = raw input
            smoothed = CGPoint(
                x: last.position.x + (p.x - last.position.x) * k,
                y: last.position.y + (p.y - last.position.y) * k
            )
        } else {
            smoothed = p
        }
        let c = Self.palette[(colorIndex / 20) % Self.palette.count]
        colorIndex += 1
        trail.append(TrailPoint(position: smoothed, color: c, born: Date()))
        if trail.count > 300 { trail.removeFirst(trail.count - 300) }
    }

    func trailAlpha(_ t: TrailPoint, _ now: Date) -> Double {
        max(0, 1 - now.timeIntervalSince(t.born) / Self.trailFade)
    }

    var cursorColor: Color {
        trail.last?.color ?? Self.palette[0]
    }

    // MARK: Shapes

    func addShape(at p: CGPoint? = nil, jitter: CGFloat = 0) {
        let sz = NSScreen.main?.frame.size ?? CGSize(width: 1440, height: 900)
        var pos = p ?? CGPoint(
            x: .random(in: 60...(sz.width - 60)),
            y: .random(in: 60...(sz.height * 0.5))
        )
        if jitter > 0 {
            pos.x += .random(in: -jitter...jitter)
            pos.y += .random(in: -jitter...jitter)
        }
        shapes.append(BabyShape(
            position: pos,
            color: Self.palette.randomElement()!,
            kind: .random(in: 0...2),
            size: .random(in: 40...160)
        ))
        if shapes.count > 40 { shapes.removeFirst() }
    }

    func shapeAlpha(_ s: BabyShape, _ now: Date) -> Double {
        if let st = s.settledTime {
            return max(0, 1 - now.timeIntervalSince(st) / Self.shapeFade)
        }
        // Still in motion — fully visible, but safety cap at 15s
        let age = now.timeIntervalSince(s.born)
        if age > 15 { return max(0, 1 - (age - 15) / Self.shapeFade) }
        return 1.0
    }

    // MARK: Ribbons

    func startDrag(at point: CGPoint) {
        dragStart = point
        dragCurrent = point
    }

    func updateDrag(to point: CGPoint) {
        dragCurrent = point
    }

    func endDrag(at point: CGPoint) {
        guard let start = dragStart else { return }
        let dx = point.x - start.x
        let dy = point.y - start.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 20 else {
            dragStart = nil
            dragCurrent = nil
            return
        }
        let midX = (start.x + point.x) / 2
        let midY = (start.y + point.y) / 2
        let perpX = -dy * 0.3
        let perpY = dx * 0.3
        ribbons.append(Ribbon(
            startPoint: start,
            endPoint: point,
            control1: CGPoint(x: midX + perpX, y: midY + perpY),
            control2: CGPoint(x: midX - perpX, y: midY - perpY),
            color: Self.palette.randomElement()!,
            width: .random(in: 6...14),
            born: Date()
        ))
        if ribbons.count > 15 { ribbons.removeFirst() }
        dragStart = nil
        dragCurrent = nil
    }

    func ribbonAlpha(_ r: Ribbon, _ now: Date) -> Double {
        max(0, 1 - now.timeIntervalSince(r.born) / Self.ribbonFade)
    }

    // MARK: Bubbles

    func popBubble(_ b: Bubble) {
        let count = Int.random(in: 8...12)
        let now = Date()
        for i in 0..<count {
            let angle = (CGFloat(i) / CGFloat(count)) * 2 * .pi + .random(in: -0.3...0.3)
            let speed: CGFloat = .random(in: 60...150)
            bubbleParticles.append(BubbleParticle(
                position: b.position,
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                color: b.color,
                size: .random(in: 4...8),
                born: now
            ))
        }
    }

    // MARK: Physics Tick (called ~60fps)

    func tick() {
        let now = Date()
        let dt = CGFloat(now.timeIntervalSince(lastTick))
        lastTick = now
        guard dt > 0, dt < 0.5 else { return }

        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1440, height: 900)

        // --- Shape physics ---
        let gravity: CGFloat = 120
        let bounceDamping: CGFloat = 0.5
        let settleThreshold: CGFloat = 10

        for shape in shapes {
            guard !shape.settled else { continue }
            shape.velocity.y += gravity * dt
            shape.position.x += shape.velocity.x * dt
            shape.position.y += shape.velocity.y * dt

            let half = shape.size / 2
            if shape.position.x < half {
                shape.position.x = half
                shape.velocity.x = abs(shape.velocity.x) * bounceDamping
            } else if shape.position.x > screenSize.width - half {
                shape.position.x = screenSize.width - half
                shape.velocity.x = -abs(shape.velocity.x) * bounceDamping
            }
            if shape.position.y > screenSize.height - half {
                shape.position.y = screenSize.height - half
                shape.velocity.y = -abs(shape.velocity.y) * bounceDamping
                shape.velocity.x *= 0.9
            }
            if shape.position.y < half {
                shape.position.y = half
                shape.velocity.y = abs(shape.velocity.y) * bounceDamping
            }

            let speed = sqrt(shape.velocity.x * shape.velocity.x + shape.velocity.y * shape.velocity.y)
            if speed < settleThreshold && shape.position.y > screenSize.height - half - 2 {
                shape.settled = true
                shape.settledTime = now
                shape.velocity = .zero
            }
        }

        // --- Cursor velocity tracking ---
        if let cp = cursorPosition, let prev = prevCursorPos, dt > 0 {
            cursorVelocity = CGPoint(
                x: (cp.x - prev.x) / dt,
                y: (cp.y - prev.y) / dt
            )
        }
        prevCursorPos = cursorPosition

        // --- Cursor pushes shapes ---
        if let cp = cursorPosition {
            for shape in shapes {
                let dx = shape.position.x - cp.x
                let dy = shape.position.y - cp.y
                let dist = sqrt(dx * dx + dy * dy)
                let pushRadius = shape.size / 2 + 40
                if dist < pushRadius && dist > 0.1 {
                    // Gentle radial push away from cursor
                    let force: CGFloat = 600 * (1 - dist / pushRadius)
                    shape.velocity.x += (dx / dist) * force * dt
                    shape.velocity.y += (dy / dist) * force * dt

                    // Soft momentum transfer from cursor movement
                    let cursorSpeed = sqrt(cursorVelocity.x * cursorVelocity.x + cursorVelocity.y * cursorVelocity.y)
                    if cursorSpeed > 20 {
                        shape.velocity.x += cursorVelocity.x * 0.06
                        shape.velocity.y += cursorVelocity.y * 0.06
                    }

                    if shape.settled {
                        shape.settled = false
                        shape.settledTime = nil
                    }
                }
            }
        }

        // --- Bubble physics ---
        for b in bubbles {
            b.position.x += b.velocity.x * dt
            b.position.y += b.velocity.y * dt
            if b.position.x < b.radius { b.velocity.x = abs(b.velocity.x) }
            if b.position.x > screenSize.width - b.radius { b.velocity.x = -abs(b.velocity.x) }
            if b.position.y < b.radius { b.velocity.y = abs(b.velocity.y) }
            if b.position.y > screenSize.height - b.radius { b.velocity.y = -abs(b.velocity.y) }
        }

        // Cursor pops bubbles
        if let cp = cursorPosition {
            bubbles.removeAll { b in
                let dx = b.position.x - cp.x
                let dy = b.position.y - cp.y
                if sqrt(dx * dx + dy * dy) < b.radius + 18 {
                    popBubble(b)
                    return true
                }
                return false
            }
        }

        // Respawn bubbles
        if bubbles.count < Self.maxBubbles {
            if Double.random(in: 0...1) < Double(dt) * 0.5 {
                bubbles.append(Bubble(screenSize: screenSize))
            }
        }

        // Prune old bubble particles
        bubbleParticles.removeAll { now.timeIntervalSince($0.born) > Self.bubbleParticleFade }
        if bubbleParticles.count > 100 { bubbleParticles.removeFirst(bubbleParticles.count - 100) }

        objectWillChange.send()
    }

    // MARK: Prune (called ~1/sec)

    func prune() {
        let now = Date()
        trail.removeAll { now.timeIntervalSince($0.born) > Self.trailFade }
        shapes.removeAll { s in
            if let st = s.settledTime {
                return now.timeIntervalSince(st) > Self.shapeFade
            }
            return now.timeIntervalSince(s.born) > 18
        }
        ribbons.removeAll { now.timeIntervalSince($0.born) > Self.ribbonFade }
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

                    // Bubbles (behind everything interactive)
                    for b in state.bubbles {
                        ctx.opacity = 0.5
                        let br = CGRect(
                            x: b.position.x - b.radius,
                            y: b.position.y - b.radius,
                            width: b.radius * 2, height: b.radius * 2
                        )
                        ctx.fill(Path(ellipseIn: br), with: .color(b.color))
                        // Glossy highlight
                        ctx.opacity = 0.3
                        let hr = b.radius * 0.4
                        ctx.fill(
                            Path(ellipseIn: CGRect(
                                x: b.position.x - hr * 0.5,
                                y: b.position.y - b.radius * 0.55,
                                width: hr, height: hr
                            )),
                            with: .color(.white)
                        )
                        // Ring
                        ctx.opacity = 0.3
                        ctx.stroke(
                            Path(ellipseIn: br),
                            with: .color(.white),
                            style: StrokeStyle(lineWidth: 1.5)
                        )
                    }

                    // Bubble pop particles
                    for p in state.bubbleParticles {
                        let age = CGFloat(now.timeIntervalSince(p.born))
                        let alpha = max(0, 1 - age / CGFloat(AppState.bubbleParticleFade))
                        guard alpha > 0.01 else { continue }
                        let px = p.position.x + p.velocity.x * age
                        let py = p.position.y + p.velocity.y * age
                        ctx.opacity = Double(alpha)
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: px - p.size / 2, y: py - p.size / 2, width: p.size, height: p.size)),
                            with: .color(p.color)
                        )
                    }

                    // Shapes (with physics positions)
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

                    // Ribbons
                    for r in state.ribbons {
                        let a = state.ribbonAlpha(r, now)
                        guard a > 0.01 else { continue }
                        var path = Path()
                        path.move(to: r.startPoint)
                        path.addCurve(to: r.endPoint, control1: r.control1, control2: r.control2)
                        ctx.opacity = a * 0.7
                        ctx.stroke(
                            path,
                            with: .color(r.color),
                            style: StrokeStyle(lineWidth: r.width, lineCap: .round, lineJoin: .round)
                        )
                        ctx.opacity = a * 0.3
                        ctx.stroke(
                            path,
                            with: .color(.white),
                            style: StrokeStyle(lineWidth: r.width * 0.3, lineCap: .round)
                        )
                    }

                    // Live drag preview (rubber band)
                    if let start = state.dragStart, let current = state.dragCurrent {
                        let dx = current.x - start.x
                        let dy = current.y - start.y
                        let dist = sqrt(dx * dx + dy * dy)
                        if dist > 10 {
                            let midX = (start.x + current.x) / 2
                            let midY = (start.y + current.y) / 2
                            var preview = Path()
                            preview.move(to: start)
                            preview.addCurve(
                                to: current,
                                control1: CGPoint(x: midX - dy * 0.3, y: midY + dx * 0.3),
                                control2: CGPoint(x: midX + dy * 0.3, y: midY - dx * 0.3)
                            )
                            ctx.opacity = 0.4
                            ctx.stroke(
                                preview,
                                with: .color(state.cursorColor),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round, dash: [12, 8])
                            )
                        }
                    }

                    // Smooth rainbow trail (midpoint-bezier smoothing, tapering width, shimmer)
                    let maxTrailWidth: CGFloat = 40
                    let trailCount = state.trail.count
                    let timeShift = now.timeIntervalSinceReferenceDate * 0.3

                    if trailCount >= 3 {
                        for i in 1..<(trailCount - 1) {
                            let p0 = state.trail[i - 1]
                            let p1 = state.trail[i]
                            let p2 = state.trail[i + 1]
                            guard p1.born.timeIntervalSince(p0.born) < 0.15,
                                  p2.born.timeIntervalSince(p1.born) < 0.15 else { continue }

                            let age = now.timeIntervalSince(p1.born)
                            let life = max(0, 1 - age / AppState.trailFade)
                            guard life > 0.01 else { continue }

                            // Taper width: thick near cursor, rapid falloff toward tail
                            let posFrac = CGFloat(i) / CGFloat(trailCount - 1)
                            let width = maxTrailWidth * posFrac * posFrac

                            // Rainbow shimmer: hue based on trail position + time
                            let normPos = Double(i) / Double(trailCount)
                            let hue = (normPos * 1.5 + timeShift).truncatingRemainder(dividingBy: 1.0)
                            let trailColor = Color(hue: abs(hue), saturation: 0.35, brightness: 0.92)

                            ctx.opacity = life * 0.85

                            // Smooth bezier through midpoints
                            let mid1 = CGPoint(
                                x: (p0.position.x + p1.position.x) / 2,
                                y: (p0.position.y + p1.position.y) / 2
                            )
                            let mid2 = CGPoint(
                                x: (p1.position.x + p2.position.x) / 2,
                                y: (p1.position.y + p2.position.y) / 2
                            )
                            var seg = Path()
                            seg.move(to: mid1)
                            seg.addQuadCurve(to: mid2, control: p1.position)
                            ctx.stroke(
                                seg,
                                with: .color(trailColor),
                                style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
                            )
                        }
                    }

                    ctx.opacity = 1

                    // Custom star cursor
                    if let cp = state.cursorPosition {
                        ctx.opacity = 0.25
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: cp.x - 26, y: cp.y - 26, width: 52, height: 52)),
                            with: .color(state.cursorColor)
                        )
                        ctx.opacity = 1.0
                        let outerR: CGFloat = 18, innerR: CGFloat = 8
                        var star = Path()
                        for i in 0..<10 {
                            let r: CGFloat = i % 2 == 0 ? outerR : innerR
                            let angle = Double(i) * .pi / 5.0 - .pi / 2.0
                            let pt = CGPoint(
                                x: cp.x + CGFloat(cos(angle)) * r,
                                y: cp.y + CGFloat(sin(angle)) * r
                            )
                            if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
                        }
                        star.closeSubpath()
                        ctx.fill(star, with: .color(state.cursorColor))
                        ctx.stroke(
                            star,
                            with: .color(.white.opacity(0.9)),
                            style: StrokeStyle(lineWidth: 2)
                        )
                    }

                    // Exit progress indicator
                    if state.exitProgress > 0 {
                        let w: CGFloat = 100, h: CGFloat = 4
                        let x = size.width - w - 16, y: CGFloat = 16
                        ctx.opacity = 1
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

            // Instruction banner (top)
            if state.showBanner {
                VStack {
                    InfoBanner(onDismiss: { withAnimation { state.showBanner = false } })
                    Spacer()
                }
                .ignoresSafeArea()
                .transition(.move(edge: .top))
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                withAnimation { state.showBanner = false }
            }
        }
    }
}

// MARK: - Info Banner

struct InfoBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to BabyBoard")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("To exit: hold Escape for 3 seconds, or click 5 times rapidly in the top-right corner.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(.white.opacity(0.2)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(red: 0.25, green: 0.25, blue: 0.30))
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
    var tickTimer: Timer?
    var lastMouse: Date = .distantPast
    var allowTermination = false
    var frameCount = 0
    var cursorIsHidden = true
    let bannerHeight: CGFloat = 60

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

        NSApp.presentationOptions = [
            .hideDock,
            .hideMenuBar,
            .disableProcessSwitching,
            .disableForceQuit,
            .disableSessionTermination,
            .disableHideApplication,
        ]

        NSApp.activate()
        NSCursor.hide()

        setupMonitors()

        // 60fps tick for physics + bubbles; prune every ~1s
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.state.tick()
            self.frameCount += 1
            if self.frameCount % 60 == 0 {
                self.state.prune()
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil, queue: .main
        ) { _ in
            NSApp.activate()
        }

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
        NSCursor.unhide()
        NSApp.presentationOptions = []
    }

    func performExit() {
        NSCursor.unhide()
        allowTermination = true
        NSApp.presentationOptions = []
        NSApp.terminate(nil)
    }

    // MARK: Event Monitors

    func setupMonitors() {
        // Mouse movement -> trail + cursor
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .rightMouseDragged, .otherMouseDragged]) { [weak self] e in
            self?.onMouse(e)
            return e
        }

        // Left mouse down -> start drag tracking (skip banner zone)
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] e in
            guard let self else { return e }
            let h = NSScreen.main!.frame.height
            let pos = CGPoint(x: e.locationInWindow.x, y: h - e.locationInWindow.y)
            if self.state.showBanner && pos.y < self.bannerHeight {
                return e // let SwiftUI handle banner clicks
            }
            self.state.startDrag(at: pos)
            return e
        }

        // Left mouse drag -> update drag + trail
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] e in
            let h = NSScreen.main!.frame.height
            let pos = CGPoint(x: e.locationInWindow.x, y: h - e.locationInWindow.y)
            self?.state.updateDrag(to: pos)
            self?.onMouse(e)
            return e
        }

        // Left mouse up -> end drag or spawn shape (skip banner zone)
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] e in
            guard let self else { return e }
            let h = NSScreen.main!.frame.height
            let pos = CGPoint(x: e.locationInWindow.x, y: h - e.locationInWindow.y)
            if self.state.showBanner && pos.y < self.bannerHeight {
                return e
            }
            if let start = self.state.dragStart {
                let dx = pos.x - start.x
                let dy = pos.y - start.y
                if sqrt(dx * dx + dy * dy) > 20 {
                    self.state.endDrag(at: pos)
                } else {
                    self.state.addShape(at: pos)
                    self.state.dragStart = nil
                    self.state.dragCurrent = nil
                }
            }
            return e
        }

        // Right/other clicks -> shape
        NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .otherMouseDown]) { [weak self] e in
            let h = NSScreen.main!.frame.height
            self?.state.addShape(at: CGPoint(x: e.locationInWindow.x, y: h - e.locationInWindow.y))
            return e
        }

        // Keyboard -> shapes (number keys spawn count) + escape
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            self?.onKeyDown(e)
            return nil
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] e in
            if e.keyCode == 53 {
                self?.escDown = false
                self?.cancelExit()
            }
            return nil
        }

        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { _ in nil }
    }

    func onMouse(_ e: NSEvent) {
        let now = Date()
        let h = NSScreen.main!.frame.height
        let pos = CGPoint(x: e.locationInWindow.x, y: h - e.locationInWindow.y)

        // Show system cursor over banner, hide elsewhere
        if state.showBanner && pos.y < bannerHeight {
            if cursorIsHidden {
                NSCursor.unhide()
                cursorIsHidden = false
            }
            state.cursorPosition = nil
            return
        } else if !cursorIsHidden {
            NSCursor.hide()
            cursorIsHidden = true
        }

        state.cursorPosition = pos
        guard now.timeIntervalSince(lastMouse) > 0.016 else { return }
        lastMouse = now
        state.addTrailPoint(at: pos)
    }

    func onKeyDown(_ e: NSEvent) {
        if e.keyCode == 53 {
            if !escDown {
                escDown = true
                startEscapeHold()
            }
            return
        }
        guard !e.isARepeat else { return }

        // Number keys spawn that count of shapes
        var count = 1
        if let chars = e.charactersIgnoringModifiers, let digit = chars.first, digit.isNumber {
            let n = digit.wholeNumberValue ?? 1
            count = n == 0 ? 10 : n
        }
        let useJitter = count > 1
        for _ in 0..<count {
            state.addShape(jitter: useJitter ? 30 : 0)
        }
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
