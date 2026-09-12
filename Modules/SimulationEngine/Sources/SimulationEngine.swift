import Metal

enum KernelStrategy {
    case optimized
    case reference
}

enum SimulationEngineError: Error {
    case commandQueueCreationFailed
    case bufferAllocationFailed
    case functionNotFound(String)
}

/// Owns the ping-pong bit-packed grid buffers and drives the compute-kernel
/// simulation step. Buffers are `storageModeShared` so CPU-side editing/save
/// code can read and write them directly, with no staging copy.
final class SimulationEngine {
    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineOptimized: MTLComputePipelineState
    private let pipelineReference: MTLComputePipelineState

    private(set) var grid: BitGrid
    var rule: RuleSet
    var boundaryMode: BoundaryMode
    private(set) var generationCount: UInt64 = 0

    private var frontBuffer: MTLBuffer
    private var backBuffer: MTLBuffer

    var currentBuffer: MTLBuffer { frontBuffer }

    init(device: MTLDevice,
         library: MTLLibrary,
         grid: BitGrid,
         rule: RuleSet = .conway,
         boundaryMode: BoundaryMode = .toroidal) throws {
        self.device = device
        guard let queue = device.makeCommandQueue() else {
            throw SimulationEngineError.commandQueueCreationFailed
        }
        self.commandQueue = queue

        guard let optimizedFn = library.makeFunction(name: "lifeStep") else {
            throw SimulationEngineError.functionNotFound("lifeStep")
        }
        guard let referenceFn = library.makeFunction(name: "lifeStepReference") else {
            throw SimulationEngineError.functionNotFound("lifeStepReference")
        }
        self.pipelineOptimized = try device.makeComputePipelineState(function: optimizedFn)
        self.pipelineReference = try device.makeComputePipelineState(function: referenceFn)

        self.grid = grid
        self.rule = rule
        self.boundaryMode = boundaryMode

        let byteCount = grid.byteCount
        guard let bufferA = device.makeBuffer(length: byteCount, options: .storageModeShared),
              let bufferB = device.makeBuffer(length: byteCount, options: .storageModeShared) else {
            throw SimulationEngineError.bufferAllocationFailed
        }
        memset(bufferA.contents(), 0, byteCount)
        memset(bufferB.contents(), 0, byteCount)
        self.frontBuffer = bufferA
        self.backBuffer = bufferB
    }

    func setCell(row: Int, col: Int, alive: Bool) {
        precondition(row >= 0 && row < grid.height && col >= 0 && col < grid.width)
        let wordIndex = row * grid.wordsPerRow + col / 32
        let bitIndex = UInt32(col % 32)
        let words = frontBuffer.contents().bindMemory(to: UInt32.self, capacity: grid.wordCount)
        if alive {
            words[wordIndex] |= (1 << bitIndex)
        } else {
            words[wordIndex] &= ~(1 << bitIndex)
        }
    }

    func cellAlive(row: Int, col: Int) -> Bool {
        precondition(row >= 0 && row < grid.height && col >= 0 && col < grid.width)
        let wordIndex = row * grid.wordsPerRow + col / 32
        let bitIndex = UInt32(col % 32)
        let words = frontBuffer.contents().bindMemory(to: UInt32.self, capacity: grid.wordCount)
        return (words[wordIndex] >> bitIndex) & 1 == 1
    }

    func clear() {
        memset(frontBuffer.contents(), 0, grid.byteCount)
        generationCount = 0
    }

    private func makeUniforms() -> LifeUniforms {
        LifeUniforms(width: UInt32(grid.width),
                     height: UInt32(grid.height),
                     wordsPerRow: UInt32(grid.wordsPerRow),
                     validBitsInLastWord: UInt32(grid.validBitsInLastWord),
                     birthMask: rule.birthMask,
                     surviveMask: rule.surviveMask,
                     boundaryMode: boundaryMode.rawValue)
    }

    func step(using strategy: KernelStrategy = .optimized) {
        var uniforms = makeUniforms()
        let pipeline = strategy == .optimized ? pipelineOptimized : pipelineReference

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(frontBuffer, offset: 0, index: 0)
        encoder.setBuffer(backBuffer, offset: 0, index: 1)
        encoder.setBytes(&uniforms, length: MemoryLayout<LifeUniforms>.stride, index: 2)

        let threadWidth = pipeline.threadExecutionWidth
        let threadHeight = max(1, pipeline.maxTotalThreadsPerThreadgroup / threadWidth)
        let threadsPerThreadgroup = MTLSize(width: threadWidth, height: threadHeight, depth: 1)
        let threadgroupCount = MTLSize(
            width: (grid.wordsPerRow + threadWidth - 1) / threadWidth,
            height: (grid.height + threadHeight - 1) / threadHeight,
            depth: 1)

        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        swap(&frontBuffer, &backBuffer)
        generationCount += 1
    }
}
