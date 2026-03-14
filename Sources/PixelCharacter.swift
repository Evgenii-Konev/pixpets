import AppKit

struct PixelCharacter {
    // Pixel types: 0=empty, 1=main color, 2=dark (eyes/details), 3=lighter shade
    // Based on the provided character: blocky creature with ears, eyes, nose, arms, legs
    // 18x18 grid

    static let idle: [[Int]] = [
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,1,1,0,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,0,0,1,1,0,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,0,1,2,2,1,1,1,2,2,1,1,0,0,0,0],
        [0,0,0,0,1,2,2,1,1,1,2,2,1,1,0,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,0,1,1,1,2,1,2,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,0,1,1,0,1,1,1,1,0,1,1,0,0,0,0],
        [0,0,0,0,1,1,0,1,1,1,1,0,1,1,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ]

    // Blink frame: eyes closed (replace dark eye pixels with main color)
    static let blink: [[Int]] = {
        var grid = idle
        // Close eyes: rows 6-7, replace 2->1
        for r in 6...7 {
            for c in 0..<18 {
                if grid[r][c] == 2 { grid[r][c] = 1 }
            }
        }
        return grid
    }()

    // Walk frame 1: left legs shifted
    static let walkA: [[Int]] = {
        var grid = idle
        // Shift left pair of legs down by clearing row 14 left leg and adding row 16
        grid[14][4] = 0; grid[14][5] = 0
        grid[16][4] = 1; grid[16][5] = 1
        return grid
    }()

    // Walk frame 2: right legs shifted
    static let walkB: [[Int]] = {
        var grid = idle
        grid[14][12] = 0; grid[14][13] = 0
        grid[16][12] = 1; grid[16][13] = 1
        return grid
    }()

    static func render(grid: [[Int]], color: NSColor, pixelSize: Int = 2) -> NSImage {
        let gridSize = 18
        let w = gridSize * pixelSize
        let h = gridSize * pixelSize

        let safeColor = color.usingColorSpace(.sRGB) ?? color
        let darkColor = NSColor(
            srgbRed: safeColor.redComponent * 0.35,
            green: safeColor.greenComponent * 0.35,
            blue: safeColor.blueComponent * 0.35,
            alpha: 1
        )

        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: w,
            pixelsHigh: h,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: w * 4,
            bitsPerPixel: 32
        )!

        let ctx = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx

        // Clear to transparent
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: w, height: h).fill()

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let val = grid[row][col]
                guard val != 0 else { continue }

                let c: NSColor = val == 2 ? darkColor : safeColor
                c.setFill()

                let rect = NSRect(
                    x: col * pixelSize,
                    y: (gridSize - 1 - row) * pixelSize,
                    width: pixelSize,
                    height: pixelSize
                )
                rect.fill()
            }
        }

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.addRepresentation(rep)
        image.isTemplate = false
        return image
    }
}
