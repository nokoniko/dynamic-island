import Foundation

/// The newest published release of the app that ships a signed build.
struct ReleaseInfo {
    let version: String      // "1.2.0" — the tag without its leading "v"
    let zipURL: URL
    let signatureURL: URL
}

/// Reads releases from the GitHub API (no token needed for public repos).
enum ReleaseFeed {

    private struct APIRelease: Decodable {
        let tag_name: String
        let assets: [APIAsset]
    }

    private struct APIAsset: Decodable {
        let name: String
        let browser_download_url: String
    }

    /// The latest non-draft, non-prerelease release, or nil if there is none or it
    /// has no `.zip` + matching `.zip.sig` (an unsigned release is ignored).
    static func latest(repo: String) async throws -> ReleaseInfo? {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Hevel-Updater", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw UpdateError.network }
        if http.statusCode == 404 { return nil }        // no releases published yet
        guard http.statusCode == 200 else { throw UpdateError.network }

        let release = try JSONDecoder().decode(APIRelease.self, from: data)
        guard let zip = release.assets.first(where: { $0.name.hasSuffix(".zip") }),
              let sig = release.assets.first(where: { $0.name == zip.name + ".sig" }),
              let zipURL = URL(string: zip.browser_download_url), zipURL.scheme == "https",
              let sigURL = URL(string: sig.browser_download_url), sigURL.scheme == "https"
        else { return nil }

        let tag = release.tag_name
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return ReleaseInfo(version: version, zipURL: zipURL, signatureURL: sigURL)
    }

    /// Dotted numeric comparison, so "1.10.0" is newer than "1.9.2".
    static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let pa = parts(a), pb = parts(b)
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// A newer version that only changes the last number: 2.2.0 → 2.2.7 is small,
    /// 2.2.7 → 2.3.0 isn't.
    static func isSmallUpdate(_ candidate: String, from current: String) -> Bool {
        let pc = parts(candidate), pr = parts(current)
        let sameMinor = (0..<2).allSatisfy { i in
            (i < pc.count ? pc[i] : 0) == (i < pr.count ? pr[i] : 0)
        }
        return sameMinor && isVersion(candidate, newerThan: current)
    }

    private static func parts(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
    }
}

enum UpdateError: LocalizedError {
    case network
    case badSignature
    case badArchive
    case translocated
    case notWritable(String)
    case installFailed

    var errorDescription: String? {
        switch self {
        case .network:
            return tr("Couldn't reach GitHub.")
        case .badSignature:
            return tr("The update didn't have a valid signature, so it wasn't installed.")
        case .badArchive:
            return tr("The update file was damaged or not what was expected.")
        case .translocated:
            return tr("Move Hevel to your Applications folder and try again.")
        case .notWritable(let path):
            return tr("Hevel can't write to %@.", path)
        case .installFailed:
            return tr("Couldn't install the update.")
        }
    }
}
