import ArgumentParser

@main
struct FrameHeroCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "framehero",
        abstract: "Automate App Store screenshot capture across locales.",
        version: "1.0.0",
        subcommands: [InitCommand.self, CaptureCommand.self],
        defaultSubcommand: nil
    )
}
