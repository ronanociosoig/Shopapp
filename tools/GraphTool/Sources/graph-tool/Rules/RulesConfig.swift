import Foundation

// MARK: - Rules config model

/// Top-level structure of `allowed-dependencies.json`.
///
/// A layer defines a named group of modules and the set of other layer
/// names whose modules it is permitted to import.  Any dependency that
/// crosses layer boundaries in a direction not listed in `canDependOn`
/// is reported as a violation.
struct RulesConfig: Codable {
    let layers: [Layer]

    struct Layer: Codable {
        /// Display name for the layer (e.g. "Feature", "Foundation").
        let name: String
        /// Module names that belong to this layer.
        let modules: [String]
        /// Names of *other* layers this layer is allowed to depend on.
        /// An empty array means the layer must be dependency-free.
        let canDependOn: [String]
    }
}

extension RulesConfig {

    // MARK: - Loading

    /// Load from a JSON file at `url`.
    static func load(from url: URL) throws -> RulesConfig {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(RulesConfig.self, from: data)
    }

    /// Returns the default config path: `<packagePath>/allowed-dependencies.json`.
    static func defaultURL(packagePath: URL) -> URL {
        packagePath.appending(path: "allowed-dependencies.json")
    }

    // MARK: - Lookups

    /// Returns the layer a given module belongs to, or `nil` if unassigned.
    func layer(for moduleName: String) -> Layer? {
        layers.first { $0.modules.contains(moduleName) }
    }

    /// Returns `true` if `fromLayer` is explicitly allowed to depend on `toLayer`.
    func isAllowed(from fromLayer: String, to toLayer: String) -> Bool {
        guard let layer = layers.first(where: { $0.name == fromLayer }) else { return false }
        return layer.canDependOn.contains(toLayer)
    }
}
