#include <metal_stdlib>
#include "ShaderTypes.h"
using namespace metal;

// Production kernel: bit-sliced neighbor counting, 32 cells per thread (one
// uint32_t word). See LifeStepReference.metal for the scalar oracle this is
// verified against.

inline uint32_t fetchWord(device const uint32_t* grid,
                           constant LifeUniforms& u,
                           int row,
                           int col) {
    if (row < 0) {
        if (u.boundaryMode == 0) { row += int(u.height); } else { return 0; }
    } else if (row >= int(u.height)) {
        if (u.boundaryMode == 0) { row -= int(u.height); } else { return 0; }
    }
    if (col < 0) {
        if (u.boundaryMode == 0) { col += int(u.wordsPerRow); } else { return 0; }
    } else if (col >= int(u.wordsPerRow)) {
        if (u.boundaryMode == 0) { col -= int(u.wordsPerRow); } else { return 0; }
    }
    return grid[uint(row) * u.wordsPerRow + uint(col)];
}

inline void halfAdd(uint32_t x, uint32_t y, thread uint32_t& sum, thread uint32_t& carry) {
    sum = x ^ y;
    carry = x & y;
}

inline void fullAdd(uint32_t x, uint32_t y, uint32_t z, thread uint32_t& sum, thread uint32_t& carry) {
    uint32_t xy = x ^ y;
    sum = xy ^ z;
    carry = (x & y) | (xy & z);
}

kernel void lifeStep(device const uint32_t* inGrid [[buffer(0)]],
                      device uint32_t* outGrid [[buffer(1)]],
                      constant LifeUniforms& u [[buffer(2)]],
                      uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= u.wordsPerRow || gid.y >= u.height) return;

    int row = int(gid.y);
    int col = int(gid.x);

    uint32_t center = inGrid[gid.y * u.wordsPerRow + gid.x];

    uint32_t leftCur     = fetchWord(inGrid, u, row,     col - 1);
    uint32_t rightCur    = fetchWord(inGrid, u, row,     col + 1);
    uint32_t centerAbove = fetchWord(inGrid, u, row - 1, col);
    uint32_t leftAbove   = fetchWord(inGrid, u, row - 1, col - 1);
    uint32_t rightAbove  = fetchWord(inGrid, u, row - 1, col + 1);
    uint32_t centerBelow = fetchWord(inGrid, u, row + 1, col);
    uint32_t leftBelow   = fetchWord(inGrid, u, row + 1, col - 1);
    uint32_t rightBelow  = fetchWord(inGrid, u, row + 1, col + 1);

    // The naive shift-and-carry formula below assumes the word to the west
    // always contributes its bit 31 as the wrapped-in neighbor. That's true
    // at every interior word boundary, but wrong for the wraparound from
    // column 0 back to the row's last word when that word is only partially
    // filled (width not a multiple of 32) -- its true top bit lives at
    // validBitsInLastWord - 1, not 31 (bit 31+ are forced-zero padding).
    // Symmetric issue on the east side: the wrapped-in bit from the word to
    // the east normally lands at bit 31, but when THIS word is the row's
    // last (possibly partial) word, the wraparound point is actually at
    // validBitsInLastWord - 1 -- everything from there to bit 31 is padding.
    uint32_t westTopShift = 31;
    if (col == 0 && u.boundaryMode == 0) {
        westTopShift = u.validBitsInLastWord - 1;
    }
    uint32_t eastTopShift = 31;
    if (col == int(u.wordsPerRow) - 1 && u.boundaryMode == 0) {
        eastTopShift = u.validBitsInLastWord - 1;
    }

    uint32_t W  = (center      << 1) | (leftCur   >> westTopShift);
    uint32_t E  = (center      >> 1) | (rightCur  << eastTopShift);
    uint32_t N  = centerAbove;
    uint32_t NW = (centerAbove << 1) | (leftAbove  >> westTopShift);
    uint32_t NE = (centerAbove >> 1) | (rightAbove << eastTopShift);
    uint32_t S  = centerBelow;
    uint32_t SW = (centerBelow << 1) | (leftBelow  >> westTopShift);
    uint32_t SE = (centerBelow >> 1) | (rightBelow << eastTopShift);

    // Bit-sliced population count of the 8 one-bit-per-lane neighbor words
    // into a 4-bit (0-8) count per lane, via a half/full-adder reduction
    // network (equivalent to a small Wallace tree).
    uint32_t s0_1, c0_1, s0_2, c0_2, s0_3, c0_3;
    fullAdd(NW, N, NE, s0_1, c0_1);
    fullAdd(W, E, SW, s0_2, c0_2);
    halfAdd(S, SE, s0_3, c0_3);

    uint32_t bit0, carryA;
    fullAdd(s0_1, s0_2, s0_3, bit0, carryA);

    uint32_t s1_1, c1_1;
    fullAdd(c0_1, c0_2, c0_3, s1_1, c1_1);
    uint32_t bit1, carryB;
    halfAdd(s1_1, carryA, bit1, carryB);

    uint32_t bit2, carryC;
    halfAdd(c1_1, carryB, bit2, carryC);

    uint32_t bit3 = carryC;

    uint32_t currentAlive = center;
    uint32_t currentDead = ~center;
    uint32_t newAlive = 0;

    for (uint32_t k = 0; k <= 8; k++) {
        uint32_t isK = 0xFFFFFFFFu;
        isK &= (k & 1u) ? bit0 : ~bit0;
        isK &= (k & 2u) ? bit1 : ~bit1;
        isK &= (k & 4u) ? bit2 : ~bit2;
        isK &= (k & 8u) ? bit3 : ~bit3;

        if (((u.birthMask >> k) & 1u) != 0) {
            newAlive |= isK & currentDead;
        }
        if (((u.surviveMask >> k) & 1u) != 0) {
            newAlive |= isK & currentAlive;
        }
    }

    if (gid.x == u.wordsPerRow - 1 && u.validBitsInLastWord < 32) {
        uint32_t validMask = (1u << u.validBitsInLastWord) - 1u;
        newAlive &= validMask;
    }

    outGrid[gid.y * u.wordsPerRow + gid.x] = newAlive;
}
