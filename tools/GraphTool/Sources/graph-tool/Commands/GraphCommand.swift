import ArgumentParser
import Foundation

struct GraphCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "graph",
        abstract: "Generate a dependency graph of a Swift package."
    )

    // MARK: - Options

    @Option(name: .shortAndLong, help: "Output format: mermaid | dot | plain.")
    var format: OutputFormat = .mermaid

    @Option(name: [.customLong("package-path"), .customShort("p")],
            help: "Path to the Swift package (default: current directory).")
    var packagePath: String = "."

    @Option(name: .shortAndLong,
            help: "Write output to a file instead of stdout.")
    var output: String?

    @Option(name: [.customLong("config"), .customShort("c")],
            help: "Path to allowed-dependencies.json (default: <package-path>/allowed-dependencies.json).")
    var configPath: String?

    @Flag(name: [.customLong("include-tests")],
          help: "Include test targets in the graph.")
    var includeTests: Bool = false

    @Flag(name: [.customLong("include-apps")],
          help: "Include executable micro-app targets in the graph.")
    var includeApps: Bool = false

    @Flag(name: [.customLong("include-external")],
          help: "Show external package dependencies as leaf nodes.")
    var includeExternal: Bool = false

    // MARK: - Run

    func run() throws {
        let pkgURL = URL(fileURLWithPath: packagePath).standardized

        // Parse the package
        let graph = try PackageParser.parse(packagePath: pkgURL)

        // Load optional layer config for colouring
        let config: RulesConfig? = try loadConfig(packagePath: pkgURL)

        // Render
        let rendered = GraphFormatter.format(
            graph,
            as: format,
            config: config,
            includeTests: includeTests,
            includeApps: includeApps,
            includeExternal: includeExternal
        )

        // Write to file or stdout
        if let outputPath = output {
            let outURL = URL(fileURLWithPath: outputPath)
            try rendered.write(to: outURL, atomically: true, encoding: .utf8)
        } else {
            print(rendered)
        }
    }

    // MARK: - Private

    private func loadConfig(packagePath: URL) throws -> RulesConfig? {
        let url: URL
        if let path = configPath {
            url = URL(fileURLWithPath: path).standardized
        } else {
            url = RulesConfig.defaultURL(packagePath: packagePath)
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try RulesConfig.load(from: url)
    }
}
