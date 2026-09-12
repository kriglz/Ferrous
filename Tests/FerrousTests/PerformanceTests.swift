import XCTest
import Metal
@testable import Ferrous

final class PerformanceTests: XCTestCase {
    func testStepThroughputAtLargeGridSize() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let library = try XCTUnwrap(device.makeDefaultLibrary(bundle: Bundle(for: PerformanceTests.self)))
        let width = 8192
        let height = 8192
        let engine = try SimulationEngine(device: device, library: library, grid: BitGrid(width: width, height: height))

        // R-pentomino, a long-lived chaotic seed, so the kernel does real work.
        let seed = [(0, 1), (0, 2), (1, 0), (1, 1), (2, 1)]
        for (row, col) in seed {
            engine.setCell(row: row + height / 2, col: col + width / 2, alive: true)
        }

        let stepCount = 200
        let start = DispatchTime.now()
        for _ in 0..<stepCount {
            engine.step(using: .optimized)
        }
        let elapsedSeconds = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000

        let cellCount = Double(width) * Double(height)
        let generationsPerSecond = Double(stepCount) / elapsedSeconds
        let cellsPerSecond = generationsPerSecond * cellCount

        print("""
        [PerformanceTests] \(width)x\(height) grid (\(Int(cellCount / 1_000_000))M cells): \
        \(stepCount) generations in \(String(format: "%.3f", elapsedSeconds))s -> \
        \(String(format: "%.1f", generationsPerSecond)) gen/s, \
        \(String(format: "%.2f", cellsPerSecond / 1_000_000_000)) billion cells/s
        """)

        XCTAssertGreaterThan(generationsPerSecond, 30, "Expected comfortably real-time stepping at 8192x8192")
    }

    func testStepThroughputAtBillionCellScale() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let library = try XCTUnwrap(device.makeDefaultLibrary(bundle: Bundle(for: PerformanceTests.self)))
        let width = 32768
        let height = 32768
        let engine = try SimulationEngine(device: device, library: library, grid: BitGrid(width: width, height: height))

        let seed = [(0, 1), (0, 2), (1, 0), (1, 1), (2, 1)]
        for (row, col) in seed {
            engine.setCell(row: row + height / 2, col: col + width / 2, alive: true)
        }

        let stepCount = 30
        let start = DispatchTime.now()
        for _ in 0..<stepCount {
            engine.step(using: .optimized)
        }
        let elapsedSeconds = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000

        let cellCount = Double(width) * Double(height)
        let generationsPerSecond = Double(stepCount) / elapsedSeconds
        let cellsPerSecond = generationsPerSecond * cellCount

        print("""
        [PerformanceTests] \(width)x\(height) grid (\(String(format: "%.2f", cellCount / 1_000_000_000)) billion cells): \
        \(stepCount) generations in \(String(format: "%.3f", elapsedSeconds))s -> \
        \(String(format: "%.1f", generationsPerSecond)) gen/s, \
        \(String(format: "%.2f", cellsPerSecond / 1_000_000_000)) billion cells/s
        """)

        XCTAssertGreaterThan(generationsPerSecond, 1, "Expected at least interactive stepping at billion-cell scale")
    }
}
