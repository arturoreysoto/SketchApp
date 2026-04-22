import SwiftUI
import Combine

class ToolState: ObservableObject {
    static let shared = ToolState()
    @Published var currentTool: ShapeType = .line
    @Published var isCursorMode: Bool = false
    @Published var currentColor: Color = .black
    @Published var isShiftPressed: Bool = false
}

enum ShapeType {
    case line
    case rectangle
    case circle
    case straightLine
    case arrow
    case eraser
}
