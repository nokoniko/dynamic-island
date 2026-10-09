import Testing
@testable import DynamicIsland

struct SettingsSearchTests {
	@Test(arguments: ["", "   "])
	func anEmptyQueryShowsEverything(query: String) {
		#expect(SettingsItem.matching(query) == SettingsItem.allCases)
		#expect(SettingsItem.panes(matching: query) == SettingsPane.allCases)
	}

	@Test(arguments: [
		("fullscreen", [SettingsItem.showInFullscreen]),
		("FULL screen", [.showInFullscreen]),
		("battery", [.chargingAnimation]),
		("version", [.about, .checkForUpdates]),
		("morning", [.updateTimeOfDay]),
		("weekly", [.updateFrequency]),
		("album cover", [.flipArtwork]),
	])
	func findsSettingsByTitleAndKeywords(query: String, expected: [SettingsItem]) {
		#expect(SettingsItem.matching(query) == expected)
	}

	@Test func everyWordHasToMatch() {
		#expect(SettingsItem.matching("lock spotify").isEmpty)
	}

	@Test func aPaneNameListsTheWholePane() {
		#expect(SettingsItem.matching("general") == SettingsItem.allCases.filter { $0.pane == .general })
		#expect(SettingsItem.panes(matching: "general") == [.general])
	}

	@Test func panesFollowTheirMatches() {
		#expect(SettingsItem.panes(matching: "update") == [.general])
		#expect(SettingsItem.panes(matching: "lock") == [.dynamicIsland])
		#expect(SettingsItem.panes(matching: "animation") == [.dynamicIsland])
		#expect(SettingsItem.panes(matching: "xyzzy").isEmpty)
	}

	@Test func everyPaneHasSettings() {
		for pane in SettingsPane.allCases {
			#expect(SettingsItem.allCases.contains { $0.pane == pane })
		}
	}
}
