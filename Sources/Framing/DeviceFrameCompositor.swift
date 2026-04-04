import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Errors

enum FramingError: LocalizedError {
    case deviceNotSupported(String)
    case resourceNotFound(String)
    case compositingFailed

    var errorDescription: String? {
        switch self {
        case .deviceNotSupported(let device):
            return "Device not supported: \(device)"
        case .resourceNotFound(let detail):
            return "Resource not found: \(detail)"
        case .compositingFailed:
            return "Failed to composite the framed image"
        }
    }
}

// MARK: - Metadata models

struct FrameMetadata: Codable {
    let id: String
    let device: String
    let frame: FrameAssetInfo
    let screen: ScreenInfo
}

struct FrameAssetInfo: Codable {
    let file: String
    let size: [Double]
}

struct ScreenInfo: Codable {
    let points: [[Double]]
    let size: [Double]
    let cornerRadius: Double
}

// MARK: - Compositor

struct DeviceFrameCompositor {

    // MARK: - Device mapping

    /// Normalized lookup key: lowercase with whitespace and punctuation stripped.
    private static func normalizeKey(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// Maps normalized display names to the resource directory name used under
    /// `Resources/DeviceFrames/`.
    private static let deviceDirectoryMap: [String: String] = {
        var map: [String: String] = [:]
        let entries: [(String, String)] = [
            ("iPhone 16 Pro", "iPhone16Pro"),
            ("iPhone 16 Pro Max", "iPhone16ProMax"),
            ("iPhone 17 Pro", "iPhone16Pro"),        // same form factor
            ("iPhone 17 Pro Max", "iPhone16ProMax"),  // same form factor
            ("iPhone 16", "iPhone16"),
            ("iPhone 16 Plus", "iPhone16Plus"),
            ("iPad Pro 13", "iPadPro13"),
            ("iPad Pro 11", "iPadPro11"),
        ]
        for (display, dir) in entries {
            map[normalizeKey(display)] = dir
        }
        return map
    }()

    // MARK: - Public API

    /// Apply a device frame to a screenshot.
    ///
    /// - Parameters:
    ///   - screenshot: URL of the source screenshot PNG.
    ///   - device: Display name of the device (e.g. "iPhone 16 Pro").
    ///   - outputURL: Destination URL for the composited PNG.
    /// - Returns: The `outputURL` after writing.
    @discardableResult
    static func frame(screenshot: URL, device: String, outputURL: URL) throws -> URL {
        // 1. Resolve resource directory
        let key = normalizeKey(device)
        guard let deviceDir = deviceDirectoryMap[key] else {
            throw FramingError.deviceNotSupported(device)
        }

        guard let resourceBase = Bundle.module.resourceURL?
            .appendingPathComponent("DeviceFrames")
            .appendingPathComponent(deviceDir)
        else {
            throw FramingError.resourceNotFound("DeviceFrames/\(deviceDir)")
        }

        // 2. Locate frame PNG and metadata JSON inside the directory
        let (framePNGURL, metadataURL) = try locateAssets(in: resourceBase, deviceDir: deviceDir)

        // 3. Parse metadata
        let metadataData = try Data(contentsOf: metadataURL)
        let metadata = try JSONDecoder().decode(FrameMetadata.self, from: metadataData)

        // 4. Load images
        let frameImage = try loadCGImage(from: framePNGURL)
        let screenshotImage = try loadCGImage(from: screenshot)

        // 5. Composite
        let composited = try composite(
            screenshot: screenshotImage,
            frame: frameImage,
            metadata: metadata
        )

        // 6. Write output
        try writePNG(composited, to: outputURL)

        return outputURL
    }

    // MARK: - Internals

    /// Find the flat-variant frame PNG and metadata JSON in the given directory.
    private static func locateAssets(
        in directory: URL, deviceDir: String
    ) throws -> (png: URL, json: URL) {
        let framePNG = directory.appendingPathComponent("\(deviceDir)_flat_frame.png")
        let metadataJSON = directory.appendingPathComponent("\(deviceDir)_flat_metadata.json")

        guard FileManager.default.fileExists(atPath: framePNG.path) else {
            throw FramingError.resourceNotFound(framePNG.lastPathComponent)
        }
        guard FileManager.default.fileExists(atPath: metadataJSON.path) else {
            throw FramingError.resourceNotFound(metadataJSON.lastPathComponent)
        }
        return (framePNG, metadataJSON)
    }

    /// Load a `CGImage` from a file URL using ImageIO.
    private static func loadCGImage(from url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw FramingError.resourceNotFound(url.lastPathComponent)
        }
        return image
    }

    /// Composite the screenshot beneath the device frame.
    private static func composite(
        screenshot: CGImage,
        frame: CGImage,
        metadata: FrameMetadata
    ) throws -> CGImage {
        let canvasWidth = Int(metadata.frame.size[0])
        let canvasHeight = Int(metadata.frame.size[1])

        // Screen rect from metadata (top-left origin in metadata)
        let screenX = metadata.screen.points[0][0]
        let screenY_topLeft = metadata.screen.points[0][1]
        let screenWidth = metadata.screen.points[1][0] - metadata.screen.points[0][0]
        let screenHeight = metadata.screen.points[2][1] - metadata.screen.points[0][1]

        // Flip Y for CoreGraphics (bottom-left origin)
        let screenY = Double(canvasHeight) - screenY_topLeft - screenHeight

        let screenRect = CGRect(x: screenX, y: screenY, width: screenWidth, height: screenHeight)
        let cornerRadius = metadata.screen.cornerRadius

        // Create bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: canvasWidth,
            height: canvasHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw FramingError.compositingFailed
        }

        // a. Draw screenshot clipped to the rounded-rect screen area
        ctx.saveGState()
        let clipPath = CGPath(
            roundedRect: screenRect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        ctx.addPath(clipPath)
        ctx.clip()
        ctx.draw(screenshot, in: screenRect)
        ctx.restoreGState()

        // b. Draw frame on top (full canvas)
        let fullCanvas = CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)
        ctx.draw(frame, in: fullCanvas)

        // c. Produce final image
        guard let result = ctx.makeImage() else {
            throw FramingError.compositingFailed
        }
        return result
    }

    /// Write a `CGImage` as PNG to the given URL.
    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw FramingError.compositingFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw FramingError.compositingFailed
        }
    }
}
