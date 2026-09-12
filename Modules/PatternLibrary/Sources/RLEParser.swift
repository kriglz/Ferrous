import Foundation

enum RLEParseError: Error {
    case missingHeader
    case invalidToken(Character)
}

/// Parses the standard LifeWiki RLE pattern format:
/// header line `x = W, y = H, rule = ...`, then a body of
/// `<count><b|o>` runs and `$` end-of-line markers, terminated by `!`.
/// `#`-prefixed lines (name/comment/author) are ignored.
enum RLEParser {
    static func parse(_ text: String, name: String) throws -> Pattern {
        var width = 0
        var height = 0
        var ruleString: String?
        var bodyLines: [String] = []

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.lowercased().hasPrefix("x") {
                for part in line.split(separator: ",") {
                    let keyValue = part.split(separator: "=", maxSplits: 1).map {
                        $0.trimmingCharacters(in: .whitespaces)
                    }
                    guard keyValue.count == 2 else { continue }
                    switch keyValue[0].lowercased() {
                    case "x": width = Int(keyValue[1]) ?? 0
                    case "y": height = Int(keyValue[1]) ?? 0
                    case "rule": ruleString = keyValue[1]
                    default: break
                    }
                }
                continue
            }
            bodyLines.append(line)
        }

        guard width > 0, height > 0 else { throw RLEParseError.missingHeader }

        var cells: [PatternCell] = []
        var row = 0
        var col = 0
        var numberBuffer = ""

        func takeCount() -> Int {
            defer { numberBuffer = "" }
            return Int(numberBuffer) ?? 1
        }

        bodyLoop: for char in bodyLines.joined() {
            switch char {
            case let digit where digit.isNumber:
                numberBuffer.append(digit)
            case "b":
                col += takeCount()
            case "o":
                let count = takeCount()
                cells.append(contentsOf: (0..<count).map { PatternCell(row: row, col: col + $0) })
                col += count
            case "$":
                row += takeCount()
                col = 0
            case "!":
                break bodyLoop
            default:
                throw RLEParseError.invalidToken(char)
            }
        }

        return Pattern(name: name, width: width, height: height, aliveCells: cells, originalRuleString: ruleString)
    }
}
