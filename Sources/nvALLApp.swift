import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.appearance = NSAppearance(named: .darkAqua)

    }
}

@main
struct nvALLApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var notesManager = NotesManager()

    var body: some Scene {
        WindowGroup("nvALL") {
            ContentView()
                .environmentObject(notesManager)
        }
        .defaultSize(width: 550, height: 450)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    notesManager.createNote(title: notesManager.searchText)
                    notesManager.searchText = ""
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            TextEditingCommands()
        }

        Settings {
            SettingsView()
        }
    }
}
