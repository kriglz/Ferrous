import SwiftUI

struct EditingControlsView: View {
    @ObservedObject var editingViewModel: EditingViewModel
    @ObservedObject var camera: Camera
    let engine: SimulationEngine

    var body: some View {
        HStack(spacing: 12) {
            Picker("Tool", selection: $editingViewModel.toolMode) {
                ForEach(ToolMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
            .labelsHidden()

            Button("Reset View") {
                camera.fitToGrid(width: engine.grid.width, height: engine.grid.height)
            }

            Text("Zoom: \(String(format: "%.2f", 1 / camera.cellsPerPixel))x")
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
