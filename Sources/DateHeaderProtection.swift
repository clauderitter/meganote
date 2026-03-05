import AppKit

/// Handles protection of date header lines from editing
struct DateHeaderProtection {

    /// Custom attribute key to mark date header text
    static let isDateHeaderKey = NSAttributedString.Key("MeganoteDateHeader")

    /// Find all date header ranges in the text storage
    static func dateHeaderRanges(in textStorage: NSTextStorage) -> [NSRange] {
        var ranges: [NSRange] = []
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.enumerateAttribute(isDateHeaderKey, in: fullRange, options: []) { value, range, _ in
            if value as? Bool == true {
                ranges.append(range)
            }
        }
        return ranges
    }

    /// Check if a given range overlaps with any date header
    static func overlapsDateHeader(range: NSRange, in textStorage: NSTextStorage) -> Bool {
        let headerRanges = dateHeaderRanges(in: textStorage)
        for headerRange in headerRanges {
            if NSIntersectionRange(range, headerRange).length > 0 {
                return true
            }
        }
        return false
    }

    /// Determine if a text change should be allowed.
    /// Returns the adjusted range if the change can proceed with modification,
    /// or nil if the change should be blocked entirely.
    static func adjustedRange(
        for proposedRange: NSRange,
        in textStorage: NSTextStorage
    ) -> NSRange? {
        let headerRanges = dateHeaderRanges(in: textStorage)
        if headerRanges.isEmpty { return proposedRange }

        // Check if the proposed range overlaps any header
        var hasOverlap = false
        for headerRange in headerRanges {
            if NSIntersectionRange(proposedRange, headerRange).length > 0 {
                hasOverlap = true
                break
            }
        }

        if !hasOverlap { return proposedRange }

        // If editing a zero-length range (typing) at the start of a header, redirect before the header
        if proposedRange.length == 0 {
            for headerRange in headerRanges {
                if proposedRange.location >= headerRange.location &&
                   proposedRange.location < NSMaxRange(headerRange) {
                    // Don't allow typing inside a date header
                    return nil
                }
            }
        }

        // For selections that span a header, block the change
        return nil
    }

    /// Check if a character index is inside a date header
    static func isInsideDateHeader(at index: Int, in textStorage: NSTextStorage) -> Bool {
        let headerRanges = dateHeaderRanges(in: textStorage)
        for range in headerRanges {
            if index >= range.location && index < NSMaxRange(range) {
                return true
            }
        }
        return false
    }

    /// Get the full line range for a date header that contains the given index
    static func headerLineRange(at index: Int, in textStorage: NSTextStorage) -> NSRange? {
        let headerRanges = dateHeaderRanges(in: textStorage)
        for range in headerRanges {
            if index >= range.location && index <= NSMaxRange(range) {
                return range
            }
        }
        return nil
    }

    /// Find empty date sections (sections where there's no non-whitespace content between headers)
    static func emptyDateSections(in textStorage: NSTextStorage) -> [(header: NSRange, headerText: String)] {
        let string = textStorage.string
        let headerRanges = dateHeaderRanges(in: textStorage)
        var emptySections: [(header: NSRange, headerText: String)] = []

        for (index, headerRange) in headerRanges.enumerated() {
            let contentStart = NSMaxRange(headerRange)
            let contentEnd: Int
            if index + 1 < headerRanges.count {
                contentEnd = headerRanges[index + 1].location
            } else {
                contentEnd = textStorage.length
            }

            if contentStart <= contentEnd {
                let contentRange = NSRange(location: contentStart, length: contentEnd - contentStart)
                if contentRange.length >= 0 {
                    let startIdx = string.index(string.startIndex, offsetBy: contentStart)
                    let endIdx = string.index(string.startIndex, offsetBy: min(contentEnd, string.count))
                    let content = String(string[startIdx..<endIdx])
                    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        let headerText = (string as NSString).substring(with: headerRange)
                        emptySections.append((header: headerRange, headerText: headerText))
                    }
                }
            }
        }

        return emptySections
    }
}
