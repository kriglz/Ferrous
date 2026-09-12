import Metal
import MetalKit

/// M1: draws the whole grid scaled to fit the drawable. Viewport-aware
/// pan/zoom sampling (and the dedicated zoom-out density sampling) lands in M2.
final class GridRenderer: NSObject, MTKViewDelegate {
    private struct RenderUniforms {
        var gridWidth: UInt32
        var gridHeight: UInt32
        var wordsPerRow: UInt32
        var outputWidth: UInt32
        var outputHeight: UInt32
    }

    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    var engine: SimulationEngine?

    init(device: MTLDevice, library: MTLLibrary) throws {
        guard let queue = device.makeCommandQueue() else {
            throw SimulationEngineError.commandQueueCreationFailed
        }
        self.commandQueue = queue
        guard let function = library.makeFunction(name: "renderGrid") else {
            throw SimulationEngineError.functionNotFound("renderGrid")
        }
        self.pipeline = try device.makeComputePipelineState(function: function)
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let engine = engine,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }

        var uniforms = RenderUniforms(
            gridWidth: UInt32(engine.grid.width),
            gridHeight: UInt32(engine.grid.height),
            wordsPerRow: UInt32(engine.grid.wordsPerRow),
            outputWidth: UInt32(drawable.texture.width),
            outputHeight: UInt32(drawable.texture.height))

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(engine.currentBuffer, offset: 0, index: 0)
        encoder.setBytes(&uniforms, length: MemoryLayout<RenderUniforms>.stride, index: 1)
        encoder.setTexture(drawable.texture, index: 0)

        let threadWidth = pipeline.threadExecutionWidth
        let threadHeight = max(1, pipeline.maxTotalThreadsPerThreadgroup / threadWidth)
        let threadsPerThreadgroup = MTLSize(width: threadWidth, height: threadHeight, depth: 1)
        let threadgroupCount = MTLSize(
            width: (drawable.texture.width + threadWidth - 1) / threadWidth,
            height: (drawable.texture.height + threadHeight - 1) / threadHeight,
            depth: 1)

        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
