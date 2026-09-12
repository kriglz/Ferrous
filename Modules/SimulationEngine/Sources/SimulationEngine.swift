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
    private let pipelineAgeUpdate: MTLComputePipelineState

    private(set) var grid: BitGrid
    var rule: RuleSet
    var boundaryMode: BoundaryMode
    private(set) var generationCount: UInt64 = 0

    private var frontBuffer: MTLBuffer
    private var backBuffer: MTLBuffer
    private var ageFrontBuffer: MTLBuffer
    private var ageBackBuffer: MTLBuffer

    var currentBuffer: MTLBuffer { frontBuffer }
    /// Per-cell (not per-word) `UInt8` generations-alive counter, saturating
    /// at 255. Purely a rendering aid -- see `AgeUpdate.metal`.
    var currentAgeBuffer: MTLBuffer { ageFrontBuffer }

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
        guard let ageUpdateFn = library.makeFunction(name: "updateAge") else {
            throw SimulationEngineError.functionNotFound("updateAge")
        }
        self.pipelineOptimized = try device.makeComputePipelineState(function: optimizedFn)
        self.pipelineReference = try device.makeComputePipelineState(function: referenceFn)
        self.pipelineAgeUpdate = try device.makeComputePipelineState(function: ageUpdateFn)

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

        let cellCount = grid.width * grid.height
        guard let ageA = device.makeBuffer(length: cellCount, options: .storageModeShared),
              let ageB = device.makeBuffer(length: cellCount, options: .storageModeShared) else {
            throw SimulationEngineError.bufferAllocationFailed
        }
        memset(ageA.contents(), 0, cellCount)
        memset(ageB.contents(), 0, cellCount)
        self.ageFrontBuffer = ageA
        self.ageBackBuffer = ageB
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
        let ages = ageFrontBuffer.contents().bindMemory(to: UInt8.self, capacity: grid.width * grid.height)
        ages[row * grid.width + col] = alive ? 1 : 0
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
        memset(ageFrontBuffer.contents(), 0, grid.width * grid.height)
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

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        guard let lifeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        lifeEncoder.setComputePipelineState(pipeline)
        lifeEncoder.setBuffer(frontBuffer, offset: 0, index: 0)
        lifeEncoder.setBuffer(backBuffer, offset: 0, index: 1)
        lifeEncoder.setBytes(&uniforms, length: MemoryLayout<LifeUniforms>.stride, index: 2)

        let threadWidth = pipeline.threadExecutionWidth
        let threadHeight = max(1, pipeline.maxTotalThreadsPerThreadgroup / threadWidth)
        let threadsPerThreadgroup = MTLSize(width: threadWidth, height: threadHeight, depth: 1)
        let wordThreadgroupCount = MTLSize(
            width: (grid.wordsPerRow + threadWidth - 1) / threadWidth,
            height: (grid.height + threadHeight - 1) / threadHeight,
            depth: 1)
        lifeEncoder.dispatchThreadgroups(wordThreadgroupCount, threadsPerThreadgroup: threadsPerThreadgroup)
        lifeEncoder.endEncoding()

        // Second pass, one thread per cell (not per word): maintains the
        // rendering-only age buffer. Reads backBuffer (this step's freshly
        // written result) -- automatic hazard tracking within the same
        // command buffer orders this after the life-step encoder above.
        guard let ageEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        ageEncoder.setComputePipelineState(pipelineAgeUpdate)
        ageEncoder.setBuffer(frontBuffer, offset: 0, index: 0)
        ageEncoder.setBuffer(backBuffer, offset: 0, index: 1)
        ageEncoder.setBuffer(ageFrontBuffer, offset: 0, index: 2)
        ageEncoder.setBuffer(ageBackBuffer, offset: 0, index: 3)
        ageEncoder.setBytes(&uniforms, length: MemoryLayout<LifeUniforms>.stride, index: 4)

        let ageThreadWidth = pipelineAgeUpdate.threadExecutionWidth
        let ageThreadHeight = max(1, pipelineAgeUpdate.maxTotalThreadsPerThreadgroup / ageThreadWidth)
        let ageThreadsPerThreadgroup = MTLSize(width: ageThreadWidth, height: ageThreadHeight, depth: 1)
        let cellThreadgroupCount = MTLSize(
            width: (grid.width + ageThreadWidth - 1) / ageThreadWidth,
            height: (grid.height + ageThreadHeight - 1) / ageThreadHeight,
            depth: 1)
        ageEncoder.dispatchThreadgroups(cellThreadgroupCount, threadsPerThreadgroup: ageThreadsPerThreadgroup)
        ageEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        swap(&frontBuffer, &backBuffer)
        swap(&ageFrontBuffer, &ageBackBuffer)
        generationCount += 1
    }
}
