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

        // 2. Resolve overrides
        let targetLocales = resolveLocales(from: cfg)
        let simDevice = simulator ?? cfg.app.simulator ?? "iPhone 16 Pro Max"
        let outputDir = URL(fileURLWithPath: output ?? cfg.output ?? "./captures")
        let projectName = project ?? cfg.project ?? cfg.app.scheme

        fmt.printHeader("Capturing \(cfg.screens.count) screens in \(targetLocales.count) locales on \(simDevice)\n")

        // 3. Check accessibility permissions if any screen needs navigation
        let hasNavigation = cfg.screens.contains { screen in
            let action = try? ScreenAction.parse(screen.action)
            switch action {
            case .tap, .navigate: return true
            default: return false
            }
        }

        if hasNavigation {
            do {
                try TestRunner.checkAccessibility()
            } catch {
                fmt.printError(error.localizedDescription)
                throw ExitCode(1)
            }
        }

        // 4. Capture screenshots for each locale
        var allResults: [(locale: String, screens: [String])] = []
        var hadFailure = false

        for locale in targetLocales {
            // Set simulator locale via simctl
            do {
                try setSimulatorLocale(locale, bundleId: cfg.app.bundleId)
            } catch {
                fmt.printError("\(locale): Failed to set locale — \(error.localizedDescription)")
                hadFailure = true
                continue
            }

            // Capture all screens
            do {
                let screenshots = try TestRunner.captureScreens(
                    screens: cfg.screens,
                    bundleId: cfg.app.bundleId,
                    simulator: simDevice,
                    locale: locale,
                    outputDir: outputDir
                )

                let screenNames = screenshots.map(\.name)
                allResults.append((locale: locale, screens: screenNames))
                fmt.printLocaleResult(locale: locale, screens: screenNames, status: "ok")

            } catch {
                fmt.printLocaleResult(locale: locale, screens: [], status: "failed")
                fmt.printError("\(locale): \(error.localizedDescription)")
                hadFailure = true
            }
        }

        // 4. Import into FrameHero project
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

        // 5. Summary
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
