import Foundation

struct UIDiscovery {

    struct DiscoveredScreen {
        let name: String
        let path: String
        let action: String
    }

    /// Launch the app and use AppleScript accessibility to scan the Simulator window for navigable screens.
    static func discover(bundleId: String, simulator: String) throws -> [DiscoveredScreen] {
        // Launch the app
        let launchProcess = Process()
        launchProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        launchProcess.arguments = ["simctl", "launch", "booted", bundleId]
        launchProcess.standardOutput = FileHandle.nullDevice
        launchProcess.standardError = FileHandle.nullDevice
        try launchProcess.run()
        launchProcess.waitUntilExit()

        // Activate the Simulator via AppleScript
        try runAppleScript("""
            tell application "Simulator" to activate
        """)

        // Wait for app to settle
        Thread.sleep(forTimeInterval: 2.0)

        var screens: [DiscoveredScreen] = []

        // Always include a Launch screen as the first entry
        screens.append(DiscoveredScreen(
            name: "Launch",
            path: "App Launch",
            action: "launch"
        ))

        // Scan the Simulator window for UI elements
        let elements = scanSimulatorWindow()

        // Look for buttons that resemble sidebar/tab items (wide, moderate height)
        let sidebarItems = elements.filter { $0.isSidebarCandidate }

        if sidebarItems.isEmpty {
            // Try toggling a sidebar: find the deepest button in nested groups and click it
            if let toggleResult = try? toggleSidebarAndRescan() {
                for item in toggleResult {
                    screens.append(DiscoveredScreen(
                        name: item,
                        path: "Sidebar > \(item)",
                        action: "tap \"\(item)\""
                    ))
                }
            }
        } else {
            for item in sidebarItems {
                screens.append(DiscoveredScreen(
                    name: item.name,
                    path: "Sidebar > \(item.name)",
                    action: "tap \"\(item.name)\""
                ))
            }
        }

        return screens
    }

    // MARK: - AppleScript helpers

    private struct ScannedElement {
        let name: String
        let role: String
        let width: Double
        let height: Double

        var isSidebarCandidate: Bool {
            role.contains("button") && width > 200 && height >= 30 && height <= 80
        }
    }

    private static func scanSimulatorWindow() -> [ScannedElement] {
        // Use AppleScript to get entire contents of the Simulator front window
        let script = """
            tell application "System Events"
                tell process "Simulator"
                    set frontWin to front window
                    set allElements to entire contents of frontWin
                    set output to ""
                    repeat with elem in allElements
                        try
                            set elemRole to role of elem as text
                            set elemName to name of elem as text
                            set elemSize to size of elem
                            set elemW to item 1 of elemSize as text
                            set elemH to item 2 of elemSize as text
                            set output to output & elemRole & "|||" & elemName & "|||" & elemW & "|||" & elemH & linefeed
                        end try
                    end repeat
                    return output
                end tell
            end tell
        """

        guard let raw = try? runAppleScript(script) else {
            return []
        }

        var elements: [ScannedElement] = []
        let lines = raw.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.components(separatedBy: "|||")
            guard parts.count == 4,
                  let w = Double(parts[2].trimmingCharacters(in: .whitespaces)),
                  let h = Double(parts[3].trimmingCharacters(in: .whitespaces))
            else { continue }

            let role = parts[0].trimmingCharacters(in: .whitespaces)
            let name = parts[1].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }

            elements.append(ScannedElement(name: name, role: role, width: w, height: h))
        }
        return elements
    }

    /// Attempt to find a sidebar toggle button (deepest button in nested groups), click it, then re-scan.
    private static func toggleSidebarAndRescan() throws -> [String] {
        // Find the deepest button inside nested groups and click it
        let clickScript = """
            tell application "System Events"
                tell process "Simulator"
                    set frontWin to front window
                    set allElements to entire contents of frontWin
                    set deepestButton to missing value
                    set maxDepth to 0
                    repeat with elem in allElements
                        try
                            if role of elem is "AXButton" then
                                -- estimate depth by counting groups in the element's path
                                set elemDesc to description of elem as text
                                set currentDepth to 0
                                set allContainers to entire contents of frontWin
                                -- simple heuristic: use the element position in the list as depth proxy
                                set idx to 0
                                repeat with c in allElements
                                    set idx to idx + 1
                                    if c is elem then exit repeat
                                end repeat
                                if idx > maxDepth then
                                    set maxDepth to idx
                                    set deepestButton to elem
                                end if
                            end if
                        end try
                    end repeat
                    if deepestButton is not missing value then
                        click deepestButton
                    end if
                end tell
            end tell
        """

        try runAppleScript(clickScript)

        // Wait for sidebar to appear
        Thread.sleep(forTimeInterval: 1.0)

        // Re-scan and return sidebar candidates
        let elements = scanSimulatorWindow()
        return elements.filter { $0.isSidebarCandidate }.map { $0.name }
    }

    @discardableResult
    private static func runAppleScript(_ source: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
