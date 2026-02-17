import AppKit
import Foundation

actor JellyfinArtworkCache {
    static let shared = JellyfinArtworkCache()

    private let memoryCache = NSCache<NSString, NSImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        memoryCache.countLimit = 300

        let cachesRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        cacheDirectory = cachesRoot.appendingPathComponent("HiFidelity/JellyfinArtwork", isDirectory: true)

        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func image(for url: URL) async -> NSImage? {
        let key = cacheKey(for: url)

        if let inMemory = memoryCache.object(forKey: key as NSString) {
            return inMemory
        }

        let diskURL = cacheDirectory.appendingPathComponent(fileName(for: key))
        if let data = try? Data(contentsOf: diskURL), let image = NSImage(data: data) {
            memoryCache.setObject(image, forKey: key as NSString)
            return image
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 25

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let image = NSImage(data: data) else {
                return nil
            }

            memoryCache.setObject(image, forKey: key as NSString)
            try? data.write(to: diskURL, options: .atomic)
            return image
        } catch {
            return nil
        }
    }

    private func cacheKey(for url: URL) -> String {
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if let items = comps?.queryItems {
            comps?.queryItems = items.filter { $0.name.lowercased() != "api_key" }
        }

        return comps?.string ?? url.absoluteString
    }

    private func fileName(for key: String) -> String {
        Data(key.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
            + ".img"
    }
}
