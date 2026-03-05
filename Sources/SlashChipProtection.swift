import AppKit

/// Handles protection and styling of slash command chips
struct SlashChipProtection {

    /// Custom attribute key to mark slash command chip text.
    /// Value is the command name string (e.g. "bookmark").
    static let isSlashChipKey = NSAttributedString.Key("MeganoteSlashChip")

    // MARK: - Range Detection

    /// Find all slash chip ranges in the text storage
    /// Returns array of (range, commandName) tuples
    static func chipRanges(in textStorage: NSTextStorage) -> [(range: NSRange, commandName: String)] {
        var results: [(range: NSRange, commandName: String)] = []
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.enumerateAttribute(isSlashChipKey, in: fullRange, options: []) { value, range, _ in
            if let name = value as? String {
                results.append((range: range, commandName: name))
            }
        }
        return results
    }

    /// Check if a given range overlaps with any slash chip
    static func overlapsChip(range: NSRange, in textStorage: NSTextStorage) -> Bool {
        let chips = chipRanges(in: textStorage)
        for chip in chips {
            if NSIntersectionRange(range, chip.range).length > 0 {
                return true
            }
        }
        return false
    }

    /// Check if the proposed edit range is allowed considering chip protection.
    /// Returns true if the edit should be BLOCKED.
    static func shouldBlockEdit(range: NSRange, replacementString: String?, in textStorage: NSTextStorage) -> Bool {
        let chips = chipRanges(in: textStorage)

        for chip in chips {
            let intersection = NSIntersectionRange(range, chip.range)
            if intersection.length > 0 {
                // The edit overlaps a chip

                // Allow if we're deleting the full line (chip + content)
                let nsString = textStorage.string as NSString
                let lineRange = nsString.lineRange(for: chip.range)
                if range.location <= lineRange.location && NSMaxRange(range) >= NSMaxRange(lineRange) {
                    return false // Allow full-line deletion
                }

                // Allow if we're deleting from before the chip through the whole line
                if range.location <= chip.range.location && NSMaxRange(range) >= NSMaxRange(chip.range) {
                    return false // Allow deletion that encompasses entire chip
                }

                // Block partial overlap
                return true
            }

            // Block insertion at any position inside the chip
            if range.length == 0 && range.location > chip.range.location && range.location < NSMaxRange(chip.range) {
                return true
            }
        }

        return false
    }

    /// Check if a character index is inside a slash chip
    static func isInsideChip(at index: Int, in textStorage: NSTextStorage) -> Bool {
        let chips = chipRanges(in: textStorage)
        for chip in chips {
            if index >= chip.range.location && index < NSMaxRange(chip.range) {
                return true
            }
        }
        return false
    }

    // MARK: - Styled Chip Builder

    /// Create a styled attributed string for a slash command chip.
    /// The chip text is "/command" (no trailing space — space added separately).
    static func styledChip(for command: SlashCommand) -> NSAttributedString {
        let chipText = "/\(command.name)"
        let chipFont = NSFont(name: "Menlo-Bold", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: chipFont,
            .foregroundColor: command.color,
            .backgroundColor: command.color.withAlphaComponent(0.12),
            isSlashChipKey: command.name,
        ]

        return NSAttributedString(string: chipText, attributes: attrs)
    }
}
