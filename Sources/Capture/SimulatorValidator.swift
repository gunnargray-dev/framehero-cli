import Foundation

enum ValidationError: LocalizedError {
    case xcodebuildNotFound
    case noBootedSimulator
    case appNotInstalled(bundleId: String)

    var errorDescription: String? {
        switch self {
        case .xcodebuildNotFound:
            return "Xcode Command Line Tools required. Run: xcode-select --install"
        case .noBootedSimulator:
            return "No simulator booted. Run: xcrun simctl boot \"iPhone 16 Pro Max\""
        case .appNotInstalled(let bundleId):
            return "App \(bundleId) not found on simulator. Build and run it from Xcode first."
        }
    }
}

struct SimulatorValidator {

    /// Check that xcodebuild is available. Throws with install instructions if not.
    static func checkXcodebuild() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["xcodebuild"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw ValidationError.xcodebuildNotFound
        }
    }

    /// Check that a simulator is booted. Returns the booted device name.
    /// Throws with boot instructions if nothing is booted.
    static func checkBootedSimulator() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "devices", "booted"]

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // Match lines like: "    iPhone 17 Pro (XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX) (Booted)"
        let pattern = #"^\s+(.+?)\s+\([0-9A-F\-]+\)\s+\(Booted\)"#
        let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
        let range = NSRange(output.startIndex..., in: output)

        if let match = regex.firstMatch(in: output, range: range),
           let nameRange = Range(match.range(at: 1), in: output) {
            return String(output[nameRange])
        }

        throw ValidationError.noBootedSimulator
    }

    /// Check if the requested device matches a booted simulator.
    /// Returns the actual booted device name to use.
    /// If the requested device isn't booted but another is, returns the booted one
    /// and prints a warning to stderr.
    static func resolveSimulator(requested: String) throws -> String {
        let booted = try checkBootedSimulator()

        if booted == requested {
            return booted
        }

        FileHandle.standardError.write(
            Data("Warning: \"\(requested)\" is not booted. Using booted simulator \"\(booted)\" instead.\n".utf8)
        )
        return booted
    }

    /// Check that an app with the given bundle ID is installed on the booted simulator.
    /// Throws with instructions if not found.
    static func checkAppInstalled(bundleId: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "listapps", "booted"]

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if !output.contains(bundleId) {
            throw ValidationError.appNotInstalled(bundleId: bundleId)
        }
    }
}
