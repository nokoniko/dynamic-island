import Foundation
import Testing
@testable import Hevel

struct LocalizationTests {
	static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

	static func table(_ code: String) -> [String: String] {
		let url = root.appendingPathComponent("Localization/\(code).lproj/Localizable.strings")
		return (NSDictionary(contentsOf: url) as? [String: String]) ?? [:]
	}

	/// Every `tr("…")` in the app, plus the settings titles that go through `tr` by name.
	static let keysInCode: Set<String> = {
		var keys = Set(SettingsItem.allCases.map(\.englishTitle) + SettingsPane.allCases.map(\.englishTitle))
		let sources = root.appendingPathComponent("Sources/Hevel")
		let regex = try! NSRegularExpression(pattern: #"\btr\("((?:[^"\\]|\\.)*)""#)
		for case let file as URL in FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)!
		where file.pathExtension == "swift" {
			let text = try! String(contentsOf: file, encoding: .utf8)
			for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
				keys.insert(String(text[Range(match.range(at: 1), in: text)!]).replacingOccurrences(of: #"\""#, with: "\""))
			}
		}
		return keys
	}()

	@Test(arguments: ["nb", "he"])
	func everyTextIsTranslated(code: String) {
		let missing = Self.keysInCode.subtracting(Self.table(code).keys)
		#expect(missing.isEmpty, "missing in \(code): \(missing.sorted())")
	}

	@Test(arguments: ["nb", "he"])
	func noLeftoverTranslations(code: String) {
		let unused = Set(Self.table(code).keys).subtracting(Self.keysInCode)
		#expect(unused.isEmpty, "unused in \(code): \(unused.sorted())")
	}

	@Test(arguments: ["nb", "he"])
	func placeholdersMatch(code: String) {
		let placeholder = try! NSRegularExpression(pattern: #"%(\d\$)?@"#)
		func placeholders(_ s: String) -> [String] {
			placeholder.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { String(s[Range($0.range, in: s)!]) }.sorted()
		}
		for (key, value) in Self.table(code) {
			#expect(placeholders(key) == placeholders(value), "\(code): \(key)")
		}
	}

	@Test(arguments: [
		(AppLanguage.english, ["nb-NO"], "en"),
		(.norwegian, ["en-US"], "nb"),
		(.hebrew, ["en-US"], "he"),
		(.system, ["nb-NO", "en-US"], "nb"),
		(.system, ["nn-NO"], "nb"),
		(.system, ["no"], "nb"),
		(.system, ["he-IL"], "he"),
		(.system, ["iw"], "he"),
		(.system, ["fr-FR", "he-IL", "en"], "he"),
		(.system, ["en_GB"], "en"),
		(.system, ["fr-FR", "de"], "en"),
		(.system, [], "en"),
	])
	func picksTheLanguage(choice: AppLanguage, preferred: [String], expected: String) {
		#expect(Localization.resolve(choice, preferred: preferred) == expected)
	}
}
