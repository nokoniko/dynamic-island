import Testing
@testable import DynamicIsland

struct NotchMetricsTests {
	@Test func collapsedGeometryIsDerivedFromTheNotch() {
		let metrics = NotchMetrics(notchWidth: 185, notchHeight: 37, hasNotch: true)
		#expect(metrics.collapsedWidth == 245)
		#expect(metrics.restHeight == 38)
	}

	@Test func canvasFitsThePopOut() {
		let metrics = NotchMetrics(notchWidth: 185, notchHeight: 37, hasNotch: true)
		#expect(metrics.maxWindowSize.width >= metrics.collapsedWidth)
		#expect(metrics.maxWindowSize.height >= metrics.restHeight)
	}
}
