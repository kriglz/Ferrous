import Foundation

/// Parses the plaintext `.cells` format: `!`-prefixed comment/header lines
/// (an optional `!Name: ...` line supplies a display name), then rows of
/// `.` (dead) and `O`/`*` (alive).
enum PlaintextCellsParser {
    static func parse(_ text: String, fallbackName: String) -> Pattern {
        var cells: [PatternCell] = []
        var maxWidth = 0
        var row = 0
        var displayName = fallbackName

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("!") {
                if line.lowercased().hasPrefix("!name:") {
                    displayName = line.dropFirst("!name:".count).trimmingCharacters(in: .whitespaces)
                }
                continue
            }
            if line.isEmpty { continue }
            for (col, char) in line.enumerated() where char == "O" || char == "o" || char == "*" {
                cells.append(PatternCell(row: row, col: col))
            }
            maxWidth = max(maxWidth, line.count)
            row += 1
        }

        return Pattern(name: displayName, width: maxWidth, height: row, aliveCells: cells, originalRuleString: nil)
    }
}
