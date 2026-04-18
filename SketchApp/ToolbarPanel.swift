import SwiftUI
import AppKit

class ToolbarWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        guard let screen = screen ?? NSScreen.main else { return frameRect }
        let screenRect = screen.visibleFrame
        var newRect = frameRect
        if newRect.minX < screenRect.minX { newRect.origin.x = screenRect.minX }
        if newRect.minY < screenRect.minY { newRect.origin.y = screenRect.minY }
        if newRect.maxX > screenRect.maxX { newRect.origin.x = screenRect.maxX - newRect.width }
        if newRect.maxY > screenRect.maxY { newRect.origin.y = screenRect.maxY - newRect.height }
        return newRect
    }
}

class ToolbarWindowController: NSWindowController {
    convenience init(appDelegate: AppDelegate) {
        let window = ToolbarWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 52),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
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

struct GlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(in: RoundedRectangle(cornerRadius: 34))
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 34))
        }
    }
}

struct ToolbarView: View {
    let appDelegate: AppDelegate
    @State private var selectedTool: SketchTool = .cursor

    var body: some View {
        HStack(spacing: 24) {
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
        .modifier(GlassModifier())
    }
}

struct ToolButton: View {
    let icon: String
    let tool: SketchTool
    @Binding var selected: SketchTool
    let appDelegate: AppDelegate
    @State private var isHovered = false

    var body: some View {
        Button {
            selected = tool
            ToolState.shared.currentTool = tool == .rectangle ? .rectangle : tool == .eraser ? .eraser : .line
            if tool == .cursor || tool == .lasso || tool == .ruler {
                ToolState.shared.isCursorMode = true
                appDelegate.overlayWindow?.ignoresMouseEvents = true
            } else if tool == .eraser {
                ToolState.shared.isCursorMode = false
                appDelegate.overlayWindow?.ignoresMouseEvents = false
                appDelegate.overlayWindow?.orderFront(nil)
            } else if tool == .trash {
                ToolState.shared.isCursorMode = false
                appDelegate.overlayWindow?.ignoresMouseEvents = false
                appDelegate.overlayWindow?.clearDrawing()
            } else {
                ToolState.shared.isCursorMode = false
                appDelegate.overlayWindow?.ignoresMouseEvents = false
                appDelegate.overlayWindow?.orderFront(nil)
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(selected == tool ? .primary : .secondary)
                .scaleEffect(isHovered ? 1.2 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
