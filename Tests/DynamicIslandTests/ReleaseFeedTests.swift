import Testing
@testable import DynamicIsland

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
}
