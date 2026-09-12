import SwiftUI
import MetalKit

struct MetalCanvasView: NSViewRepresentable {
    let engine: SimulationEngine

    func makeCoordinator() -> GridRenderer {
        guard let library = engine.device.makeDefaultLibrary() else {
            fatalError("Failed to load default Metal library")
        }
        do {
            let renderer = try GridRenderer(device: engine.device, library: library)
            renderer.engine = engine
            return renderer
        } catch {
            fatalError("Failed to create GridRenderer: \(error)")
        }
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: engine.device)
        view.delegate = context.coordinator
        view.framebufferOnly = false
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 30
        view.clearColor = MTLClearColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1.0)
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}
}
