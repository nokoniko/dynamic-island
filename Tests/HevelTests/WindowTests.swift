import CoreGraphics
import Testing
@testable import Hevel

struct NotchGeometryTests {
	@Test func measuresTheNotchBetweenTheAuxiliaryAreas() {
		let geometry = NotchController.ScreenGeometry(width: 1512, topInset: 38,
													  topLeftAreaWidth: 662, topRightAreaWidth: 665)
		let metrics = NotchController.metrics(geometry: geometry)
		#expect(metrics.hasNotch)
		#expect(metrics.notchWidth == 185)
		#expect(metrics.notchHeight == 38)
	}

	@Test func neverGoesBelowTheMinimumNotchWidth() {
		let geometry = NotchController.ScreenGeometry(width: 1000, topInset: 38,
													  topLeftAreaWidth: 500, topRightAreaWidth: 450)
		#expect(NotchController.metrics(geometry: geometry).notchWidth == 120)
	}

	@Test(arguments: [
		NotchController.ScreenGeometry(width: 1920, topInset: 0, topLeftAreaWidth: nil, topRightAreaWidth: nil),
		NotchController.ScreenGeometry(width: 1920, topInset: 0, topLeftAreaWidth: 800, topRightAreaWidth: 800),
		NotchController.ScreenGeometry(width: 1512, topInset: 38, topLeftAreaWidth: nil, topRightAreaWidth: 665),
		NotchController.ScreenGeometry(width: 1512, topInset: 38, topLeftAreaWidth: 662, topRightAreaWidth: nil),
	])
	func withoutANotchItDrawsAFloatingPill(geometry: NotchController.ScreenGeometry) {
		let metrics = NotchController.metrics(geometry: geometry)
		#expect(!metrics.hasNotch)
		#expect(metrics.notchWidth == 190)
		#expect(metrics.notchHeight == 32)
	}

	@Test func withoutAScreenItFallsBackToADefaultPill() {
		let metrics = NotchController.metrics(geometry: nil)
		#expect(!metrics.hasNotch)
		#expect(metrics.notchWidth == 200)
		#expect(metrics.notchHeight == 32)
	}
}

struct FakeWindow: Sendable {
	var owner: String?
	var layer: Int?
	var bounds: CGRect?

	var info: [String: Any] {
		var info: [String: Any] = [:]
		if let owner { info[kCGWindowOwnerName as String] = owner }
		if let layer { info[kCGWindowLayer as String] = layer }
		if let bounds { info[kCGWindowBounds as String] = bounds.dictionaryRepresentation }
		return info
	}
}

struct WindowListCase: Sendable, CustomTestStringConvertible {
	let testDescription: String
	let windows: [FakeWindow]
	let isFullscreen: Bool
}

private let width: CGFloat = 1512
private let menuBar = CGRect(x: 0, y: 0, width: width, height: 37)

struct FullscreenDetectionTests {
	@Test(arguments: [
		WindowListCase(testDescription: "no windows", windows: [], isFullscreen: false),
		WindowListCase(testDescription: "regular app window",
					   windows: [FakeWindow(owner: "Safari", layer: 0, bounds: CGRect(x: 0, y: 38, width: width, height: 900))],
					   isFullscreen: false),
		WindowListCase(testDescription: "maximized window flush with the top",
					   windows: [FakeWindow(owner: "Safari", layer: 0, bounds: CGRect(x: 0, y: 0, width: width, height: 982))],
					   isFullscreen: false),
		WindowListCase(testDescription: "fullscreen app's menu-bar overlay",
					   windows: [FakeWindow(owner: "Safari", layer: 26, bounds: menuBar)],
					   isFullscreen: true),
		WindowListCase(testDescription: "overlay among other windows",
					   windows: [
						FakeWindow(owner: "Window Server", layer: 24, bounds: menuBar),
						FakeWindow(owner: "Finder", layer: 0, bounds: CGRect(x: 100, y: 100, width: 800, height: 600)),
						FakeWindow(owner: "Safari", layer: 26, bounds: menuBar),
					   ],
					   isFullscreen: true),
		WindowListCase(testDescription: "system menu bar (Window Server)",
					   windows: [FakeWindow(owner: "Window Server", layer: 24, bounds: menuBar)],
					   isFullscreen: false),
		WindowListCase(testDescription: "Dock strip",
					   windows: [FakeWindow(owner: "Dock", layer: 26, bounds: menuBar)],
					   isFullscreen: false),
		WindowListCase(testDescription: "our own panel",
					   windows: [FakeWindow(owner: "Hevel", layer: 25, bounds: menuBar)],
					   isFullscreen: false),
		WindowListCase(testDescription: "partial-width strip",
					   windows: [FakeWindow(owner: "Spotlight", layer: 25, bounds: CGRect(x: 500, y: 0, width: 300, height: 37))],
					   isFullscreen: false),
		WindowListCase(testDescription: "too tall to be a menu bar",
					   windows: [FakeWindow(owner: "Safari", layer: 26, bounds: CGRect(x: 0, y: 0, width: width, height: 60))],
					   isFullscreen: false),
		WindowListCase(testDescription: "not at the very top",
					   windows: [FakeWindow(owner: "Safari", layer: 26, bounds: CGRect(x: 0, y: 2, width: width, height: 37))],
					   isFullscreen: false),
		WindowListCase(testDescription: "one point narrower still counts",
					   windows: [FakeWindow(owner: "Safari", layer: 26, bounds: CGRect(x: 0, y: 0, width: width - 1, height: 37))],
					   isFullscreen: true),
		WindowListCase(testDescription: "below the menu-bar level",
					   windows: [FakeWindow(owner: "Safari", layer: 23, bounds: menuBar)],
					   isFullscreen: false),
		WindowListCase(testDescription: "missing layer counts as 0",
					   windows: [FakeWindow(owner: "Safari", layer: nil, bounds: menuBar)],
					   isFullscreen: false),
		WindowListCase(testDescription: "missing bounds",
					   windows: [FakeWindow(owner: "Safari", layer: 26, bounds: nil)],
					   isFullscreen: false),
		WindowListCase(testDescription: "unnamed overlay still counts",
					   windows: [FakeWindow(owner: nil, layer: 26, bounds: menuBar)],
					   isFullscreen: true),
	])
	func detectsTheFullscreenMenuBarOverlay(windowList: WindowListCase) {
		let detected = NotchController.hasFullscreenMenuBarOverlay(
			in: windowList.windows.map(\.info),
			screenWidth: width,
			menuBarLevel: Int(CGWindowLevelForKey(.mainMenuWindow)))
		#expect(detected == windowList.isFullscreen)
	}
}

struct PopoutTests {
	@Test(arguments: [
		(false, false, true, false, true),
		(false, false, false, true, true),
		(false, false, true, true, true),
		(false, false, false, false, false),
		(true, false, true, false, false),
		(true, false, false, true, false),
		(false, true, true, false, false),
		(false, true, false, true, false),
		(true, true, true, true, false),
	])
	func showsOnlyWhilePlayingOrLingeringAndNotHidden(hidden: Bool, suppressed: Bool, playing: Bool,
													  lingering: Bool, shown: Bool) {
		let result = NotchController.popoutShown(hiddenForFullscreen: hidden, suppressedForFrontmost: suppressed,
												 isPlaying: playing, pausedLingering: lingering)
		#expect(result == shown)
	}
}

struct FrontmostCase: Sendable, CustomTestStringConvertible {
	let testDescription: String
	var hasMedia = true
	var playingPID: Int? = 10
	var playingBundleID: String? = "com.spotify.client"
	var front: (pid: Int, bundleID: String?)?
	let isFrontmost: Bool
}

struct FrontmostTests {
	@Test(arguments: [
		FrontmostCase(testDescription: "nothing playing", hasMedia: false,
					  front: (10, "com.spotify.client"), isFrontmost: false),
		FrontmostCase(testDescription: "no playing process", playingPID: nil,
					  front: (10, "com.spotify.client"), isFrontmost: false),
		FrontmostCase(testDescription: "no frontmost app", front: nil, isFrontmost: false),
		FrontmostCase(testDescription: "same process", front: (10, "com.spotify.client"), isFrontmost: true),
		FrontmostCase(testDescription: "same app, other process",
					  front: (20, "com.spotify.client"), isFrontmost: true),
		FrontmostCase(testDescription: "browser plays from a helper process",
					  playingBundleID: "com.google.Chrome.helper",
					  front: (20, "com.google.Chrome"), isFrontmost: true),
		FrontmostCase(testDescription: "front app has the longer id",
					  playingBundleID: "com.google.Chrome",
					  front: (20, "com.google.Chrome.helper"), isFrontmost: true),
		FrontmostCase(testDescription: "different app", front: (20, "com.apple.Safari"), isFrontmost: false),
		FrontmostCase(testDescription: "playing app has no bundle id", playingBundleID: nil,
					  front: (20, "com.spotify.client"), isFrontmost: false),
		FrontmostCase(testDescription: "front app has no bundle id", front: (20, nil), isFrontmost: false),
	])
	func matchesTheFrontmostAppAgainstThePlayer(frontmostCase: FrontmostCase) {
		let result = NotchController.isPlayerFrontmost(
			hasMedia: frontmostCase.hasMedia,
			playingPID: frontmostCase.playingPID,
			frontmost: { frontmostCase.front },
			bundleID: { _ in frontmostCase.playingBundleID })
		#expect(result == frontmostCase.isFrontmost)
	}

	@Test func looksUpTheSystemOnlyWhenNeeded() {
		var frontmostLookups = 0
		var bundleLookups = 0
		let frontmost = { () -> (pid: Int, bundleID: String?)? in
			frontmostLookups += 1
			return (10, "com.spotify.client")
		}
		let bundleID = { (_: Int) -> String? in
			bundleLookups += 1
			return "com.spotify.client"
		}

		_ = NotchController.isPlayerFrontmost(hasMedia: false, playingPID: 10, frontmost: frontmost, bundleID: bundleID)
		#expect(frontmostLookups == 0)

		_ = NotchController.isPlayerFrontmost(hasMedia: true, playingPID: 10, frontmost: frontmost, bundleID: bundleID)
		#expect(frontmostLookups == 1)
		#expect(bundleLookups == 0)
	}
}
