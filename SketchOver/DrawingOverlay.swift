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
                        // Detectar Shift para flecha
                        let isShift = NSEvent.modifierFlags.contains(.shift)
                        if isShift && toolState.currentTool == .straightLine {
                            NSCursor.crosshair.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                        let shapeType: ShapeType
                        if toolState.currentTool == .straightLine && isShift {
                            shapeType = .arrow
                        } else {
                            shapeType = toolState.currentTool
                        }
                        currentShape = DrawnShape(type: shapeType, points: [], color: toolState.currentColor, width: 6)
                    }

                    switch currentShape.type {
                    case .rectangle, .circle, .straightLine, .arrow:
                        currentShape.points = [value.startLocation, value.location]
                    default:
                        currentShape.points.append(value.location)
                    }
                }
                .onEnded { _ in
                    guard !toolState.isCursorMode else { return }
                    guard toolState.currentTool != .eraser else { return }
                    guard !currentShape.points.isEmpty else { return }
                    shapes.append(currentShape)
                    currentShape = DrawnShape(type: toolState.currentTool, points: [], color: toolState.currentColor, width: 6)
                }
        )
    }

    func eraseAt(point: CGPoint) {
        shapes.removeAll { shape in
            switch shape.type {
            case .rectangle:
                guard shape.points.count == 2 else { return false }
                let rect = CGRect(
                    x: min(shape.points[0].x, shape.points[1].x),
                    y: min(shape.points[0].y, shape.points[1].y),
                    width: abs(shape.points[1].x - shape.points[0].x),
                    height: abs(shape.points[1].y - shape.points[0].y)
                )
                return rect.contains(point)
            case .circle:
                guard shape.points.count == 2 else { return false }
                let cx = (shape.points[0].x + shape.points[1].x) / 2
                let cy = (shape.points[0].y + shape.points[1].y) / 2
                let rx = abs(shape.points[1].x - shape.points[0].x) / 2
                let ry = abs(shape.points[1].y - shape.points[0].y) / 2
                guard rx > 0 && ry > 0 else { return false }
                let dx = (point.x - cx) / rx
                let dy = (point.y - cy) / ry
                return (dx * dx + dy * dy) <= 1.0
            case .straightLine, .arrow:
                guard shape.points.count == 2 else { return false }
                return pointDistance(shape.points[0], point) < 20 ||
                       pointDistance(shape.points[1], point) < 20 ||
                       distanceFromPointToSegment(point, shape.points[0], shape.points[1]) < 20
            default:
                return shape.points.contains { shapePoint in
                    pointDistance(shapePoint, point) < 20
                }
            }
        }
    }

    func distanceFromPointToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSq = dx * dx + dy * dy
        guard lengthSq > 0 else { return pointDistance(p, a) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSq))
        let proj = CGPoint(x: a.x + t * dx, y: a.y + t * dy)
        return pointDistance(p, proj)
    }

    func drawShape(context: GraphicsContext, shape: DrawnShape) {
        let style = StrokeStyle(lineWidth: shape.width, lineCap: .round, lineJoin: .round)

        switch shape.type {
        case .line:
            guard shape.points.count > 1 else { return }
            var path = Path()
            path.move(to: shape.points[0])
            for point in shape.points.dropFirst() {
                path.addLine(to: point)
            }
            context.stroke(path, with: .color(shape.color), style: style)

        case .rectangle:
            guard shape.points.count == 2 else { return }
            let rect = CGRect(
                x: min(shape.points[0].x, shape.points[1].x),
                y: min(shape.points[0].y, shape.points[1].y),
                width: abs(shape.points[1].x - shape.points[0].x),
                height: abs(shape.points[1].y - shape.points[0].y)
            )
            let path = Path(roundedRect: rect, cornerRadius: 4)
            context.stroke(path, with: .color(shape.color), style: style)

        case .circle:
            guard shape.points.count == 2 else { return }
            let rect = CGRect(
                x: min(shape.points[0].x, shape.points[1].x),
                y: min(shape.points[0].y, shape.points[1].y),
                width: abs(shape.points[1].x - shape.points[0].x),
                height: abs(shape.points[1].y - shape.points[0].y)
            )
            let path = Path(ellipseIn: rect)
            context.stroke(path, with: .color(shape.color), style: style)

        case .straightLine:
            guard shape.points.count == 2 else { return }
            var path = Path()
            path.move(to: shape.points[0])
            path.addLine(to: shape.points[1])
            context.stroke(path, with: .color(shape.color), style: style)

        case .arrow:
            guard shape.points.count == 2 else { return }
            let start = shape.points[0]
            let end = shape.points[1]

            // Línea principal
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            context.stroke(path, with: .color(shape.color), style: style)

            // Punta de flecha
            let arrowLength: CGFloat = 20
            let arrowAngle: CGFloat = .pi / 6
            let angle = atan2(end.y - start.y, end.x - start.x)

            let tip1 = CGPoint(
                x: end.x - arrowLength * cos(angle - arrowAngle),
                y: end.y - arrowLength * sin(angle - arrowAngle)
            )
            let tip2 = CGPoint(
                x: end.x - arrowLength * cos(angle + arrowAngle),
                y: end.y - arrowLength * sin(angle + arrowAngle)
            )

            var arrowPath = Path()
            arrowPath.move(to: end)
            arrowPath.addLine(to: tip1)
            arrowPath.move(to: end)
            arrowPath.addLine(to: tip2)
            context.stroke(arrowPath, with: .color(shape.color), style: style)

        case .eraser:
            break
        }
    }
}
