import Foundation

struct FrameHeroConfig: Codable {
    var app: AppConfig
    var screens: [ScreenConfig]
    var locales: [String]
    var output: String?
    var project: String?
    var frame: String?
    var setup: [String]?

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
    case scroll(direction: String)
    case swipe(direction: String)
    case dismiss

    static func parse(_ raw: String) throws -> ScreenAction {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        if trimmed == "launch" {
            return .launch
        }

        if trimmed == "dismiss" || trimmed == "dismiss alert" {
            return .dismiss
        }

        if trimmed.hasPrefix("scroll ") {
            let dir = String(trimmed.dropFirst("scroll ".count)).trimmingCharacters(in: .whitespaces).lowercased()
            guard ["up", "down", "left", "right"].contains(dir) else {
                throw ConfigError.invalidAction(trimmed, "Expected: scroll up|down|left|right")
            }
            return .scroll(direction: dir)
        }

        if trimmed.hasPrefix("swipe ") {
            let dir = String(trimmed.dropFirst("swipe ".count)).trimmingCharacters(in: .whitespaces).lowercased()
            guard ["up", "down", "left", "right"].contains(dir) else {
                throw ConfigError.invalidAction(trimmed, "Expected: swipe up|down|left|right")
            }
            return .swipe(direction: dir)
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
            let rawParts = rest.components(separatedBy: " > ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            var labels: [String] = []
            for part in rawParts {
                guard let quoted = extractQuotedBare(part) else {
                    throw ConfigError.invalidAction(trimmed, "'\(part)' must be in quotes. Expected: navigate \"A\" > \"B\"")
                }
                labels.append(quoted)
            }
            guard !labels.isEmpty else {
                throw ConfigError.invalidAction(trimmed, "Expected: navigate \"A\" > \"B\"")
            }
            return .navigate(labels: labels)
        }

        throw ConfigError.invalidAction(trimmed, "Unknown action. Use: launch, tap \"Label\", navigate \"A\" > \"B\", scroll down, swipe left, or dismiss")
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
