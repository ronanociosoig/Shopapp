import ArgumentParser
import Foundation

// MARK: - Output format

enum OutputFormat: String, CaseIterable, ExpressibleByArgument {
    case mermaid
    case dot
    case plain

    var defaultValueDescription: String { rawValue }
    static var allValueStrings: [String] { allCases.map(\.rawValue) }
}

// MARK: - Formatter

struct GraphFormatter {

    // MARK: Public entry point

    /// Render the graph in the requested format.
    /// - Parameters:
    ///   - graph: The dependency graph to render.
    ///   - format: The output format.
    ///   - config: Optional layer config used for node colouring (Mermaid/DOT only).
    ///   - includeTests: Include test targets in the output.
    ///   - includeApps: Include executable micro-app targets in the output.
    ///   - includeExternal: Append external package products as leaf nodes.
    static func format(
        _ graph: DependencyGraph,
        as format: OutputFormat,
        config: RulesConfig? = nil,
        includeTests: Bool = false,
        includeApps: Bool = false,
        includeExternal: Bool = false
    ) -> String {
        switch format {
        case .mermaid: return mermaid(graph, config: config, includeTests: includeTests, includeApps: includeApps, includeExternal: includeExternal)
        case .dot:     return dot(graph, config: config, includeTests: includeTests, includeApps: includeApps, includeExternal: includeExternal)
        case .plain:   return plain(graph, includeTests: includeTests, includeApps: includeApps, includeExternal: includeExternal)
        }
    }

    // MARK: - Mermaid

    private static func mermaid(
        _ graph: DependencyGraph,
        config: RulesConfig?,
        includeTests: Bool,
        includeApps: Bool,
        includeExternal: Bool
    ) -> String {
        let visible = visibleModules(graph, includeTests: includeTests, includeApps: includeApps)
        let visibleNames = Set(visible.map(\.name))

        var lines: [String] = ["graph LR"]

        // Layer-based node styling via classDef
        if let config = config {
            for layer in config.layers {
                let cls = mermaidClassName(layer.name)
                let style = mermaidStyle(for: layer.name)
                lines.append("    classDef \(cls) \(style)")
            }
            lines.append("")
        }

        // Subgraphs per layer (if config provided)
        if let config = config {
            var unassigned = visibleNames
            for layer in config.layers {
                let members = layer.modules.filter { visibleNames.contains($0) }
                guard !members.isEmpty else { continue }
                unassigned.subtract(members)
                let safeName = layer.name.replacingOccurrences(of: " ", with: "_")
                lines.append("    subgraph \(safeName)[\"\(layer.name)\"]")
                for m in members.sorted() {
                    lines.append("        \(mermaidID(m))[\"\(m)\"]")
                }
                lines.append("    end")
            }
            // Modules not assigned to any layer
            for name in unassigned.sorted() {
                lines.append("    \(mermaidID(name))[\"\(name)\"]")
            }
            lines.append("")
        }

        // Edges — internal deps
        var edgesAdded = false
        for module in visible.sorted(by: { $0.name < $1.name }) {
            for dep in module.internalDeps.sorted() where visibleNames.contains(dep) {
                lines.append("    \(mermaidID(module.name)) --> \(mermaidID(dep))")
                edgesAdded = true
            }
            // External deps as dashed edges (optional)
            if includeExternal {
                for ext in module.externalDeps.sorted(by: { $0.product < $1.product }) {
                    let extID = mermaidID("ext_\(ext.product)")
                    lines.append("    \(mermaidID(module.name)) -.-> \(extID)[\"\(ext.product)\"]:::external")
                    edgesAdded = true
                }
            }
        }

        if !edgesAdded {
            lines.append("    %% No edges — all modules are independent")
        }

        // Apply class assignments
        if let config = config {
            lines.append("")
            for layer in config.layers {
                let cls = mermaidClassName(layer.name)
                let members = layer.modules.filter { visibleNames.contains($0) }
                guard !members.isEmpty else { continue }
                let ids = members.sorted().map { mermaidID($0) }.joined(separator: ",")
                lines.append("    class \(ids) \(cls)")
            }
            if includeExternal {
                lines.append("    classDef external fill:#eee,stroke:#bbb,color:#555,stroke-dasharray:4 4")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - DOT

    private static func dot(
        _ graph: DependencyGraph,
        config: RulesConfig?,
        includeTests: Bool,
        includeApps: Bool,
        includeExternal: Bool
    ) -> String {
        let visible = visibleModules(graph, includeTests: includeTests, includeApps: includeApps)
        let visibleNames = Set(visible.map(\.name))

        var lines: [String] = [
            "digraph \(graph.packageName) {",
            "    rankdir=LR;",
            "    node [shape=box, fontname=\"Helvetica\", style=filled];",
            "    edge [fontname=\"Helvetica\"];",
            "",
        ]

        // Node declarations with colour
        if let config = config {
            for layer in config.layers {
                let members = layer.modules.filter { visibleNames.contains($0) }
                guard !members.isEmpty else { continue }
                let (fill, border) = dotFill(for: layer.name)
                lines.append("    // \(layer.name)")
                for name in members.sorted() {
                    lines.append("    \"\(name)\" [fillcolor=\"\(fill)\", color=\"\(border)\", fontcolor=\"white\"];")
                }
            }
        } else {
            for module in visible.sorted(by: { $0.name < $1.name }) {
                lines.append("    \"\(module.name)\";")
            }
        }

        lines.append("")

        // Edges
        for module in visible.sorted(by: { $0.name < $1.name }) {
            for dep in module.internalDeps.sorted() where visibleNames.contains(dep) {
                lines.append("    \"\(module.name)\" -> \"\(dep)\";")
            }
            if includeExternal {
                for ext in module.externalDeps.sorted(by: { $0.product < $1.product }) {
                    lines.append("    \"\(module.name)\" -> \"\(ext.product)\" [style=dashed, color=\"#aaa\"];")
                    lines.append("    \"\(ext.product)\" [shape=ellipse, fillcolor=\"#eeeeee\", color=\"#bbbbbb\", fontcolor=\"#555555\"];")
                }
            }
        }

        lines.append("}")
        return lines.joined(separator: "\n")
    }

    // MARK: - Plain text

    private static func plain(
        _ graph: DependencyGraph,
        includeTests: Bool,
        includeApps: Bool,
        includeExternal: Bool
    ) -> String {
        let visible = visibleModules(graph, includeTests: includeTests, includeApps: includeApps)

        var lines = ["\(graph.packageName) — dependency graph", ""]

        for module in visible.sorted(by: { $0.name < $1.name }) {
            let tag: String
            switch module.kind {
            case .test:       tag = "[test]"
            case .executable: tag = "[app]"
            case .library:    tag = ""
            default:          tag = "[\(module.kind.rawValue)]"
            }
            let header = tag.isEmpty ? module.name : "\(module.name) \(tag)"
            lines.append("  \(header)")

            let internalVisible = module.internalDeps.filter { graph.modules[$0] != nil }
            for dep in internalVisible.sorted() {
                lines.append("    → \(dep)")
            }
            if includeExternal {
                for ext in module.externalDeps.sorted(by: { $0.product < $1.product }) {
                    lines.append("    → \(ext.product) (external: \(ext.package))")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func visibleModules(
        _ graph: DependencyGraph,
        includeTests: Bool,
        includeApps: Bool
    ) -> [Module] {
        graph.allModules.filter { module in
            if module.kind == .test && !includeTests { return false }
            if module.kind == .executable && !includeApps { return false }
            if module.kind == .plugin { return false }
            if module.kind == .system { return false }
            return true
        }
    }

    // MARK: Mermaid helpers

    /// Safe Mermaid node identifier (letters, digits, underscores only).
    private static func mermaidID(_ name: String) -> String {
        name.replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func mermaidClassName(_ layer: String) -> String {
        layer.lowercased().replacingOccurrences(of: " ", with: "_")
    }

    private static func mermaidStyle(for layer: String) -> String {
        switch layer.lowercased() {
        case "app":        return "fill:#E67E22,stroke:#CA6F1E,color:#fff"
        case "feature":    return "fill:#2980B9,stroke:#1F618D,color:#fff"
        case "foundation": return "fill:#27AE60,stroke:#1E8449,color:#fff"
        default:           return "fill:#8E44AD,stroke:#6C3483,color:#fff"
        }
    }

    // MARK: DOT helpers

    private static func dotFill(for layer: String) -> (fill: String, border: String) {
        switch layer.lowercased() {
        case "app":        return ("#E67E22", "#CA6F1E")
        case "feature":    return ("#2980B9", "#1F618D")
        case "foundation": return ("#27AE60", "#1E8449")
        default:           return ("#8E44AD", "#6C3483")
        }
    }
}
