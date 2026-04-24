import SwiftUI
import AppKit

@main
struct DrawOverApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Button("Show DrawOver") {
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

        // Monitor global — cuando otra app tiene el foco
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            let cmdShift = event.modifierFlags.contains([.command, .shift])
            if cmdShift && event.charactersIgnoringModifiers == key {
                DispatchQueue.main.async { self.toggleToolbar() }
                return
            }
            guard !event.modifierFlags.contains(.command),
                  !event.modifierFlags.contains(.shift) else { return }
            self.handleToolShortcut(event.charactersIgnoringModifiers ?? "")
        }

        // Monitor local — cuando DrawOver tiene el foco
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
            }
        case "3":
            DispatchQueue.main.async {
                ToolState.shared.currentTool = .rectangle
                ToolState.shared.selectedTool = .rectangle
                ToolState.shared.isCursorMode = false
                self.overlayWindow?.ignoresMouseEvents = false
            }
        case "4":
            DispatchQueue.main.async {
                ToolState.shared.currentTool = .circle
                ToolState.shared.selectedTool = .circle
                ToolState.shared.isCursorMode = false
                self.overlayWindow?.ignoresMouseEvents = false
            }
        case "5":
            DispatchQueue.main.async {
                ToolState.shared.currentTool = .straightLine
                ToolState.shared.selectedTool = .line
                ToolState.shared.isCursorMode = false
                self.overlayWindow?.ignoresMouseEvents = false
            }
        case "6":
            DispatchQueue.main.async {
                ToolState.shared.currentTool = .eraser
                ToolState.shared.selectedTool = .eraser
                ToolState.shared.isCursorMode = false
                self.overlayWindow?.ignoresMouseEvents = false
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
    }

    func toggleToolbar() {
        if toolbarController?.window?.isVisible == true {
            toolbarController?.close()
            overlayWindow?.orderOut(nil)
            overlayWindow?.ignoresMouseEvents = true
            ToolState.shared.isCursorMode = true
        } else {
            showToolbar()
            ToolState.shared.isCursorMode = true
            overlayWindow?.ignoresMouseEvents = true
            overlayWindow?.orderOut(nil)
        }
    }
}

struct SettingsView: View {
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

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("1 — Cursor")
                    Text("2 — Pencil")
                    Text("3 — Rectangle")
                    Text("4 — Circle")
                    Text("5 — Line")
                    Text("6 — Eraser")
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            } header: {
                Text("Tool shortcuts")
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .padding()
    }

    func startRecording() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
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
