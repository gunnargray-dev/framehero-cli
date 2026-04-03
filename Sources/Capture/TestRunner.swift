import Foundation

/// Captures screenshots using simctl for screenshots and cliclick for navigation.
/// Uses coordinate-based tapping inside the Simulator window.
struct TestRunner {

    /// Capture all screens for a single locale.
    static func captureScreens(
        screens: [FrameHeroConfig.ScreenConfig],
        bundleId: String,
        simulator: String,
        locale: String,
        outputDir: URL
    ) throws -> [(name: String, url: URL)] {
        let localeDir = outputDir.appendingPathComponent(locale)
        try FileManager.default.createDirectory(at: localeDir, withIntermediateDirectories: true)

        var results: [(name: String, url: URL)] = []

        for (index, screen) in screens.enumerated() {
            let action = try ScreenAction.parse(screen.action)

            // Relaunch app before each screen for a clean state
            try terminateApp(bundleId: bundleId)
            Thread.sleep(forTimeInterval: 0.5)
            try launchApp(bundleId: bundleId)
            Thread.sleep(forTimeInterval: 2.0)

            // Navigate if needed
            switch action {
            case .launch:
                break

            case .tap(let label):
                try tapInSimulator(label: label)
                Thread.sleep(forTimeInterval: 1.0)

            case .navigate(let labels):
                for label in labels {
                    try tapInSimulator(label: label)
                    Thread.sleep(forTimeInterval: 1.0)
                }
            }

            // Capture
            let screenshotURL = localeDir.appendingPathComponent("\(screen.name).png")
            try captureScreenshot(to: screenshotURL)
            results.append((name: screen.name, url: screenshotURL))
        }

        return results
    }

    // MARK: - simctl

    private static func launchApp(bundleId: String) throws {
        try simctl("launch", "booted", bundleId)
    }

    private static func terminateApp(bundleId: String) throws {
        try? simctl("terminate", "booted", bundleId)
    }

    private static func captureScreenshot(to url: URL) throws {
        try simctl("io", "booted", "screenshot", url.path)
    }

    private static func simctl(_ args: String...) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl"] + args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw TestRunnerError.simctlFailed(args.joined(separator: " "))
        }
    }

    // MARK: - Tap via coordinate clicking

    /// Tap inside the Simulator by finding the window and clicking at
    /// the position where a tab bar item with the given label would be.
    /// Uses cliclick for coordinate-based clicking.
    private static func tapInSimulator(label: String) throws {
        // Activate Simulator
        let activateScript = "tell application \"Simulator\" to activate"
        let activate = Process()
        activate.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        activate.arguments = ["-e", activateScript]
        activate.standardOutput = FileHandle.nullDevice
        activate.standardError = FileHandle.nullDevice
        try activate.run()
        activate.waitUntilExit()
        Thread.sleep(forTimeInterval: 0.5)

        // Get Simulator window bounds
        let bounds = try getSimulatorWindowBounds()

        // Try to find and tap the element using Accessibility Inspector's
        // coordinate mapping. Tab bar items are at the bottom of the screen.
        // We search common positions for tab bar items.
        let tabBarY = bounds.y + bounds.height - 50 // Tab bar is ~50pt from bottom
        let contentAreaWidth = bounds.width

        // Common tab bar positions (2-5 items evenly spaced)
        // Try clicking at positions that match typical tab bar layouts
        let possiblePositions = generateTabBarPositions(
            windowX: bounds.x,
            windowWidth: contentAreaWidth,
            tabBarY: tabBarY
        )

        // Try each position — check if the label matches by looking at
        // the accessibility description at that point
        // For now, use a simpler heuristic: common tab bar item names
        // map to ordinal positions
        let commonTabOrder = ["Home", "Search", "Explore", "Discover", "Browse",
                              "Favorites", "Saved", "Bookmarks", "Liked",
                              "Activity", "Notifications", "Updates",
                              "Profile", "Account", "Settings", "More"]

        if let tabIndex = findTabIndex(label: label, commonOrder: commonTabOrder) {
            // Estimate tab count from the screens config — but we don't have that here
            // Use 3-5 tab assumption and try center of each segment
            for tabCount in [5, 4, 3] {
                if tabIndex < tabCount {
                    let segmentWidth = contentAreaWidth / Double(tabCount)
                    let x = bounds.x + segmentWidth * (Double(tabIndex) + 0.5)
                    let y = tabBarY

                    try clickAt(x: Int(x), y: Int(y))
                    return
                }
            }
        }

        // Fallback: try clicking in common positions
        throw TestRunnerError.tapFailed(
            label: label,
            output: "Could not determine screen position for '\(label)'. Use 'launch' action or specify coordinates."
        )
    }

    private static func findTabIndex(label: String, commonOrder: [String]) -> Int? {
        // Map label to a tab position based on common app patterns
        let lower = label.lowercased()

        // First/home tab
        if lower == "home" || lower == "featured" || lower == "today" || lower == "feed" {
            return 0
        }
        // Second tab
        if lower == "search" || lower == "explore" || lower == "discover" || lower == "browse" {
            return 1
        }
        // Third tab (middle)
        if lower == "favorites" || lower == "saved" || lower == "bookmarks" || lower == "liked" || lower == "add" {
            return 2
        }
        // Fourth tab
        if lower == "activity" || lower == "notifications" || lower == "updates" || lower == "messages" {
            return 3
        }
        // Last tab
        if lower == "profile" || lower == "account" || lower == "settings" || lower == "more" || lower == "me" {
            return 4
        }

        return nil
    }

    private struct WindowBounds {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }

    private static func getSimulatorWindowBounds() throws -> WindowBounds {
        let script = """
        tell application "System Events"
            tell process "Simulator"
                set w to front window
                set {x, y} to position of w
                set {width, height} to size of w
                return "" & x & "," & y & "," & width & "," & height
            end tell
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let parts = output.components(separatedBy: ",").compactMap { Double($0) }
        guard parts.count == 4 else {
            throw TestRunnerError.simctlFailed("Could not get Simulator window bounds")
        }

        return WindowBounds(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }

    private static func generateTabBarPositions(windowX: Double, windowWidth: Double, tabBarY: Double) -> [(x: Int, y: Int)] {
        var positions: [(x: Int, y: Int)] = []
        for count in 3...5 {
            let segmentWidth = windowWidth / Double(count)
            for i in 0..<count {
                let x = windowX + segmentWidth * (Double(i) + 0.5)
                positions.append((x: Int(x), y: Int(tabBarY)))
            }
        }
        return positions
    }

    private static func clickAt(x: Int, y: Int) throws {
        let process = Process()
        // Try cliclick first
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/cliclick") {
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/cliclick")
            process.arguments = ["c:\(x),\(y)"]
        } else if FileManager.default.fileExists(atPath: "/usr/local/bin/cliclick") {
            process.executableURL = URL(fileURLWithPath: "/usr/local/bin/cliclick")
            process.arguments = ["c:\(x),\(y)"]
        } else {
            // Fallback to AppleScript click at position
            let script = """
            tell application "System Events"
                click at {\(x), \(y)}
            end tell
            """
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
        }

        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
    }
}

enum TestRunnerError: LocalizedError {
    case simctlFailed(String)
    case tapFailed(label: String, output: String)

    var errorDescription: String? {
        switch self {
        case .simctlFailed(let cmd):
            return "simctl command failed: \(cmd)"
        case .tapFailed(let label, let output):
            return "Could not tap '\(label)'. \(output)"
        }
    }
}
