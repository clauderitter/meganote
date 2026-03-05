import AppKit

class NoteTextView: NSTextView {

    /// Callback when text changes
    var onTextChange: (() -> Void)?
    /// Callback when a deletion occurs (for empty section detection)
    var onDeletion: (() -> Void)?
    /// Callback when a slash command chip is created
    var onSlashCommand: (() -> Void)?
    /// Track if the last change was a deletion
    private var lastChangeWasDeletion = false

    // MARK: - Setup

    func setupDefaults() {
        allowsUndo = true
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticDataDetectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        usesFontPanel = false
        usesRuler = false

        // We manage rich text ourselves for date header styling
        isRichText = true
        isEditable = true
        isSelectable = true

        textContainerInset = NSSize(width: 16, height: 16)
    }

    // MARK: - Paste (strip formatting)

    override func paste(_ sender: Any?) {
        pasteAsPlainText(sender)
    }

    override func pasteAsPlainText(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        guard let text = pasteboard.string(forType: .string) else { return }

        // Check if inserting into a date header or chip
        if let storage = textStorage {
            let selectedRange = self.selectedRange()
            if DateHeaderProtection.overlapsDateHeader(range: selectedRange, in: storage) {
                NSSound.beep()
                return
            }
            if SlashChipProtection.shouldBlockEdit(range: selectedRange, replacementString: text, in: storage) {
                NSSound.beep()
                return
            }
        }

        insertPlainText(text)
    }

    // MARK: - Copy (ensure plain text, reconstruct slash prefixes)

    override func copy(_ sender: Any?) {
        let selectedRange = self.selectedRange()
        guard selectedRange.length > 0, let storage = textStorage else {
            super.copy(sender)
            return
        }

        // Build plain text, reconstructing /command prefixes from chips
        var result = ""
        let subAttr = storage.attributedSubstring(from: selectedRange)
        var pos = 0
        while pos < subAttr.length {
            var effectiveRange = NSRange()
            let chipName = subAttr.attribute(SlashChipProtection.isSlashChipKey, at: pos, effectiveRange: &effectiveRange) as? String
            if let name = chipName {
                result += "/\(name)"
            } else {
                result += subAttr.attributedSubstring(from: effectiveRange).string
            }
            pos = NSMaxRange(effectiveRange)
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(result, forType: .string)
    }

    override func cut(_ sender: Any?) {
        copy(sender)
        deleteBackward(sender)
    }

    // MARK: - Drag and Drop

    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        return [.string]
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        guard let text = pasteboard.string(forType: .string) else { return false }
        insertPlainText(text)
        return true
    }

    // MARK: - Enter Key (Slash Command Detection)

    override func insertNewline(_ sender: Any?) {
        guard let storage = textStorage else {
            super.insertNewline(sender)
            return
        }

        let cursorPos = selectedRange().location
        let nsString = storage.string as NSString
        let currentLineRange = nsString.lineRange(for: NSRange(location: cursorPos, length: 0))
        let lineText = nsString.substring(with: currentLineRange).trimmingCharacters(in: .newlines)

        // Check if the line starts with a slash command
        if let parsed = SlashCommand.parse(line: lineText) {
            if parsed.command.name == "help" {
                // Replace the /help line with help text
                handleHelpCommand(lineRange: currentLineRange)
                return
            }

            if parsed.text.trimmingCharacters(in: .whitespaces).isEmpty {
                // Empty command (e.g. "/bookmark" with no text) — beep, don't transform
                NSSound.beep()
                super.insertNewline(sender)
                return
            }

            // Transform the /command prefix into a styled chip
            transformLineToChip(command: parsed.command, lineRange: currentLineRange, lineText: lineText)
            return
        }

        super.insertNewline(sender)
    }

    /// Transform a line's /command prefix into a styled chip
    private func transformLineToChip(command: SlashCommand, lineRange: NSRange, lineText: String) {
        guard let storage = textStorage else { return }

        let prefix = "/\(command.name) "
        guard lineText.hasPrefix(prefix) else { return }

        let bodyText = String(lineText.dropFirst(prefix.count))
        let bodyFont = NSFont(name: "Menlo", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: NSColor.textColor,
        ]

        // Build the replacement: chip + space + body text + newline
        let replacement = NSMutableAttributedString()
        replacement.append(SlashChipProtection.styledChip(for: command))
        replacement.append(NSAttributedString(string: " " + bodyText, attributes: bodyAttrs))
        replacement.append(NSAttributedString(string: "\n", attributes: bodyAttrs))

        // Replace the line content (excluding the trailing newline if it exists)
        let replaceRange: NSRange
        if NSMaxRange(lineRange) <= storage.length && lineRange.length > 0 {
            let lastChar = nsStringChar(in: storage.string, at: NSMaxRange(lineRange) - 1)
            if lastChar == "\n" {
                replaceRange = NSRange(location: lineRange.location, length: lineRange.length - 1)
            } else {
                replaceRange = lineRange
            }
        } else {
            replaceRange = lineRange
        }

        storage.beginEditing()
        storage.replaceCharacters(in: replaceRange, with: replacement)
        storage.endEditing()

        // Place cursor after the new line
        let newCursorPos = replaceRange.location + replacement.length
        setSelectedRange(NSRange(location: newCursorPos, length: 0))

        didChangeText()
        onSlashCommand?()
    }

    private func nsStringChar(in string: String, at index: Int) -> Character? {
        let nsString = string as NSString
        guard index >= 0 && index < nsString.length else { return nil }
        let scalar = nsString.character(at: index)
        return Character(UnicodeScalar(scalar)!)
    }

    /// Handle /help command: replace the line with help text
    private func handleHelpCommand(lineRange: NSRange) {
        guard let storage = textStorage else { return }

        let helpText = SlashCommand.helpText()
        let bodyFont = NSFont(name: "Menlo", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: NSColor.secondaryLabelColor,
        ]

        let replacement = NSMutableAttributedString(string: helpText + "\n", attributes: bodyAttrs)

        // Replace the /help line (excluding trailing newline)
        let replaceRange: NSRange
        if lineRange.length > 0 {
            let lastChar = nsStringChar(in: storage.string, at: NSMaxRange(lineRange) - 1)
            if lastChar == "\n" {
                replaceRange = NSRange(location: lineRange.location, length: lineRange.length - 1)
            } else {
                replaceRange = lineRange
            }
        } else {
            replaceRange = lineRange
        }

        storage.beginEditing()
        storage.replaceCharacters(in: replaceRange, with: replacement)
        storage.endEditing()

        let newCursorPos = replaceRange.location + replacement.length
        setSelectedRange(NSRange(location: newCursorPos, length: 0))

        didChangeText()
    }

    // MARK: - Text Input Protection

    override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?) -> Bool {
        guard let storage = textStorage else {
            return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
        }

        // Track if this is a deletion (replacement is empty or shorter than selection)
        if let replacement = replacementString {
            lastChangeWasDeletion = replacement.isEmpty && affectedCharRange.length > 0
        }

        // Check if change overlaps a date header
        if DateHeaderProtection.overlapsDateHeader(range: affectedCharRange, in: storage) {
            NSSound.beep()
            return false
        }

        // Check if change overlaps a slash chip
        if SlashChipProtection.shouldBlockEdit(range: affectedCharRange, replacementString: replacementString, in: storage) {
            NSSound.beep()
            return false
        }

        // Prevent typing attribute inheritance from date headers or chips
        if affectedCharRange.length == 0, let replacement = replacementString, !replacement.isEmpty {
            let bodyFont = NSFont(name: "Menlo", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            self.typingAttributes = [
                .font: bodyFont,
                .foregroundColor: NSColor.textColor,
            ]
        }

        return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
    }

    override func didChangeText() {
        super.didChangeText()
        applyBodyStylingToRecentChange()
        onTextChange?()
        if lastChangeWasDeletion {
            lastChangeWasDeletion = false
            onDeletion?()
        }
    }

    // MARK: - URL Detection

    private var urlDetectionTimer: Timer?

    func scheduleURLDetection() {
        urlDetectionTimer?.invalidate()
        urlDetectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.detectURLs()
        }
    }

    func detectURLs() {
        guard let storage = textStorage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        let text = storage.string

        // Remove existing links (but not from date headers)
        storage.beginEditing()
        storage.enumerateAttribute(.link, in: fullRange, options: []) { value, range, _ in
            if value != nil {
                let isHeader = storage.attribute(DateHeaderProtection.isDateHeaderKey, at: range.location, effectiveRange: nil) as? Bool ?? false
                if !isHeader {
                    storage.removeAttribute(.link, range: range)
                }
            }
        }

        // Detect URLs (not emails)
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let matches = detector.matches(in: text, options: [], range: fullRange)
            for match in matches {
                guard let url = match.url else { continue }
                // Skip email links (mailto:)
                if url.scheme == "mailto" { continue }
                // Skip if inside a date header
                let isHeader = storage.attribute(DateHeaderProtection.isDateHeaderKey, at: match.range.location, effectiveRange: nil) as? Bool ?? false
                if isHeader { continue }
                storage.addAttribute(.link, value: url, range: match.range)
            }
        }
        storage.endEditing()
    }

    // MARK: - Styling

    /// Apply body font to recently changed text (not date headers or slash chips).
    /// Also strips spurious header attributes from text that isn't a valid date.
    private func applyBodyStylingToRecentChange() {
        guard let storage = textStorage else { return }
        let bodyFont = NSFont(name: "Menlo", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        let selectedRange = self.selectedRange()
        let lineRange = (storage.string as NSString).lineRange(for: selectedRange)
        guard lineRange.length > 0 else { return }

        let nsString = storage.string as NSString
        var scanLocation = lineRange.location

        while scanLocation < NSMaxRange(lineRange) {
            let currentLineRange = nsString.lineRange(for: NSRange(location: scanLocation, length: 0))
            let lineText = nsString.substring(with: currentLineRange)
            let trimmed = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
            let isValidDate = !trimmed.isEmpty && DateManager.parseDate(trimmed) != nil

            let hasHeaderAttr: Bool
            let hasChipAttr: Bool
            if currentLineRange.length > 0 {
                hasHeaderAttr = storage.attribute(DateHeaderProtection.isDateHeaderKey, at: currentLineRange.location, effectiveRange: nil) as? Bool ?? false
                hasChipAttr = storage.attribute(SlashChipProtection.isSlashChipKey, at: currentLineRange.location, effectiveRange: nil) as? String != nil
            } else {
                hasHeaderAttr = false
                hasChipAttr = false
            }

            // Skip lines with chip attributes — their styling is managed by the chip
            if hasChipAttr {
                let nextLocation = NSMaxRange(currentLineRange)
                if nextLocation <= scanLocation { break }
                scanLocation = nextLocation
                continue
            }

            if hasHeaderAttr && !isValidDate {
                // Spurious header attribute on non-date text — strip it
                storage.removeAttribute(DateHeaderProtection.isDateHeaderKey, range: currentLineRange)
                storage.addAttribute(.font, value: bodyFont, range: currentLineRange)
                storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: currentLineRange)
            } else if !hasHeaderAttr {
                // Apply body styling to non-chip portion only
                // Find chip range on this line (if any) and skip it
                let chips = SlashChipProtection.chipRanges(in: storage)
                var bodyStart = currentLineRange.location
                for chip in chips {
                    if chip.range.location >= currentLineRange.location && chip.range.location < NSMaxRange(currentLineRange) {
                        // There's a chip on this line — only style the text after the chip
                        bodyStart = NSMaxRange(chip.range)
                        break
                    }
                }
                if bodyStart < NSMaxRange(currentLineRange) {
                    let bodyRange = NSRange(location: bodyStart, length: NSMaxRange(currentLineRange) - bodyStart)
                    if bodyRange.length > 0 {
                        storage.addAttribute(.font, value: bodyFont, range: bodyRange)
                        storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: bodyRange)
                    }
                }
            }

            let nextLocation = NSMaxRange(currentLineRange)
            if nextLocation <= scanLocation { break }
            scanLocation = nextLocation
        }
    }

    // MARK: - Helpers

    func insertPlainText(_ text: String) {
        let bodyFont = NSFont(name: "Menlo", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: NSColor.textColor,
        ]
        let attrText = NSAttributedString(string: text, attributes: attrs)

        let selectedRange = self.selectedRange()
        if shouldChangeText(in: selectedRange, replacementString: text) {
            textStorage?.replaceCharacters(in: selectedRange, with: attrText)
            didChangeText()
            let newLocation = selectedRange.location + text.count
            setSelectedRange(NSRange(location: newLocation, length: 0))
        }
    }

    // MARK: - Context Menu

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()

        // Search With Google (uses default browser)
        let searchItem = NSMenuItem(title: "Search With Google", action: #selector(searchWithGoogle(_:)), keyEquivalent: "")
        searchItem.target = self
        if selectedRange().length == 0 { searchItem.isEnabled = false }
        menu.addItem(searchItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Cut", action: #selector(cut(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Copy", action: #selector(copy(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Paste", action: #selector(paste(_:)), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Select All", action: #selector(selectAll(_:)), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        // Spelling and Grammar
        let spellingItem = NSMenuItem(title: "Spelling and Grammar", action: nil, keyEquivalent: "")
        let spellingSubmenu = NSMenu()
        spellingSubmenu.addItem(NSMenuItem(title: "Show Spelling and Grammar", action: #selector(showGuessPanel(_:)), keyEquivalent: ""))
        spellingSubmenu.addItem(NSMenuItem(title: "Check Document Now", action: #selector(checkSpelling(_:)), keyEquivalent: ""))
        spellingItem.submenu = spellingSubmenu
        menu.addItem(spellingItem)

        // Transformations
        let transformItem = NSMenuItem(title: "Transformations", action: nil, keyEquivalent: "")
        let transformSubmenu = NSMenu()
        transformSubmenu.addItem(NSMenuItem(title: "Make Upper Case", action: #selector(uppercaseWord(_:)), keyEquivalent: ""))
        transformSubmenu.addItem(NSMenuItem(title: "Make Lower Case", action: #selector(lowercaseWord(_:)), keyEquivalent: ""))
        transformSubmenu.addItem(NSMenuItem(title: "Capitalize", action: #selector(capitalizeWord(_:)), keyEquivalent: ""))
        transformItem.submenu = transformSubmenu
        menu.addItem(transformItem)

        return menu
    }

    @objc private func searchWithGoogle(_ sender: Any?) {
        let range = selectedRange()
        guard range.length > 0, let storage = textStorage else { return }
        let text = (storage.string as NSString).substring(with: range)
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.google.com/search?q=\(encoded)") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Keyboard handling

    override func keyDown(with event: NSEvent) {
        // Escape closes search
        if event.keyCode == 53 { // Escape
            if let vc = self.window?.contentViewController as? NoteViewController {
                vc.hideSearch()
            }
            return
        }
        super.keyDown(with: event)
    }
}
