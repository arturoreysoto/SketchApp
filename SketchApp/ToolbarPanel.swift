import SwiftUI
import AppKit

class ToolbarWindowController: NSWindowController {
    convenience init(appDelegate: AppDelegate) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 52),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.center()
        window.contentView = NSHostingView(rootView: ToolbarView(appDelegate: appDelegate))
        self.init(window: window)
    }
}

enum SketchTool {
    case cursor
    case pencil
    case rectangle
    case scribble
    case eraser
    case lasso
    case ruler
    case trash
}

struct ToolbarView: View {
    let appDelegate: AppDelegate
    @State private var selectedTool: SketchTool = .cursor

    var body: some View {
        HStack(spacing: 16) {
            ToolButton(icon: "pointer.arrow.ipad", tool: .cursor, selected: $selectedTool, appDelegate: appDelegate)
            ToolButton(icon: "pencil.tip", tool: .pencil, selected: $selectedTool, appDelegate: appDelegate)
            ToolButton(icon: "square", tool: .rectangle, selected: $selectedTool, appDelegate: appDelegate)
            ToolButton(icon: "scribble", tool: .scribble, selected: $selectedTool, appDelegate: appDelegate)
            ToolButton(icon: "eraser", tool: .eraser, selected: $selectedTool, appDelegate: appDelegate)
            ToolButton(icon: "lasso.badge.sparkles", tool: .lasso, selected: $selectedTool, appDelegate: appDelegate)
            ToolButton(icon: "pencil.and.ruler", tool: .ruler, selected: $selectedTool, appDelegate: appDelegate)
            ToolButton(icon: "trash", tool: .trash, selected: $selectedTool, appDelegate: appDelegate)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct ToolButton: View {
    let icon: String
    let tool: SketchTool
    @Binding var selected: SketchTool
    let appDelegate: AppDelegate

    var body: some View {
        Button {
            selected = tool
            ToolState.shared.currentTool = tool == .rectangle ? .rectangle : .line
            if tool == .cursor {
                ToolState.shared.isCursorMode = true
                appDelegate.overlayWindow?.ignoresMouseEvents = true
            } else if tool == .eraser || tool == .trash {
                ToolState.shared.isCursorMode = false
                appDelegate.overlayWindow?.ignoresMouseEvents = false
                appDelegate.overlayWindow?.clearDrawing()
            } else {
                ToolState.shared.isCursorMode = false
                appDelegate.overlayWindow?.ignoresMouseEvents = false
                appDelegate.overlayWindow?.orderFront(nil)
                print("Lápiz - overlayWindow: \(String(describing: appDelegate.overlayWindow))")
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(selected == tool ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }
}
