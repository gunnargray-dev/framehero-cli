import Foundation

struct OutputFormatter {
    enum Format {
        case text
        case json
        case auto
    }

    let format: Format

    init(format: Format = .auto) {
        self.format = format
    }

    private var useJSON: Bool {
        switch format {
        case .json: return true
        case .text: return false
        case .auto: return !isatty(fileno(stdout)).boolValue
        }
    }

    func printProgress(_ message: String) {
        guard !useJSON else { return }
        print("  \(message)")
    }

    func printSuccess(_ message: String) {
        guard !useJSON else { return }
        print("  ✓ \(message)")
    }

    func printError(_ message: String) {
        // Errors always go to stderr regardless of format
        FileHandle.standardError.write(Data("  ✗ \(message)\n".utf8))
    }

    func printHeader(_ message: String) {
        guard !useJSON else { return }
        print(message)
    }

    func printLocaleResult(locale: String, screens: [String], status: String) {
        if useJSON {
            let json: [String: Any] = [
                "locale": locale,
                "screens": screens,
                "count": screens.count,
                "status": status
            ]
            if let data = try? JSONSerialization.data(withJSONObject: json),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        } else {
            let screenList = screens.joined(separator: ", ")
            let icon = status == "ok" ? "✓" : "✗"
            print("  \(icon) \(locale): \(screenList) (\(screens.count) screenshots)")
        }
    }

    func printSummary(total: Int, localeCount: Int, output: String, project: String?, imported: Bool) {
        if useJSON {
            var json: [String: Any] = [
                "total": total,
                "output": output,
                "imported": imported
            ]
            if let project { json["project"] = project }
            if let data = try? JSONSerialization.data(withJSONObject: json),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        } else {
            if localeCount > 1 {
                print("\n\(total) screenshots captured across \(localeCount) locales")
            } else {
                print("\n\(total) screenshots saved to \(output)")
            }
            if imported, let project {
                print("Imported into FrameHero project \"\(project)\"")
            }
            print("Add text overlays and export for App Store \u{2192} framehero.dev")
        }
    }
}

private extension Int32 {
    var boolValue: Bool { self != 0 }
}
