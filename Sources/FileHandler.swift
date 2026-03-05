import Foundation
import AppKit

class FileHandler {

    static let shared = FileHandler()

    private let meganoteDir: URL
    private let fileURL: URL
    private let backupURL: URL
    private let snippetsDir: URL

    private init() {
        let documentsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents")

        meganoteDir = documentsPath.appendingPathComponent("Meganote")
        fileURL = meganoteDir.appendingPathComponent("meganote.md")
        backupURL = meganoteDir.appendingPathComponent("meganote.md.bak")
        snippetsDir = meganoteDir.appendingPathComponent("snippets")

        ensureDirectories()
        migrateFromOldLocation()
    }

    // MARK: - Directory Setup

    private func ensureDirectories() {
        let fm = FileManager.default
        for dir in [meganoteDir, snippetsDir] {
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    /// Migrate from old ~/Documents/meganote.md to ~/Documents/Meganote/meganote.md
    private func migrateFromOldLocation() {
        let fm = FileManager.default
        let documentsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents")
        let oldFile = documentsPath.appendingPathComponent("meganote.md")
        let oldBackup = documentsPath.appendingPathComponent("meganote.md.bak")

        // Only migrate if old exists and new doesn't
        if fm.fileExists(atPath: oldFile.path) && !fm.fileExists(atPath: fileURL.path) {
            try? fm.moveItem(at: oldFile, to: fileURL)
            if fm.fileExists(atPath: oldBackup.path) {
                try? fm.moveItem(at: oldBackup, to: backupURL)
            }
        }
    }

    // MARK: - Load

    /// Load the meganote file and return an attributed string with styled date headers and slash chips
    func load() -> NSAttributedString {
        guard let markdown = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return NSAttributedString(string: "")
        }
        return markdownToAttributedString(markdown)
    }

    // MARK: - Save

    /// Save the attributed string as markdown, then regenerate snippet files
    func save(attributedString: NSAttributedString) {
        let markdown = attributedStringToMarkdown(attributedString)
        createBackup()
        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            NSLog("Meganote: Failed to save: \(error)")
        }
        regenerateSnippets(from: markdown)
    }

    // MARK: - Backup

    private func createBackup() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return }
        do {
            if fm.fileExists(atPath: backupURL.path) {
                try fm.removeItem(at: backupURL)
            }
            try fm.copyItem(at: fileURL, to: backupURL)
        } catch {
            NSLog("Meganote: Failed to create backup: \(error)")
        }
    }

    // MARK: - Snippet Generation

    /// Regenerate snippet files from the markdown source
    private func regenerateSnippets(from markdown: String) {
        // Collect entries by command name
        var entries: [String: [String]] = [:]
        for cmd in SlashCommand.all where cmd.generatesSnippet {
            entries[cmd.name] = []
        }

        let lines = markdown.components(separatedBy: "\n")
        for line in lines {
            if let parsed = SlashCommand.parse(line: line), parsed.command.generatesSnippet {
                let text = parsed.text.trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    entries[parsed.command.name, default: []].append(text)
                }
            }
        }

        let fm = FileManager.default
        for (name, items) in entries {
            let snippetURL = snippetsDir.appendingPathComponent("\(name).md")
            if items.isEmpty {
                // Remove empty snippet files
                if fm.fileExists(atPath: snippetURL.path) {
                    try? fm.removeItem(at: snippetURL)
                }
            } else {
                let content = items.joined(separator: "\n") + "\n"
                try? content.write(to: snippetURL, atomically: true, encoding: .utf8)
            }
        }
    }

    // MARK: - Markdown Conversion

    /// Convert markdown text to attributed string with styled date headers and slash chips
    func markdownToAttributedString(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")

        let bodyFont = NSFont(name: "Menlo", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let headerFont = NSFont(name: "Menlo-Bold", size: 18) ?? NSFont.monospacedSystemFont(ofSize: 18, weight: .bold)
        let bodyColor = NSColor.textColor
        let headerColor = NSColor.textColor

        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.lineSpacing = 2

        let headerParagraph = NSMutableParagraphStyle()
        headerParagraph.paragraphSpacingBefore = 12
        headerParagraph.paragraphSpacing = 4

        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: bodyColor,
            .paragraphStyle: bodyParagraph,
        ]

        for (index, line) in lines.enumerated() {
            let isLast = index == lines.count - 1
            let newline = isLast ? "" : "\n"

            if DateManager.isDateHeader(line) {
                // Render header without ## prefix
                let displayText = String(line.dropFirst(3)) // Remove "## "
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: headerFont,
                    .foregroundColor: headerColor,
                    .paragraphStyle: headerParagraph,
                    DateHeaderProtection.isDateHeaderKey: true,
                ]
                result.append(NSAttributedString(string: displayText + newline, attributes: attrs))
            } else if let parsed = SlashCommand.parse(line: line), parsed.command.generatesSnippet {
                // Render slash command chip + space + body text
                let chip = SlashChipProtection.styledChip(for: parsed.command)
                result.append(chip)
                result.append(NSAttributedString(string: " " + parsed.text + newline, attributes: bodyAttrs))
            } else {
                result.append(NSAttributedString(string: line + newline, attributes: bodyAttrs))
            }
        }

        return result
    }

    /// Convert attributed string back to markdown
    func attributedStringToMarkdown(_ attrString: NSAttributedString) -> String {
        var markdown = ""

        // We need to handle both date headers and slash chips.
        // Enumerate through the string tracking attribute changes.
        var pos = 0
        while pos < attrString.length {
            var effectiveRange = NSRange()

            // Check for date header
            let isDateHeader = attrString.attribute(DateHeaderProtection.isDateHeaderKey, at: pos, effectiveRange: &effectiveRange) as? Bool ?? false
            if isDateHeader {
                let text = attrString.attributedSubstring(from: effectiveRange).string
                let lines = text.components(separatedBy: "\n")
                for (i, line) in lines.enumerated() {
                    if !line.isEmpty && DateManager.parseDate(line.trimmingCharacters(in: .whitespaces)) != nil {
                        markdown += "## " + line
                    } else {
                        markdown += line
                    }
                    if i < lines.count - 1 {
                        markdown += "\n"
                    }
                }
                pos = NSMaxRange(effectiveRange)
                continue
            }

            // Check for slash chip
            let chipName = attrString.attribute(SlashChipProtection.isSlashChipKey, at: pos, effectiveRange: &effectiveRange) as? String
            if let name = chipName {
                // Write just the command — the body text after the chip already starts with a space
                markdown += "/\(name)"
                pos = NSMaxRange(effectiveRange)
                continue
            }

            // Regular text
            let text = attrString.attributedSubstring(from: effectiveRange).string
            markdown += text
            pos = NSMaxRange(effectiveRange)
        }

        return markdown
    }
}
