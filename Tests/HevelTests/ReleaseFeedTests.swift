import Testing
@testable import Hevel

struct ReleaseFeedTests {
	@Test(arguments: [
		("1.0.1", "1.0.0", true),
		("1.1.0", "1.0.9", true),
		("2.0.0", "1.99.99", true),
		("1.10.0", "1.9.2", true),
		("1.0.1", "1.0", true),
		("1.0.0", "1.0.0", false),
		("1.0", "1.0.0", false),
		("1.0.0", "1.0", false),
		("1.0.0", "1.0.1", false),
		("1.9.2", "1.10.0", false),
		("1.2.3beta", "1.2.2", true),
		("abc", "0", false),
		("0.0.1", "abc", true),
	])
	func comparesDottedVersionsNumerically(candidate: String, current: String, isNewer: Bool) {
		#expect(ReleaseFeed.isVersion(candidate, newerThan: current) == isNewer)
	}

	@Test(arguments: [
		("2.2.7", "2.2.0", true),
		("2.2.1", "2.2", true),
		("2.2.10", "2.2.9", true),
		("2.3.0", "2.2.7", false),
		("2.3", "2.2.0", false),
		("3.0.0", "2.9.9", false),
		("2.3.4", "2.2.0", false),
		("2.2.0", "2.2.0", false),
		("2.2.0", "2.2.7", false),
	])
	func smallUpdatesOnlyChangeTheLastNumber(candidate: String, current: String, isSmall: Bool) {
		#expect(ReleaseFeed.isSmallUpdate(candidate, from: current) == isSmall)
	}
}
