import Testing
@testable import DynamicIsland

struct PreferencesTests {
	@Test(arguments: [
		(Preferences.hideWhilePlayerInFrontKey, true),
		(Preferences.showInFullscreenKey, false),
		(Preferences.flipArtworkKey, true),
		(Preferences.chargingAnimationKey, true),
		(Preferences.lockScreenIconKey, true),
		(Preferences.autoCheckForUpdatesKey, true),
	])
	func defaultsKeepTheOriginalBehavior(key: String, value: Bool) {
		#expect(Preferences.defaults[key] as? Bool == value)
	}

	@Test func updatesAreCheckedDailyInTheMorning() {
		#expect(Preferences.defaults[Preferences.updateFrequencyKey] as? String == UpdateFrequency.daily.rawValue)
		#expect(Preferences.defaults[Preferences.updateTimeOfDayKey] as? String == UpdateTimeOfDay.morning.rawValue)
	}

	@Test func everySettingHasADefault() {
		#expect(Preferences.defaults.count == 8)
	}
}
