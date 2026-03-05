import AppKit

class NoteViewController: NSViewController, NSTextViewDelegate, SearchBarDelegate, DateSidebarDelegate, SnippetsDropdownDelegate, NSSplitViewDelegate {

    private var splitView: NSSplitView!
    private var sidebarContainer: NSView!
    private var contentContainer: NSView!
    private var dateSidebar: DateSidebar!
    private var scrollView: NSScrollView!
    private var textView: NoteTextView!
    private var searchBar: SearchBar!
    private var snippetsDropdown: SnippetsDropdown!

    private var autoSaveTimer: Timer?
    private var dateCheckTimer: Timer?
    private var sidebarUpdateTimer: Timer?
    private var searchMatches: [NSRange] = []
    private var currentMatchIndex: Int = -1
    private var isSearchVisible = false
    private var isDirty = false
    private var isShowingEmptySectionAlert = false

    private let sidebarWidth: CGFloat = 160

    // MARK: - View Lifecycle

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 860, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSplitView()
        setupSidebar()
        setupSearchBar()
        setupSnippetsDropdown()
        setupTextView()
        loadDocument()
        startDateCheckTimer()

        textView.onTextChange = { [weak self] in
            self?.isDirty = true
            self?.scheduleSave()
            self?.textView.scheduleURLDetection()
            self?.scheduleSidebarUpdate()
        }

        textView.onDeletion = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.checkForEmptySections()
            }
        }

        textView.onSlashCommand = { [weak self] in
            self?.isDirty = true
            self?.scheduleSave()
            self?.scheduleSidebarUpdate()
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        checkDateIfNeeded()
        updateSidebar()
    }

    deinit {
        autoSaveTimer?.invalidate()
        dateCheckTimer?.invalidate()
        sidebarUpdateTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupSplitView() {
        splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        splitView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: view.topAnchor),
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Sidebar container (left)
        sidebarContainer = NSView()
        sidebarContainer.translatesAutoresizingMaskIntoConstraints = false
        splitView.addSubview(sidebarContainer)

        // Content container (right)
        contentContainer = NSView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        splitView.addSubview(contentContainer)
    }

    private func setupSidebar() {
        dateSidebar = DateSidebar()
        dateSidebar.delegate = self
        dateSidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.addSubview(dateSidebar)

        NSLayoutConstraint.activate([
            dateSidebar.topAnchor.constraint(equalTo: sidebarContainer.topAnchor),
            dateSidebar.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor),
            dateSidebar.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            dateSidebar.bottomAnchor.constraint(equalTo: sidebarContainer.bottomAnchor),
        ])
    }

    private func setupSearchBar() {
        searchBar = SearchBar()
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.isHidden = true
        contentContainer.addSubview(searchBar)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
        ])
    }

    private func setupSnippetsDropdown() {
        snippetsDropdown = SnippetsDropdown()
        snippetsDropdown.snippetsDelegate = self
        snippetsDropdown.translatesAutoresizingMaskIntoConstraints = false
        // Added later so it floats above the scroll view
    }

    private func setupTextView() {
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        contentContainer.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])

        let contentSize = scrollView.contentSize
        let textContainer = NSTextContainer(size: NSSize(
            width: contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        ))
        textContainer.widthTracksTextView = true

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)

        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        textView = NoteTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.setupDefaults()
        textView.delegate = self
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: contentSize.height)

        scrollView.documentView = textView

        // Add snippets dropdown floating above the scroll view
        contentContainer.addSubview(snippetsDropdown)
        NSLayoutConstraint.activate([
            snippetsDropdown.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 4),
            snippetsDropdown.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -8),
            snippetsDropdown.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    // MARK: - NSSplitViewDelegate

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return 120 // Minimum sidebar width
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return 250 // Maximum sidebar width
    }

    func splitView(_ splitView: NSSplitView, constrainSplitPosition proposedPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return proposedPosition
    }

    func splitView(_ splitView: NSSplitView, shouldAdjustSizeOfSubview view: NSView) -> Bool {
        // When resizing, keep sidebar fixed and adjust content
        return view == contentContainer
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        // Set initial sidebar width if not yet positioned
        if sidebarContainer.frame.width < 10 {
            splitView.setPosition(sidebarWidth, ofDividerAt: 0)
        }
    }

    // MARK: - Sidebar

    private func scheduleSidebarUpdate() {
        sidebarUpdateTimer?.invalidate()
        sidebarUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.updateSidebar()
        }
    }

    private func updateSidebar() {
        guard let storage = textView.textStorage else { return }
        dateSidebar.update(from: storage)
        snippetsDropdown.update(from: storage)
    }

    // MARK: - DateSidebarDelegate

    func dateSidebar(_ sidebar: DateSidebar, didSelectDate dateText: String, headerRange: NSRange) {
        guard let storage = textView.textStorage else { return }

        // Re-find the header range (may have shifted since sidebar was built)
        let headerRanges = DateHeaderProtection.dateHeaderRanges(in: storage)
        var targetRange: NSRange?
        for range in headerRanges {
            let text = (storage.string as NSString).substring(with: range)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if text == dateText {
                targetRange = range
                break
            }
        }

        guard let range = targetRange else { return }

        // Scroll to the header
        textView.scrollRangeToVisible(range)

        // Place cursor right after the header
        let afterHeader = NSMaxRange(range)
        if afterHeader <= storage.length {
            textView.setSelectedRange(NSRange(location: afterHeader, length: 0))
        }

        // Flash the header with a subtle pulse
        flashHeaderRange(range)
    }

    // MARK: - SnippetsDropdownDelegate

    func snippetsDropdown(_ dropdown: SnippetsDropdown, didSelectChipAt range: NSRange) {
        guard let storage = textView.textStorage else { return }

        // Re-find the chip (range may have shifted)
        let chips = SlashChipProtection.chipRanges(in: storage)
        var targetChip: NSRange?
        for chip in chips {
            if chip.range.location == range.location {
                targetChip = chip.range
                break
            }
        }

        // Fall back to finding nearest chip
        if targetChip == nil {
            for chip in chips {
                let nsString = storage.string as NSString
                let lineRange = nsString.lineRange(for: chip.range)
                if lineRange.location == range.location || chip.range.location == range.location {
                    targetChip = chip.range
                    break
                }
            }
        }

        guard let chipRange = targetChip else { return }

        let nsString = storage.string as NSString
        let lineRange = nsString.lineRange(for: chipRange)

        textView.scrollRangeToVisible(lineRange)

        let afterChip = NSMaxRange(chipRange)
        if afterChip <= storage.length {
            textView.setSelectedRange(NSRange(location: afterChip, length: 0))
        }

        flashHeaderRange(lineRange)
        view.window?.makeFirstResponder(textView)
    }

    // MARK: - Flash Animation

    private func flashHeaderRange(_ range: NSRange) {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // Get the glyph range and bounding rect for the header
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        // Adjust for text container inset and extend to full width
        rect.origin.x = 0
        rect.origin.y += textView.textContainerInset.height
        rect.size.width = textView.bounds.width
        rect.size.height += 4 // Small padding

        // Create a flash overlay
        let flashView = NSView(frame: rect)
        flashView.wantsLayer = true
        flashView.layer?.backgroundColor = NSColor.selectedTextBackgroundColor.withAlphaComponent(0.3).cgColor
        flashView.layer?.cornerRadius = 4
        flashView.alphaValue = 0
        textView.addSubview(flashView)

        // Animate: fade in, hold, fade out
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            flashView.animator().alphaValue = 1.0
        }, completionHandler: {
            // Hold briefly, then fade out
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.5
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    flashView.animator().alphaValue = 0
                }, completionHandler: {
                    flashView.removeFromSuperview()
                })
            }
        })
    }

    // MARK: - Document

    private func loadDocument() {
        let content = FileHandler.shared.load()
        textView.textStorage?.setAttributedString(content)
        ensureStagingArea()
        textView.detectURLs()
        isDirty = false
    }

    /// Ensure there's an empty line above the first date header so the user can type in the staging area
    private func ensureStagingArea() {
        guard let storage = textView.textStorage else { return }
        guard storage.length > 0 else { return }

        let isHeaderAtStart = storage.attribute(DateHeaderProtection.isDateHeaderKey, at: 0, effectiveRange: nil) as? Bool ?? false
        if isHeaderAtStart {
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont(name: "Menlo", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor.textColor,
            ]
            storage.insert(NSAttributedString(string: "\n", attributes: bodyAttrs), at: 0)
        }
    }

    func saveImmediately() {
        guard isDirty, let storage = textView.textStorage else { return }
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
        FileHandler.shared.save(attributedString: storage)
        isDirty = false
    }

    private func scheduleSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.saveImmediately()
        }
    }

    // MARK: - Date Management

    private func startDateCheckTimer() {
        dateCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkDateIfNeeded()
        }
    }

    func checkDateIfNeeded() {
        guard let storage = textView.textStorage else { return }

        // Update window title
        view.window?.title = DateManager.todayWindowTitle()

        // Check if today's header already exists
        let markdown = FileHandler.shared.attributedStringToMarkdown(storage)
        if DateManager.todayHeaderExists(in: markdown) {
            return
        }

        let headerRanges = DateHeaderProtection.dateHeaderRanges(in: storage)
        let text = storage.string

        if headerRanges.isEmpty {
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                insertTodayHeader()
            }
            return
        }

        let firstHeaderLoc = headerRanges[0].location
        if firstHeaderLoc > 0 {
            let beforeHeader = (text as NSString).substring(with: NSRange(location: 0, length: firstHeaderLoc))
            if !beforeHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                insertTodayHeader()
            }
        }
    }

    private func insertTodayHeader() {
        guard let storage = textView.textStorage else { return }

        let headerText = DateManager.formatDate(Date())
        let headerFont = NSFont(name: "Menlo-Bold", size: 18) ?? NSFont.monospacedSystemFont(ofSize: 18, weight: .bold)
        let headerParagraph = NSMutableParagraphStyle()
        headerParagraph.paragraphSpacingBefore = 12
        headerParagraph.paragraphSpacing = 4

        let attrs: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: headerParagraph,
            DateHeaderProtection.isDateHeaderKey: true,
        ]

        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Menlo", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.textColor,
        ]

        let headerAttrStr = NSMutableAttributedString()
        headerAttrStr.append(NSAttributedString(string: "\n", attributes: bodyAttrs)) // staging area
        headerAttrStr.append(NSAttributedString(string: headerText, attributes: attrs))
        headerAttrStr.append(NSAttributedString(string: "\n\n", attributes: bodyAttrs))

        if storage.length > 0 {
            storage.insert(headerAttrStr, at: 0)
        } else {
            storage.setAttributedString(headerAttrStr)
        }

        // Place cursor in the staging area (position 0, before the header)
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        isDirty = true
        scheduleSave()
        updateSidebar()
    }

    // MARK: - NSTextViewDelegate

    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        guard let storage = textView.textStorage else { return true }

        if affectedCharRange.location == 0 && replacementString != nil && !(replacementString?.isEmpty ?? true) {
            let markdown = FileHandler.shared.attributedStringToMarkdown(storage)
            if !DateManager.todayHeaderExists(in: markdown) {
                insertTodayHeader()
                return false
            }
        }

        return true
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        if let url = link as? URL {
            NSWorkspace.shared.open(url)
            return true
        }
        return false
    }

    // MARK: - Empty Section Detection

    private func checkForEmptySections() {
        guard !isShowingEmptySectionAlert else { return }
        guard let storage = textView.textStorage else { return }
        let emptySections = DateHeaderProtection.emptyDateSections(in: storage)
        guard !emptySections.isEmpty else { return }

        let todayStr = DateManager.formatDate(Date())
        let nonTodaySections = emptySections.filter { !$0.headerText.contains(todayStr) }
        guard !nonTodaySections.isEmpty else { return }

        isShowingEmptySectionAlert = true

        let dateNames = nonTodaySections.map { $0.headerText.trimmingCharacters(in: .whitespacesAndNewlines) }
        let message: String
        if dateNames.count == 1 {
            message = "The section for \(dateNames[0]) is empty. Remove it?"
        } else {
            message = "Remove \(dateNames.count) empty date sections?\n\(dateNames.joined(separator: "\n"))"
        }

        let alert = NSAlert()
        alert.messageText = "Empty Date Section"
        alert.informativeText = message
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Keep")
        alert.alertStyle = .informational

        guard let window = view.window else {
            isShowingEmptySectionAlert = false
            return
        }

        alert.beginSheetModal(for: window) { [weak self] response in
            self?.isShowingEmptySectionAlert = false
            if response == .alertFirstButtonReturn {
                self?.removeEmptySections(nonTodaySections)
            }
        }
    }

    private func removeEmptySections(_ sections: [(header: NSRange, headerText: String)]) {
        guard let storage = textView.textStorage else { return }

        let currentEmpty = DateHeaderProtection.emptyDateSections(in: storage)
        let toRemove = currentEmpty.filter { empty in
            sections.contains { $0.headerText == empty.headerText }
        }

        let sortedSections = toRemove.sorted { $0.header.location > $1.header.location }
        storage.beginEditing()
        for section in sortedSections {
            let headerRanges = DateHeaderProtection.dateHeaderRanges(in: storage)
            guard let headerIndex = headerRanges.firstIndex(where: { $0.location == section.header.location }) else { continue }

            let removeStart = section.header.location
            let removeEnd: Int
            if headerIndex + 1 < headerRanges.count {
                removeEnd = headerRanges[headerIndex + 1].location
            } else {
                removeEnd = storage.length
            }

            var adjustedStart = removeStart
            if adjustedStart > 0 {
                let prevChar = (storage.string as NSString).substring(with: NSRange(location: adjustedStart - 1, length: 1))
                if prevChar == "\n" {
                    adjustedStart -= 1
                }
            }

            let removeRange = NSRange(location: adjustedStart, length: removeEnd - adjustedStart)
            if removeRange.location + removeRange.length <= storage.length {
                storage.replaceCharacters(in: removeRange, with: "")
            }
        }
        storage.endEditing()

        isDirty = true
        scheduleSave()
        updateSidebar()
    }

    // MARK: - Search

    @objc func showSearch(_ sender: Any?) {
        searchBar.isHidden = false
        isSearchVisible = true
        searchBar.focus()
    }

    @objc func findNext(_ sender: Any?) {
        if !isSearchVisible {
            showSearch(sender)
            return
        }
        navigateMatch(forward: true)
    }

    @objc func findPrevious(_ sender: Any?) {
        if !isSearchVisible {
            showSearch(sender)
            return
        }
        navigateMatch(forward: false)
    }

    func hideSearch() {
        searchBar.isHidden = true
        isSearchVisible = false
        clearSearchHighlights()
        view.window?.makeFirstResponder(textView)
    }

    private func performSearch(_ query: String) {
        clearSearchHighlights()

        guard !query.isEmpty, let storage = textView.textStorage else {
            searchBar.updateMatchCount(current: 0, total: 0)
            return
        }

        let text = storage.string as NSString
        var searchRange = NSRange(location: 0, length: text.length)

        storage.beginEditing()
        while searchRange.location < text.length {
            let foundRange = text.range(of: query, options: .caseInsensitive, range: searchRange)
            if foundRange.location == NSNotFound { break }

            searchMatches.append(foundRange)
            storage.addAttribute(.backgroundColor, value: NSColor.yellow, range: foundRange)

            searchRange.location = NSMaxRange(foundRange)
            searchRange.length = text.length - searchRange.location
        }
        storage.endEditing()

        if !searchMatches.isEmpty {
            currentMatchIndex = 0
            highlightCurrentMatch()
        }

        searchBar.updateMatchCount(current: searchMatches.isEmpty ? 0 : 1, total: searchMatches.count)
    }

    private func navigateMatch(forward: Bool) {
        guard !searchMatches.isEmpty else { return }

        if currentMatchIndex >= 0 && currentMatchIndex < searchMatches.count {
            textView.textStorage?.addAttribute(.backgroundColor, value: NSColor.yellow, range: searchMatches[currentMatchIndex])
        }

        if forward {
            currentMatchIndex = (currentMatchIndex + 1) % searchMatches.count
        } else {
            currentMatchIndex = currentMatchIndex - 1
            if currentMatchIndex < 0 { currentMatchIndex = searchMatches.count - 1 }
        }

        highlightCurrentMatch()
        searchBar.updateMatchCount(current: currentMatchIndex + 1, total: searchMatches.count)
    }

    private func highlightCurrentMatch() {
        guard currentMatchIndex >= 0 && currentMatchIndex < searchMatches.count else { return }
        let range = searchMatches[currentMatchIndex]

        textView.textStorage?.addAttribute(.backgroundColor, value: NSColor.orange, range: range)
        textView.scrollRangeToVisible(range)
        textView.showFindIndicator(for: range)
    }

    private func clearSearchHighlights() {
        guard let storage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.removeAttribute(.backgroundColor, range: fullRange)
        searchMatches = []
        currentMatchIndex = -1

        // Restore chip background colors (search highlight removal strips them)
        let chips = SlashChipProtection.chipRanges(in: storage)
        for chip in chips {
            if let cmd = SlashCommand.find(chip.commandName) {
                storage.addAttribute(.backgroundColor, value: cmd.color.withAlphaComponent(0.12), range: chip.range)
            }
        }
    }

    // MARK: - SearchBarDelegate

    func searchBar(_ searchBar: SearchBar, searchFor text: String) {
        performSearch(text)
    }

    func searchBarFindNext(_ searchBar: SearchBar) {
        navigateMatch(forward: true)
    }

    func searchBarFindPrevious(_ searchBar: SearchBar) {
        navigateMatch(forward: false)
    }

    func searchBarDidClose(_ searchBar: SearchBar) {
        hideSearch()
    }
}
