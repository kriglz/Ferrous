#include <metal_stdlib>
#include "ShaderTypes.h"
using namespace metal;

inline bool getBitAt(device const uint32_t* grid, constant LifeUniforms& u, uint row, uint col) {
    uint wordIndex = row * u.wordsPerRow + col / 32;
    uint bitIndex = col % 32;
    return ((grid[wordIndex] >> bitIndex) & 1u) != 0;
}

// Runs once per cell (not per word) after the life-step kernel, comparing
// the pre-step and post-step grids to maintain a saturating per-cell age
// counter purely for rendering (cell-age color gradient) -- it has no
// effect on simulation correctness.
kernel void updateAge(device const uint32_t* oldGrid [[buffer(0)]],
                       device const uint32_t* newGrid [[buffer(1)]],
                       device const uint8_t* oldAge [[buffer(2)]],
                       device uint8_t* newAge [[buffer(3)]],
                       constant LifeUniforms& u [[buffer(4)]],
                       uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= u.width || gid.y >= u.height) return;
    uint idx = gid.y * u.width + gid.x;

    bool wasAlive = getBitAt(oldGrid, u, gid.y, gid.x);
    bool isAlive = getBitAt(newGrid, u, gid.y, gid.x);

    uint8_t age = 0;
    if (isAlive) {
        age = wasAlive ? uint8_t(min(uint(oldAge[idx]) + 1u, 255u)) : uint8_t(1);
    }
    newAge[idx] = age;
}
