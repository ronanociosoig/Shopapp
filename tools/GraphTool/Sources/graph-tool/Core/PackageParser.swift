import Foundation

enum PackageParserError: Error, CustomStringConvertible {
    case swiftNotFound
    case dumpPackageFailed(exitCode: Int32, stderr: String)
    case decodingFailed(Error)

    var description: String {
        switch self {
        case .swiftNotFound:
            return "Could not locate the `swift` executable. Make sure Xcode Command Line Tools are installed."
        case .dumpPackageFailed(let code, let stderr):
            return "`swift package dump-package` exited with code \(code).\n\(stderr)"
        case .decodingFailed(let error):
            return "Failed to decode package manifest: \(error)"
        }
    }
}

struct PackageParser {

    // MARK: - Public API

    /// Runs `swift package dump-package` and returns a fully-built `DependencyGraph`.
    static func parse(packagePath: URL) throws -> DependencyGraph {
        let data = try runDumpPackage(at: packagePath)
        return try buildGraph(from: data)
    }

    // MARK: - Private helpers

    private static func runDumpPackage(at packagePath: URL) throws -> Data {
        guard let swiftURL = swiftExecutableURL() else {
            throw PackageParserError.swiftNotFound
        }

        let process = Process()
        process.executableURL = swiftURL
        process.arguments = [
            "package",
            "--package-path", packagePath.path,
            "dump-package",
        ]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError  = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            throw PackageParserError.dumpPackageFailed(
                exitCode: process.terminationStatus,
                stderr: stderr
            )
        }

        return stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    }

    private static func buildGraph(from data: Data) throws -> DependencyGraph {
        let manifest: PackageManifest
        do {
            manifest = try JSONDecoder().decode(PackageManifest.self, from: data)
        } catch {
            throw PackageParserError.decodingFailed(error)
        }

        // Build a set of all target names so we can distinguish internal
        // vs external byName references.
        let internalNames = Set(manifest.targets.map(\.name))

        var modules = [String: Module]()

        for target in manifest.targets {
            var internalDeps  = [String]()
            var externalDeps  = [(product: String, package: String)]()

            for dep in target.dependencies {
                switch dep {
                case .byName(let name):
                    // byName may refer to either an internal target OR a
                    // product whose name happens to match a package name;
                    // we treat it as internal only when the name is a known target.
                    if internalNames.contains(name) {
                        internalDeps.append(name)
                    } else {
                        externalDeps.append((product: name, package: name))
                    }
                case .target(let name):
                    internalDeps.append(name)
                case .product(let productName, let packageName):
                    externalDeps.append((product: productName, package: packageName))
                }
            }

            modules[target.name] = Module(
                name: target.name,
                kind: ModuleKind(rawManifestType: target.type),
                internalDeps: internalDeps,
                externalDeps: externalDeps
            )
        }

        return DependencyGraph(packageName: manifest.name, modules: modules)
    }

    // MARK: - Locate `swift`

    private static func swiftExecutableURL() -> URL? {
        // 1. Try xcrun to find the active toolchain's swift.
        if let url = runXcrun() { return url }
        // 2. Fall back to a well-known location.
        let fallback = URL(fileURLWithPath: "/usr/bin/swift")
        return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
    }

    private static func runXcrun() -> URL? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["--find", "swift"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError  = Pipe()
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: output, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return path.map { URL(fileURLWithPath: $0) }
    }
}
