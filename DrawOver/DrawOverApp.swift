import SwiftUI
import AppKit

@main
struct DrawOverApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Button("Show Draw Over") {
                appDelegate.showToolbar()
            }
            Divider()
            SettingsLink {
                Text("Settings...")
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: "pencil.tip")
        }

        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var toolbarController: ToolbarWindowController?
    var overlayWindow: DrawingOverlayWindow?
    private var eventMonitor: Any?
    private var localMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if UserDefaults.standard.string(forKey: "shortcutKey") == nil {
            UserDefaults.standard.set("s", forKey: "shortcutKey")
        }
        overlayWindow = DrawingOverlayWindow()
        overlayWindow?.ignoresMouseEvents = true
        showToolbar()
        setupGlobalShortcut()
    }

    func setupGlobalShortcut() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        let key = UserDefaults.standard.string(forKey: "shortcutKey") ?? "s"

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            let cmdShift = event.modifierFlags.contains([.command, .shift])
            if cmdShift && event.charactersIgnoringModifiers == key {
                DispatchQueue.main.async { self.toggleToolbar() }
                return
            }
            guard self.toolbarController?.window?.isVisible == true else { return }
            guard !event.modifierFlags.contains(.command),
                  !event.modifierFlags.contains(.shift) else { return }
            self.handleToolShortcut(event.charactersIgnoringModifiers ?? "")
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let cmdShift = event.modifierFlags.contains([.command, .shift])
            if cmdShift && event.charactersIgnoringModifiers == key {
                DispatchQueue.main.async { self.toggleToolbar() }
                return nil
            }
            guard !event.modifierFlags.contains(.command),
                  !event.modifierFlags.contains(.shift) else { return event }
            let handled = self.handleToolShortcut(event.charactersIgnoringModifiers ?? "")
            return handled ? nil : event
        }
    }

    @discardableResult
    func handleToolShortcut(_ key: String) -> Bool {
        switch key {
        case "1":
            DispatchQueue.main.async {
                ToolState.shared.isCursorMode = true
                ToolState.shared.selectedTool = .cursor
                self.overlayWindow?.ignoresMouseEvents = true
            }
        case "2":
            DispatchQueue.main.async {
                ToolState.shared.currentTool = .line
                ToolState.shared.selectedTool = .pencil
                ToolState.shared.isCursorMode = false
                self.overlayWindow?.ignoresMouseEvents = false
                self.overlayWindow?.orderFront(nil)
            }
        case "3":
            DispatchQueue.main.async {
                ToolState.shared.currentTool = .rectangle
                ToolState.shared.selectedTool = .rectangle
                ToolState.shared.isCursorMode = false
                self.overlayWindow?.ignoresMouseEvents = false
                self.overlayWindow?.orderFront(nil)
            }
        case "4":
            DispatchQueue.main.async {
                ToolState.shared.currentTool = .circle
                ToolState.shared.selectedTool = .circle
                ToolState.shared.isCursorMode = false
                self.overlayWindow?.ignoresMouseEvents = false
                self.overlayWindow?.orderFront(nil)
            }
        case "5":
            DispatchQueue.main.async {
                ToolState.shared.currentTool = .straightLine
                ToolState.shared.selectedTool = .line
                ToolState.shared.isCursorMode = false
                self.overlayWindow?.ignoresMouseEvents = false
                self.overlayWindow?.orderFront(nil)
            }
        case "6":
            DispatchQueue.main.async {
                ToolState.shared.currentTool = .eraser
                ToolState.shared.selectedTool = .eraser
                ToolState.shared.isCursorMode = false
                self.overlayWindow?.ignoresMouseEvents = false
                self.overlayWindow?.orderFront(nil)
            }
        default:
            return false
        }
        return true
    }

    func showToolbar() {
        if toolbarController == nil {
            toolbarController = ToolbarWindowController(appDelegate: self)
        }
        toolbarController?.showWindow(nil)
        ToolState.shared.isCursorMode = true
        ToolState.shared.selectedTool = .cursor
        overlayWindow?.ignoresMouseEvents = true
    }

    func toggleToolbar() {
        if toolbarController?.window?.isVisible == true {
            toolbarController?.close()
            overlayWindow?.orderOut(nil)
            overlayWindow?.ignoresMouseEvents = true
            ToolState.shared.isCursorMode = true
            ToolState.shared.selectedTool = .cursor
        } else {
            showToolbar()
        }
    }
}

// MARK: - Helper ventana separada
func openPanelWindow<V: View>(view: V, title: String, width: CGFloat, height: CGFloat) {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: width, height: height),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
    window.title = title
    window.center()
    window.isReleasedWhenClosed = false
    window.setContentSize(NSSize(width: width, height: height))
    window.minSize = NSSize(width: width, height: height)
    window.maxSize = NSSize(width: width, height: height)
    window.contentView = NSHostingView(rootView: view)
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}

// MARK: - Settings
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 560, height: 240)
    }
}

// MARK: - General Tab
struct GeneralSettingsTab: View {
    @AppStorage("shortcutKey") private var shortcutKey: String = "s"
    @State private var isRecording = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Toggle shortcut")
                    Spacer()
                    Button {
                        isRecording = true
                        startRecording()
                    } label: {
                        HStack(spacing: 6) {
                            if isRecording {
                                Text("Press any key...")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("⌘ ⇧ \(shortcutKey.uppercased())")
                                    .fontWeight(.medium)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isRecording ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Keyboard")
            }
        }
        .formStyle(.grouped)
    }

    func startRecording() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard self.isRecording else { return event }
            let key = event.charactersIgnoringModifiers ?? ""
            guard !key.isEmpty && key != "\u{1B}" else {
                self.isRecording = false
                return nil
            }
            self.shortcutKey = key
            self.isRecording = false
            UserDefaults.standard.set(key, forKey: "shortcutKey")
            if let delegate = NSApp.delegate as? AppDelegate {
                delegate.setupGlobalShortcut()
            }
            return nil
        }
    }
}

// MARK: - About Tab
struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 24) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 80, height: 80)
                    .cornerRadius(18)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Draw Over")
                        .font(.system(size: 22, weight: .bold))
                        .fixedSize()

                    Text("Version 1.1.0")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 13))
                        Text("Licensed Free")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(spacing: 8) {
                    Button("What's New") {
                        openPanelWindow(
                            view: WhatsNewView(),
                            title: "What's New",
                            width: 460,
                            height: 460
                        )
                    }
                    .buttonStyle(AboutButtonStyle())

                    Button("Introduction") {
                        openPanelWindow(
                            view: IntroductionView(),
                            title: "Introduction",
                            width: 460,
                            height: 560
                        )
                    }
                    .buttonStyle(AboutButtonStyle())

                    Button("Support") {
                        if let url = URL(string: "https://magicappslab.app/") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(AboutButtonStyle())
                }
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)

            Text("© 2025 Magic Apps Lab. All rights reserved.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(20)
    }
}

// MARK: - About Button Style
struct AboutButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .frame(width: 130)
            .padding(.vertical, 7)
            .background(configuration.isPressed
                ? Color.secondary.opacity(0.2)
                : Color(NSColor.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(8)
    }
}

// MARK: - What's New
struct WhatsNewView: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 60, height: 60)
                    .cornerRadius(14)

                Text("What's New in Draw Over")
                    .font(.system(size: 24, weight: .bold))
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            VStack(spacing: 10) {
                WhatsNewRow(
                    icon: "gearshape.2",
                    title: "New Settings",
                    description: "Redesigned settings with a cleaner, more professional look.",
                    badge: "New"
                )
                WhatsNewRow(
                    icon: "info.circle",
                    title: "About Section",
                    description: "Version info, license status and quick links in one place."
                )
                WhatsNewRow(
                    icon: "keyboard",
                    title: "Tool Shortcuts",
                    description: "Use keys 1–6 to switch tools instantly while drawing."
                )
            }
            .padding(.horizontal, 20)

            Spacer()

            Button("Continue") {
                NSApp.keyWindow?.close()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.pink)
            .padding(.bottom, 28)
        }
        .frame(width: 460, height: 460)
    }
}

// MARK: - What's New Row
struct WhatsNewRow: View {
    let icon: String
    let title: String
    let description: String
    var badge: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.pink)
                .frame(width: 44, height: 44)
                .background(Color.pink.opacity(0.1))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.pink.opacity(0.15))
                            .foregroundColor(.pink)
                            .cornerRadius(4)
                    }
                }
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - Introduction
struct IntroductionView: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 60, height: 60)
                    .cornerRadius(14)

                Text("Introduction")
                    .font(.system(size: 24, weight: .bold))
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            VStack(spacing: 8) {
                IntroRow(step: "1", title: "Toggle Draw Over", description: "Press ⌘ ⇧ S to show or hide the toolbar from anywhere.")
                IntroRow(step: "2", title: "Pick a tool", description: "Use keys 1–6: Cursor, Pencil, Rectangle, Circle, Line, Eraser.")
                IntroRow(step: "3", title: "Draw over anything", description: "Draw Over floats above all your apps. Annotate anything on screen.")
                IntroRow(step: "4", title: "Save your work", description: "Hit the share button to save your drawing as a PNG.")
            }
            .padding(.horizontal, 20)

            Spacer()

            Button("Got it!") {
                NSApp.keyWindow?.close()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.pink)
            .padding(.bottom, 24)
        }
        .frame(width: 460, height: 480)
    }
}

// MARK: - Intro Row
struct IntroRow: View {
    let step: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(step)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Color(red: 1.0, green: 0.45, blue: 0.45))  // ← rojo pastel
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}
