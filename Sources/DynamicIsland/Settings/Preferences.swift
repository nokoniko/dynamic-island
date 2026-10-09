import Foundation

/// User settings, stored in UserDefaults. The settings window binds to the same
/// keys with `@AppStorage`; the rest of the app reads them at the moment it acts.
enum Preferences {
    static let hideWhilePlayerInFrontKey = "hideWhilePlayerInFront"
    static let showInFullscreenKey = "showInFullscreen"
    static let flipArtworkKey = "flipArtworkOnTrackChange"
    static let chargingAnimationKey = "chargingAnimation"
    static let lockScreenIconKey = "lockScreenIcon"
    static let autoCheckForUpdatesKey = "autoCheckForUpdates"
    static let updateFrequencyKey = "updateFrequency"
    static let updateTimeOfDayKey = "updateTimeOfDay"
    /// Seconds since 1970 of the last check that reached GitHub; absent until the first one.
    static let lastUpdateCheckKey = "lastUpdateCheck"

    /// The defaults match how the app behaved before it had settings.
    static let defaults: [String: Any] = [
        hideWhilePlayerInFrontKey: true,
        showInFullscreenKey: false,
        flipArtworkKey: true,
        chargingAnimationKey: true,
        lockScreenIconKey: true,
        autoCheckForUpdatesKey: true,
        updateFrequencyKey: UpdateFrequency.daily.rawValue,
        updateTimeOfDayKey: UpdateTimeOfDay.morning.rawValue,
    ]

    static func register() {
        UserDefaults.standard.register(defaults: defaults)
    }

    static var hideWhilePlayerInFront: Bool { UserDefaults.standard.bool(forKey: hideWhilePlayerInFrontKey) }
    static var showInFullscreen: Bool { UserDefaults.standard.bool(forKey: showInFullscreenKey) }
    static var chargingAnimation: Bool { UserDefaults.standard.bool(forKey: chargingAnimationKey) }
    static var lockScreenIcon: Bool { UserDefaults.standard.bool(forKey: lockScreenIconKey) }
    static var autoCheckForUpdates: Bool { UserDefaults.standard.bool(forKey: autoCheckForUpdatesKey) }

    static var updateFrequency: UpdateFrequency {
        UserDefaults.standard.string(forKey: updateFrequencyKey).flatMap(UpdateFrequency.init) ?? .daily
    }

    static var updateTimeOfDay: UpdateTimeOfDay {
        UserDefaults.standard.string(forKey: updateTimeOfDayKey).flatMap(UpdateTimeOfDay.init) ?? .morning
    }

    static var lastUpdateCheck: Date? {
        get {
            let seconds = UserDefaults.standard.double(forKey: lastUpdateCheckKey)
            return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
        }
        set { UserDefaults.standard.set(newValue?.timeIntervalSince1970, forKey: lastUpdateCheckKey) }
    }

    static func nextUpdateCheck(now: Date = Date()) -> Date {
        UpdateSchedule.nextCheck(after: lastUpdateCheck, frequency: updateFrequency,
                                 timeOfDay: updateTimeOfDay, now: now, calendar: .current)
    }
}
