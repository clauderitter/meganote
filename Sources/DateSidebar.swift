import AppKit

protocol DateSidebarDelegate: AnyObject {
    func dateSidebar(_ sidebar: DateSidebar, didSelectDate dateText: String, headerRange: NSRange)
}

// MARK: - Hover-aware row view

class HoverableRowView: NSTableRowView {

    private var trackingArea: NSTrackingArea?

    var isHovered = false {
        didSet {
            if isHovered != oldValue {
                needsDisplay = true
            }
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHovered && !isSelected {
            NSColor.labelColor.withAlphaComponent(0.06).setFill()
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 1), xRadius: 4, yRadius: 4)
            path.fill()
        }
        super.draw(dirtyRect)
    }

    override var interiorBackgroundStyle: NSView.BackgroundStyle {
        return .normal
    }
}

// MARK: - DateSidebar

class DateSidebar: NSView, NSTableViewDataSource, NSTableViewDelegate {

    weak var delegate: DateSidebarDelegate?

    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let leftPadding: CGFloat = 16

    private var entries: [(text: String, range: NSRange)] = []

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

        // Right border
        let border = NSView()
        border.wantsLayer = true
        border.layer?.backgroundColor = NSColor.separatorColor.cgColor
        addSubview(border)
        border.translatesAutoresizingMaskIntoConstraints = false

        // Table view
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("DateColumn"))
        column.title = ""
        column.isEditable = false
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 28
        tableView.dataSource = self
        tableView.delegate = self
        tableView.selectionHighlightStyle = .none
        tableView.style = .plain
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.backgroundColor = .clear
        tableView.target = self
        tableView.action = #selector(tableClicked(_:))

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        // Title label
        let titleLabel = NSTextField(labelWithString: "Dates")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leftPadding),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            border.topAnchor.constraint(equalTo: topAnchor),
            border.bottomAnchor.constraint(equalTo: bottomAnchor),
            border.trailingAnchor.constraint(equalTo: trailingAnchor),
            border.widthAnchor.constraint(equalToConstant: 1),
        ])
    }

    // MARK: - Update

    func update(from textStorage: NSTextStorage) {
        entries = []

        let headerRanges = DateHeaderProtection.dateHeaderRanges(in: textStorage)
        let string = textStorage.string

        for range in headerRanges {
            let text = (string as NSString).substring(with: range)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                entries.append((text: text, range: range))
            }
        }

        tableView.reloadData()

        if let column = tableView.tableColumns.first {
            column.width = tableView.bounds.width
        }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return entries.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let entry = entries[row]
        let identifier = NSUserInterfaceItemIdentifier("DateCell")
        var wrapper = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSView
        var label: NSTextField?

        if wrapper == nil {
            wrapper = NSView()
            wrapper?.identifier = identifier

            let tf = NSTextField(labelWithString: "")
            tf.lineBreakMode = .byTruncatingTail
            tf.translatesAutoresizingMaskIntoConstraints = false
            wrapper?.addSubview(tf)

            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: wrapper!.leadingAnchor, constant: leftPadding),
                tf.trailingAnchor.constraint(equalTo: wrapper!.trailingAnchor, constant: -8),
                tf.centerYAnchor.constraint(equalTo: wrapper!.centerYAnchor),
            ])

            label = tf
        } else {
            label = wrapper?.subviews.first as? NSTextField
        }

        label?.stringValue = entry.text
        label?.font = NSFont.systemFont(ofSize: 14)
        label?.textColor = .labelColor

        return wrapper!
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return HoverableRowView()
    }

    // MARK: - Click

    @objc private func tableClicked(_ sender: Any?) {
        let row = tableView.clickedRow
        guard row >= 0 && row < entries.count else { return }
        let entry = entries[row]
        delegate?.dateSidebar(self, didSelectDate: entry.text, headerRange: entry.range)
        tableView.deselectRow(row)
    }
}
