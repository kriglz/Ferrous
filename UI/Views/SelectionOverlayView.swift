import SwiftUI

/// Visual-only selection rectangle (M2). Copy/paste/rotate/flip on the
/// selected region arrive in M3.
struct SelectionOverlayView: View {
    @ObservedObject var camera: Camera
    @ObservedObject var editingViewModel: EditingViewModel

    var body: some View {
        if editingViewModel.toolMode == .select,
           let start = editingViewModel.selectionStart,
           let end = editingViewModel.selectionEnd {
            let minRow = min(start.row, end.row)
            let maxRow = max(start.row, end.row)
            let minCol = min(start.col, end.col)
            let maxCol = max(start.col, end.col)

            let originX = (Double(minCol) - camera.originCellX) / camera.cellsPerPixel
            let originY = (Double(minRow) - camera.originCellY) / camera.cellsPerPixel
            let width = max(Double(maxCol - minCol + 1) / camera.cellsPerPixel, 1)
            let height = max(Double(maxRow - minRow + 1) / camera.cellsPerPixel, 1)

            Rectangle()
                .strokeBorder(Color.yellow, lineWidth: 1.5)
                .frame(width: width, height: height)
                .position(x: originX + width / 2, y: originY + height / 2)
                .allowsHitTesting(false)
        }
    }
}
