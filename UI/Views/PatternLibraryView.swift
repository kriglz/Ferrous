import SwiftUI

struct PatternLibraryView: View {
    let patternLibrary: PatternLibrary
    @ObservedObject var editingViewModel: EditingViewModel

    var body: some View {
        List {
            ForEach(patternLibrary.categoryOrder, id: \.self) { category in
                Section(category) {
                    ForEach(patternLibrary.categories[category] ?? [], id: \.name) { pattern in
                        Button(pattern.name) {
                            editingViewModel.loadFromLibrary(pattern)
                        }
                    }
                }
            }
        }
    }
}
