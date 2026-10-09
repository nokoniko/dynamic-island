import Foundation
import Testing
@testable import Hevel

struct UpdateInstallerTests {
	func folder(with apps: [String]) throws -> URL {
		let folder = FileManager.default.temporaryDirectory.appendingPathComponent("HevelTests-\(UUID().uuidString)")
		for app in apps {
			try FileManager.default.createDirectory(at: folder.appendingPathComponent(app), withIntermediateDirectories: true)
		}
		try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
		return folder
	}

	@Test func prefersHevelOverTheLegacyCopy() throws {
		let folder = try folder(with: ["DynamicIsland.app", "Hevel.app"])
		defer { try? FileManager.default.removeItem(at: folder) }
		#expect(UpdateInstaller.appBundle(in: folder)?.lastPathComponent == "Hevel.app")
	}

	@Test func takesAReleaseFromBeforeTheRename() throws {
		let folder = try folder(with: ["DynamicIsland.app"])
		defer { try? FileManager.default.removeItem(at: folder) }
		#expect(UpdateInstaller.appBundle(in: folder)?.lastPathComponent == "DynamicIsland.app")
	}

	@Test func findsNothingWithoutAnApp() throws {
		let folder = try folder(with: ["__MACOSX"])
		defer { try? FileManager.default.removeItem(at: folder) }
		#expect(UpdateInstaller.appBundle(in: folder) == nil)
	}
}
