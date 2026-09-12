import Foundation

@MainActor
final class EditingViewModel: ObservableObject {
    @Published var toolMode: ToolMode = .draw
    @Published var selectionStart: (row: Int, col: Int)?
    @Published var selectionEnd: (row: Int, col: Int)?
}
