import Testing
@testable import Hevel

struct SettingsHistoryTests {
	@Test func startsOnGeneralWithNowhereToGo() {
		let history = SettingsHistory()
		#expect(history.current == .pane(.general))
		#expect(!history.canGoBack)
		#expect(!history.canGoForward)
	}

	@Test func backAndForwardRetraceTheSteps() {
		var history = SettingsHistory()
		history.go(to: .softwareUpdate)
		history.go(to: .pane(.island))
		history.goBack()
		#expect(history.current == .softwareUpdate)
		history.goBack()
		#expect(history.current == .pane(.general))
		#expect(!history.canGoBack)
		history.goForward()
		history.goForward()
		#expect(history.current == .pane(.island))
		#expect(!history.canGoForward)
	}

	@Test func goingSomewhereNewDropsTheForwardSteps() {
		var history = SettingsHistory()
		history.go(to: .pane(.island))
		history.goBack()
		history.go(to: .pane(.language))
		#expect(!history.canGoForward)
		history.goBack()
		#expect(history.current == .pane(.general))
	}

	@Test func theCurrentPageIsNoStep() {
		var history = SettingsHistory()
		history.go(to: .pane(.general))
		#expect(!history.canGoBack)
	}

	@Test func replacingLeavesNoStep() {
		var history = SettingsHistory()
		history.replace(with: .pane(.island))
		#expect(history.current == .pane(.island))
		#expect(!history.canGoBack)
	}

	@Test func softwareUpdateBelongsToGeneral() {
		#expect(SettingsPage.softwareUpdate.pane == .general)
	}
}
