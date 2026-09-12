#include <metal_stdlib>
using namespace metal;

struct RenderUniforms {
    uint32_t gridWidth;
    uint32_t gridHeight;
    uint32_t wordsPerRow;
    uint32_t outputWidth;
    uint32_t outputHeight;
};

inline bool cellAlive(device const uint32_t* grid, constant RenderUniforms& u, uint row, uint col) {
    uint wordIndex = row * u.wordsPerRow + col / 32;
    uint bitIndex = col % 32;
    return ((grid[wordIndex] >> bitIndex) & 1u) != 0;
}

// M1: renders the whole grid scaled to fit the drawable, nearest-neighbor
// sampled. Viewport-aware pan/zoom sampling arrives in M2.
kernel void renderGrid(device const uint32_t* grid [[buffer(0)]],
                        constant RenderUniforms& u [[buffer(1)]],
                        texture2d<float, access::write> outTexture [[texture(0)]],
                        uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= u.outputWidth || gid.y >= u.outputHeight) return;

    uint col = min(u.gridWidth - 1, (gid.x * u.gridWidth) / u.outputWidth);
    uint row = min(u.gridHeight - 1, (gid.y * u.gridHeight) / u.outputHeight);

    bool alive = cellAlive(grid, u, row, col);
    float4 color = alive ? float4(0.90, 0.55, 0.25, 1.0) : float4(0.06, 0.06, 0.08, 1.0);
    outTexture.write(color, gid);
}
