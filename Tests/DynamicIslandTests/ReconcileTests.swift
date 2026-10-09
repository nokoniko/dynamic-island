import Testing
@testable import DynamicIsland

struct ReconcileTests {
	private func track(_ title: String?, playing: Bool?, from source: String) -> NowPlayingInfo {
		var info = NowPlayingInfo()
		info.title = title
		info.isPlaying = playing
		info.sourceApp = source
		return info
	}

	@Test func withoutAnAppSourceTheSystemSnapshotIsUsed() {
		let system = track("Video", playing: true, from: "system")
		#expect(NowPlayingModel.reconcile(system: system, app: nil)?.sourceApp == "system")
		#expect(NowPlayingModel.reconcile(system: nil, app: nil) == nil)
	}

	@Test func forTheSameTrackTheAppStateWins() {
		let system = track("Song", playing: true, from: "system")
		let app = track("  song ", playing: false, from: "Spotify")
		let chosen = NowPlayingModel.reconcile(system: system, app: app)
		#expect(chosen?.sourceApp == "Spotify")
		#expect(chosen?.isPlaying == false)
	}

	@Test func forDifferentTracksAPlayingAppWins() {
		let system = track("Video", playing: true, from: "system")
		let app = track("Song", playing: true, from: "Spotify")
		#expect(NowPlayingModel.reconcile(system: system, app: app)?.sourceApp == "Spotify")
	}

	@Test func forDifferentTracksAPlayingSystemSourceBeatsAPausedApp() {
		let system = track("Video", playing: true, from: "system")
		let app = track("Song", playing: false, from: "Spotify")
		#expect(NowPlayingModel.reconcile(system: system, app: app)?.sourceApp == "system")
	}

	@Test func whenNothingPlaysTheSystemSnapshotIsPreferred() {
		let system = track("Video", playing: false, from: "system")
		let app = track("Song", playing: false, from: "Spotify")
		#expect(NowPlayingModel.reconcile(system: system, app: app)?.sourceApp == "system")
		#expect(NowPlayingModel.reconcile(system: nil, app: app)?.sourceApp == "Spotify")
	}

	@Test(arguments: [
		("Song", "Song", true),
		("Song", "  sOnG  ", true),
		("Song", "Other", false),
		("", "", false),
		("Song", "Song (Live)", false),
	])
	func sameTrackComparesTrimmedCaseInsensitiveTitles(a: String, b: String, same: Bool) {
		let first = track(a, playing: true, from: "system")
		let second = track(b, playing: true, from: "Spotify")
		#expect(NowPlayingModel.sameTrack(first, second) == same)
	}

	@Test func aMissingTitleIsNeverTheSameTrack() {
		let untitled = track(nil, playing: true, from: "system")
		#expect(!NowPlayingModel.sameTrack(untitled, untitled))
	}
}

struct PauseLingerTests {
	@Test(arguments: [
		("Spotify", true, false, "Song", NowPlayingModel.PauseLinger.start),
		("Music", true, false, "Song", .start),
		("system", true, false, "Video", .cancel),
		("Google Chrome", true, false, "Video", .cancel),
		("Helium", true, false, "Video", .cancel),
		("Spotify", true, false, "", .cancel),
		("Spotify", false, true, "Song", .cancel),
		("system", true, true, "Video", .cancel),
		("Spotify", false, false, "Song", .unchanged),
		("system", false, false, "Video", .unchanged),
	])
	func decidesWhetherAPauseLingers(source: String, wasPlaying: Bool, isPlaying: Bool,
									 title: String, expected: NowPlayingModel.PauseLinger) {
		let decision = NowPlayingModel.pauseLinger(wasPlaying: wasPlaying, isPlaying: isPlaying,
												  title: title, source: source)
		#expect(decision == expected)
	}

	@Test func anUnknownSourceNeverLingers() {
		#expect(NowPlayingModel.pauseLinger(wasPlaying: true, isPlaying: false, title: "Song", source: nil) == .cancel)
	}
}
