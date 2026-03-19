import Foundation
import CoreServices

class ScreenshotWatcher {
    private var eventStream: FSEventStreamRef?
    private let namer = ScreenshotNamer()

    /// Files we're currently processing — prevents double-rename
    private var processingFiles = Set<String>()
    private let queue = DispatchQueue(label: "com.screenshotnamer.watcher", qos: .utility)

    func start() {
        let folder = AppSettings.shared.watchedFolder.path as CFString
        let pathsToWatch = [folder] as CFArray

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        eventStream = FSEventStreamCreate(
            nil,
            eventCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5, // latency in seconds
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        if let stream = eventStream {
            FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            FSEventStreamStart(stream)
            print("[Watcher] Started watching: \(AppSettings.shared.watchedFolder.path)")
        }
    }

    func stop() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
            print("[Watcher] Stopped.")
        }
    }

    fileprivate func handleEvents(paths: [String], flags: [FSEventStreamEventFlags]) {
        for (path, flag) in zip(paths, flags) {
            let isCreated = flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0
            let isRenamed = flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed) != 0
            let isFile = flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile) != 0

            guard isFile && (isCreated || isRenamed) else { continue }
            guard isScreenshot(path: path) else { continue }
            guard !processingFiles.contains(path) else { continue }

            processingFiles.insert(path)

            queue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.processFile(at: path)
            }
        }
    }

    private func isScreenshot(path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard url.pathExtension.lowercased() == "png" else { return false }
        let name = url.deletingPathExtension().lastPathComponent
        // Match macOS default: "Screenshot 2026-03-18 at 9.41.23 AM"
        return name.hasPrefix("Screenshot ")
    }

    private func processFile(at path: String) {
        defer { processingFiles.remove(path) }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else { return }

        print("[Watcher] New screenshot detected: \(url.lastPathComponent)")

        namer.rename(url: url) { result in
            switch result {
            case .success(let newURL):
                print("[Watcher] Renamed to: \(newURL.lastPathComponent)")
                NotificationCenter.default.post(
                    name: .screenshotRenamed,
                    object: nil,
                    userInfo: ["original": url, "renamed": newURL]
                )
            case .failure(let error):
                print("[Watcher] Rename failed: \(error.localizedDescription)")
                NotificationCenter.default.post(
                    name: .screenshotRenameFailed,
                    object: nil,
                    userInfo: ["url": url, "error": error]
                )
            }
        }
    }
}

// MARK: - C callback (must be a free function)

private let eventCallback: FSEventStreamCallback = { _, clientCallBackInfo, numEvents, eventPaths, eventFlags, _ in
    guard let info = clientCallBackInfo else { return }
    let watcher = Unmanaged<ScreenshotWatcher>.fromOpaque(info).takeUnretainedValue()

    guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }
    let flags = (0..<numEvents).map { eventFlags[$0] }

    watcher.handleEvents(paths: paths, flags: flags)
}

// MARK: - Notification names

extension Notification.Name {
    static let screenshotRenamed = Notification.Name("screenshotRenamed")
    static let screenshotRenameFailed = Notification.Name("screenshotRenameFailed")
}
