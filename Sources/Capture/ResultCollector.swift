import Foundation

struct ResultCollector {

    /// Extract all screenshot attachments from an xcresult bundle.
    /// Returns a mapping of screen name to PNG file URL.
    static func collectScreenshots(
        from resultBundle: URL,
        to outputDir: URL,
        locale: String
    ) throws -> [(name: String, url: URL)] {
        let localeDir = outputDir.appendingPathComponent(locale)
        try FileManager.default.createDirectory(at: localeDir, withIntermediateDirectories: true)

        let attachments = try exportAttachments(from: resultBundle)

        var results: [(name: String, url: URL)] = []

        for attachment in attachments {
            let destURL = localeDir.appendingPathComponent("\(attachment.name).png")
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: attachment.url, to: destURL)
            results.append((name: attachment.name, url: destURL))
        }

        return results
    }

    private struct Attachment {
        let name: String
        let url: URL
    }

    private static func exportAttachments(from resultBundle: URL) throws -> [Attachment] {
        // Get the result bundle's JSON graph
        let graphJSON = try runProcess(
            "/usr/bin/xcrun",
            args: ["xcresulttool", "get", "--path", resultBundle.path, "--format", "json"]
        )

        guard let data = graphJSON.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        let attachmentRefs = findAttachmentRefs(in: root)

        var attachments: [Attachment] = []

        for ref in attachmentRefs {
            let tempFile = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(ref.name)-\(UUID().uuidString).png")

            let _ = try? runProcess(
                "/usr/bin/xcrun",
                args: [
                    "xcresulttool", "export",
                    "--path", resultBundle.path,
                    "--id", ref.id,
                    "--output-path", tempFile.path,
                    "--type", "file"
                ]
            )

            if FileManager.default.fileExists(atPath: tempFile.path) {
                attachments.append(Attachment(name: ref.name, url: tempFile))
            }
        }

        return attachments
    }

    private struct AttachmentRef {
        let name: String
        let id: String
    }

    private static func findAttachmentRefs(in json: Any) -> [AttachmentRef] {
        var refs: [AttachmentRef] = []

        if let dict = json as? [String: Any] {
            if let name = (dict["name"] as? [String: Any])?["_value"] as? String,
               let payloadRef = dict["payloadRef"] as? [String: Any],
               let id = payloadRef["id"] as? [String: Any],
               let idValue = id["_value"] as? String {
                refs.append(AttachmentRef(name: name, id: idValue))
            }

            for (_, value) in dict {
                refs.append(contentsOf: findAttachmentRefs(in: value))
            }
        } else if let array = json as? [Any] {
            for item in array {
                refs.append(contentsOf: findAttachmentRefs(in: item))
            }
        }

        return refs
    }

    private static func runProcess(_ executable: String, args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
