import SwiftUI
import AppKit

struct SettingsView: View {
    @AppStorage("notesDirectory") private var notesDirectoryPath: String = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".nvALL").path
    }()
    @AppStorage("maxVersions") private var maxVersions: Int = 50

    var body: some View {
        Form {
            Section("Storage") {
                HStack {
                    Text("Notes folder:")
                    TextField("", text: $notesDirectoryPath)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 200)
                    Button("Choose...") {
                        chooseFolder()
                    }
                }
                Text("Notes are saved as Markdown (.md) files.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Section("History") {
                HStack {
                    Text("Max versions per note:")
                    TextField("", value: $maxVersions, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Stepper("", value: $maxVersions, in: 5...500, step: 5)
                        .labelsHidden()
                }
            }
            Section {
                Text("Changes take effect after restarting nvALL.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 300)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Choose a folder to store your notes"
        if panel.runModal() == .OK, let url = panel.url {
            notesDirectoryPath = url.path
        }
    }
}
