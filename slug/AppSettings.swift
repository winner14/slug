import Foundation
import Combine

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "isEnabled") }
    }

    @Published var apiKey: String {
        didSet { saveAPIKey(apiKey) }
    }

    @Published var watchedFolder: URL {
        didSet { UserDefaults.standard.set(watchedFolder.path, forKey: "watchedFolder") }
    }

    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }

    @Published var renameCount: Int {
        didSet { UserDefaults.standard.set(renameCount, forKey: "renameCount") }
    }

    /// Monthly free tier limit
    let freeTierLimit = 30

    var remainingFreeRenames: Int {
        max(0, freeTierLimit - renameCount)
    }

    var isOverFreeLimit: Bool {
        renameCount >= freeTierLimit
    }

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: "isEnabled")

        let savedPath = UserDefaults.standard.string(forKey: "watchedFolder")
        if let path = savedPath {
            watchedFolder = URL(fileURLWithPath: path)
        } else {
            // Default: ~/Desktop/Screenshots or ~/Desktop
            let screenshots = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            watchedFolder = screenshots
        }

        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        renameCount = UserDefaults.standard.integer(forKey: "renameCount")
        apiKey = AppSettings.loadAPIKey() ?? ""
    }

    // MARK: - Keychain storage for API key

    private static let keychainService = "com.screenshotnamer.apikey"
    private static let keychainAccount = "anthropic"

    private func saveAPIKey(_ key: String) {
        let data = key.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppSettings.keychainService,
            kSecAttrAccount as String: AppSettings.keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
        if !key.isEmpty {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private static func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else { return nil }
        return key
    }

    func incrementRenameCount() {
        renameCount += 1
    }

    func resetMonthlyCount() {
        renameCount = 0
    }
}
