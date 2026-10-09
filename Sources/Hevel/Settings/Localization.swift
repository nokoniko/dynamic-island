import Foundation

/// The language picked in Settings. `system` follows the order of languages in
/// macOS's System Settings.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english, norwegian, hebrew

    var id: Self { self }

    var code: String? {
        switch self {
        case .system: nil
        case .english: "en"
        case .norwegian: "nb"
        case .hebrew: "he"
        }
    }

    /// Each language in its own words, so anyone can find theirs.
    var name: String {
        switch self {
        case .system: tr("System")
        case .english: "English"
        case .norwegian: "Norsk"
        case .hebrew: "עברית"
        }
    }
}

/// Looks texts up in `Localization/<code>.lproj/Localizable.strings` (copied into the
/// app by `builder`). The keys are the English texts, so English needs no table and
/// anything missing falls back to English. Lookups go through the chosen language's
/// table directly rather than macOS's preferred one, so switching takes effect at
/// once, without a restart.
enum Localization {
    static var language: String {
        resolve(Preferences.appLanguage, preferred: Locale.preferredLanguages)
    }

    static var isRightToLeft: Bool { language == "he" }

    static var locale: Locale { Locale(identifier: language) }

    /// The chosen language, or the first of the user's macOS languages the app has.
    /// Nynorsk and plain "no" get Bokmål; "iw" is the old code for Hebrew.
    static func resolve(_ choice: AppLanguage, preferred: [String]) -> String {
        if let code = choice.code { return code }
        for identifier in preferred {
            let base = identifier.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)
            switch base {
            case "en": return "en"
            case "nb", "nn", "no": return "nb"
            case "he", "iw": return "he"
            default: continue
            }
        }
        return "en"
    }

    static var bundle: Bundle {
        Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    }
}

/// The text in the current language.
func tr(_ key: String) -> String {
    Localization.bundle.localizedString(forKey: key, value: key, table: nil)
}

/// The text in the current language with `%@` placeholders filled in.
func tr(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: tr(key), locale: Localization.locale, arguments: arguments)
}
