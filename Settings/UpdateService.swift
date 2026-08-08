import Foundation

final class UpdateService {
    enum Result {
        case upToDate
        case updateAvailable(version: String, url: URL)
        case noPublishedRelease
        case failed
    }

    private struct GitHubRelease: Decodable {
        let tagName: String
        let htmlURL: URL
        private enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    private let latestReleaseURL = URL(
        string: "https://api.github.com/repos/norgera/Blackout/releases/latest"
    )!

    func check(currentVersion: String, completion: @escaping (Result) -> Void) {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Blackout/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, response, error in
            let result: Result
            if error != nil {
                result = .failed
            } else if (response as? HTTPURLResponse)?.statusCode == 404 {
                result = .noPublishedRelease
            } else if let response = response as? HTTPURLResponse,
                      (200..<300).contains(response.statusCode),
                      let data,
                      let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) {
                let latestVersion = Self.normalized(release.tagName)
                let currentVersion = Self.normalized(currentVersion)
                if latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
                    result = .updateAvailable(
                        version: release.tagName,
                        url: release.htmlURL
                    )
                } else {
                    result = .upToDate
                }
            } else {
                result = .failed
            }

            DispatchQueue.main.async {
                completion(result)
            }
        }.resume()
    }

    private static func normalized(_ version: String) -> String {
        guard version.first == "v" || version.first == "V" else {
            return version
        }
        return String(version.dropFirst())
    }
}
