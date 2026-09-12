import SwiftUI

struct SidebarView: View {
    @ObservedObject var simulationViewModel: SimulationViewModel
    let patternLibrary: PatternLibrary
    @ObservedObject var editingViewModel: EditingViewModel

    var body: some View {
        VStack(spacing: 0) {
            InspectorView(viewModel: simulationViewModel)
            Divider()
            PatternLibraryView(patternLibrary: patternLibrary, editingViewModel: editingViewModel)
        }
        .frame(minWidth: 200)
    }
}
