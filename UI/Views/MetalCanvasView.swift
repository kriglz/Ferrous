import SwiftUI
import MetalKit

struct MetalCanvasView: NSViewRepresentable {
    @ObservedObject var simulationViewModel: SimulationViewModel
    @ObservedObject var editingViewModel: EditingViewModel
    let camera: Camera

    func makeCoordinator() -> GridRenderer {
        guard let library = simulationViewModel.engine.device.makeDefaultLibrary() else {
            fatalError("Failed to load default Metal library")
        }
        do {
            let renderer = try GridRenderer(device: simulationViewModel.engine.device, library: library)
            renderer.engine = simulationViewModel.engine
            renderer.camera = camera
            return renderer
        } catch {
            fatalError("Failed to create GridRenderer: \(error)")
        }
    }

    func makeNSView(context: Context) -> CanvasMTKView {
        let view = CanvasMTKView(frame: .zero, device: simulationViewModel.engine.device)
        view.camera = camera
        view.engine = simulationViewModel.engine
        view.editingViewModel = editingViewModel
        view.simulationViewModel = simulationViewModel
        view.delegate = context.coordinator
        view.framebufferOnly = false
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 30
        view.clearColor = MTLClearColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1.0)
        return view
    }

    func updateNSView(_ nsView: CanvasMTKView, context: Context) {}
}
