import SwiftUI

struct InspectorView: View {
    @ObservedObject var viewModel: SimulationViewModel
    @State private var customRuleText: String = ""

    private let presets: [(name: String, rule: RuleSet)] = [
        ("Conway", .conway),
        ("HighLife", .highLife),
        ("Seeds", .seeds),
        ("Day & Night", .dayAndNight),
        ("Fractal", .fractal)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rule").font(.headline)
            Picker("Rule", selection: Binding(
                get: { viewModel.rule.bsString },
                set: { newValue in
                    if let parsed = RuleSet(bsString: newValue) {
                        viewModel.rule = parsed
                    }
                }
            )) {
                ForEach(presets, id: \.name) { preset in
                    Text("\(preset.name) (\(preset.rule.bsString))").tag(preset.rule.bsString)
                }
            }
            .labelsHidden()

            HStack {
                TextField("Custom (e.g. B3/S23)", text: $customRuleText)
                    .textFieldStyle(.roundedBorder)
                Button("Apply") {
                    if let parsed = RuleSet(bsString: customRuleText) {
                        viewModel.rule = parsed
                    }
                }
                .disabled(RuleSet(bsString: customRuleText) == nil)
            }
            .onAppear { customRuleText = viewModel.rule.bsString }

            Text("Boundary").font(.headline)
            Picker("Boundary", selection: $viewModel.boundaryMode) {
                Text("Toroidal").tag(BoundaryMode.toroidal)
                Text("Fixed").tag(BoundaryMode.fixed)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding()
    }
}
