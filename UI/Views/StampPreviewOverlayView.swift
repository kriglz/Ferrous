import SwiftUI

/// Bounding-box preview of where a pending library/clipboard pattern would
/// land if placed at the current mouse position.
struct StampPreviewOverlayView: View {
    @ObservedObject var camera: Camera
    @ObservedObject var editingViewModel: EditingViewModel

    var body: some View {
        if editingViewModel.toolMode == .stamp,
           let pattern = editingViewModel.pendingPattern,
           let origin = editingViewModel.stampPreviewOrigin {
            let originX = (Double(origin.col) - camera.originCellX) / camera.cellsPerPixel
            let originY = (Double(origin.row) - camera.originCellY) / camera.cellsPerPixel
            let width = max(Double(pattern.width) / camera.cellsPerPixel, 1)
            let height = max(Double(pattern.height) / camera.cellsPerPixel, 1)

            Rectangle()
                .strokeBorder(Color.cyan, lineWidth: 1.5)
                .background(Rectangle().fill(Color.cyan.opacity(0.15)))
                .frame(width: width, height: height)
                .position(x: originX + width / 2, y: originY + height / 2)
                .allowsHitTesting(false)
        }
    }
}
