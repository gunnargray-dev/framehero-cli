import CoreGraphics
import Foundation
import ImageIO

/// Composites a screenshot into a 3D perspective device mockup by replacing
/// magenta (#FF00FF) screen pixels with the screenshot, mapped via inverse
/// homography derived from the screen quad corners in the metadata.
///
/// Corners in metadata are in screen coordinates (y-down, origin at top-left),
/// ordered: top-left, top-right, bottom-right, bottom-left.
struct PerspectiveCompositor {

    /// Composite a screenshot into a perspective device frame.
    /// - Parameters:
    ///   - screenshot: Source screenshot image.
    ///   - frame: Device frame PNG with magenta screen area.
    ///   - metadata: Frame metadata (points in screen coords, y-down).
    /// - Returns: Composited CGImage at frame resolution.
    static func composite(
        screenshot: CGImage,
        frame: CGImage,
        metadata: FrameMetadata
    ) throws -> CGImage {
        let w = Int(metadata.frame.size[0])
        let h = Int(metadata.frame.size[1])

        // Convert screen-coord corners (y-down) to CG coords (y-up) for
        // pixel-space homography. The CGContext we build below is y-up.
        let pts = metadata.screen.points
        guard pts.count == 4 else { throw FramingError.compositingFailed }
        let cgH = CGFloat(h)
        let tl = CGPoint(x: pts[0][0], y: cgH - pts[0][1])
        let tr = CGPoint(x: pts[1][0], y: cgH - pts[1][1])
        let br = CGPoint(x: pts[2][0], y: cgH - pts[2][1])
        let bl = CGPoint(x: pts[3][0], y: cgH - pts[3][1])

        // Build destination bitmap and render the frame into it so we can
        // read+write pixels in place.
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: colorSpace, bitmapInfo: bitmapInfo.rawValue
        ) else { throw FramingError.compositingFailed }
        ctx.draw(frame, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { throw FramingError.compositingFailed }
        let px = data.bindMemory(to: UInt8.self, capacity: w * h * 4)

        // Read screenshot pixels into a separate context.
        let sw = screenshot.width, sh = screenshot.height
        guard let sctx = CGContext(
            data: nil, width: sw, height: sh,
            bitsPerComponent: 8, bytesPerRow: sw * 4,
            space: colorSpace, bitmapInfo: bitmapInfo.rawValue
        ) else { throw FramingError.compositingFailed }
        sctx.draw(screenshot, in: CGRect(x: 0, y: 0, width: sw, height: sh))
        guard let sdata = sctx.data else { throw FramingError.compositingFailed }
        let spx = sdata.bindMemory(to: UInt8.self, capacity: sw * sh * 4)

        // Compute inverse homography: (x, y) in frame pixel space -> (u, v) in [0,1]^2.
        guard let invH = computeInverseHomography(p00: bl, p10: br, p11: tr, p01: tl) else {
            throw FramingError.compositingFailed
        }
        let (m00, m01, m02, m10, m11, m12, m20, m21, m22) = invH

        // Bounding box around the quad, padded a few pixels.
        let xs = [tl.x, tr.x, br.x, bl.x]
        let ys = [tl.y, tr.y, br.y, bl.y]
        let minCol = max(0, Int(xs.min()!) - 5)
        let maxCol = min(w - 1, Int(xs.max()!) + 5)
        let minRow = max(0, Int(ys.min()!) - 5)
        let maxRow = min(h - 1, Int(ys.max()!) + 5)

        // Iterate over magenta pixels inside the bounding box, bilinearly
        // sample the screenshot at the computed UV, and overwrite the frame pixel.
        for row in minRow...maxRow {
            let cy = CGFloat(row)
            let rowOffset = row * w
            for col in minCol...maxCol {
                let i = (rowOffset + col) * 4
                // Magenta detection: strong red+blue, low green, opaque.
                let r = Int(px[i]), g = Int(px[i+1]), b = Int(px[i+2]), a = Int(px[i+3])
                guard a > 100 else { continue }
                guard r > g + 20 && b > g + 20 else { continue }

                let cx = CGFloat(col)
                let wx = m00 * cx + m01 * cy + m02
                let wy = m10 * cx + m11 * cy + m12
                let ww = m20 * cx + m21 * cy + m22
                guard abs(ww) > 0.0001 else { continue }
                let u = wx / ww, v = wy / ww
                guard u >= 0 && u <= 1 && v >= 0 && v <= 1 else { continue }

                // Bilinear sample the screenshot. (0,0)=bottom-left of screenshot
                // in CG space, which corresponds to v=0. Since the screenshot
                // context is also y-up, row 0 = bottom; v=1 is the status bar.
                let fx = u * CGFloat(sw - 1), fy = v * CGFloat(sh - 1)
                let x0 = Int(fx), y0 = Int(fy)
                let x1 = min(x0 + 1, sw - 1), y1 = min(y0 + 1, sh - 1)
                let dx = fx - CGFloat(x0), dy = fy - CGFloat(y0)
                let i00 = (y0 * sw + x0) * 4
                let i10 = (y0 * sw + x1) * 4
                let i01 = (y1 * sw + x0) * 4
                let i11 = (y1 * sw + x1) * 4
                let w00 = (1 - dx) * (1 - dy), w10 = dx * (1 - dy)
                let w01 = (1 - dx) * dy, w11 = dx * dy

                for c in 0..<3 {
                    let val = CGFloat(spx[i00+c]) * w00 + CGFloat(spx[i10+c]) * w10
                            + CGFloat(spx[i01+c]) * w01 + CGFloat(spx[i11+c]) * w11
                    px[i+c] = UInt8(min(max(val, 0), 255))
                }
                px[i+3] = 255
            }
        }

        guard let result = ctx.makeImage() else { throw FramingError.compositingFailed }
        return result
    }

    // MARK: - Homography

    /// Compute the inverse of the perspective homography that maps the unit
    /// square [0,1]×[0,1] to the quad (p00=bl, p10=br, p11=tr, p01=tl).
    /// Returns the 3×3 inverse matrix as a 9-tuple, or nil if degenerate.
    private static func computeInverseHomography(
        p00: CGPoint, p10: CGPoint, p11: CGPoint, p01: CGPoint
    ) -> (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)? {
        let dx1 = p10.x - p11.x
        let dx2 = p01.x - p11.x
        let dx3 = p00.x - p10.x + p11.x - p01.x
        let dy1 = p10.y - p11.y
        let dy2 = p01.y - p11.y
        let dy3 = p00.y - p10.y + p11.y - p01.y

        let den = dx1 * dy2 - dx2 * dy1
        guard abs(den) > 0.0001 else { return nil }

        let g = (dx3 * dy2 - dx2 * dy3) / den
        let h = (dx1 * dy3 - dx3 * dy1) / den

        let h00 = p10.x - p00.x + g * p10.x
        let h01 = p01.x - p00.x + h * p01.x
        let h02 = p00.x
        let h10 = p10.y - p00.y + g * p10.y
        let h11 = p01.y - p00.y + h * p01.y
        let h12 = p00.y
        let h20 = g
        let h21 = h
        let h22: CGFloat = 1.0

        // Inverse via cofactor expansion.
        let m00 = h11 * h22 - h12 * h21
        let m01 = -(h01 * h22 - h02 * h21)
        let m02 = h01 * h12 - h02 * h11
        let m10 = -(h10 * h22 - h12 * h20)
        let m11 = h00 * h22 - h02 * h20
        let m12 = -(h00 * h12 - h02 * h10)
        let m20 = h10 * h21 - h11 * h20
        let m21 = -(h00 * h21 - h01 * h20)
        let m22 = h00 * h11 - h01 * h10

        let detH = h00 * m00 + h01 * m10 + h02 * m20
        guard abs(detH) > 0.0001 else { return nil }

        return (m00, m01, m02, m10, m11, m12, m20, m21, m22)
    }
}
