import Foundation

/// A bit-packed 2D cell grid: 1 bit per cell, row-major, 32 cells per `UInt32` word.
struct BitGrid {
    let width: Int
    let height: Int
    let wordsPerRow: Int
    let validBitsInLastWord: Int

    init(width: Int, height: Int) {
        precondition(width > 0 && height > 0)
        self.width = width
        self.height = height
        self.wordsPerRow = (width + 31) / 32
        let remainder = width % 32
        self.validBitsInLastWord = remainder == 0 ? 32 : remainder
    }

    var wordCount: Int { wordsPerRow * height }
    var byteCount: Int { wordCount * MemoryLayout<UInt32>.size }
}
