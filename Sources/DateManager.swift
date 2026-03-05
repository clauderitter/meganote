import Foundation

struct DateManager {

    /// Format: "Wed 4. Mar 2026"
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE d. MMM yyyy"
        return formatter.string(from: date)
    }

    /// Markdown header: "## Wed 4. Mar 2026"
    static func markdownHeader(for date: Date) -> String {
        return "## \(formatDate(date))"
    }

    /// Today's markdown header
    static func todayHeader() -> String {
        return markdownHeader(for: Date())
    }

    /// Window title: "Wed 4. Mar 2026"
    static func todayWindowTitle() -> String {
        return formatDate(Date())
    }

    /// Check if a line is a date header (starts with "## " and matches date pattern)
    static func isDateHeader(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("## ") else { return false }
        let dateStr = String(trimmed.dropFirst(3))
        return parseDate(dateStr) != nil
    }

    /// Parse a date string like "Wed 4. Mar 2026" into a Date
    static func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE d. MMM yyyy"
        return formatter.date(from: string)
    }

    /// Extract date from a markdown header line
    static func dateFromHeader(_ line: String) -> Date? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("## ") else { return nil }
        return parseDate(String(trimmed.dropFirst(3)))
    }

    /// Check if today's date header exists in the given text
    static func todayHeaderExists(in text: String) -> Bool {
        let todayStr = todayHeader()
        return text.contains(todayStr)
    }

    /// Check if we're on a new day compared to the topmost date header
    static func isNewDay(in text: String) -> Bool {
        let lines = text.components(separatedBy: "\n")
        for line in lines {
            if isDateHeader(line) {
                let headerDate = dateFromHeader(line)
                if let headerDate = headerDate {
                    return !Calendar.current.isDateInToday(headerDate)
                }
                return false
            }
        }
        // No headers at all → it's a new day (first use)
        return true
    }

    /// Find the range of the first date header in the text
    static func rangeOfFirstHeader(in text: String) -> Range<String.Index>? {
        let lines = text.components(separatedBy: "\n")
        var currentIndex = text.startIndex
        for line in lines {
            if isDateHeader(line) {
                let endIndex = text.index(currentIndex, offsetBy: line.count)
                return currentIndex..<endIndex
            }
            currentIndex = text.index(currentIndex, offsetBy: line.count)
            if currentIndex < text.endIndex {
                currentIndex = text.index(after: currentIndex) // skip newline
            }
        }
        return nil
    }
}
