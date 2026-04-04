import Foundation
import Yams

struct ConfigParser {
    static func load(from path: String) throws -> FrameHeroConfig {
        let url = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ConfigError.fileNotFound(path)
        }

        let yamlString: String
        do {
            yamlString = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ConfigError.invalidYAML("Could not read file: \(error.localizedDescription)")
        }

        let config: FrameHeroConfig
        do {
            let decoder = YAMLDecoder()
            config = try decoder.decode(FrameHeroConfig.self, from: yamlString)
        } catch {
            throw ConfigError.invalidYAML(error.localizedDescription)
        }

        if config.app.bundleId.isEmpty { throw ConfigError.missingField("app.bundle-id") }
        if config.app.scheme.isEmpty { throw ConfigError.missingField("app.scheme") }
        if config.screens.isEmpty { throw ConfigError.missingField("screens") }
        if config.locales.isEmpty { throw ConfigError.missingField("locales") }

        for screen in config.screens {
            _ = try ScreenAction.parse(screen.action)
        }

        return config
    }

    static func save(_ config: FrameHeroConfig, to path: String) throws {
        let encoder = YAMLEncoder()
        let yamlString = try encoder.encode(config)
        let url = URL(fileURLWithPath: path)
        try yamlString.write(to: url, atomically: true, encoding: .utf8)
    }

    static func saveWithComments(_ config: FrameHeroConfig, to path: String) throws {
        var lines: [String] = []

        // App section
        lines.append("# App to capture")
        lines.append("app:")
        lines.append("  bundle-id: \(config.app.bundleId)")
        lines.append("  scheme: \(config.app.scheme)")
        if let simulator = config.app.simulator {
            lines.append("  simulator: \(simulator)")
        }

        // Screens section
        lines.append("")
        lines.append("# Screens to capture")
        lines.append("# Actions: launch, tap \"Label\", navigate \"A\" > \"B\"")
        lines.append("screens:")
        for screen in config.screens {
            lines.append("  - name: \(screen.name)")
            lines.append("    action: \(screen.action)")
        }

        // Locales section
        lines.append("")
        lines.append("# Locales to capture (BCP 47 codes)")
        lines.append("locales:")
        for locale in config.locales {
            lines.append("  - \(locale)")
        }

        // Output section
        if let output = config.output {
            lines.append("")
            lines.append("# Output directory for screenshots")
            lines.append("output: \(output)")
        }

        // Project section
        if let project = config.project {
            lines.append("")
            lines.append("# FrameHero project name (for import into FrameHero.app)")
            lines.append("project: \(project)")
        }

        lines.append("")

        let yamlString = lines.joined(separator: "\n")
        let url = URL(fileURLWithPath: path)
        try yamlString.write(to: url, atomically: true, encoding: .utf8)
    }
}
