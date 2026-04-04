import ArgumentParser
import Foundation

struct InitCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Discover app screens and generate framehero.yml config."
    )

    @Option(name: .long, help: "App bundle identifier.")
    var bundleId: String

    @Option(name: .long, help: "Xcode scheme name.")
    var scheme: String

    @Option(name: .long, help: "Simulator device name.")
    var simulator: String = "iPhone 16 Pro Max"

    @Option(name: .long, help: "Output config file path.")
    var output: String = "./framehero.yml"

    func run() async throws {
        let interactive = isatty(fileno(stdin)) != 0

        // Pre-flight: ensure simulator is booted and app is installed
        let _ = try SimulatorValidator.checkBootedSimulator()
        try SimulatorValidator.checkAppInstalled(bundleId: bundleId)

        print("Launching \(bundleId) on \(simulator)...")

        let screens: [UIDiscovery.DiscoveredScreen]
        do {
            screens = try UIDiscovery.discover(bundleId: bundleId, simulator: simulator)
        } catch {
            print("Error discovering screens: \(error.localizedDescription)")
            print("Make sure the simulator is booted and the app is installed.")
            throw ExitCode(2)
        }

        guard !screens.isEmpty else {
            print("No screens found. Make sure the app is running in the simulator.")
            throw ExitCode(2)
        }

        let selectedScreens: [UIDiscovery.DiscoveredScreen]
        let locales: [String]

        if interactive {
            print("\nFound \(screens.count) screens:")
            for (i, screen) in screens.enumerated() {
                print("  \(i + 1). \(screen.name) (\(screen.path))")
            }

            print("\nSelect screens to capture (comma-separated numbers, or 'all'):", terminator: " ")
            guard let selectionInput = readLine()?.trimmingCharacters(in: .whitespaces) else {
                throw ExitCode(1)
            }

            if selectionInput.lowercased() == "all" {
                selectedScreens = screens
            } else {
                let indices = selectionInput.components(separatedBy: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                    .map { $0 - 1 }
                    .filter { $0 >= 0 && $0 < screens.count }
                selectedScreens = indices.map { screens[$0] }
            }

            guard !selectedScreens.isEmpty else {
                print("No screens selected.")
                throw ExitCode(1)
            }

            print("Locales (comma-separated) [en-US]:", terminator: " ")
            let localeInput = readLine()?.trimmingCharacters(in: .whitespaces) ?? ""
            if localeInput.isEmpty {
                locales = ["en-US"]
            } else {
                locales = localeInput.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
            }
        } else {
            // Non-interactive: use all screens and default locale
            selectedScreens = screens
            locales = ["en-US"]
        }

        let config = FrameHeroConfig(
            app: .init(bundleId: bundleId, scheme: scheme, simulator: simulator),
            screens: selectedScreens.map { .init(name: $0.name, action: $0.action) },
            locales: locales,
            output: "./captures",
            project: scheme
        )

        do {
            try ConfigParser.saveWithComments(config, to: output)
            if interactive {
                print("\nSaved to \(output)")
                print("Run `framehero capture` to start capturing.")
            } else {
                print(output)
            }
        } catch {
            print("Error writing config: \(error.localizedDescription)")
            throw ExitCode(1)
        }
    }
}
