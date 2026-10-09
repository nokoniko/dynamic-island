import AppKit
import CryptoKit

/// Downloads a release, checks its Ed25519 signature against the public key baked
/// into this build, then swaps it in place of the running app and relaunches.
/// Nothing outside a temp folder is touched until the signature checks out.
enum UpdateInstaller {

    /// Download, verify and unpack. Returns the verified new `.app` and the temp
    /// folder it lives in (cleaned up by the swap script after install).
    static func prepare(_ release: ReleaseInfo, publicKeyHex: String) async throws -> (app: URL, workDir: URL) {
        guard let publicKey = publicKey(fromHex: publicKeyHex) else { throw UpdateError.badSignature }

        let (sigData, _) = try await URLSession.shared.data(from: release.signatureURL)
        guard let signature = signature(fromSigFile: sigData) else { throw UpdateError.badSignature }

        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("DynamicIslandUpdate-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        do {
            let (downloaded, _) = try await URLSession.shared.download(from: release.zipURL)
            let zip = work.appendingPathComponent("update.zip")
            try fm.moveItem(at: downloaded, to: zip)

            // The signature covers the exact zip bytes we're about to unpack.
            let zipData = try Data(contentsOf: zip, options: .mappedIfSafe)
            guard isAuthentic(zipData, signature: signature, publicKey: publicKey) else { throw UpdateError.badSignature }

            let unpacked = work.appendingPathComponent("unpacked")
            guard run("/usr/bin/ditto", ["-x", "-k", zip.path, unpacked.path]) else { throw UpdateError.badArchive }
            let newApp = unpacked.appendingPathComponent("DynamicIsland.app")
            guard let bundle = Bundle(url: newApp),
                  bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
                  run("/usr/bin/codesign", ["--verify", "--deep", newApp.path])
            else { throw UpdateError.badArchive }
            run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newApp.path])
            return (newApp, work)
        } catch {
            try? fm.removeItem(at: work)
            throw error
        }
    }

    /// Hand the verified bundle to a small shell script that waits for this process
    /// to exit, swaps the bundles (rolling back if the copy fails), cleans up and
    /// reopens the app — then quit so it can run.
    @MainActor
    static func installAndRelaunch(newApp: URL, workDir: URL) throws {
        let target = Bundle.main.bundleURL
        // A quarantined app run from Downloads runs from a read-only random path.
        guard !target.path.contains("/AppTranslocation/") else { throw UpdateError.translocated }
        let parent = target.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: parent.path) else {
            throw UpdateError.notWritable(parent.path)
        }

        let script = """
        pid="$1"; target="$2"; new="$3"; work="$4"
        while kill -0 "$pid" 2>/dev/null; do sleep 0.2; done
        rm -rf "$target.old"
        if mv "$target" "$target.old" && ditto "$new" "$target"; then
          rm -rf "$target.old"
        else
          rm -rf "$target"; mv "$target.old" "$target"
        fi
        rm -rf "$work"
        open "$target"
        """
        let swap = Process()
        swap.executableURL = URL(fileURLWithPath: "/bin/sh")
        swap.arguments = ["-c", script, "sh",
                          String(ProcessInfo.processInfo.processIdentifier),
                          target.path, newApp.path, workDir.path]
        do { try swap.run() } catch { throw UpdateError.installFailed }
        NSApp.terminate(nil)
    }

    static func publicKey(fromHex hex: String) -> Curve25519.Signing.PublicKey? {
        guard let bytes = Data(hex: hex) else { return nil }
        return try? Curve25519.Signing.PublicKey(rawRepresentation: bytes)
    }

    /// A release's `.sig` file: the hex signature, optionally followed by whitespace.
    static func signature(fromSigFile data: Data) -> Data? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        return Data(hex: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func isAuthentic(_ data: Data, signature: Data, publicKey: Curve25519.Signing.PublicKey) -> Bool {
        publicKey.isValidSignature(signature, for: data)
    }

    @discardableResult
    private static func run(_ tool: String, _ args: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }
}

extension Data {
    /// Decode a hex string like "0a1bff"; nil if it's malformed.
    init?(hex: String) {
        let chars = Array(hex.utf8)
        guard chars.count % 2 == 0 else { return nil }
        func nibble(_ c: UInt8) -> UInt8? {
            switch c {
            case UInt8(ascii: "0")...UInt8(ascii: "9"): return c - UInt8(ascii: "0")
            case UInt8(ascii: "a")...UInt8(ascii: "f"): return c - UInt8(ascii: "a") + 10
            case UInt8(ascii: "A")...UInt8(ascii: "F"): return c - UInt8(ascii: "A") + 10
            default: return nil
            }
        }
        var out = Data(capacity: chars.count / 2)
        var i = 0
        while i < chars.count {
            guard let hi = nibble(chars[i]), let lo = nibble(chars[i + 1]) else { return nil }
            out.append(hi << 4 | lo)
            i += 2
        }
        self = out
    }
}
