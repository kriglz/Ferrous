import XCTest
import Metal
@testable import Ferrous

final class PatternLibraryTests: XCTestCase {
    // MARK: - RLE parser, hand-crafted strings

    func testParsesGliderRLE() throws {
        let text = """
        #N Glider
        x = 3, y = 3, rule = B3/S23
        bob$2bo$3o!
        """
        let pattern = try RLEParser.parse(text, name: "Glider")
        XCTAssertEqual(pattern.width, 3)
        XCTAssertEqual(pattern.height, 3)
        let expected: Set<PatternCell> = [
            PatternCell(row: 0, col: 1),
            PatternCell(row: 1, col: 2),
            PatternCell(row: 2, col: 0),
            PatternCell(row: 2, col: 1),
            PatternCell(row: 2, col: 2),
        ]
        XCTAssertEqual(Set(pattern.aliveCells), expected)
    }

    func testRLERunLengthsAndLineWrapping() throws {
        // Exercises multi-digit run counts and a body split across lines,
        // as real .rle files commonly wrap at ~70 columns.
        let text = """
        x = 10, y = 2, rule = B3/S23
        10o$5b5
        o!
        """
        let pattern = try RLEParser.parse(text, name: "Test")
        XCTAssertEqual(pattern.width, 10)
        XCTAssertEqual(pattern.height, 2)
        XCTAssertEqual(pattern.aliveCells.count, 15)
        XCTAssertTrue(pattern.aliveCells.contains(PatternCell(row: 0, col: 0)))
        XCTAssertTrue(pattern.aliveCells.contains(PatternCell(row: 0, col: 9)))
        XCTAssertFalse(pattern.aliveCells.contains(PatternCell(row: 1, col: 4)))
        XCTAssertTrue(pattern.aliveCells.contains(PatternCell(row: 1, col: 5)))
        XCTAssertTrue(pattern.aliveCells.contains(PatternCell(row: 1, col: 9)))
    }

    func testRLEMissingHeaderThrows() {
        XCTAssertThrowsError(try RLEParser.parse("bob$2bo$3o!", name: "NoHeader"))
    }

    // MARK: - Plaintext .cells parser

    func testParsesPlaintextCells() {
        let text = """
        !Name: Test Glider
        .O.
        ..O
        OOO
        """
        let pattern = PlaintextCellsParser.parse(text, fallbackName: "fallback")
        XCTAssertEqual(pattern.name, "Test Glider")
        XCTAssertEqual(pattern.width, 3)
        XCTAssertEqual(pattern.height, 3)
        XCTAssertEqual(pattern.aliveCells.count, 5)
    }

    // MARK: - Pattern transforms

    func testRotate90PreservesCellCount() {
        let pattern = Pattern(name: "L", width: 2, height: 3,
                               aliveCells: [PatternCell(row: 0, col: 0), PatternCell(row: 1, col: 0), PatternCell(row: 2, col: 0), PatternCell(row: 2, col: 1)],
                               originalRuleString: nil)
        let rotated = pattern.rotated90()
        XCTAssertEqual(rotated.width, 3)
        XCTAssertEqual(rotated.height, 2)
        XCTAssertEqual(rotated.aliveCells.count, pattern.aliveCells.count)
    }

    func testFlipHorizontallyMirrorsColumns() {
        let pattern = Pattern(name: "Corner", width: 3, height: 1, aliveCells: [PatternCell(row: 0, col: 0)], originalRuleString: nil)
        let flipped = pattern.flippedHorizontally()
        XCTAssertEqual(flipped.aliveCells, [PatternCell(row: 0, col: 2)])
    }

    // MARK: - Built-in catalog loads and round-trips through the simulation

    func testBuiltInLibraryLoadsAllCatalogEntries() {
        let library = PatternLibrary(bundle: Bundle(for: PatternLibraryTests.self))
        XCTAssertEqual(library.patterns.count, 6, "Expected all 6 catalog entries to parse successfully")
        XCTAssertTrue(library.patterns.contains { $0.name == "Glider" })
    }

    func testLibraryGliderTranslatesAfterFourGenerations() throws {
        let library = PatternLibrary(bundle: Bundle(for: PatternLibraryTests.self))
        let glider = try XCTUnwrap(library.patterns.first { $0.name == "Glider" })

        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let mtlLibrary = try XCTUnwrap(device.makeDefaultLibrary(bundle: Bundle(for: PatternLibraryTests.self)))
        let engine = try SimulationEngine(device: device, library: mtlLibrary, grid: BitGrid(width: 20, height: 20))
        engine.stamp(glider, atRow: 2, col: 2, merge: false)

        var before: Set<PatternCell> = []
        for row in 0..<20 {
            for col in 0..<20 where engine.cellAlive(row: row, col: col) {
                before.insert(PatternCell(row: row, col: col))
            }
        }

        for _ in 0..<4 {
            engine.step(using: .optimized)
        }

        var after: Set<PatternCell> = []
        for row in 0..<20 {
            for col in 0..<20 where engine.cellAlive(row: row, col: col) {
                after.insert(PatternCell(row: row, col: col))
            }
        }

        // A glider is period-4 up to a (1,1) translation.
        let shifted = Set(before.map { PatternCell(row: $0.row + 1, col: $0.col + 1) })
        XCTAssertEqual(after, shifted)
    }

    func testGosperGliderGunPopulationGrowsAsGlidersEscape() throws {
        let library = PatternLibrary(bundle: Bundle(for: PatternLibraryTests.self))
        let gun = try XCTUnwrap(library.patterns.first { $0.name == "Gosper Glider Gun" })

        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let mtlLibrary = try XCTUnwrap(device.makeDefaultLibrary(bundle: Bundle(for: PatternLibraryTests.self)))
        // Large fixed-boundary grid so escaping gliders have room and don't wrap into the gun.
        let engine = try SimulationEngine(device: device, library: mtlLibrary, grid: BitGrid(width: 200, height: 200), boundaryMode: .fixed)
        engine.stamp(gun, atRow: 10, col: 10, merge: false)

        func population() -> Int {
            var count = 0
            for row in 0..<200 {
                for col in 0..<200 where engine.cellAlive(row: row, col: col) {
                    count += 1
                }
            }
            return count
        }

        let initialPopulation = population()
        for _ in 0..<100 {
            engine.step(using: .optimized)
        }
        let laterPopulation = population()

        XCTAssertGreaterThan(laterPopulation, initialPopulation, "Expected escaping gliders to grow total population over time")
    }
}
