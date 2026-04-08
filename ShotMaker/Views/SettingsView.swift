import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Watch Directory") {
                HStack {
                    Text(settings.watchDirectory)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer()
                    Button("Choose...") {
                        pickDirectory()
                    }
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            Section("Display") {
                HStack {
                    Text("Thumbnail Size")
                    Slider(value: $settings.thumbnailSize, in: 120...300, step: 20)
                    Text("\(Int(settings.thumbnailSize))px")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 40)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 220)
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: settings.watchDirectory)

        if panel.runModal() == .OK, let url = panel.url {
            settings.watchDirectory = url.path
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("[ShotMaker] Launch at login error: \(error)")
            }
        }
    }
}
