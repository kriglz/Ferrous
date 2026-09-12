import Foundation
import Metal
import Combine

@MainActor
final class SimulationViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var generationCount: UInt64 = 0
    @Published var stepsPerSecond: Double = 10

    let engine: SimulationEngine
    private var timer: Timer?

    init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this Mac")
        }
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to load the default Metal library")
        }
        let grid = BitGrid(width: 256, height: 256)
        do {
            engine = try SimulationEngine(device: device, library: library, grid: grid)
        } catch {
            fatalError("Failed to create SimulationEngine: \(error)")
        }
        seedGlider()
    }

    private func seedGlider() {
        let offsets = [(0, 1), (1, 2), (2, 0), (2, 1), (2, 2)]
        for (row, col) in offsets {
            engine.setCell(row: row + 10, col: col + 10, alive: true)
        }
    }

    func togglePlay() {
        isPlaying.toggle()
        isPlaying ? startTimer() : stopTimer()
    }

    func stepOnce() {
        engine.step()
        generationCount = engine.generationCount
    }

    func clear() {
        stopTimer()
        isPlaying = false
        engine.clear()
        generationCount = 0
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / stepsPerSecond, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.stepOnce()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
