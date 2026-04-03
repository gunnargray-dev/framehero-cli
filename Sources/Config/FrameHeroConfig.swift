import Foundation

struct FrameHeroConfig: Codable {
    var app: AppConfig
    var screens: [ScreenConfig]
    var locales: [String]
    var output: String?
    var project: String?

    struct AppConfig: Codable {
        var bundleId: String
        var scheme: String
        var simulator: String?

        enum CodingKeys: String, CodingKey {
            case bundleId = "bundle-id"
            case scheme
            case simulator
        }
    }

    struct ScreenConfig: Codable {
        var name: String
        var action: String
    }
}

enum ScreenAction {
    case launch
    case tap(label: String)
    case navigate(labels: [String])

    static func parse(_ raw: String) throws -> ScreenAction {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        if trimmed == "launch" {
            return .launch
        }

        if trimmed.hasPrefix("tap ") {
            let label = extractQuoted(from: trimmed, after: "tap ")
            guard let label else {
                throw ConfigError.invalidAction(trimmed, "Expected: tap \"Label\"")
            }
            return .tap(label: label)
        }

        if trimmed.hasPrefix("navigate ") {
            let rest = String(trimmed.dropFirst("navigate ".count))
            let parts = rest.components(separatedBy: " > ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .compactMap { extractQuotedBare($0) }
            guard !parts.isEmpty else {
                throw ConfigError.invalidAction(trimmed, "Expected: navigate \"A\" > \"B\"")
            }
            return .navigate(labels: parts)
        }

        throw ConfigError.invalidAction(trimmed, "Unknown action. Use: launch, tap \"Label\", or navigate \"A\" > \"B\"")
    }

    private static func extractQuoted(from string: String, after prefix: String) -> String? {
        let rest = String(string.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        return extractQuotedBare(rest)
    }

    private static func extractQuotedBare(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && trimmed.count >= 2 {
            return String(trimmed.dropFirst().dropLast())
        }
        return nil
    }
}

enum ConfigError: LocalizedError {
    case fileNotFound(String)
    case invalidYAML(String)
    case invalidAction(String, String)
    case missingField(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Config file not found: \(path)\nRun `framehero init` to create one."
        case .invalidYAML(let detail):
            return "Invalid YAML in config: \(detail)"
        case .invalidAction(let action, let hint):
            return "Invalid action '\(action)'. \(hint)"
        case .missingField(let field):
            return "Missing required field '\(field)' in config."
        }
    }
}
