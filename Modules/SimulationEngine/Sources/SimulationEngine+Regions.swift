/// Region operations for selection copy and pattern/library stamping.
/// Selections and patterns are always screen- or selection-bounded (never
/// grid-sized), so plain per-cell loops over the existing bit accessor are
/// simple, correct, and fast enough -- no bit-blit optimization needed.
extension SimulationEngine {
    func extractRegion(rowRange: Range<Int>, colRange: Range<Int>, name: String = "Selection") -> Pattern {
        var cells: [PatternCell] = []
        for row in rowRange {
            for col in colRange where cellAlive(row: row, col: col) {
                cells.append(PatternCell(row: row - rowRange.lowerBound, col: col - colRange.lowerBound))
            }
        }
        return Pattern(name: name, width: colRange.count, height: rowRange.count, aliveCells: cells, originalRuleString: nil)
    }

    /// Stamps `pattern` with its top-left corner at (originRow, originCol).
    /// `merge: false` clears the pattern's bounding box first (paste-style
    /// overwrite); `merge: true` only turns cells on, leaving the rest of
    /// the target area untouched (library-stamping style).
    func stamp(_ pattern: Pattern, atRow originRow: Int, col originCol: Int, merge: Bool) {
        if !merge {
            for row in 0..<pattern.height {
                for col in 0..<pattern.width {
                    let targetRow = originRow + row
                    let targetCol = originCol + col
                    guard targetRow >= 0, targetRow < grid.height, targetCol >= 0, targetCol < grid.width else { continue }
                    setCell(row: targetRow, col: targetCol, alive: false)
                }
            }
        }
        for cell in pattern.aliveCells {
            let targetRow = originRow + cell.row
            let targetCol = originCol + cell.col
            guard targetRow >= 0, targetRow < grid.height, targetCol >= 0, targetCol < grid.width else { continue }
            setCell(row: targetRow, col: targetCol, alive: true)
        }
    }
}
