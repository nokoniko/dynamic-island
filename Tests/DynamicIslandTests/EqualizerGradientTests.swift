import AppKit
import Testing
@testable import DynamicIsland

struct EqualizerGradientTests {
	private func hsb(_ color: NSColor) -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat) {
		var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
		color.usingColorSpace(.deviceRGB)!.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
		return (h, s, b)
	}

	@Test func runsFromDeeperToLighterAroundTheAccent() {
		let accent = NSColor(hue: 0.6, saturation: 0.7, brightness: 0.8, alpha: 1)
		let stops = EqualizerView.gradient(for: accent).map(hsb)
		#expect(stops.count == 3)
		#expect(abs(stops[1].hue - 0.6) < 0.001)
		#expect(abs(stops[0].hue - 0.52) < 0.001)
		#expect(abs(stops[2].hue - 0.68) < 0.001)
		#expect(stops[0].brightness < stops[1].brightness)
		#expect(stops[1].brightness < stops[2].brightness)
	}

	@Test func wrapsTheHueAroundRed() {
		let stops = EqualizerView.gradient(for: NSColor(hue: 0.02, saturation: 0.9, brightness: 0.9, alpha: 1)).map(hsb)
		#expect(abs(stops[0].hue - 0.94) < 0.001)
		#expect(abs(stops[2].hue - 0.10) < 0.001)
	}

	@Test func aNeutralAccentStaysNeutral() {
		let stops = EqualizerView.gradient(for: .white).map(hsb)
		#expect(stops.allSatisfy { $0.saturation < 0.001 })
		#expect(stops[0].brightness < stops[2].brightness)
	}

	@Test func staysWithinValidRanges() {
		let stops = EqualizerView.gradient(for: NSColor(hue: 0.3, saturation: 1, brightness: 1, alpha: 1)).map(hsb)
		#expect(stops.allSatisfy { (0...1).contains($0.saturation) && (0...1).contains($0.brightness) })
	}
}
