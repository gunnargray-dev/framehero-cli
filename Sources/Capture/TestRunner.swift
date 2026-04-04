import Foundation

/// Simple screenshot capture using simctl. Only supports `launch` action.
/// For tap/navigate actions, use XCUITest via CaptureCommand.
struct TestRunner {

    static func captureScreens(
        screens: [FrameHeroConfig.ScreenConfig],
        bundleId: String,
        locale: String,
        outputDir: URL
    ) throws -> [(name: String, url: URL)] {
        let localeDir = outputDir.appendingPathComponent(locale)
        try FileManager.default.createDirectory(at: localeDir, withIntermediateDirectories: true)

        var results: [(name: String, url: URL)] = []

        for screen in screens {
            try? simctl("terminate", "booted", bundleId)
            Thread.sleep(forTimeInterval: 0.5)
            try simctl("launch", "booted", bundleId)
            Thread.sleep(forTimeInterval: 2.0)

            let screenshotURL = localeDir.appendingPathComponent("\(screen.name).png")
            try simctl("io", "booted", "screenshot", screenshotURL.path)
            results.append((name: screen.name, url: screenshotURL))
        }

        return results
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
}

enum TestRunnerError: LocalizedError {
    case simctlFailed(String)

    var errorDescription: String? {
        switch self {
        case .simctlFailed(let cmd):
            return "simctl command failed: \(cmd)"
        }
    }
}
