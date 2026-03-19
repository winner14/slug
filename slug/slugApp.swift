//
//  slugApp.swift
//  slug
//
//  Created by Winner on 18/03/2026.
//

import SwiftUI

@main
struct ScreenshotNamerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — pure menu bar app
        Settings {
            SettingsView()
        }
    }
}
