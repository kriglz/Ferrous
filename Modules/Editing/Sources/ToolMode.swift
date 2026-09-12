enum ToolMode: String, CaseIterable, Identifiable {
    case draw = "Draw"
    case erase = "Erase"
    case pan = "Pan"
    case select = "Select"
    case stamp = "Stamp"

    var id: String { rawValue }
}
