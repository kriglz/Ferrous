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
            .frame(maxWidth: 360)
            .labelsHidden()

            Button("Copy Selection") {
                editingViewModel.copySelection(from: engine)
            }
            .disabled(editingViewModel.toolMode != .select || editingViewModel.selectionStart == nil)

            Button("Rotate") {
                editingViewModel.pendingPattern = editingViewModel.pendingPattern?.rotated90()
            }
            .disabled(editingViewModel.pendingPattern == nil)

            Button("Flip H") {
                editingViewModel.pendingPattern = editingViewModel.pendingPattern?.flippedHorizontally()
            }
            .disabled(editingViewModel.pendingPattern == nil)

            Button("Flip V") {
                editingViewModel.pendingPattern = editingViewModel.pendingPattern?.flippedVertically()
            }
            .disabled(editingViewModel.pendingPattern == nil)

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
