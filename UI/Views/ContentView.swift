import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SimulationViewModel()

    var body: some View {
        VStack(spacing: 0) {
            MetalCanvasView(engine: viewModel.engine)
                .frame(minWidth: 480, minHeight: 480)
            PlaybackControlsView(viewModel: viewModel)
        }
    }
}
