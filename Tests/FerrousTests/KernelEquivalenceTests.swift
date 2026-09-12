import XCTest
import Metal
@testable import Ferrous

final class KernelEquivalenceTests: XCTestCase {
    private var device: MTLDevice!
    private var library: MTLLibrary!

    override func setUpWithError() throws {
        device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        library = try XCTUnwrap(device.makeDefaultLibrary(bundle: Bundle(for: KernelEquivalenceTests.self)))
    }

    private func makeEngine(width: Int, height: Int, rule: RuleSet = .conway) throws -> SimulationEngine {
        try SimulationEngine(device: device, library: library, grid: BitGrid(width: width, height: height), rule: rule)
    }

    private func seed(_ engine: SimulationEngine, points: [(Int, Int)]) {
        for (row, col) in points { engine.setCell(row: row, col: col, alive: true) }
    }

    private func snapshot(_ engine: SimulationEngine) -> [[Bool]] {
        (0..<engine.grid.height).map { row in
            (0..<engine.grid.width).map { col in engine.cellAlive(row: row, col: col) }
        }
    }

    func testGliderEquivalence() throws {
        let optimizedEngine = try makeEngine(width: 64, height: 64)
        let referenceEngine = try makeEngine(width: 64, height: 64)
        let glider = [(1, 2), (2, 3), (3, 1), (3, 2), (3, 3)]
        seed(optimizedEngine, points: glider)
        seed(referenceEngine, points: glider)

        for generation in 0..<20 {
            optimizedEngine.step(using: .optimized)
            referenceEngine.step(using: .reference)
            XCTAssertEqual(snapshot(optimizedEngine), snapshot(referenceEngine), "diverged at generation \(generation)")
        }
    }

    func testBlinkerEquivalence() throws {
        let optimizedEngine = try makeEngine(width: 32, height: 32)
        let referenceEngine = try makeEngine(width: 32, height: 32)
        let blinker = [(15, 14), (15, 15), (15, 16)]
        seed(optimizedEngine, points: blinker)
        seed(referenceEngine, points: blinker)

        for generation in 0..<10 {
            optimizedEngine.step(using: .optimized)
            referenceEngine.step(using: .reference)
            XCTAssertEqual(snapshot(optimizedEngine), snapshot(referenceEngine), "diverged at generation \(generation)")
        }
    }

    /// Width not a multiple of 32 deliberately exercises the padding-bit and
    /// horizontal-wraparound edge cases the two kernels handle differently.
    func testRandomSoupEquivalenceOnNonMultipleOf32Width() throws {
        let width = 50
        let height = 37
        let optimizedEngine = try makeEngine(width: width, height: height)
        let referenceEngine = try makeEngine(width: width, height: height)

        var points: [(Int, Int)] = []
        for row in 0..<height {
            for col in 0..<width where Bool.random() {
                points.append((row, col))
            }
        }
        seed(optimizedEngine, points: points)
        seed(referenceEngine, points: points)

        for generation in 0..<15 {
            optimizedEngine.step(using: .optimized)
            referenceEngine.step(using: .reference)
            XCTAssertEqual(snapshot(optimizedEngine), snapshot(referenceEngine), "diverged at generation \(generation)")
        }
    }

    func testHighLifeRuleEquivalence() throws {
        let optimizedEngine = try makeEngine(width: 40, height: 40, rule: .highLife)
        let referenceEngine = try makeEngine(width: 40, height: 40, rule: .highLife)
        // HighLife replicator
        let replicator = [(1, 2), (1, 3), (1, 4), (2, 1), (3, 1), (4, 1), (2, 4), (3, 4), (4, 4), (4, 2), (4, 3)]
        seed(optimizedEngine, points: replicator)
        seed(referenceEngine, points: replicator)

        for generation in 0..<12 {
            optimizedEngine.step(using: .optimized)
            referenceEngine.step(using: .reference)
            XCTAssertEqual(snapshot(optimizedEngine), snapshot(referenceEngine), "diverged at generation \(generation)")
        }
    }

    func testFractalRuleEquivalence() throws {
        let optimizedEngine = try makeEngine(width: 40, height: 40, rule: .fractal)
        let referenceEngine = try makeEngine(width: 40, height: 40, rule: .fractal)
        let seedPoints = [(20, 20), (20, 21), (21, 20)]
        seed(optimizedEngine, points: seedPoints)
        seed(referenceEngine, points: seedPoints)

        for generation in 0..<12 {
            optimizedEngine.step(using: .optimized)
            referenceEngine.step(using: .reference)
            XCTAssertEqual(snapshot(optimizedEngine), snapshot(referenceEngine), "diverged at generation \(generation)")
        }
    }

    /// The fractal/"Replicator" rule (B1357/S1357) is exactly the parity of
    /// alive neighbors, with no dependence on the cell's own current state.
    /// That makes it algebraically linear over GF(2): evolving two seeds
    /// together must equal the XOR (symmetric difference) of evolving them
    /// separately. This is the property that produces the self-similar
    /// fractal -- checking it directly is more robust than trusting a
    /// specific numeric cell-count formula.
    func testFractalRuleIsLinearOverGF2() throws {
        let width = 40, height = 40
        let engineA = try makeEngine(width: width, height: height, rule: .fractal)
        let engineB = try makeEngine(width: width, height: height, rule: .fractal)
        let engineCombined = try makeEngine(width: width, height: height, rule: .fractal)

        let pointA = (10, 10)
        let pointB = (25, 30)
        seed(engineA, points: [pointA])
        seed(engineB, points: [pointB])
        seed(engineCombined, points: [pointA, pointB])

        for generation in 0..<8 {
            engineA.step(using: .optimized)
            engineB.step(using: .optimized)
            engineCombined.step(using: .optimized)

            let snapshotA = snapshot(engineA)
            let snapshotB = snapshot(engineB)
            let expected = snapshotA.indices.map { row in
                (0..<width).map { col in snapshotA[row][col] != snapshotB[row][col] }
            }
            XCTAssertEqual(snapshot(engineCombined), expected, "XOR-linearity broke at generation \(generation)")
        }
    }

    /// Ground-truth check independent of kernel-vs-kernel agreement: a
    /// blinker must have period 2 under Conway's actual rule.
    func testBlinkerOscillatesWithPeriod2() throws {
        let engine = try makeEngine(width: 16, height: 16)
        let blinker = [(7, 6), (7, 7), (7, 8)]
        seed(engine, points: blinker)

        let generation0 = snapshot(engine)
        engine.step(using: .optimized)
        let generation1 = snapshot(engine)
        XCTAssertNotEqual(generation0, generation1)
        engine.step(using: .optimized)
        let generation2 = snapshot(engine)
        XCTAssertEqual(generation0, generation2)
    }
}
