import AppKit
import SwiftUI
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var watcher: ScreenshotWatcher?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        startWatcherIfEnabled()
        registerLoginItem()
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            if let icon = NSImage(named: "MenuBarIcon") {
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = true
                button.image = icon
            }
            button.action = #selector(togglePopover)
            button.target = self
        }

        updateIcon()
    }

    @objc private func togglePopover() {
        if let popover = popover, popover.isShown {
            popover.performClose(nil)
            return
        }

        if popover == nil {
            let p = NSPopover()
            p.contentSize = NSSize(width: 280, height: 320)
            p.behavior = .transient
            p.contentViewController = NSHostingController(
                rootView: MenuBarView(onClose: { [weak self] in
                    self?.popover?.performClose(nil)
                })
            )
            self.popover = p
        }

        if let button = statusItem.button {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover?.contentViewController?.view.window?.makeKey()
        }
    }
    
    @objc private func closePopover() {
        popover?.performClose(nil)
    }

    func updateIcon() {
        let isOn = AppSettings.shared.isEnabled
        let symbolName = isOn ? "camera.viewfinder" : "camera.viewfinder"
        if let icon = NSImage(named: "MenuBarIcon") {
            icon.size = NSSize(width: 18, height: 18)
            icon.isTemplate = false
            statusItem.button?.image = icon
        }
        statusItem.button?.appearsDisabled = !isOn
    }

    // MARK: - Watcher

    func startWatcherIfEnabled() {
        guard AppSettings.shared.isEnabled else { return }
        watcher = ScreenshotWatcher()
        watcher?.start()
    }

    func stopWatcher() {
        watcher?.stop()
        watcher = nil
    }

    func restartWatcher() {
        stopWatcher()
        startWatcherIfEnabled()
    }

    // MARK: - Login Item

    private func registerLoginItem() {
        if AppSettings.shared.launchAtLogin {
            enableLoginItem()
        }
    }

    func enableLoginItem() {
        if #available(macOS 13.0, *) {
            try? SMAppService.mainApp.register()
        }
    }

    func disableLoginItem() {
        if #available(macOS 13.0, *) {
            try? SMAppService.mainApp.unregister()
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
}
