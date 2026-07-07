import ArgumentParser

@main
struct GraphTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "graph-tool",
        abstract: "Analyse a Swift package's internal module dependency graph.",
        discussion: """
        graph-tool reads `swift package dump-package` output and builds an
        in-memory dependency graph from it.  Two subcommands are provided:

          graph   Emit a visual diagram of the module graph (Mermaid or DOT).
          check   Validate that modules only depend on permitted layers.
                  Exits with a non-zero status on violation — suitable for CI.
        """,
        subcommands: [GraphCommand.self, CheckCommand.self]
    )
}
