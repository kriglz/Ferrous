import Foundation

@MainActor
final class EditingViewModel: ObservableObject {
    @Published var toolMode: ToolMode = .draw
    @Published var selectionStart: (row: Int, col: Int)?
    @Published var selectionEnd: (row: Int, col: Int)?

    /// A pattern loaded from the library or copied from a selection, ready
    /// to be stamped onto the grid by clicking in `.stamp` tool mode.
    @Published var pendingPattern: Pattern?
    @Published var pendingPatternMerge: Bool = true
    @Published var stampPreviewOrigin: (row: Int, col: Int)?

    func loadFromLibrary(_ pattern: Pattern) {
        pendingPattern = pattern
        pendingPatternMerge = true
        toolMode = .stamp
    }

    func copySelection(from engine: SimulationEngine) {
        guard let start = selectionStart, let end = selectionEnd else { return }
        let minRow = min(start.row, end.row), maxRow = max(start.row, end.row)
        let minCol = min(start.col, end.col), maxCol = max(start.col, end.col)
        pendingPattern = engine.extractRegion(rowRange: minRow..<(maxRow + 1), colRange: minCol..<(maxCol + 1))
        pendingPatternMerge = false
        toolMode = .stamp
    }
}
