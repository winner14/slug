import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var apiKeyInput: String = AppSettings.shared.apiKey
    @State private var showAPIKey = false
    @State private var folderPickerOpen = false
    @State private var testStatus: TestStatus = .idle

    enum TestStatus {
        case idle, testing, success(String), failure(String)
    }

    var body: some View {
        Form {
            // API Key
            Section {
                HStack {
                    if showAPIKey {
                        TextField("AIza...", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("AIza...", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button {
                        showAPIKey.toggle()
                    } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }

                HStack {
                    Button("Save Key") {
                        settings.apiKey = apiKeyInput
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKeyInput == settings.apiKey)

                    Button("Test") {
                        runAPITest()
                    }
                    .disabled(settings.apiKey.isEmpty)

                    testStatusView
                }

                Link("Get a free Gemini API key →", destination: URL(string: "https://aistudio.google.com/apikey")!)
                    .font(.caption)
            } header: {
                Text("Gemini API Key")
            } footer: {
                Text("Free at aistudio.google.com — no credit card needed. Stored securely in macOS Keychain.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Watched Folder
            Section("Screenshots Folder") {
                HStack {
                    Text(settings.watchedFolder.path)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Change…") {
                        pickFolder()
                    }
                }
            }

            // Preferences
            Section("Preferences") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { enabled in
                        let delegate = NSApp.delegate as? AppDelegate
                        if enabled {
                            delegate?.enableLoginItem()
                        } else {
                            delegate?.disableLoginItem()
                        }
                    }
            }

            // Usage
            Section("Usage") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Free renames used")
                        Spacer()
                        Text("\(settings.renameCount) / \(settings.freeTierLimit)")
                            .foregroundColor(settings.isOverFreeLimit ? .red : .primary)
                    }
                    ProgressView(value: Double(settings.renameCount), total: Double(settings.freeTierLimit))

                    if settings.isOverFreeLimit {
                        Text("You've reached the free limit. Upgrade for unlimited renames.")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text("\(settings.remainingFreeRenames) renames remaining this month.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button("Reset count (for testing)") {
                        settings.resetMonthlyCount()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 480)
    }

    @ViewBuilder
    private var testStatusView: some View {
        switch testStatus {
        case .idle:
            EmptyView()
        case .testing:
            ProgressView().scaleEffect(0.6)
        case .success(let msg):
            Label(msg, systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        case .failure(let msg):
            Label(msg, systemImage: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.caption)
        }
    }

    private func runAPITest() {
        testStatus = .testing
//        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(settings.apiKey)"
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(settings.apiKey)"
        let body: [String: Any] = [
            "contents": [["parts": [["text": "Say OK"]]]]
        ]
        guard let url = URL(string: urlString),
              let data = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        URLSession.shared.dataTask(with: request) { respData, _, _ in
            DispatchQueue.main.async {
                if let respData = respData,
                   let json = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
                   json["candidates"] != nil {
                    testStatus = .success("Key valid!")
                } else {
                    testStatus = .failure("Invalid key")
                }
            }
        }.resume()
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        panel.message = "Choose the folder to watch for new screenshots."

        if panel.runModal() == .OK, let url = panel.url {
            settings.watchedFolder = url
            let delegate = NSApp.delegate as? AppDelegate
            delegate?.restartWatcher()
        }
    }
}
