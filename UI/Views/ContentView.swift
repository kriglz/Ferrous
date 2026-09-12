import SwiftUI

struct ContentView: View {
    @StateObject private var simulationViewModel = SimulationViewModel()
    @StateObject private var editingViewModel = EditingViewModel()
    @StateObject private var camera = Camera()

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                MetalCanvasView(simulationViewModel: simulationViewModel, editingViewModel: editingViewModel, camera: camera)
                SelectionOverlayView(camera: camera, editingViewModel: editingViewModel)
            }
            .frame(minWidth: 480, minHeight: 480)
            EditingControlsView(editingViewModel: editingViewModel, camera: camera, engine: simulationViewModel.engine)
            PlaybackControlsView(viewModel: simulationViewModel)
        }
    }
}
