#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

typedef struct {
    uint32_t width;                 // logical grid width in cells
    uint32_t height;                // logical grid height in cells
    uint32_t wordsPerRow;           // packed 32-bit words per row
    uint32_t validBitsInLastWord;   // valid bits (1...32) in the last word of each row
    uint32_t birthMask;             // bit k set -> birth on exactly k neighbors
    uint32_t surviveMask;           // bit k set -> survive on exactly k neighbors
    uint32_t boundaryMode;          // 0 = toroidal, 1 = fixed (dead) edges
} LifeUniforms;

#endif
