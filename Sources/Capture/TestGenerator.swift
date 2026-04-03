import Foundation

struct TestGenerator {

    static func generate(
        screens: [FrameHeroConfig.ScreenConfig],
        bundleId: String,
        outputDirectory: URL
    ) throws -> URL {
        let testClassName = "FrameHeroCaptureTests"
        var lines: [String] = []

        lines.append("import XCTest")
        lines.append("")
        lines.append("final class \(testClassName): XCTestCase {")
        lines.append("")

        for screen in screens {
            let action = try ScreenAction.parse(screen.action)
            let methodName = "testCapture\(sanitize(screen.name))"

            lines.append("    func \(methodName)() {")
            lines.append("        let app = XCUIApplication(bundleIdentifier: \"\(bundleId)\")")
            lines.append("        app.launch()")
            lines.append("        sleep(1)")
            lines.append("")

            switch action {
            case .launch:
                lines.append("        // Capture launch screen")

            case .tap(let label):
                lines.append("        let element = app.descendants(matching: .any)[\"\(label)\"]")
                lines.append("        XCTAssertTrue(element.waitForExistence(timeout: 5), \"Could not find element '\(label)'\")")
                lines.append("        element.tap()")
                lines.append("        sleep(1)")

            case .navigate(let labels):
                for (i, label) in labels.enumerated() {
                    lines.append("        let nav\(i) = app.descendants(matching: .any)[\"\(label)\"]")
                    lines.append("        XCTAssertTrue(nav\(i).waitForExistence(timeout: 5), \"Could not find element '\(label)'\")")
                    lines.append("        nav\(i).tap()")
                    lines.append("        sleep(1)")
                }
            }

            lines.append("")
            lines.append("        let screenshot = app.screenshot()")
            lines.append("        let attachment = XCTAttachment(screenshot: screenshot)")
            lines.append("        attachment.name = \"\(screen.name)\"")
            lines.append("        attachment.lifetime = .keepAlways")
            lines.append("        add(attachment)")
            lines.append("    }")
            lines.append("")
        }

        lines.append("}")
        lines.append("")

        let content = lines.joined(separator: "\n")
        let filePath = outputDirectory.appendingPathComponent("\(testClassName).swift")

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        try content.write(to: filePath, atomically: true, encoding: .utf8)

        return filePath
    }

    private static func sanitize(_ name: String) -> String {
        name.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
    }
}
