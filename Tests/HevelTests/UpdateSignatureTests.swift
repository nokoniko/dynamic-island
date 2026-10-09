import CryptoKit
import Foundation
import Testing
@testable import Hevel

struct UpdateSignatureTests {
	let key = Curve25519.Signing.PrivateKey()
	let zip = Data("pretend this is Hevel-1.2.0.zip".utf8)

	private func sigFile(for data: Data, signedBy signer: Curve25519.Signing.PrivateKey) throws -> Data {
		Data((try signer.signature(for: data).hexString + "\n").utf8)
	}

	private func verify(_ data: Data, sigFile: Data, publicKey: Curve25519.Signing.PublicKey) throws -> Bool {
		let signature = try #require(UpdateInstaller.signature(fromSigFile: sigFile))
		return UpdateInstaller.isAuthentic(data, signature: signature, publicKey: publicKey)
	}

	@Test func acceptsAValidSignature() throws {
		let publicKey = try #require(UpdateInstaller.publicKey(fromHex: key.publicKey.rawRepresentation.hexString))
		#expect(try verify(zip, sigFile: sigFile(for: zip, signedBy: key), publicKey: publicKey))
	}

	@Test func rejectsATamperedZip() throws {
		var tampered = zip
		tampered[0] ^= 0xFF
		#expect(try !verify(tampered, sigFile: sigFile(for: zip, signedBy: key), publicKey: key.publicKey))
	}

	@Test func rejectsASignatureFromAnotherKey() throws {
		let other = Curve25519.Signing.PrivateKey()
		#expect(try !verify(zip, sigFile: sigFile(for: zip, signedBy: other), publicKey: key.publicKey))
	}

	@Test func rejectsAnEmptySigFile() throws {
		#expect(try !verify(zip, sigFile: Data(), publicKey: key.publicKey))
	}

	@Test func readsUppercaseHexAndSurroundingWhitespace() throws {
		let signature = try key.signature(for: zip)
		let file = Data(("  " + signature.hexString.uppercased() + "\r\n").utf8)
		#expect(UpdateInstaller.signature(fromSigFile: file) == signature)
	}

	@Test(arguments: [
		Data("zz".utf8) + Data(String(repeating: "0", count: 126).utf8),
		Data("abc".utf8),
		Data("not hex at all\n".utf8),
		Data([0xFF, 0xFE, 0x00]),
	])
	func refusesSigFilesThatAreNotHex(contents: Data) {
		#expect(UpdateInstaller.signature(fromSigFile: contents) == nil)
	}

	@Test(arguments: ["", "abc", "zz", String(repeating: "ab", count: 31), String(repeating: "ab", count: 33)])
	func refusesPublicKeysThatAreNotA32ByteHexKey(hex: String) {
		#expect(UpdateInstaller.publicKey(fromHex: hex) == nil)
	}
}

struct RustSignedFixtureTests {
	private func fixture(_ name: String) throws -> Data {
		let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures/rust-signed"))
		return try Data(contentsOf: url)
	}

	private func fixturePublicKey() throws -> Curve25519.Signing.PublicKey {
		let hex = String(decoding: try fixture("public_key.txt"), as: UTF8.self)
		return try #require(UpdateInstaller.publicKey(fromHex: hex.trimmingCharacters(in: .whitespacesAndNewlines)))
	}

	@Test func cryptoKitAcceptsAnUpdateSignedByTheRustBuilder() throws {
		let signature = try #require(UpdateInstaller.signature(fromSigFile: fixture("update.zip.sig")))
		#expect(UpdateInstaller.isAuthentic(try fixture("update.zip"), signature: signature, publicKey: try fixturePublicKey()))
	}

	@Test func cryptoKitRejectsTheRustSignedUpdateOnceTampered() throws {
		var zip = try fixture("update.zip")
		zip[zip.count / 2] ^= 0x01
		let signature = try #require(UpdateInstaller.signature(fromSigFile: fixture("update.zip.sig")))
		#expect(!UpdateInstaller.isAuthentic(zip, signature: signature, publicKey: try fixturePublicKey()))
	}
}
