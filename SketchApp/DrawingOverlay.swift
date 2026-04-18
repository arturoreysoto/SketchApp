import SwiftUI
import AppKit

class DrawingOverlayWindow: NSWindow {
    init() {
        let screen = NSScreen.main!.frame
        super.init(
            contentRect: screen,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.contentView = NSHostingView(rootView: DrawingView())
    }
    
    func clearDrawing() {
        self.contentView = NSHostingView(rootView: DrawingView())
    }
}

struct DrawnShape {
    var type: ShapeType
    var points: [CGPoint]
    var color: Color
    var width: CGFloat
}

func pointDistance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    sqrt(pow(b.x - a.x, 2) + pow(b.y - a.y, 2))
}

struct DrawingView: View {
    @State private var shapes: [DrawnShape] = []
    @State private var currentShape: DrawnShape = DrawnShape(type: .line, points: [], color: .black, width: 6)
    @ObservedObject private var toolState = ToolState.shared

    var body: some View {
        Canvas { context, size in
            for shape in shapes {
                drawShape(context: context, shape: shape)
            }
            drawShape(context: context, shape: currentShape)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard !toolState.isCursorMode else { return }
                    
                    if toolState.currentTool == .eraser {
                        eraseAt(point: value.location)
                        return
                    }
                    
                    if currentShape.points.isEmpty {
                        currentShape = DrawnShape(type: toolState.currentTool, points: [], color: .black, width: 6)
                    }
                    if toolState.currentTool == .rectangle {
                        currentShape.points = [value.startLocation, value.location]
                    } else {
                        currentShape.points.append(value.location)
                    }
                }
                .onEnded { _ in
                    guard !toolState.isCursorMode else { return }
                    guard toolState.currentTool != .eraser else { return }
                    guard !currentShape.points.isEmpty else { return }
                    shapes.append(currentShape)
                    currentShape = DrawnShape(type: toolState.currentTool, points: [], color: .black, width: 6)
                }
        )
    }

    func eraseAt(point: CGPoint) {
        shapes.removeAll { shape in
            shape.points.contains { shapePoint in
                pointDistance(shapePoint, point) < 20
            }
        }
    }

    func drawShape(context: GraphicsContext, shape: DrawnShape) {
        if shape.type == .line {
            guard shape.points.count > 1 else { return }
            var path = Path()
            path.move(to: shape.points[0])
            for point in shape.points.dropFirst() {
                path.addLine(to: point)
            }
            let style = StrokeStyle(lineWidth: shape.width, lineCap: .round, lineJoin: .round)
            context.stroke(path, with: .color(shape.color), style: style)
        } else if shape.type == .rectangle {
            guard shape.points.count == 2 else { return }
            let rect = CGRect(
                x: min(shape.points[0].x, shape.points[1].x),
                y: min(shape.points[0].y, shape.points[1].y),
                width: abs(shape.points[1].x - shape.points[0].x),
                height: abs(shape.points[1].y - shape.points[0].y)
            )
            let path = Path(roundedRect: rect, cornerRadius: 4)
            let style = StrokeStyle(lineWidth: shape.width, lineCap: .round, lineJoin: .round)
            context.stroke(path, with: .color(shape.color), style: style)
        }
    }
}
