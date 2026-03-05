import AppKit

/// Registry of available slash commands
struct SlashCommand {
    let name: String           // "bookmark", "try", "help"
    let color: NSColor         // chip color
    let description: String    // for /help output
    let generatesSnippet: Bool // false for /help

    static let all: [SlashCommand] = [
        SlashCommand(name: "bookmark", color: .systemBlue, description: "Save a link or reference", generatesSnippet: true),
        SlashCommand(name: "try", color: .systemOrange, description: "Something to try later", generatesSnippet: true),
        SlashCommand(name: "help", color: .systemGray, description: "Show available commands", generatesSnippet: false),
    ]

    /// Find a command by name (case-insensitive)
    static func find(_ name: String) -> SlashCommand? {
        all.first { $0.name == name.lowercased() }
    }

    /// Check if a line starts with a known slash command prefix
    /// Returns (command, restOfLine) if found
    static func parse(line: String) -> (command: SlashCommand, text: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("/") else { return nil }

        for cmd in all {
            let prefix = "/\(cmd.name) "
            if trimmed.hasPrefix(prefix) {
                let text = String(trimmed.dropFirst(prefix.count))
                return (cmd, text)
            }
            // Exact match with no trailing text (e.g. "/help")
            if trimmed == "/\(cmd.name)" {
                return (cmd, "")
            }
        }
        return nil
    }

    /// Generate help text listing all commands
    static func helpText() -> String {
        var lines: [String] = ["Available commands:"]
        for cmd in all {
            lines.append("  /\(cmd.name) — \(cmd.description)")
        }
        return lines.joined(separator: "\n")
    }
}
