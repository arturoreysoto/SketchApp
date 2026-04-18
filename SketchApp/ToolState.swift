import SwiftUI
import Combine

class ToolState: ObservableObject {
    static let shared = ToolState()
    @Published var currentTool: ShapeType = .line
    @Published var isCursorMode: Bool = false
}
