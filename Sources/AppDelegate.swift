import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    var window: NSWindow!
    var noteViewController: NoteViewController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            window.makeKeyAndOrderFront(nil)
        }
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        noteViewController?.checkDateIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        noteViewController?.saveImmediately()
    }

    // MARK: - Window Setup

    private func setupWindow() {
        let frame = NSRect(x: 0, y: 0, width: 860, height: 600)
        window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.minSize = NSSize(width: 500, height: 300)
        window.title = DateManager.todayWindowTitle()
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("MeganoteMainWindow")

        noteViewController = NoteViewController()
        window.contentViewController = noteViewController
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Window Delegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        window.orderOut(nil)
        return false
    }

    // MARK: - Menu

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Meganote", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide Meganote", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthersItem = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Meganote", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Find menu
        let findMenuItem = NSMenuItem()
        let findMenu = NSMenu(title: "Find")
        let findItem = NSMenuItem(title: "Find...", action: #selector(NoteViewController.showSearch(_:)), keyEquivalent: "f")
        findMenu.addItem(findItem)
        let findNextItem = NSMenuItem(title: "Find Next", action: #selector(NoteViewController.findNext(_:)), keyEquivalent: "g")
        findMenu.addItem(findNextItem)
        let findPrevItem = NSMenuItem(title: "Find Previous", action: #selector(NoteViewController.findPrevious(_:)), keyEquivalent: "G")
        findMenu.addItem(findPrevItem)
        findMenuItem.submenu = findMenu
        mainMenu.addItem(findMenuItem)

        NSApp.mainMenu = mainMenu
    }
}
