import Foundation
import CoreGraphics

/// Maps between screen points and grid cell coordinates. Uses `Double`
/// throughout so huge grids combined with deep zoom don't lose precision;
/// conversion to camera-relative `Float` happens only at the Metal
/// shader-uniform boundary (see `GridRenderer`).
@MainActor
final class Camera: ObservableObject {
    @Published private(set) var originCellX: Double
    @Published private(set) var originCellY: Double
    @Published private(set) var cellsPerPixel: Double

    private(set) var viewportWidth: Double = 1
    private(set) var viewportHeight: Double = 1

    private static let minCellsPerPixel = 1.0 / 64.0
    private static let maxCellsPerPixel = 4096.0

    init(originCellX: Double = 0, originCellY: Double = 0, cellsPerPixel: Double = 1) {
        self.originCellX = originCellX
        self.originCellY = originCellY
        self.cellsPerPixel = cellsPerPixel
    }

    func updateViewportSize(width: Double, height: Double) {
        viewportWidth = max(width, 1)
        viewportHeight = max(height, 1)
    }

    /// Centers the whole grid in the viewport, zoomed to fit.
    func fitToGrid(width: Int, height: Int) {
        guard viewportWidth > 0, viewportHeight > 0 else { return }
        let scaleX = Double(width) / viewportWidth
        let scaleY = Double(height) / viewportHeight
        cellsPerPixel = max(scaleX, scaleY, Self.minCellsPerPixel)
        originCellX = (Double(width) - viewportWidth * cellsPerPixel) / 2
        originCellY = (Double(height) - viewportHeight * cellsPerPixel) / 2
    }

    func pan(dxPixels: Double, dyPixels: Double) {
        originCellX -= dxPixels * cellsPerPixel
        originCellY -= dyPixels * cellsPerPixel
    }

    /// Zooms by `factor` (>1 zooms in), keeping the cell under `screenPoint` fixed.
    func zoom(by factor: Double, atScreenPoint screenPoint: CGPoint) {
        let (cellX, cellY) = cellCoordinate(atScreenPoint: screenPoint)
        let newCellsPerPixel = min(max(cellsPerPixel / factor, Self.minCellsPerPixel), Self.maxCellsPerPixel)
        cellsPerPixel = newCellsPerPixel
        originCellX = cellX - Double(screenPoint.x) * cellsPerPixel
        originCellY = cellY - Double(screenPoint.y) * cellsPerPixel
    }

    /// Fractional cell coordinate under a screen point. May fall outside the
    /// grid bounds -- callers validate against the actual grid size.
    func cellCoordinate(atScreenPoint point: CGPoint) -> (x: Double, y: Double) {
        (originCellX + Double(point.x) * cellsPerPixel,
         originCellY + Double(point.y) * cellsPerPixel)
    }

    /// The integer cell under a screen point, or nil if outside the grid.
    func cell(atScreenPoint point: CGPoint, gridWidth: Int, gridHeight: Int) -> (row: Int, col: Int)? {
        let (x, y) = cellCoordinate(atScreenPoint: point)
        let col = Int(x.rounded(.down))
        let row = Int(y.rounded(.down))
        guard col >= 0, col < gridWidth, row >= 0, row < gridHeight else { return nil }
        return (row, col)
    }
}
