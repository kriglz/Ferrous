import SwiftUI

struct PlaybackControlsView: View {
    @ObservedObject var viewModel: SimulationViewModel

    var body: some View {
        HStack(spacing: 12) {
            Button(viewModel.isPlaying ? "Pause" : "Play") {
                viewModel.togglePlay()
            }
            Button("Step") {
                viewModel.stepOnce()
            }
            .disabled(viewModel.isPlaying)
            Button("Clear") {
                viewModel.clear()
            }
            Text("Generation: \(viewModel.generationCount)")
                .monospacedDigit()
            Spacer()
        }
        .padding()
    }
}
