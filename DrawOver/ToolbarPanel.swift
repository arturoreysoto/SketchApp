import SwiftUI
import AppKit
import UniformTypeIdentifiers

class ToolbarWindow: NSPanel {


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
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 52),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.becomesKeyOnlyIfNeeded = true
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
    case circle
    case line
    case eraser
    case share
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
    @ObservedObject private var toolState = ToolState.shared
    @AppStorage("toolbarOpacity") private var toolbarOpacity: Double = 1.0

    let colors: [Color] = [.black, .white, .red, .orange, .yellow, .green, .blue, .purple]

    var body: some View {
        HStack(spacing: 16) {
            ToolButton(icon: "pointer.arrow.ipad", tool: .cursor, selected: $toolState.selectedTool, appDelegate: appDelegate)
            ToolButton(icon: "pencil.tip", tool: .pencil, selected: $toolState.selectedTool, appDelegate: appDelegate)
            ToolButton(icon: "square", tool: .rectangle, selected: $toolState.selectedTool, appDelegate: appDelegate)
            ToolButton(icon: "circle", tool: .circle, selected: $toolState.selectedTool, appDelegate: appDelegate)
            ToolButton(icon: "line.diagonal", tool: .line, selected: $toolState.selectedTool, appDelegate: appDelegate)
            ToolButton(icon: "eraser", tool: .eraser, selected: $toolState.selectedTool, appDelegate: appDelegate)

            Divider()
                .frame(height: 20)
                .opacity(0.3)

            HStack(spacing: 8) {
                ForEach(colors, id: \.self) { color in
                    ColorButton(color: color)
                }
            }

            Divider()
                .frame(height: 20)
                .opacity(0.3)

            ShareButton(appDelegate: appDelegate)

            ToolButton(icon: "trash", tool: .trash, selected: $toolState.selectedTool, appDelegate: appDelegate)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .modifier(GlassModifier())
        .opacity(toolbarOpacity)
    }
}

func saveScreenshot(appDelegate: AppDelegate) {
    ToolState.shared.isCursorMode = true
    appDelegate.overlayWindow?.ignoresMouseEvents = true

    let panel = NSSavePanel()
    panel.allowedContentTypes = [.png]
    panel.nameFieldStringValue = "DrawOver-capture.png"
    panel.begin { response in
        guard response == .OK, let url = panel.url else { return }
        guard let overlayWindow = appDelegate.overlayWindow,
              let contentView = overlayWindow.contentView else { return }
        let rep = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds)!
        contentView.cacheDisplay(in: contentView.bounds, to: rep)
        let image = NSImage(size: contentView.bounds.size)
        image.addRepresentation(rep)
        if let tiffData = image.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            try? pngData.write(to: url)
        }
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
            if tool == .cursor {
                ToolState.shared.isCursorMode = true
                appDelegate.overlayWindow?.ignoresMouseEvents = true
            } else if tool == .trash {
                ToolState.shared.isCursorMode = false
                appDelegate.overlayWindow?.ignoresMouseEvents = false
                appDelegate.overlayWindow?.clearDrawing()
            } else {
                ToolState.shared.isCursorMode = false
                appDelegate.overlayWindow?.ignoresMouseEvents = false
                appDelegate.overlayWindow?.orderFront(nil)
                ToolState.shared.currentTool = tool == .rectangle ? .rectangle :
                                                tool == .circle    ? .circle    :
                                                tool == .line      ? .straightLine :
                                                tool == .eraser    ? .eraser    : .line
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(selected == tool ? .primary : .secondary)
                .scaleEffect(isHovered ? 1.2 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isHovered)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ColorButton: View {
    let color: Color
    @ObservedObject private var toolState = ToolState.shared
    @State private var isHovered = false

    var isSelected: Bool { toolState.currentColor == color }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                toolState.currentColor = color
            }
        } label: {
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
                .shadow(
                    color: isHovered || isSelected ? color.opacity(0.6) : .clear,
                    radius: isHovered || isSelected ? 5 : 0
                )
                .overlay(
                    Circle().stroke(
                        isSelected ? Color.primary : Color.primary.opacity(0.15),
                        lineWidth: isSelected ? 2 : 1
                    )
                )
                .scaleEffect(isHovered ? 1.3 : isSelected ? 1.2 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isHovered)
                .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isSelected)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .focusEffectDisabled() // 👈 clave para quitar el azul
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ShareButton: View {
    let appDelegate: AppDelegate
    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
            saveScreenshot(appDelegate: appDelegate)
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 18))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .scaleEffect(isPressed ? 0.85 : isHovered ? 1.2 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isHovered)
                .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isPressed)
        }
        .buttonStyle(.plain)
        .focusable(false)          // 👈 añadir
        .focusEffectDisabled()     // 👈 añadir
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
