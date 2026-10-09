import AppKit

extension NotchController {

    static func targetScreen() -> NSScreen? {
        // Prefer the built-in display that actually has a notch.
        if let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            return notched
        }
        return NSScreen.main
    }

    /// The parts of a screen that decide the notch geometry.
    struct ScreenGeometry {
        var width: CGFloat
        var topInset: CGFloat
        var topLeftAreaWidth: CGFloat?
        var topRightAreaWidth: CGFloat?
    }

    static func metrics(for screen: NSScreen?) -> NotchMetrics {
        metrics(geometry: screen.map {
            ScreenGeometry(width: $0.frame.width,
                           topInset: $0.safeAreaInsets.top,
                           topLeftAreaWidth: $0.auxiliaryTopLeftArea?.width,
                           topRightAreaWidth: $0.auxiliaryTopRightArea?.width)
        })
    }

    nonisolated static func metrics(geometry: ScreenGeometry?) -> NotchMetrics {
        guard let geometry else {
            return NotchMetrics(notchWidth: 200, notchHeight: 32, hasNotch: false)
        }

        if geometry.topInset > 0,
           let left = geometry.topLeftAreaWidth,
           let right = geometry.topRightAreaWidth {
            let notchWidth = geometry.width - left - right
            return NotchMetrics(notchWidth: max(notchWidth, 120),
                                notchHeight: geometry.topInset,
                                hasNotch: true)
        }
        // No notch: synthesize a floating pill.
        return NotchMetrics(notchWidth: 190, notchHeight: 32, hasNotch: false)
    }

    /// The window is a fixed size (large enough for the glow margin) and never
    /// moves — it stays centered on the notch. Click-through handles the rest, so
    /// the fixed size blocks nothing around it. Also caches the popped-out notch
    /// rect used by the mouse-move click-through check.
    func positionWindow() {
        guard let screen = Self.targetScreen() else { return }
        let m = state.metrics
        let size = m.maxWindowSize
        let x = screen.frame.midX - size.width / 2
        let y = screen.frame.maxY - size.height   // top-aligned
        let frame = NSRect(x: x, y: y, width: size.width, height: size.height)
        panel.setFrame(frame, display: true)
        lockPanel?.setFrame(frame, display: false)

        // The clickable pop-out only ever appears at its popped-out width, so cache
        // that rect here instead of recomputing it on every mouse move.
        poppedNotchRect = CGRect(x: screen.frame.midX - m.collapsedWidth / 2,
                                 y: screen.frame.maxY - m.restHeight,
                                 width: m.collapsedWidth, height: m.restHeight)
    }

    func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.state.metrics = Self.metrics(for: Self.targetScreen())
                self.positionWindow()
            }
        }
    }
}
