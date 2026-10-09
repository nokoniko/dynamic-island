import Testing
@testable import Hevel

struct StreamLineParsingTests {
	@Test func readsAFullLine() throws {
		let line = #"{"title":"Song","artist":"Artist","album":"Album","id":"x","duration":215.50,"elapsed":12.25,"isPlaying":true,"pid":4242}"#
		let info = try #require(SystemNowPlaying.parse(line: line))
		#expect(info.title == "Song")
		#expect(info.artist == "Artist")
		#expect(info.album == "Album")
		#expect(info.duration == 215.5)
		#expect(info.elapsed == 12.25)
		#expect(info.isPlaying == true)
		#expect(info.pid == 4242)
		#expect(info.sourceApp == "system")
	}

	@Test func emptyOptionalFieldsBecomeNil() throws {
		let line = #"{"title":"Song","artist":"","album":"","duration":0.00,"elapsed":0.00,"isPlaying":false,"pid":0}"#
		let info = try #require(SystemNowPlaying.parse(line: line))
		#expect(info.artist == nil)
		#expect(info.album == nil)
		#expect(info.isPlaying == false)
		#expect(info.pid == nil)
	}

	@Test func missingFieldsBecomeNil() throws {
		let info = try #require(SystemNowPlaying.parse(line: #"{"title":"Song"}"#))
		#expect(info.artist == nil)
		#expect(info.duration == nil)
		#expect(info.elapsed == nil)
		#expect(info.isPlaying == nil)
		#expect(info.pid == nil)
	}

	@Test func readsEscapedUnicode() throws {
		let info = try #require(SystemNowPlaying.parse(line: #"{"title":"Blå \"live\""}"#))
		#expect(info.title == "Blå \"live\"")
	}

	@Test(arguments: [
		"",
		"{",
		"{}",
		"[]",
		"not json",
		#"{"title":"Song""#,
		#"{"title":""}"#,
		#"{"title":null}"#,
		#"{"artist":"Artist"}"#,
		#"{"title":42}"#,
	])
	func rejectsBrokenOrUntitledLines(line: String) {
		#expect(SystemNowPlaying.parse(line: line) == nil)
	}
}

struct AppleScriptParsingTests {
	@Test func spotifyReportsDurationInMilliseconds() throws {
		let raw = "Song|||Artist|||Album|||215000|||12.5|||playing|||https://i.scdn.co/image/abc"
		let info = try #require(MediaFallback.parseAppOutput(raw, app: "Spotify"))
		#expect(info.title == "Song")
		#expect(info.artist == "Artist")
		#expect(info.album == "Album")
		#expect(info.duration == 215)
		#expect(info.elapsed == 12.5)
		#expect(info.isPlaying == true)
		#expect(info.artworkURL == "https://i.scdn.co/image/abc")
		#expect(info.sourceApp == "Spotify")
		#expect(info.pid == nil)
	}

	@Test func musicReportsDurationInSeconds() throws {
		let info = try #require(MediaFallback.parseAppOutput("Song|||Artist|||Album|||215.5|||3|||paused|||", app: "Music"))
		#expect(info.duration == 215.5)
		#expect(info.isPlaying == false)
		#expect(info.artworkURL == nil)
	}

	@Test(arguments: [
		("Spotify", "215000,0", "12,5", 215.0, 12.5),
		("Music", "215,5", "3,25", 215.5, 3.25),
	])
	func acceptsACommaAsDecimalSeparator(app: String, duration: String, position: String,
										 expectedDuration: Double, expectedElapsed: Double) throws {
		let raw = "Song|||Artist|||Album|||\(duration)|||\(position)|||playing|||"
		let info = try #require(MediaFallback.parseAppOutput(raw, app: app))
		#expect(info.duration == expectedDuration)
		#expect(info.elapsed == expectedElapsed)
	}

	@Test func emptyFieldsBecomeNil() throws {
		let info = try #require(MediaFallback.parseAppOutput("||||||||||||||||||", app: "Music"))
		#expect(info.title == nil)
		#expect(info.artist == nil)
		#expect(info.album == nil)
		#expect(info.duration == nil)
		#expect(info.elapsed == nil)
		#expect(info.isPlaying == false)
	}

	@Test func readsThePlayerStateCaseInsensitively() throws {
		let info = try #require(MediaFallback.parseAppOutput("Song|||A|||B|||1|||0|||Playing", app: "Music"))
		#expect(info.isPlaying == true)
		#expect(info.artworkURL == nil)
	}

	@Test(arguments: ["STOPPED", "", "Song|||Artist", "Song|||Artist|||Album|||1|||2"])
	func rejectsStoppedOrTruncatedReplies(raw: String) {
		#expect(MediaFallback.parseAppOutput(raw, app: "Spotify") == nil)
	}
}

struct BrowserScriptParsingTests {
	@Test func readsAPlayingTab() throws {
		let raw = "1|||Video|||Channel|||https://i.ytimg.com/vi/x/hq.jpg|||12,5|||300"
		let info = try #require(MediaFallback.parseBrowserOutput(raw, browser: "Helium"))
		#expect(info.title == "Video")
		#expect(info.artist == "Channel")
		#expect(info.artworkURL == "https://i.ytimg.com/vi/x/hq.jpg")
		#expect(info.elapsed == 12.5)
		#expect(info.duration == 300)
		#expect(info.isPlaying == true)
		#expect(info.sourceApp == "Helium")
	}

	@Test(arguments: ["NaN", "Infinity"])
	func dropsNonFiniteDurationsFromLiveStreams(duration: String) throws {
		let info = try #require(MediaFallback.parseBrowserOutput("1|||Live|||Channel||||||5|||\(duration)", browser: "Safari"))
		#expect(info.duration == nil)
		#expect(info.artworkURL == nil)
	}

	@Test func aMinimalReplyStillYieldsATrack() throws {
		let info = try #require(MediaFallback.parseBrowserOutput("1|||Video", browser: "Arc"))
		#expect(info.artist == "")
		#expect(info.elapsed == nil)
		#expect(info.duration == nil)
	}

	@Test(arguments: ["", "1", "0|||Video|||Channel", "1||||||Channel", "garbage"])
	func rejectsPausedUntitledOrBrokenReplies(raw: String) {
		#expect(MediaFallback.parseBrowserOutput(raw, browser: "Google Chrome") == nil)
	}
}
