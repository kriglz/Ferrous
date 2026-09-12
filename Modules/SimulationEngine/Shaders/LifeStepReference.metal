#include <metal_stdlib>
#include "ShaderTypes.h"
using namespace metal;

// Scalar, per-bit correctness oracle. Deliberately avoids every bit-packing
// trick used by LifeStep.metal (Strategy A) so the two can be cross-checked.
inline uint32_t referenceGetBit(device const uint32_t* grid,
                                 constant LifeUniforms& u,
                                 int row,
                                 int col) {
    if (row < 0) {
        if (u.boundaryMode == 0) { row += int(u.height); } else { return 0; }
    } else if (row >= int(u.height)) {
        if (u.boundaryMode == 0) { row -= int(u.height); } else { return 0; }
    }
    if (col < 0) {
        if (u.boundaryMode == 0) { col += int(u.width); } else { return 0; }
    } else if (col >= int(u.width)) {
        if (u.boundaryMode == 0) { col -= int(u.width); } else { return 0; }
    }
    uint32_t word = grid[uint(row) * u.wordsPerRow + uint(col) / 32];
    return (word >> uint(uint(col) % 32)) & 1u;
}

kernel void lifeStepReference(device const uint32_t* inGrid [[buffer(0)]],
                               device uint32_t* outGrid [[buffer(1)]],
                               constant LifeUniforms& u [[buffer(2)]],
                               uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= u.wordsPerRow || gid.y >= u.height) return;

    int row = int(gid.y);
    uint32_t validBits = (gid.x == u.wordsPerRow - 1) ? u.validBitsInLastWord : 32u;
    uint32_t result = 0;

    for (uint32_t bit = 0; bit < validBits; bit++) {
        int col = int(gid.x * 32 + bit);
        uint32_t alive = referenceGetBit(inGrid, u, row, col);

        uint32_t count = 0;
        count += referenceGetBit(inGrid, u, row - 1, col - 1);
        count += referenceGetBit(inGrid, u, row - 1, col);
        count += referenceGetBit(inGrid, u, row - 1, col + 1);
        count += referenceGetBit(inGrid, u, row,     col - 1);
        count += referenceGetBit(inGrid, u, row,     col + 1);
        count += referenceGetBit(inGrid, u, row + 1, col - 1);
        count += referenceGetBit(inGrid, u, row + 1, col);
        count += referenceGetBit(inGrid, u, row + 1, col + 1);

        bool nextAlive = (alive != 0)
            ? (((u.surviveMask >> count) & 1u) != 0)
            : (((u.birthMask >> count) & 1u) != 0);

        if (nextAlive) {
            result |= (1u << bit);
        }
    }

    outGrid[gid.y * u.wordsPerRow + gid.x] = result;
}
