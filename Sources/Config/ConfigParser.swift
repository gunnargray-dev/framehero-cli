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
}
