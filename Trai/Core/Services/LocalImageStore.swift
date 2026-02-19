import Foundation

/// Stores image blobs on-device (App Group container) so CloudKit sync stays metadata-only.
final class LocalImageStore {
    static let shared = LocalImageStore()

    private let fileManager = FileManager.default
    private let cache = NSCache<NSString, NSData>()
    private let directoryURL: URL

    private init() {
        let fallbackBaseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let appGroupBaseURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: SharedStorageKeys.AppGroup.suiteName
        )
        let baseURL = appGroupBaseURL ?? fallbackBaseURL

        let imagesURL = baseURL.appendingPathComponent("LocalImages", isDirectory: true)
        try? fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        directoryURL = imagesURL
    }

    func loadData(for key: String) -> Data? {
        let cacheKey = key as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached as Data
        }

        let fileURL = url(for: key)
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else {
            return nil
        }
        cache.setObject(data as NSData, forKey: cacheKey)
        return data
    }

    func storeData(_ data: Data, for key: String) {
        guard !data.isEmpty else { return }
        let fileURL = url(for: key)
        cache.setObject(data as NSData, forKey: key as NSString)
        try? data.write(to: fileURL, options: [.atomic])
    }

    func removeData(for key: String) {
        cache.removeObject(forKey: key as NSString)
        try? fileManager.removeItem(at: url(for: key))
    }

    private func url(for key: String) -> URL {
        directoryURL.appendingPathComponent("\(key).blob", isDirectory: false)
    }
}
