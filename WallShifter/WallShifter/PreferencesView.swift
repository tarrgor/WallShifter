import SwiftUI
import AppKit
import Combine

// MARK: - Root

struct PreferencesView: View {
    @EnvironmentObject private var configStore: ConfigStore

    var body: some View {
        TabView {
            SourcesTab()
                .tabItem { Label("Sources", systemImage: "folder") }
                .environmentObject(configStore)

            ScheduleTab()
                .tabItem { Label("Schedule", systemImage: "clock") }
                .environmentObject(configStore)

            DisplaysTab()
                .tabItem { Label("Displays", systemImage: "display") }
                .environmentObject(configStore)

            AdvancedTab()
                .tabItem { Label("Advanced", systemImage: "gearshape") }
                .environmentObject(configStore)
        }
        .frame(width: 520, height: 380)
        .padding()
    }
}

// MARK: - Sources tab

struct SourcesTab: View {
    @EnvironmentObject private var configStore: ConfigStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Image Sources")
                .font(.headline)

            if configStore.config.sources.isEmpty {
                Text("No sources added yet. Click + to add a folder.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                List {
                    ForEach($configStore.config.sources) { $source in
                        SourceRow(source: $source) {
                            removeSource(id: source.id)
                        }
                    }
                }
                .listStyle(.bordered)
                .frame(minHeight: 160)
            }

            HStack {
                Button(action: addFolderSource) {
                    Label("Add Folder…", systemImage: "plus")
                }
                Spacer()
                Text("\(configStore.config.sources.count) source(s)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding()
    }

    private func addFolderSource() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        panel.message = "Choose a folder containing wallpaper images."

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let source = ImageSource(type: .folder, path: url.path)
        configStore.createAndSaveBookmark(for: url, sourceID: source.id)
        configStore.config.sources.append(source)
    }

    private func removeSource(id: String) {
        configStore.config.sources.removeAll { $0.id == id }
        configStore.removeBookmark(for: id)
    }
}

private struct SourceRow: View {
    @Binding var source: ImageSource
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Toggle("", isOn: $source.enabled)
                .labelsHidden()
                .toggleStyle(.checkbox)

            VStack(alignment: .leading, spacing: 2) {
                Text(source.path.isEmpty ? "(no path)" : URL(fileURLWithPath: source.path).lastPathComponent)
                    .lineLimit(1)
                Text(source.path.isEmpty ? "" : source.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if source.type == .folder {
                Toggle("Recursive", isOn: $source.recursive)
                    .toggleStyle(.checkbox)
                    .font(.caption)
            }

            Button(action: onRemove) {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Schedule tab

struct ScheduleTab: View {
    @EnvironmentObject private var configStore: ConfigStore

    private let intervalOptions: [(label: String, seconds: TimeInterval)] = [
        ("1 minute", 60),
        ("5 minutes", 300),
        ("10 minutes", 600),
        ("30 minutes", 1800),
        ("1 hour", 3600),
        ("2 hours", 7200),
        ("6 hours", 21600),
        ("24 hours", 86400),
    ]

    var body: some View {
        Form {
            Section("Rotation Interval") {
                Picker("Change every", selection: $configStore.config.schedule.intervalSeconds) {
                    ForEach(intervalOptions, id: \.seconds) { option in
                        Text(option.label).tag(option.seconds)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Rotation Order") {
                Picker("Order", selection: $configStore.config.order) {
                    Text("Random (no repeat)").tag(RotationOrder.randomNoRepeat)
                    Text("Random").tag(RotationOrder.random)
                    Text("Sequential").tag(RotationOrder.sequential)
                    Text("Newest first").tag(RotationOrder.newestFirst)
                }
                .pickerStyle(.menu)
            }

            Section("Triggers") {
                Toggle("Change on wake from sleep", isOn: $configStore.config.schedule.changeOnWake)
                Toggle("Change on login", isOn: $configStore.config.schedule.changeOnLogin)
                Toggle("Change on launch", isOn: $configStore.config.schedule.changeOnLaunch)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Displays tab

struct DisplaysTab: View {
    @EnvironmentObject private var configStore: ConfigStore

    var body: some View {
        Form {
            Section("Multi-Display") {
                Picker("Display mode", selection: $configStore.config.displayMode) {
                    Text("Same image on all displays").tag(DisplayMode.allSame)
                    Text("Different image per display").tag(DisplayMode.allDifferent)
                    Text("Independent per display").tag(DisplayMode.perDisplay)
                }
                .pickerStyle(.menu)
            }

            Section("Image Fitting") {
                Picker("Default fitting", selection: $configStore.config.fitting) {
                    Text("Fill (crop to fill)").tag(WallpaperFitting.fill)
                    Text("Fit (letterbox)").tag(WallpaperFitting.fit)
                    Text("Stretch").tag(WallpaperFitting.stretch)
                    Text("Center").tag(WallpaperFitting.center)
                    Text("Tile").tag(WallpaperFitting.tile)
                }
                .pickerStyle(.menu)
            }

            if !configStore.config.displays.isEmpty {
                Section("Connected Displays") {
                    ForEach($configStore.config.displays) { $display in
                        HStack {
                            Text("Display \(display.id)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker("Fitting", selection: $display.fitting) {
                                Text("Fill").tag(WallpaperFitting.fill)
                                Text("Fit").tag(WallpaperFitting.fit)
                                Text("Stretch").tag(WallpaperFitting.stretch)
                                Text("Center").tag(WallpaperFitting.center)
                                Text("Tile").tag(WallpaperFitting.tile)
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 120)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Advanced tab

struct AdvancedTab: View {
    @EnvironmentObject private var configStore: ConfigStore
    @State private var loginItemEnabled: Bool = false
    @State private var transitionStyle: TransitionStyle = .instant

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $loginItemEnabled)
                    .onChange(of: loginItemEnabled) { _, newValue in
                        configStore.config.advanced.launchAtLogin = newValue
                        LoginItemManager.shared.setEnabled(newValue)
                    }
            }

            Section("History") {
                Stepper(
                    "Remember last \(configStore.config.advanced.historySize) images",
                    value: $configStore.config.advanced.historySize,
                    in: 5...100,
                    step: 5
                )
            }

            Section("Transition") {
                Picker("Style", selection: $transitionStyle) {
                    Text("Instant").tag(TransitionStyle.instant)
                    Text("Fade").tag(TransitionStyle.fade)
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            if #available(macOS 13, *) {
                loginItemEnabled = LoginItemManager.shared.isEnabled
            } else {
                loginItemEnabled = configStore.config.advanced.launchAtLogin
            }
            transitionStyle = configStore.config.advanced.transition
        }
        .onReceive(configStore.$config.map(\.advanced.transition).removeDuplicates()) { newValue in
            if transitionStyle != newValue { transitionStyle = newValue }
        }
        .onChange(of: transitionStyle) { _, newValue in
            configStore.config.advanced.transition = newValue
        }
    }
}
