#include <metal_stdlib>
using namespace metal;

struct RenderUniforms {
    uint32_t gridWidth;
    uint32_t gridHeight;
    uint32_t wordsPerRow;
    uint32_t outputWidth;
    uint32_t outputHeight;
    int32_t originCellXWhole;
    int32_t originCellYWhole;
    float originCellXFraction;   // [0, 1)
    float originCellYFraction;   // [0, 1)
    float cellsPerPixel;
    float pointsPerPixel;        // 1 / backingScaleFactor; converts drawable pixels -> view points
};

inline bool cellAlive(device const uint32_t* grid, constant RenderUniforms& u, int row, int col) {
    if (row < 0 || row >= int(u.gridHeight) || col < 0 || col >= int(u.gridWidth)) return false;
    uint wordIndex = uint(row) * u.wordsPerRow + uint(col) / 32;
    uint bitIndex = uint(col) % 32;
    return ((grid[wordIndex] >> bitIndex) & 1u) != 0;
}

// Never renders more than the drawable's own pixel count, regardless of grid
// size: dispatched over output pixels, not grid cells. Camera state arrives
// pre-split into a whole-cell Int32 origin plus a small Float fraction so the
// Float math here only ever operates on screen-sized magnitudes, never on
// the (potentially huge) absolute grid coordinate -- see Camera.swift.
kernel void renderGrid(device const uint32_t* grid [[buffer(0)]],
                        constant RenderUniforms& u [[buffer(1)]],
                        texture2d<float, access::write> outTexture [[texture(0)]],
                        uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= u.outputWidth || gid.y >= u.outputHeight) return;

    float pointX = float(gid.x) * u.pointsPerPixel;
    float pointY = float(gid.y) * u.pointsPerPixel;
    float fx = u.originCellXFraction + pointX * u.cellsPerPixel;
    float fy = u.originCellYFraction + pointY * u.cellsPerPixel;
    int col = u.originCellXWhole + int(floor(fx));
    int row = u.originCellYWhole + int(floor(fy));

    const float4 background = float4(0.06, 0.06, 0.08, 1.0);
    const float4 alive = float4(0.90, 0.55, 0.25, 1.0);
    float4 color;

    if (u.cellsPerPixel <= 1.0) {
        // Zoomed in: one nearest-neighbor lookup per output pixel, plus thin
        // gridlines once cells are large enough on screen to warrant them.
        color = cellAlive(grid, u, row, col) ? alive : background;
        if (u.cellsPerPixel < 0.15) {
            float fracX = fract(fx);
            float fracY = fract(fy);
            if (fracX < u.cellsPerPixel || fracY < u.cellsPerPixel) {
                color = mix(color, float4(0.0, 0.0, 0.0, 1.0), 0.35);
            }
        }
    } else {
        // Zoomed out: a bounded stratified sample per pixel (never every
        // cell in view) blended into a density value.
        int samplesPerAxis = int(clamp(ceil(u.cellsPerPixel), 1.0, 8.0));
        float step = u.cellsPerPixel / float(samplesPerAxis);
        int aliveCount = 0;
        for (int sy = 0; sy < samplesPerAxis; sy++) {
            for (int sx = 0; sx < samplesPerAxis; sx++) {
                float sampleFx = fx + (float(sx) + 0.5) * step;
                float sampleFy = fy + (float(sy) + 0.5) * step;
                int sampleCol = u.originCellXWhole + int(floor(sampleFx));
                int sampleRow = u.originCellYWhole + int(floor(sampleFy));
                if (cellAlive(grid, u, sampleRow, sampleCol)) aliveCount++;
            }
        }
        float density = float(aliveCount) / float(samplesPerAxis * samplesPerAxis);
        color = mix(background, alive, density);
    }

    outTexture.write(color, gid);
}
