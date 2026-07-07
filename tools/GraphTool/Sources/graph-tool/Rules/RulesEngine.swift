import Foundation

// MARK: - Violation

struct Violation: CustomStringConvertible {
    /// The module that has an illegal dependency.
    let fromModule: String
    /// The module being depended on.
    let toModule: String
    /// The layer `fromModule` belongs to.
    let fromLayer: String
    /// The layer `toModule` belongs to.
    let toLayer: String

    var description: String {
        "  ✗ \(fromModule) [\(fromLayer)] → \(toModule) [\(toLayer)]"
    }
}

// MARK: - RulesEngine

struct RulesEngine {

    // MARK: Public API

    /// Check every direct dependency edge in `graph` against the rules in
    /// `config` and return all violations found.
    ///
    /// A violation occurs when:
    ///   - the importing module belongs to a known layer, AND
    ///   - the imported module belongs to a known layer, AND
    ///   - the importing layer does not list the imported layer in `canDependOn`.
    ///
    /// Modules not assigned to any layer are silently ignored (no violation
    /// is raised for them, but they also won't protect other modules).
    static func check(
        graph: DependencyGraph,
        config: RulesConfig,
        includeTests: Bool = false
    ) -> [Violation] {
        var violations: [Violation] = []

        for module in graph.allModules {
            // Optionally skip test targets
            if module.kind == .test && !includeTests { continue }
            // Skip plugins and system targets — they live outside the layer model
            if module.kind == .plugin || module.kind == .system { continue }

            guard let fromLayer = config.layer(for: module.name) else { continue }

            for dep in module.internalDeps {
                guard graph.modules[dep] != nil else { continue }   // skip externals
                guard let toLayer = config.layer(for: dep) else { continue }
                guard fromLayer.name != toLayer.name else { continue } // same layer OK

                if !config.isAllowed(from: fromLayer.name, to: toLayer.name) {
                    violations.append(Violation(
                        fromModule: module.name,
                        toModule: dep,
                        fromLayer: fromLayer.name,
                        toLayer: toLayer.name
                    ))
                }
            }
        }

        return violations.sorted {
            $0.fromModule == $1.fromModule
                ? $0.toModule < $1.toModule
                : $0.fromModule < $1.fromModule
        }
    }
}
