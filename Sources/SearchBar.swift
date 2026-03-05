import AppKit

protocol SearchBarDelegate: AnyObject {
    func searchBar(_ searchBar: SearchBar, searchFor text: String)
    func searchBarFindNext(_ searchBar: SearchBar)
    func searchBarFindPrevious(_ searchBar: SearchBar)
    func searchBarDidClose(_ searchBar: SearchBar)
}

class SearchBar: NSView, NSTextFieldDelegate {

    weak var delegate: SearchBarDelegate?

    private let searchField = NSTextField()
    private let previousButton = NSButton()
    private let nextButton = NSButton()
    private let closeButton = NSButton()
    private let matchCountLabel = NSTextField(labelWithString: "")

    var searchText: String {
        return searchField.stringValue
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // Bottom border
        let border = NSView()
        border.wantsLayer = true
        border.layer?.backgroundColor = NSColor.separatorColor.cgColor
        addSubview(border)
        border.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            border.leadingAnchor.constraint(equalTo: leadingAnchor),
            border.trailingAnchor.constraint(equalTo: trailingAnchor),
            border.bottomAnchor.constraint(equalTo: bottomAnchor),
            border.heightAnchor.constraint(equalToConstant: 1),
        ])

        // Search field
        searchField.placeholderString = "Search..."
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.focusRingType = .none
        searchField.font = NSFont.systemFont(ofSize: 13)
        (searchField.cell as? NSTextFieldCell)?.sendsActionOnEndEditing = false
        searchField.target = self
        searchField.action = #selector(searchFieldAction(_:))
        addSubview(searchField)

        // Match count label
        matchCountLabel.font = NSFont.systemFont(ofSize: 11)
        matchCountLabel.textColor = .secondaryLabelColor
        matchCountLabel.translatesAutoresizingMaskIntoConstraints = false
        matchCountLabel.setContentHuggingPriority(.required, for: .horizontal)
        addSubview(matchCountLabel)

        // Previous button
        previousButton.bezelStyle = .inline
        previousButton.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Previous")
        previousButton.imagePosition = .imageOnly
        previousButton.target = self
        previousButton.action = #selector(previousAction(_:))
        previousButton.translatesAutoresizingMaskIntoConstraints = false
        previousButton.setContentHuggingPriority(.required, for: .horizontal)
        addSubview(previousButton)

        // Next button
        nextButton.bezelStyle = .inline
        nextButton.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Next")
        nextButton.imagePosition = .imageOnly
        nextButton.target = self
        nextButton.action = #selector(nextAction(_:))
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.setContentHuggingPriority(.required, for: .horizontal)
        addSubview(nextButton)

        // Close button
        closeButton.bezelStyle = .inline
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeButton.imagePosition = .imageOnly
        closeButton.target = self
        closeButton.action = #selector(closeAction(_:))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setContentHuggingPriority(.required, for: .horizontal)
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 36),

            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            searchField.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),

            matchCountLabel.leadingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: 8),
            matchCountLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            previousButton.leadingAnchor.constraint(equalTo: matchCountLabel.trailingAnchor, constant: 4),
            previousButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            nextButton.leadingAnchor.constraint(equalTo: previousButton.trailingAnchor, constant: 2),
            nextButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            closeButton.leadingAnchor.constraint(greaterThanOrEqualTo: nextButton.trailingAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func focus() {
        window?.makeFirstResponder(searchField)
        searchField.selectText(nil)
    }

    func updateMatchCount(current: Int, total: Int) {
        if total == 0 {
            matchCountLabel.stringValue = searchField.stringValue.isEmpty ? "" : "No matches"
        } else {
            matchCountLabel.stringValue = "\(current) of \(total)"
        }
    }

    // MARK: - Actions

    @objc private func searchFieldAction(_ sender: Any?) {
        delegate?.searchBar(self, searchFor: searchField.stringValue)
    }

    @objc private func previousAction(_ sender: Any?) {
        delegate?.searchBarFindPrevious(self)
    }

    @objc private func nextAction(_ sender: Any?) {
        delegate?.searchBarFindNext(self)
    }

    @objc private func closeAction(_ sender: Any?) {
        delegate?.searchBarDidClose(self)
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        delegate?.searchBar(self, searchFor: searchField.stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            delegate?.searchBarDidClose(self)
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            delegate?.searchBarFindNext(self)
            return true
        }
        return false
    }
}
