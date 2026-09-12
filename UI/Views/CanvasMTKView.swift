import AppKit
import MetalKit

/// The interactive canvas: owns mouse/scroll/magnify handling directly
/// (rather than layering SwiftUI gestures on top) for precise, low-latency
/// hit-testing at any zoom level.
final class CanvasMTKView: MTKView {
    var camera: Camera!
    var engine: SimulationEngine!
    var editingViewModel: EditingViewModel!
    var simulationViewModel: SimulationViewModel!

    private var hasFittedInitialView = false
    private var lastDragCell: (row: Int, col: Int)?
    private var lastPanLocation: CGPoint?
    private var trackingArea: NSTrackingArea?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func layout() {
        super.layout()
        camera.updateViewportSize(width: Double(bounds.width), height: Double(bounds.height))
        if !hasFittedInitialView, bounds.width > 0, bounds.height > 0 {
            camera.fitToGrid(width: engine.grid.width, height: engine.grid.height)
            hasFittedInitialView = true
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let newArea = NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(newArea)
        trackingArea = newArea
    }

    override func mouseMoved(with event: NSEvent) {
        guard editingViewModel.toolMode == .stamp, editingViewModel.pendingPattern != nil else {
            editingViewModel.stampPreviewOrigin = nil
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        editingViewModel.stampPreviewOrigin = camera.cell(atScreenPoint: point, gridWidth: engine.grid.width, gridHeight: engine.grid.height)
    }

    override func scrollWheel(with event: NSEvent) {
        camera.pan(dxPixels: event.scrollingDeltaX, dyPixels: event.scrollingDeltaY)
    }

    override func magnify(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        camera.zoom(by: 1 + event.magnification, atScreenPoint: point)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        switch editingViewModel.toolMode {
        case .pan:
            lastPanLocation = event.locationInWindow
        case .draw, .erase:
            guard !simulationViewModel.isPlaying else { return }
            paintCell(at: point)
            lastDragCell = camera.cell(atScreenPoint: point, gridWidth: engine.grid.width, gridHeight: engine.grid.height)
        case .select:
            let cell = camera.cell(atScreenPoint: point, gridWidth: engine.grid.width, gridHeight: engine.grid.height)
            editingViewModel.selectionStart = cell
            editingViewModel.selectionEnd = cell
        case .stamp:
            placeStamp(at: point)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        switch editingViewModel.toolMode {
        case .pan:
            guard let last = lastPanLocation else { return }
            let current = event.locationInWindow
            camera.pan(dxPixels: current.x - last.x, dyPixels: -(current.y - last.y))
            lastPanLocation = current
        case .draw, .erase:
            guard !simulationViewModel.isPlaying else { return }
            paintLine(to: point)
        case .select:
            if let cell = camera.cell(atScreenPoint: point, gridWidth: engine.grid.width, gridHeight: engine.grid.height) {
                editingViewModel.selectionEnd = cell
            }
        case .stamp:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        lastPanLocation = nil
        lastDragCell = nil
    }

    private func placeStamp(at point: CGPoint) {
        guard !simulationViewModel.isPlaying,
              let pattern = editingViewModel.pendingPattern,
              let cell = camera.cell(atScreenPoint: point, gridWidth: engine.grid.width, gridHeight: engine.grid.height) else { return }
        engine.stamp(pattern, atRow: cell.row, col: cell.col, merge: editingViewModel.pendingPatternMerge)
    }

    private func paintCell(at point: CGPoint) {
        guard let cell = camera.cell(atScreenPoint: point, gridWidth: engine.grid.width, gridHeight: engine.grid.height) else { return }
        engine.setCell(row: cell.row, col: cell.col, alive: editingViewModel.toolMode == .draw)
    }

    private func paintLine(to point: CGPoint) {
        let alive = editingViewModel.toolMode == .draw
        guard let end = camera.cell(atScreenPoint: point, gridWidth: engine.grid.width, gridHeight: engine.grid.height) else {
            return
        }
        guard let start = lastDragCell else {
            engine.setCell(row: end.row, col: end.col, alive: alive)
            lastDragCell = end
            return
        }
        bresenhamLine(from: start, to: end) { row, col in
            engine.setCell(row: row, col: col, alive: alive)
        }
        lastDragCell = end
    }

    /// Walks every cell between two points so fast mouse movement doesn't
    /// leave gaps in the drawn/erased stroke.
    private func bresenhamLine(from start: (row: Int, col: Int), to end: (row: Int, col: Int), plot: (Int, Int) -> Void) {
        var x0 = start.col, y0 = start.row
        let x1 = end.col, y1 = end.row
        let dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1
        let dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1
        var err = dx + dy
        while true {
            plot(y0, x0)
            if x0 == x1 && y0 == y1 { break }
            let doubledErr = 2 * err
            if doubledErr >= dy { err += dy; x0 += sx }
            if doubledErr <= dx { err += dx; y0 += sy }
        }
    }
}
