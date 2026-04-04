import ArgumentParser
import Foundation

struct CaptureCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "capture",
        abstract: "Capture screenshots across locales using framehero.yml config."
    )

    @Option(name: .long, help: "Path to config file.")
    var config: String = "./framehero.yml"

    @Option(name: .long, help: "Output directory for raw PNGs.")
    var output: String?

    @Option(name: .long, help: "Override locales (comma-separated).")
    var locales: String?

    @Option(name: .long, help: "Override simulator device.")
    var simulator: String?

    @Option(name: .long, help: "FrameHero project name.")
    var project: String?

    @Flag(name: .long, help: "Skip FrameHero project import.")
    var noImport: Bool = false

    @Option(name: .long, help: "Output format: text or json.")
    var format: String?

    @Option(name: .long, help: "Device frame: device name (e.g. \"iPhone 16 Pro\") or \"none\".")
    var frame: String?

    func run() async throws {
        let fmt = OutputFormatter(format: parseFormat())

        // 1. Load config
        let cfg: FrameHeroConfig
        do {
            cfg = try ConfigParser.load(from: config)
        } catch {
            fmt.printError(error.localizedDescription)
            throw ExitCode(1)
        }

        // 2. Pre-flight validation
        let hasNavigation = cfg.screens.contains { screen in
            let action = try? ScreenAction.parse(screen.action)
            switch action {
            case .tap, .navigate: return true
            default: return false
            }
        }

        if hasNavigation {
            do {
                try SimulatorValidator.checkXcodebuild()
            } catch {
                fmt.printError(error.localizedDescription)
                throw ExitCode(1)
            }
        }

        let simDevice: String
        do {
            let requested = simulator ?? cfg.app.simulator ?? "iPhone 16 Pro Max"
            simDevice = try SimulatorValidator.resolveSimulator(requested: requested)
        } catch {
            fmt.printError(error.localizedDescription)
            throw ExitCode(1)
        }

        do {
            try SimulatorValidator.checkAppInstalled(bundleId: cfg.app.bundleId)
        } catch {
            fmt.printError(error.localizedDescription)
            throw ExitCode(1)
        }

        // 3. Resolve overrides
        let targetLocales = resolveLocales(from: cfg)
        let outputDir = URL(fileURLWithPath: output ?? cfg.output ?? "./captures")
        let projectName = project ?? cfg.project ?? cfg.app.scheme

        fmt.printHeader("Capturing \(cfg.screens.count) screens in \(targetLocales.count) locales on \(simDevice)\n")

        // 4. Decide capture strategy
        let useXCUITest = hasNavigation

        // 5. Capture screenshots for each locale
        var allResults: [(locale: String, screens: [String])] = []
        var hadFailure = false

        for locale in targetLocales {
            do {
                try setSimulatorLocale(locale, bundleId: cfg.app.bundleId)
            } catch {
                fmt.printError("\(locale): Failed to set locale — \(error.localizedDescription)")
                hadFailure = true
                continue
            }

            do {
                let screenshots: [(name: String, url: URL)]

                if useXCUITest {
                    screenshots = try captureViaXCUITest(
                        cfg: cfg,
                        simulator: simDevice,
                        locale: locale,
                        outputDir: outputDir
                    )
                } else {
                    screenshots = try captureViaSimctl(
                        cfg: cfg,
                        locale: locale,
                        outputDir: outputDir
                    )
                }

                let screenNames = screenshots.map(\.name)
                allResults.append((locale: locale, screens: screenNames))
                fmt.printLocaleResult(locale: locale, screens: screenNames, status: "ok")

            } catch {
                fmt.printLocaleResult(locale: locale, screens: [], status: "failed")
                fmt.printError("\(locale): \(error.localizedDescription)")
                hadFailure = true
            }
        }

        // 6. Apply device frames if requested
        let frameDevice = frame ?? cfg.frame
        if let frameDevice, frameDevice.lowercased() != "none" {
            let deviceName = frameDevice == "auto" ? simDevice : frameDevice
            fmt.printProgress("Applying \(deviceName) device frame...")

            for result in allResults {
                let localeDir = outputDir.appendingPathComponent(result.locale)
                for screenName in result.screens {
                    let screenshotURL = localeDir.appendingPathComponent("\(screenName).png")
                    guard FileManager.default.fileExists(atPath: screenshotURL.path) else { continue }

                    let framedURL = localeDir.appendingPathComponent("\(screenName)_framed.png")
                    do {
                        try DeviceFrameCompositor.frame(
                            screenshot: screenshotURL,
                            device: deviceName,
                            outputURL: framedURL
                        )
                    } catch {
                        fmt.printError("Framing \(screenName): \(error.localizedDescription)")
                    }
                }
            }
        }

        // 7. Import into FrameHero project
        let totalScreenshots = allResults.reduce(0) { $0 + $1.screens.count }
        var imported = false

        if !noImport && ProjectImporter.isAvailable {
            do {
                try ProjectImporter.importCaptures(
                    results: allResults,
                    outputDir: outputDir,
                    projectName: projectName,
                    simulator: simDevice
                )
                imported = true
            } catch {
                fmt.printError("FrameHero import failed: \(error.localizedDescription)")
            }
        }

        // 7. Summary
        fmt.printSummary(
            total: totalScreenshots,
            output: outputDir.path,
            project: imported ? projectName : nil,
            imported: imported
        )

        if hadFailure {
            throw ExitCode(totalScreenshots > 0 ? 3 : 2)
        }
    }

    // MARK: - XCUITest capture

    private func captureViaXCUITest(
        cfg: FrameHeroConfig,
        simulator: String,
        locale: String,
        outputDir: URL
    ) throws -> [(name: String, url: URL)] {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("framehero-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let testDir = tempDir.appendingPathComponent("Tests")

        // Screenshots are saved directly to this directory by the XCUITest
        let screenshotDir = tempDir.appendingPathComponent("screenshots")
        try FileManager.default.createDirectory(at: screenshotDir, withIntermediateDirectories: true)

        // Generate XCUITest source
        let testFile = try TestGenerator.generate(
            screens: cfg.screens,
            bundleId: cfg.app.bundleId,
            screenshotDir: screenshotDir.path,
            outputDirectory: testDir
        )

        // Generate throwaway Xcode project
        let xcodeproj = try XcodeProjectGenerator.generate(
            testFileURL: testFile,
            projectDir: tempDir
        )

        // Run xcodebuild test
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = [
            "xcodebuild", "test",
            "-project", xcodeproj.path,
            "-scheme", "FrameHeroCaptureTests",
            "-destination", "platform=iOS Simulator,name=\(simulator)",
        ]

        let errPipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errPipe

        // Read stderr asynchronously to prevent pipe buffer deadlock
        var errData = Data()
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            errData.append(handle.availableData)
        }

        try process.run()
        process.waitUntilExit()

        errPipe.fileHandleForReading.readabilityHandler = nil

        guard process.terminationStatus == 0 else {
            let errMsg = String(data: errData, encoding: .utf8) ?? ""
            let lines = errMsg.components(separatedBy: .newlines)
            let errorLines = lines.filter {
                $0.contains("error:") || $0.contains("Could not find") || $0.contains("fatal")
            }.prefix(10)
            let summary = errorLines.isEmpty
                ? "XCUITest failed (exit code \(process.terminationStatus)). Check that Xcode and simulator are configured correctly."
                : errorLines.joined(separator: "\n")
            throw CaptureError.xctestFailed(summary)
        }

        // Collect screenshots from the filesystem
        let localeDir = outputDir.appendingPathComponent(locale)
        try FileManager.default.createDirectory(at: localeDir, withIntermediateDirectories: true)

        var results: [(name: String, url: URL)] = []

        for screen in cfg.screens {
            let srcFile = screenshotDir.appendingPathComponent("\(screen.name).png")
            let destFile = localeDir.appendingPathComponent("\(screen.name).png")

            guard FileManager.default.fileExists(atPath: srcFile.path) else { continue }

            if FileManager.default.fileExists(atPath: destFile.path) {
                try FileManager.default.removeItem(at: destFile)
            }
            try FileManager.default.copyItem(at: srcFile, to: destFile)
            results.append((name: screen.name, url: destFile))
        }

        return results
    }

    // MARK: - simctl capture (launch-only, no navigation)

    private func captureViaSimctl(
        cfg: FrameHeroConfig,
        locale: String,
        outputDir: URL
    ) throws -> [(name: String, url: URL)] {
        let localeDir = outputDir.appendingPathComponent(locale)
        try FileManager.default.createDirectory(at: localeDir, withIntermediateDirectories: true)

        var results: [(name: String, url: URL)] = []

        for screen in cfg.screens {
            // Relaunch for clean state
            try? simctl("terminate", "booted", cfg.app.bundleId)
            Thread.sleep(forTimeInterval: 0.5)
            try simctl("launch", "booted", cfg.app.bundleId)
            Thread.sleep(forTimeInterval: 2.0)

            let screenshotURL = localeDir.appendingPathComponent("\(screen.name).png")
            try simctl("io", "booted", "screenshot", screenshotURL.path)
            results.append((name: screen.name, url: screenshotURL))
        }

        return results
    }

    private func simctl(_ args: String...) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl"] + args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CaptureError.simctlFailed
        }
    }

    // MARK: - Helpers

    private func setSimulatorLocale(_ locale: String, bundleId: String) throws {
        let langCode = locale.components(separatedBy: "-").first ?? locale
        let localeCode = locale.replacingOccurrences(of: "-", with: "_")

        let langProcess = Process()
        langProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        langProcess.arguments = [
            "simctl", "spawn", "booted", "defaults", "write",
            "Apple Global Domain", "AppleLanguages", "-array", langCode
        ]
        try langProcess.run()
        langProcess.waitUntilExit()

        let localeProcess = Process()
        localeProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        localeProcess.arguments = [
            "simctl", "spawn", "booted", "defaults", "write",
            "Apple Global Domain", "AppleLocale", "-string", localeCode
        ]
        try localeProcess.run()
        localeProcess.waitUntilExit()
    }

    private func parseFormat() -> OutputFormatter.Format {
        switch format?.lowercased() {
        case "json": return .json
        case "text": return .text
        default: return .auto
        }
    }

    private func resolveLocales(from cfg: FrameHeroConfig) -> [String] {
        if let override = locales {
            return override.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        return cfg.locales
    }
}

enum CaptureError: LocalizedError {
    case xctestFailed(String)
    case simctlFailed

    var errorDescription: String? {
        switch self {
        case .xctestFailed(let detail):
            return "XCUITest failed: \(detail)"
        case .simctlFailed:
            return "simctl command failed"
        }
    }
}
