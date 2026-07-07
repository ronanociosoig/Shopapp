import Foundation

// MARK: - Module kind

enum ModuleKind: String, Equatable {
    case library     // "regular"
    case executable
    case test
    case plugin
    case system
    case macro
    case unknown

    init(rawManifestType: String) {
        switch rawManifestType {
        case "regular":    self = .library
        case "executable": self = .executable
        case "test":       self = .test
        case "plugin":     self = .plugin
        case "system":     self = .system
        case "macro":      self = .macro
        default:           self = .unknown
        }
    }

    var isExcludedByDefault: Bool {
        self == .test || self == .plugin || self == .system
    }
}

// MARK: - Module

struct Module {
    let name: String
    let kind: ModuleKind
    /// Names of other targets defined in the same package this module depends on.
    let internalDeps: [String]
    /// Product references from external Swift packages.
    let externalDeps: [(product: String, package: String)]
}

// MARK: - DependencyGraph

struct DependencyGraph {
    let packageName: String
    /// All modules keyed by name.
    let modules: [String: Module]

    // MARK: Convenience views

    var allModules: [Module] { modules.values.sorted { $0.name < $1.name } }

    func modules(ofKind kind: ModuleKind) -> [Module] {
        allModules.filter { $0.kind == kind }
    }

    // MARK: Graph queries

    /// Direct internal dependencies of a module, filtered to modules that
    /// exist in this graph (so references to externals are silently dropped).
    func directDependencies(of name: String) -> [String] {
        guard let module = modules[name] else { return [] }
        return module.internalDeps.filter { modules[$0] != nil }
    }

    /// All transitive internal dependencies of a module (breadth-first).
    func allDependencies(of name: String) -> Set<String> {
        var visited = Set<String>()
        var queue = directDependencies(of: name)
        while !queue.isEmpty {
            let current = queue.removeFirst()
            guard visited.insert(current).inserted else { continue }
            queue.append(contentsOf: directDependencies(of: current))
        }
        return visited
    }

    /// Modules that directly import a given module.
    func directDependents(of name: String) -> [String] {
        allModules
            .filter { $0.internalDeps.contains(name) }
            .map(\.name)
    }

    /// Returns true if `a` transitively depends on `b`.
    func dependsOn(_ a: String, _ b: String) -> Bool {
        allDependencies(of: a).contains(b)
    }
}
