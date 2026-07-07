import ArgumentParser
import Foundation

struct CheckCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "Check module dependencies against allowed-dependencies.json.",
        discussion: """
        Exits with code 0 when all dependency edges are permitted, or code 1
        when one or more violations are found. Suitable for use in CI pipelines.
        """
    )

    // MARK: - Options

    @Option(name: [.customLong("package-path"), .customShort("p")],
            help: "Path to the Swift package (default: current directory).")
    var packagePath: String = "."

    @Option(name: [.customLong("config"), .customShort("c")],
            help: "Path to allowed-dependencies.json (default: <package-path>/allowed-dependencies.json).")
    var configPath: String?

    @Flag(name: [.customLong("include-tests")],
          help: "Also check test target dependencies.")
    var includeTests: Bool = false

    // MARK: - Run

    func run() throws {
        let pkgURL = URL(fileURLWithPath: packagePath).standardized

        // Resolve the config path
        let cfgURL: URL
        if let path = configPath {
            cfgURL = URL(fileURLWithPath: path).standardized
        } else {
            cfgURL = RulesConfig.defaultURL(packagePath: pkgURL)
        }

        guard FileManager.default.fileExists(atPath: cfgURL.path) else {
            throw ValidationError(
                "Config file not found: \(cfgURL.path)\n" +
                "Create allowed-dependencies.json or pass --config <path>."
            )
        }

        let config = try RulesConfig.load(from: cfgURL)
        let graph  = try PackageParser.parse(packagePath: pkgURL)

        let violations = RulesEngine.check(
            graph: graph,
            config: config,
            includeTests: includeTests
        )

        if violations.isEmpty {
            print("✓ No dependency violations found.")
        } else {
            let noun = violations.count == 1 ? "violation" : "violations"
            print("✗ \(violations.count) dependency \(noun) found:\n")
            for v in violations {
                print(v.description)
            }
            print("")
            throw ExitCode(1)
        }
    }
}
