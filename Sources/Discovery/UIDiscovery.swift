import Foundation

struct UIDiscovery {

    struct DiscoveredScreen {
        let name: String
        let path: String
        let action: String
    }

    /// Launch the app and read its accessibility hierarchy to find navigable screens.
    static func discover(bundleId: String, simulator: String) throws -> [DiscoveredScreen] {
        // Launch the app
        let launchProcess = Process()
        launchProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        launchProcess.arguments = ["simctl", "launch", "booted", bundleId]
        launchProcess.standardOutput = FileHandle.nullDevice
        launchProcess.standardError = FileHandle.nullDevice
        try launchProcess.run()
        launchProcess.waitUntilExit()

        // Wait for app to settle
        Thread.sleep(forTimeInterval: 2.0)

        // Get accessibility hierarchy
        let hierarchy = try getAccessibilityHierarchy()

        var screens: [DiscoveredScreen] = []

        // Always include launch screen
        screens.append(DiscoveredScreen(
            name: "Launch",
            path: "App Launch",
            action: "launch"
        ))

        // Find tab bar items
        let tabBarItems = parseTabBarItems(from: hierarchy)
        for item in tabBarItems {
            screens.append(DiscoveredScreen(
                name: item,
                path: "TabBar > \(item)",
                action: "tap \"\(item)\""
            ))
        }

        return screens
    }

    private static func getAccessibilityHierarchy() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "ui", "booted", "describeSiblings"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func parseTabBarItems(from hierarchy: String) -> [String] {
        var items: [String] = []
        let lines = hierarchy.components(separatedBy: .newlines)
        var inTabBar = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("TabBar") || trimmed.contains("UITabBar") {
                inTabBar = true
                continue
            }

            if inTabBar {
                if let label = extractLabel(from: trimmed) {
                    items.append(label)
                }
                if !trimmed.isEmpty && !trimmed.hasPrefix("-") && !trimmed.hasPrefix("•")
                    && !trimmed.contains("Button") && !trimmed.contains("Tab") && items.count > 0 {
                    inTabBar = false
                }
            }
        }

        return items
    }

    private static func extractLabel(from line: String) -> String? {
        let patterns = ["label: \"", "title: \"", "accessibilityLabel: \""]
        for pattern in patterns {
            if let range = line.range(of: pattern) {
                let rest = line[range.upperBound...]
                if let endQuote = rest.firstIndex(of: "\"") {
                    let label = String(rest[..<endQuote])
                    if !label.isEmpty { return label }
                }
            }
        }
        return nil
    }
}
