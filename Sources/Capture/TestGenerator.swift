import Foundation

struct TestGenerator {

    /// Generate an XCUITest that captures screenshots and saves them directly to a shared directory.
    static func generate(
        screens: [FrameHeroConfig.ScreenConfig],
        bundleId: String,
        screenshotDir: String,
        setup: [String]?,
        outputDirectory: URL
    ) throws -> URL {
        let testClassName = "FrameHeroCaptureTests"
        var lines: [String] = []

        lines.append("import XCTest")
        lines.append("")
        lines.append("final class \(testClassName): XCTestCase {")
        lines.append("")

        // Output directory
        lines.append("    private let outputDir = \"\(screenshotDir)\"")
        lines.append("")

        // Helper: save screenshot
        lines.append("    private func saveScreenshot(name: String, app: XCUIApplication) {")
        lines.append("        let screenshot = app.screenshot()")
        lines.append("        let data = screenshot.pngRepresentation")
        lines.append("        let path = (outputDir as NSString).appendingPathComponent(\"\\(name).png\")")
        lines.append("        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)")
        lines.append("        FileManager.default.createFile(atPath: path, contents: data)")
        lines.append("    }")
        lines.append("")

        // Helper: dismiss alerts/modals
        lines.append("    private func dismissAlerts(in app: XCUIApplication) {")
        lines.append("        // Dismiss system alerts (permissions)")
        lines.append("        let springboard = XCUIApplication(bundleIdentifier: \"com.apple.springboard\")")
        lines.append("        for label in [\"Allow\", \"OK\", \"Allow While Using App\", \"Don\\u{2019}t Allow\"] {")
        lines.append("            let button = springboard.buttons[label]")
        lines.append("            if button.waitForExistence(timeout: 1) {")
        lines.append("                button.tap()")
        lines.append("            }")
        lines.append("        }")
        lines.append("        // Dismiss in-app alerts")
        lines.append("        for label in [\"OK\", \"Cancel\", \"Close\", \"Skip\", \"Continue\", \"Dismiss\", \"Not Now\", \"Later\"] {")
        lines.append("            let button = app.buttons[label]")
        lines.append("            if button.exists {")
        lines.append("                button.tap()")
        lines.append("                sleep(1)")
        lines.append("            }")
        lines.append("        }")
        lines.append("    }")
        lines.append("")

        // Helper: tap element with sidebar and index fallback
        lines.append("    private func tapElement(_ label: String, fallbackIndex: Int = -1, in app: XCUIApplication) {")
        lines.append("        let button = app.buttons[label]")
        lines.append("        if button.waitForExistence(timeout: 3) {")
        lines.append("            button.firstMatch.tap()")
        lines.append("            return")
        lines.append("        }")
        lines.append("        // Try opening sidebar/back navigation")
        lines.append("        let backButton = app.navigationBars.buttons.firstMatch")
        lines.append("        if backButton.waitForExistence(timeout: 2) {")
        lines.append("            backButton.tap()")
        lines.append("            sleep(1)")
        lines.append("            let retryButton = app.buttons[label]")
        lines.append("            if retryButton.waitForExistence(timeout: 3) {")
        lines.append("                retryButton.firstMatch.tap()")
        lines.append("                return")
        lines.append("            }")
        lines.append("            // Label not found (likely translated) — tap by index")
        lines.append("            if fallbackIndex >= 0 {")
        lines.append("                let cells = app.cells")
        lines.append("                if cells.count > fallbackIndex {")
        lines.append("                    cells.element(boundBy: fallbackIndex).tap()")
        lines.append("                    return")
        lines.append("                }")
        lines.append("                let buttons = app.buttons")
        lines.append("                var navButtons: [XCUIElement] = []")
        lines.append("                for i in 0..<buttons.count {")
        lines.append("                    let b = buttons.element(boundBy: i)")
        lines.append("                    let size = b.frame.size")
        lines.append("                    if size.width > 200 && size.height > 30 && size.height < 80 {")
        lines.append("                        navButtons.append(b)")
        lines.append("                    }")
        lines.append("                }")
        lines.append("                if navButtons.count > fallbackIndex {")
        lines.append("                    navButtons[fallbackIndex].tap()")
        lines.append("                    return")
        lines.append("                }")
        lines.append("            }")
        lines.append("        }")
        lines.append("        // Last resort: any descendant")
        lines.append("        let any = app.descendants(matching: .any)[label].firstMatch")
        lines.append("        if any.waitForExistence(timeout: 2) {")
        lines.append("            any.tap()")
        lines.append("            return")
        lines.append("        }")
        lines.append("        XCTFail(\"Could not find element '\\(label)' by label or index\")")
        lines.append("    }")
        lines.append("")

        // Helper: perform setup action
        lines.append("    private func performSetup(_ action: String, app: XCUIApplication) {")
        lines.append("        if action == \"dismiss\" || action == \"dismiss alert\" {")
        lines.append("            dismissAlerts(in: app)")
        lines.append("        } else if action.hasPrefix(\"tap \") {")
        lines.append("            let label = action.dropFirst(4).trimmingCharacters(in: CharacterSet(charactersIn: \"\\\"\" ))")
        lines.append("            tapElement(label, in: app)")
        lines.append("        } else if action.hasPrefix(\"scroll \") {")
        lines.append("            let dir = action.dropFirst(7).trimmingCharacters(in: .whitespaces)")
        lines.append("            performScroll(dir, in: app)")
        lines.append("        } else if action.hasPrefix(\"swipe \") {")
        lines.append("            let dir = action.dropFirst(6).trimmingCharacters(in: .whitespaces)")
        lines.append("            performSwipe(dir, in: app)")
        lines.append("        }")
        lines.append("        sleep(1)")
        lines.append("    }")
        lines.append("")

        // Helper: scroll
        lines.append("    private func performScroll(_ direction: String, in app: XCUIApplication) {")
        lines.append("        let element = app.windows.firstMatch")
        lines.append("        switch direction {")
        lines.append("        case \"down\": element.swipeUp()")
        lines.append("        case \"up\": element.swipeDown()")
        lines.append("        case \"left\": element.swipeRight()")
        lines.append("        case \"right\": element.swipeLeft()")
        lines.append("        default: break")
        lines.append("        }")
        lines.append("    }")
        lines.append("")

        // Helper: swipe
        lines.append("    private func performSwipe(_ direction: String, in app: XCUIApplication) {")
        lines.append("        let element = app.windows.firstMatch")
        lines.append("        switch direction {")
        lines.append("        case \"up\": element.swipeUp()")
        lines.append("        case \"down\": element.swipeDown()")
        lines.append("        case \"left\": element.swipeLeft()")
        lines.append("        case \"right\": element.swipeRight()")
        lines.append("        default: break")
        lines.append("        }")
        lines.append("    }")
        lines.append("")

        // Parse setup actions
        let setupActions = setup ?? []

        // Build screen index map
        var screenIndex = 0

        for screen in screens {
            let action = try ScreenAction.parse(screen.action)
            let methodName = "testCapture\(sanitize(screen.name))"

            let currentIndex: Int
            switch action {
            case .launch, .dismiss:
                currentIndex = -1
                screenIndex += 1
            case .tap, .navigate, .scroll, .swipe:
                currentIndex = screenIndex
                screenIndex += 1
            }

            lines.append("    func \(methodName)() {")
            lines.append("        let app = XCUIApplication(bundleIdentifier: \"\(bundleId)\")")
            lines.append("        app.launch()")
            lines.append("        sleep(2)")
            lines.append("")

            // Run setup steps
            if !setupActions.isEmpty {
                for setupAction in setupActions {
                    lines.append("        performSetup(\"\(setupAction)\", app: app)")
                }
                lines.append("")
            }

            switch action {
            case .launch:
                lines.append("        // Capture launch screen")

            case .tap(let label):
                lines.append("        tapElement(\"\(label)\", fallbackIndex: \(currentIndex), in: app)")
                lines.append("        sleep(1)")

            case .navigate(let labels):
                for (i, label) in labels.enumerated() {
                    let idx = i == 0 ? currentIndex : -1
                    lines.append("        tapElement(\"\(label)\", fallbackIndex: \(idx), in: app)")
                    lines.append("        sleep(1)")
                }

            case .scroll(let direction):
                lines.append("        performScroll(\"\(direction)\", in: app)")
                lines.append("        sleep(1)")

            case .swipe(let direction):
                lines.append("        performSwipe(\"\(direction)\", in: app)")
                lines.append("        sleep(1)")

            case .dismiss:
                lines.append("        dismissAlerts(in: app)")
                lines.append("        sleep(1)")
            }

            lines.append("")
            lines.append("        saveScreenshot(name: \"\(screen.name)\", app: app)")
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
