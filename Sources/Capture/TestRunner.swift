import Foundation
import CoreGraphics
import ImageIO

/// Captures screenshots using simctl for screenshots and AppleScript accessibility
/// for navigating the Simulator UI (sidebar / tab bar items).
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

        // Build a tab map from the config: labels used in tap/navigate actions
        // map to their ordinal position among all tappable screens.
        let tabMap = buildTabMap(from: screens)

        var results: [(name: String, url: URL)] = []

        for screen in screens {
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
                try navigateToScreen(label: label, tabMap: tabMap)
                Thread.sleep(forTimeInterval: 1.5)

            case .navigate(let labels):
                // For multi-step navigation, the first label opens the sidebar item,
                // subsequent labels are tapped in sequence within the screen.
                if let first = labels.first {
                    try navigateToScreen(label: first, tabMap: tabMap)
                    Thread.sleep(forTimeInterval: 1.5)
                }
                // Additional steps would need coordinate-based tapping within the screen
                for label in labels.dropFirst() {
                    try tapSidebarItem(label: label, tabMap: tabMap)
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

    /// Build a mapping of tap labels to tab indices from the config's screen list.
    private static func buildTabMap(from screens: [FrameHeroConfig.ScreenConfig]) -> [String: Int] {
        var map: [String: Int] = [:]
        var tabIndex = 0

        for screen in screens {
            guard let action = try? ScreenAction.parse(screen.action) else { continue }

            switch action {
            case .launch:
                tabIndex += 1

            case .tap(let label):
                map[label] = tabIndex
                tabIndex += 1

            case .navigate(let labels):
                if let first = labels.first {
                    map[first] = tabIndex
                }
                tabIndex += 1
            }
        }

        return map
    }

    // MARK: - Accessibility check

    /// Verify that the terminal has macOS Accessibility permissions.
    /// Navigation actions require System Events access to interact with Simulator.
    static func checkAccessibility() throws {
        let script = """
        tell application "System Events"
            return name of first process whose frontmost is true
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? ""
            if errMsg.contains("not allowed") || errMsg.contains("assistive") {
                throw TestRunnerError.accessibilityDenied
            }
        }
    }

    // MARK: - Navigation

    /// Navigate to a screen by opening the sidebar and tapping the item.
    private static func navigateToScreen(label: String, tabMap: [String: Int]) throws {
        guard let tabIndex = tabMap[label] else {
            throw TestRunnerError.tapFailed(
                label: label,
                output: "'\(label)' not found in config screens. Make sure it matches a tap or navigate action label."
            )
        }

        activateSimulator()
        Thread.sleep(forTimeInterval: 0.3)

        // Open sidebar by clicking the back/sidebar button via accessibility.
        // In NavigationSplitView on compact width, this is the deepest button
        // in the Simulator window's accessibility tree.
        try clickSidebarToggle()
        Thread.sleep(forTimeInterval: 0.5)

        // The sidebar items appear as buttons in the accessibility tree.
        // Find them by position and click the one at the target index.
        try clickSidebarItemByIndex(tabIndex)
    }

    private static func tapSidebarItem(label: String, tabMap: [String: Int]) throws {
        guard let tabIndex = tabMap[label] else {
            throw TestRunnerError.tapFailed(
                label: label,
                output: "'\(label)' not found in config screens."
            )
        }

        activateSimulator()
        Thread.sleep(forTimeInterval: 0.3)
        try clickSidebarToggle()
        Thread.sleep(forTimeInterval: 0.5)
        try clickSidebarItemByIndex(tabIndex)
    }

    /// Click the sidebar/back toggle button using AppleScript accessibility.
    /// Traverses deep into the Simulator window's group hierarchy to find it.
    private static func clickSidebarToggle() throws {
        // The sidebar toggle is the deepest button nested in group chains.
        // We try progressively deeper paths until we find one that works.
        let script = """
        tell application "System Events"
            tell process "Simulator"
                set w to front window
                -- Navigate through nested groups to find the sidebar/back button
                -- The depth varies by iOS version, so try multiple depths
                set found to false
                set depths to {17, 16, 15, 14, 13, 12, 11, 10}
                repeat with d in depths
                    try
                        set target to w
                        repeat d times
                            set target to first group of target
                        end repeat
                        click first button of target
                        set found to true
                        exit repeat
                    end try
                end repeat
                if not found then
                    error "Could not find sidebar toggle button"
                end if
            end tell
        end tell
        """
        try runAppleScript(script)
    }

    /// Click a sidebar item by its index (0-based) among the sidebar buttons.
    /// Sidebar items are buttons with consistent vertical spacing.
    private static func clickSidebarItemByIndex(_ index: Int) throws {
        // Find all unnamed buttons in the content area of the Simulator window.
        // Sidebar items appear as buttons stacked vertically below the navigation bar.
        let script = """
        tell application "System Events"
            tell process "Simulator"
                set w to front window
                set allElements to entire contents of w
                set sidebarButtons to {}

                -- Collect all unnamed buttons that are in the content area
                -- (not the hardware buttons at the edges)
                repeat with e in allElements
                    try
                        if role of e is "AXButton" then
                            set {bPosX, bPosY} to position of e
                            set {bSizeW, bSizeH} to size of e
                            -- Sidebar items are wide buttons (>200pt) in the middle area
                            if bSizeW > 200 and bSizeH > 30 and bSizeH < 80 then
                                set end of sidebarButtons to e
                            end if
                        end if
                    end try
                end repeat

                -- Sort by Y position (they should already be in order)
                -- and click the one at the target index
                if (count of sidebarButtons) > \(index) then
                    click item \(index + 1) of sidebarButtons
                else
                    error "Sidebar item at index \(index) not found. Found " & (count of sidebarButtons) & " items."
                end if
            end tell
        end tell
        """
        try runAppleScript(script)
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

    // MARK: - AppleScript helpers

    private static func activateSimulator() {
        let script = "tell application \"Simulator\" to activate"
        try? runAppleScript(script)
    }

    private static func runAppleScript(_ script: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let errPipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown error"
            throw TestRunnerError.simctlFailed("AppleScript failed: \(errMsg)")
        }
    }
}

enum TestRunnerError: LocalizedError {
    case simctlFailed(String)
    case tapFailed(label: String, output: String)
    case accessibilityDenied

    var errorDescription: String? {
        switch self {
        case .simctlFailed(let cmd):
            return "simctl command failed: \(cmd)"
        case .tapFailed(let label, let output):
            return "Could not tap '\(label)'. \(output)"
        case .accessibilityDenied:
            return """
            Accessibility permission required. \
            Grant access in System Settings > Privacy & Security > Accessibility \
            for your terminal app (Terminal, iTerm2, etc.), then try again.
            """
        }
    }
}
