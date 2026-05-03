struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                callback(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
import SwiftUI
import AppKit
import ServiceManagement

let appColor = Color(hex: "#5E5B59")

// MARK: - Color helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

struct GlassChipStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .monospaced).weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        Color.white.opacity(
                            configuration.isPressed ? 0.40 :
                            hovering ? 0.50 : 0.16
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        Color.white.opacity(hovering ? 0.7 : 0.4),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: .black.opacity(hovering ? 0.18 : 0.06),
                radius: hovering ? 10 : 5,
                y: 2
            )
            .scaleEffect(hovering ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.12), value: hovering)
            .onHover { hovering = $0 }
            
    }
}

// MARK: - Gray Menu Button Style (no blue highlight)
struct GrayMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Color.primary.opacity(0.5) : Color.primary)
    }
}

@main
struct DrawOverApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Button {
                appDelegate.showToolbar()
            } label: {
                Label("Show Draw Over", systemImage: "eye")
            }

            Button {
                appDelegate.toggleToolbar()
            } label: {
                Label("Global Shortcut", systemImage: "keyboard")
            }
            .keyboardShortcut("g", modifiers: [.command, .option, .shift])

            Divider()

            Button {
                appDelegate.handleToolShortcut("1")
            } label: {
                Label("Cursor", systemImage: "arrow.up.left")
            }
            .keyboardShortcut("1", modifiers: [])

            Button {
                appDelegate.handleToolShortcut("2")
            } label: {
                Label("Pencil", systemImage: "pencil")
            }
            .keyboardShortcut("2", modifiers: [])

            Button {
                appDelegate.handleToolShortcut("3")
            } label: {
                Label("Rectangle", systemImage: "rectangle")
            }
            .keyboardShortcut("3", modifiers: [])

            Button {
                appDelegate.handleToolShortcut("4")
            } label: {
                Label("Circle", systemImage: "circle")
            }
            .keyboardShortcut("4", modifiers: [])

            Button {
                appDelegate.handleToolShortcut("5")
            } label: {
                Label("Line", systemImage: "line.diagonal")
            }
            .keyboardShortcut("5", modifiers: [])

            Button {
                appDelegate.handleToolShortcut("5")
            } label: {
                Label("Arrow", systemImage: "arrow.up.right")
            }
            .keyboardShortcut("5", modifiers: [.shift])

            Button {
                appDelegate.handleToolShortcut("6")
            } label: {
                Label("Eraser", systemImage: "eraser")
            }
            .keyboardShortcut("6", modifiers: [])

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
        .commands {
            CommandGroup(replacing: .help) {
                Button("DrawOver Help") {
                    if let url = URL(string: "https://magicappslab.app/support.html") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
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

        let key = UserDefaults.standard.string(forKey: "shortcutKey") ?? "d"

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }

            let combo = event.modifierFlags.contains([.command, .option, .shift])

            if combo && event.charactersIgnoringModifiers?.lowercased() == key.lowercased() {
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
    window.orderFrontRegardless()
    NSApp.activate(ignoringOtherApps: true)
}

// MARK: - Settings
struct SettingsView: View {
    @State private var selection: SidebarItem = .general

    var body: some View {
        HStack(spacing: 0) {

            // Sidebar
            VStack(alignment: .leading, spacing: 12) {
                Text("General")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 4)

                sidebarItemView(title: "General", icon: "gearshape.fill", color: Color.gray, item: .general)
                sidebarItemView(title: "About", icon: "info.circle.fill", color: Color.green, item: .about)
                Spacer()
            }
            .padding(16)
            .frame(width: 180)
            .background(Color.clear)

            Divider()

            // Content
            ZStack {
                switch selection {
                case .general:
                    GeneralSettingsTab()
                case .about:
                    AboutTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.ultraThinMaterial)
        .background(WindowAccessor { window in
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isOpaque = false
            window.backgroundColor = .clear
        })
        .frame(width: 650, height: 280)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func sidebarButton(title: String, icon: String, item: SidebarItem) -> some View {
        let isSelected = selection == item

        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.12 : 0.08))
                    .frame(width: 28, height: 28)

                Image(systemName: icon)
                    .foregroundStyle(Color.primary.opacity(0.9))
                    .font(.system(size: 12, weight: .semibold))
            }

            Text(title)
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        .shadow(color: Color.black.opacity(0.06), radius: 6, y: 1)
                } else {
                    Color.clear
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selection = item
        }
    }

    @ViewBuilder
    private func sidebarItemView(title: String, icon: String, color: Color, item: SidebarItem, badge: String? = nil) -> some View {
        let isSelected = selection == item
        @State var isHovering = false

        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(color.opacity(0.18))
                    .frame(width: 26, height: 26)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? .primary : .secondary)
            if let badge = badge {
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.12))
                
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                    )
                    .cornerRadius(6)
            }
            Spacer()
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.56))
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        .shadow(color: Color.black.opacity(0.06), radius: 6, y: 1)
                } else if isHovering {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.05))
                } else {
                    Color.clear
                }
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover { isHovering = $0 }
        .onTapGesture { selection = item }
    }
}

enum SidebarItem: String, CaseIterable {
    case general
    case about
}

// MARK: - General Tab
struct GeneralSettingsTab: View {
    @AppStorage("shortcutKey") private var shortcutKey: String = "s"
    @State private var isRecording = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage("toolbarOpacity") private var toolbarOpacity: Double = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Title
            Text("General")
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.top, 16)

            // Rows (no boxed background)
            VStack(spacing: 0) {

                // Row 1
                HStack {
                    Text("Launch at login")
                    Spacer()
                    Toggle("", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .tint(Color(hex: "#14B8A6"))
                        .focusable(false)
                        .onChange(of: launchAtLogin){
                            do {
                                if launchAtLogin {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                print("Launch at login error: \(error)")
                            }
                        }
                        .accessibilityLabel("Launch at login")
                        .accessibilityHint("Automatically start Draw Over when you log in")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)

                Rectangle()
                    .fill(Color.black.opacity(0.06))
                    .frame(height: 1)
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.5))
                            .frame(height: 0.5),
                        alignment: .top
                    )
                
                
                // Row 2
                HStack {
                    Text("Toggle shortcut")
                    Spacer()
                    Button {
                        isRecording = true
                        startRecording()
                    } label: {
                        if isRecording {
                            Text("Press any key...")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.2)))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.35), lineWidth: 0.8))
                            
                        } else {
                            Text("⌘ ⌥ ⇧ \(shortcutKey.uppercased())")
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                        }
                    }
                    .buttonStyle(GlassChipStyle())
                    .focusable(false)
                    .accessibilityLabel("Toggle shortcut")
                    .accessibilityValue("Command Shift \(shortcutKey.uppercased())")
                    .accessibilityHint("Press to change the shortcut")
                    
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)

                Rectangle()
                    .fill(Color.black.opacity(0.06))
                    .frame(height: 1)
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.5))
                            .frame(height: 0.5),
                        alignment: .top
                    )

                // Row 3 - Opacity / Contrast
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Toolbar opacity")
                        Spacer()
                        Text("\(Int(toolbarOpacity * 100))%")
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $toolbarOpacity, in: 0.5...1.0)
                        .tint(Color(hex: "#14B8A6"))
                        .accessibilityLabel("Toolbar opacity")
                        .accessibilityValue("\(Int(toolbarOpacity * 100)) percent")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 1)
            .padding(.horizontal, 20)

            Spacer()
        }
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
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 20) {
                Image(nsImage: NSImage(named: "AppIconMarketing") ?? NSImage())
                    .resizable()
                    .frame(width: 90, height: 90)
                    .cornerRadius(20)
                    
                    

                VStack(alignment: .leading, spacing: 5) {
                    Text("Draw Over")
                        .font(.system(size: 20, weight: .bold))
                    

                    Text("Version 1.1.0")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Color(hex: "#14b8a6"))
                            .font(.system(size: 12))
                        Text("Licensed Free")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(spacing: 6) {
                    Button("What's New") {
                        openPanelWindow(view: WhatsNewView(), title: "What's New", width: 460, height: 460)
                    }
                    .buttonStyle(AboutButtonStyle())
                    .focusable(false)  // ← añade esto

                    Button("Introduction") {
                        openPanelWindow(view: IntroductionView(), title: "Introduction", width: 460, height: 520)
                    }
                    .buttonStyle(AboutButtonStyle())
                    .focusable(false)  // ← añade esto

                    Button("Support") {
                        if let url = URL(string: "https://magicappslab.app/support.html") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(AboutButtonStyle())
                    .focusable(false)  // ← añade esto
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 40)
           
            .cornerRadius(12)                                  // ← esquinas redondeadas

            Text("© 2026 Magic Apps Lab. All rights reserved.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.top, 16)
        }
        .padding(16)
    }
}

// MARK: - About Button Style
struct AboutButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .frame(width: 130)
            .padding(.vertical, 6)
            .background(
                isHovered
                    ? Color(hex: "#5E5B59").opacity(0.12)
                    : Color.clear
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.3), lineWidth: 0.8)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - What's New
struct WhatsNewView: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(nsImage: NSImage(named: "AppIconMarketing") ?? NSImage())
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
                    description: "Redesigned with improved contrast, cleaner layout and refined controls.",
                    badge: "New"
                )

                WhatsNewRow(
                    icon: "info.circle",
                    title: "About Section",
                    description: "Updated design with clearer layout, better hierarchy and quick access to key information."
                )
                WhatsNewRow(icon: "keyboard", title: "Tool Shortcuts", description: "Press 1–6 to switch tools. Hold ⇧ with Line to draw arrows.")
            }
            .padding(.horizontal, 20)

            Spacer()

            Button("Continue") { NSApp.keyWindow?.close() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(appColor)
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
                .foregroundStyle(appColor)
                .frame(width: 44, height: 44)
                .background(appColor.opacity(0.1))
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
                            .background(appColor.opacity(0.15))
                            .foregroundColor(appColor)
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
                Image(nsImage: NSImage(named: "AppIconMarketing") ?? NSImage())
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
                IntroRow(step: "2", title: "Pick a tool", description: "Press 1–6 to switch tools. Hold ⇧ with Line to draw arrows.")
                IntroRow(step: "3", title: "Draw over anything", description: "Draw Over floats above all your apps. Annotate anything on screen.")
                IntroRow(step: "4", title: "Save your work", description: "Hit the share button to save your drawing as a PNG.")
            }
            .padding(.horizontal, 20)

            Spacer()

            Button("Got it!") { NSApp.keyWindow?.close() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(appColor)
                .padding(.bottom, 24)
        }
        .frame(width: 460, height: 520)
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
                .background(appColor)
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

