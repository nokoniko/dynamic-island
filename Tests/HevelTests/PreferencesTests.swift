import Testing
@testable import Hevel

struct PreferencesTests {
	@Test(arguments: [
		(Preferences.hideWhilePlayerInFrontKey, true),
		(Preferences.showInFullscreenKey, false),
		(Preferences.flipArtworkKey, true),
		(Preferences.chargingAnimationKey, true),
		(Preferences.lockScreenIconKey, true),
		(Preferences.autoCheckForUpdatesKey, true),
		(Preferences.installUpdatesAutomaticallyKey, true),
		(Preferences.skipSmallUpdatesKey, false),
	])
	func defaultsKeepTheOriginalBehavior(key: String, value: Bool) {
		#expect(Preferences.defaults[key] as? Bool == value)
	}

	@Test func languageFollowsTheSystem() {
		#expect(Preferences.defaults[Preferences.appLanguageKey] as? String == AppLanguage.system.rawValue)
	}

	@Test func updatesAreCheckedDailyInTheMorning() {
		#expect(Preferences.defaults[Preferences.updateFrequencyKey] as? String == UpdateFrequency.daily.rawValue)
		#expect(Preferences.defaults[Preferences.updateTimeOfDayKey] as? String == UpdateTimeOfDay.morning.rawValue)
	}

	@Test func everySettingHasADefault() {
		#expect(Preferences.defaults.count == 11)
	}
}
