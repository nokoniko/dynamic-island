import SwiftUI
import AppKit

/// Smooth, organic equalizer bars shown while audio plays.
///
/// Driven by `TimelineView(.animation)`, which advances only while `active` (it is
/// `paused` otherwise) — so it costs nothing when nothing is playing. Each bar has
/// its own frequency and phase so the motion looks lively rather than uniform.
/// The bars are cut out of one gradient built around the accent color, so taller
/// bars reveal the lighter end of it.
struct EqualizerView: View {
    var color: Color
    var active: Bool

    private let barCount = 5
    private let barWidth: CGFloat = 2.5
    private let spacing: CGFloat = 2
    private let maxHeight: CGFloat = 16
    private let minHeight: CGFloat = 3

    private var width: CGFloat { CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing }

    var body: some View {
        let colors = Self.gradient(for: NSColor(color)).map { Color(nsColor: $0) }
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !active)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            LinearGradient(colors: colors, startPoint: .bottomLeading, endPoint: .topTrailing)
                .mask {
                    HStack(alignment: .center, spacing: spacing) {
                        ForEach(0..<barCount, id: \.self) { i in
                            Capsule()
                                .frame(width: barWidth, height: height(bar: i, time: t))
                        }
                    }
                }
                .frame(width: width, height: maxHeight)
                .animation(.easeOut(duration: 0.08), value: active)
        }
    }

    /// Three stops around the accent: a deeper, slightly shifted hue, the accent
    /// itself, and a lighter hue shifted the other way.
    nonisolated static func gradient(for accent: NSColor) -> [NSColor] {
        guard let rgb = accent.usingColorSpace(.deviceRGB) else { return [accent, accent, accent] }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        func wrapped(_ hue: CGFloat) -> CGFloat { hue - floor(hue) }
        return [
            NSColor(hue: wrapped(h - 0.08), saturation: min(s * 1.15, 1), brightness: b * 0.8, alpha: a),
            NSColor(hue: h, saturation: s, brightness: b, alpha: a),
            NSColor(hue: wrapped(h + 0.08), saturation: s * 0.85, brightness: min(b * 1.15 + 0.05, 1), alpha: a),
        ]
    }

    private func height(bar i: Int, time t: Double) -> CGFloat {
        guard active else { return minHeight }
        // Two detuned sine waves per bar → a fuller, less mechanical bounce.
        let freq = 5.0 + Double(i) * 1.6
        let phase = Double(i) * 0.8
        let a = sin(t * freq + phase)
        let b = sin(t * freq * 0.5 + phase * 1.7)
        let level = (a * 0.65 + b * 0.35 + 1) / 2          // 0…1
        let eased = level * level * (3 - 2 * level)         // smoothstep for softer peaks
        return minHeight + CGFloat(eased) * (maxHeight - minHeight)
    }
}
