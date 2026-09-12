struct PatternCell: Hashable {
    let row: Int
    let col: Int
}

/// A pattern's alive cells relative to its own (0,0) top-left corner.
struct Pattern {
    let name: String
    let width: Int
    let height: Int
    let aliveCells: [PatternCell]
    let originalRuleString: String?
}

extension Pattern {
    /// 90-degree clockwise rotation.
    func rotated90() -> Pattern {
        let newCells = aliveCells.map { PatternCell(row: $0.col, col: height - 1 - $0.row) }
        return Pattern(name: name, width: height, height: width, aliveCells: newCells, originalRuleString: originalRuleString)
    }

    func flippedHorizontally() -> Pattern {
        let newCells = aliveCells.map { PatternCell(row: $0.row, col: width - 1 - $0.col) }
        return Pattern(name: name, width: width, height: height, aliveCells: newCells, originalRuleString: originalRuleString)
    }

    func flippedVertically() -> Pattern {
        let newCells = aliveCells.map { PatternCell(row: height - 1 - $0.row, col: $0.col) }
        return Pattern(name: name, width: width, height: height, aliveCells: newCells, originalRuleString: originalRuleString)
    }
}
