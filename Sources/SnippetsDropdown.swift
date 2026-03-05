import AppKit

protocol SnippetsDropdownDelegate: AnyObject {
    func snippetsDropdown(_ dropdown: SnippetsDropdown, didSelectChipAt range: NSRange)
}

/// A button that shows all slash command entries in a dropdown menu.
/// Entries are listed in document order (newest first since dates are top-down).
class SnippetsDropdown: NSButton {

    weak var snippetsDelegate: SnippetsDropdownDelegate?

    private var menuItems: [(range: NSRange, commandName: String, text: String)] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        title = "/"
        bezelStyle = .texturedRounded
        font = NSFont(name: "Menlo-Bold", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        target = self
        action = #selector(showSnippetsMenu(_:))
        toolTip = "Snippets"
        isHidden = true
        setContentHuggingPriority(.required, for: .horizontal)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.cursorUpdate, .activeInActiveApp],
            owner: self
        ))
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.pointingHand.set()
    }

    // MARK: - Update

    func update(from textStorage: NSTextStorage) {
        menuItems = []

        let chips = SlashChipProtection.chipRanges(in: textStorage)
        let string = textStorage.string as NSString

        for chip in chips {
            let lineRange = string.lineRange(for: chip.range)
            let textStart = NSMaxRange(chip.range)
            let textEnd = NSMaxRange(lineRange)
            var bodyText = ""
            if textStart < textEnd {
                bodyText = string.substring(with: NSRange(location: textStart, length: textEnd - textStart))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if !bodyText.isEmpty {
                menuItems.append((range: chip.range, commandName: chip.commandName, text: bodyText))
            }
        }

        isHidden = menuItems.isEmpty
    }

    // MARK: - Menu

    @objc private func showSnippetsMenu(_ sender: NSButton) {
        let menu = NSMenu()

        var groups: [(command: SlashCommand, items: [(range: NSRange, text: String)])] = []
        for cmd in SlashCommand.all where cmd.generatesSnippet {
            let items = menuItems.filter { $0.commandName == cmd.name }
            if !items.isEmpty {
                groups.append((command: cmd, items: items.map { (range: $0.range, text: $0.text) }))
            }
        }

        for (groupIndex, group) in groups.enumerated() {
            if groupIndex > 0 {
                menu.addItem(NSMenuItem.separator())
            }

            // Section header
            let header = NSMenuItem(title: group.command.name.capitalized + "s", action: nil, keyEquivalent: "")
            header.isEnabled = false
            header.attributedTitle = NSAttributedString(
                string: group.command.name.capitalized + "s",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]
            )
            menu.addItem(header)

            for item in group.items {
                let menuItem = NSMenuItem(title: item.text, action: #selector(menuItemClicked(_:)), keyEquivalent: "")
                menuItem.target = self
                menuItem.representedObject = NSValue(range: item.range)

                let attrTitle = NSMutableAttributedString()
                attrTitle.append(NSAttributedString(
                    string: "/\(group.command.name) ",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                        .foregroundColor: group.command.color,
                    ]
                ))
                let displayText = item.text.count > 60 ? String(item.text.prefix(57)) + "…" : item.text
                attrTitle.append(NSAttributedString(
                    string: displayText,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 12),
                        .foregroundColor: NSColor.labelColor,
                    ]
                ))
                menuItem.attributedTitle = attrTitle
                menu.addItem(menuItem)
            }
        }

        if menu.items.isEmpty {
            let empty = NSMenuItem(title: "No snippets yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }

        // Size the menu to find its width, then right-align to button
        menu.update()
        let menuWidth = menu.size.width
        let x = bounds.maxX - menuWidth
        menu.popUp(positioning: nil, at: NSPoint(x: x, y: bounds.minY), in: self)
    }

    @objc private func menuItemClicked(_ sender: NSMenuItem) {
        guard let rangeValue = sender.representedObject as? NSValue else { return }
        snippetsDelegate?.snippetsDropdown(self, didSelectChipAt: rangeValue.rangeValue)
    }
}
