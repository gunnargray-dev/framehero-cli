import Foundation

/// Imports captured screenshots into FrameHero's data directory.
/// Copies PNGs into the project storage folder and writes a pending-import
/// manifest that FrameHero.app reads on next launch.
struct ProjectImporter {

    static var appSupportDir: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("FrameHero")
    }

    /// Check if FrameHero.app data directory exists
    static var isAvailable: Bool {
        guard let dir = appSupportDir else { return false }
        return FileManager.default.fileExists(atPath: dir.path)
    }

    /// Import captured screenshots by copying them into FrameHero's storage
    /// and writing a pending-import manifest.
    static func importCaptures(
        results: [(locale: String, screens: [String])],
        outputDir: URL,
        projectName: String,
        simulator: String
    ) throws {
        guard let appSupport = appSupportDir, isAvailable else {
            throw ImportError.frameheroNotInstalled
        }

        // Create a pending import directory
        let importID = UUID().uuidString
        let pendingDir = appSupport.appendingPathComponent("PendingImports/\(importID)")
        let screenshotsDir = pendingDir.appendingPathComponent("screenshots")
        try FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)

        // Copy all screenshots
        var manifestEntries: [[String: String]] = []

        for result in results {
            for screenName in result.screens {
                let sourceFile = outputDir
                    .appendingPathComponent(result.locale)
                    .appendingPathComponent("\(screenName).png")

                guard FileManager.default.fileExists(atPath: sourceFile.path) else { continue }

                let destFileName = "\(result.locale)_\(screenName).png"
                let destFile = screenshotsDir.appendingPathComponent(destFileName)
                try FileManager.default.copyItem(at: sourceFile, to: destFile)

                manifestEntries.append([
                    "locale": result.locale,
                    "name": screenName,
                    "file": destFileName
                ])
            }
        }

        // Write the manifest
        let manifest: [String: Any] = [
            "version": 1,
            "project": projectName,
            "simulator": simulator,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "screenshots": manifestEntries
        ]

        let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: .prettyPrinted)
        let manifestURL = pendingDir.appendingPathComponent("manifest.json")
        try manifestData.write(to: manifestURL)
    }
}

enum ImportError: LocalizedError {
    case frameheroNotInstalled

    var errorDescription: String? {
        switch self {
        case .frameheroNotInstalled:
            return "FrameHero.app not installed (no data directory found). Screenshots saved as raw PNGs only."
        }
    }
}
