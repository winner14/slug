import SwiftUI

struct MenuBarView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var recentRenames: [RenameEvent] = RenameHistory.shared.events
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            // Header
            HStack {
                Image(systemName: "camera.viewfinder")
                    .foregroundColor(.accentColor)
                Text("Slug")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            // Toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.isEnabled ? "Active" : "Paused")
                        .font(.subheadline).bold()
                    Text(settings.isEnabled
                         ? "Watching for new screenshots"
                         : "Tap to resume renaming")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $settings.isEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: settings.isEnabled) { enabled in
                        let delegate = NSApp.delegate as? AppDelegate
                        if enabled {
                            delegate?.startWatcherIfEnabled()
                        } else {
                            delegate?.stopWatcher()
                        }
                        delegate?.updateIcon()
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Recent renames
            VStack(alignment: .leading, spacing: 0) {
                Text("Recent")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                if recentRenames.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("No renames yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                } else {
                    ForEach(recentRenames.prefix(8)) { event in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(event.newName)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(event.timeAgo)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 5)
                        .background(Color.clear)
                    }
                }
            }
            .padding(.bottom, 10)

            Divider()

            // Footer buttons
            HStack(spacing: 8) {
                SettingsLink {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(7)
                    .font(.subheadline)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NSApp.activate(ignoringOtherApps: true)
                    }
                })

                Button {
                    NSApp.terminate(nil)
                } label: {
                    HStack {
                        Image(systemName: "power")
                        Text("Quit")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(7)
                    .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 300)
        .onReceive(NotificationCenter.default.publisher(for: .screenshotRenamed)) { _ in
            recentRenames = RenameHistory.shared.events
        }
    }
}
