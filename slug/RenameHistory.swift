import Foundation

struct RenameEvent: Identifiable, Codable {
    let id: UUID
    let originalName: String
    let newName: String
    let date: Date

    var timeAgo: String {
        let interval = Date().timeIntervalSince(date)
        switch interval {
        case ..<60: return "just now"
        case ..<3600: return "\(Int(interval / 60))m ago"
        case ..<86400: return "\(Int(interval / 3600))h ago"
        default: return "\(Int(interval / 86400))d ago"
        }
    }
}

class RenameHistory {
    static let shared = RenameHistory()

    private let maxEvents = 50
    private let storageKey = "renameHistory"
    private(set) var events: [RenameEvent] = []

    var recent: [RenameEvent] { Array(events.prefix(8)) }

    private init() {
        load()
        observeRenames()
    }

    private func observeRenames() {
        NotificationCenter.default.addObserver(
            forName: .screenshotRenamed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let original = notification.userInfo?["original"] as? URL,
                  let renamed = notification.userInfo?["renamed"] as? URL else { return }
            self?.add(original: original.lastPathComponent, renamed: renamed.lastPathComponent)
        }
    }

    func add(original: String, renamed: String) {
        let event = RenameEvent(
            id: UUID(),
            originalName: original,
            newName: renamed,
            date: Date()
        )
        events.insert(event, at: 0)
        if events.count > maxEvents {
            events = Array(events.prefix(maxEvents))
        }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([RenameEvent].self, from: data) else { return }
        events = decoded
    }
}
