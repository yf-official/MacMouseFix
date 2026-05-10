import ApplicationServices

enum Keyboard {
    static func press(_ keyCode: CGKeyCode, modifiers: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.flags = modifiers
        up?.flags = modifiers
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    static func commandLeftBracket() {
        press(33, modifiers: .maskCommand)
    }

    static func commandRightBracket() {
        press(30, modifiers: .maskCommand)
    }

    static func controlUp() {
        press(126, modifiers: .maskControl)
    }

    static func controlDown() {
        press(125, modifiers: .maskControl)
    }

    static func showDesktop() {
        press(103)
    }

    static func launchpad() {
        press(118)
    }

    static func moveSpaceLeft() {
        press(123, modifiers: .maskControl)
    }

    static func moveSpaceRight() {
        press(124, modifiers: .maskControl)
    }

    static func previousTab() {
        press(48, modifiers: [.maskControl, .maskShift])
    }

    static func nextTab() {
        press(48, modifiers: .maskControl)
    }

    static func newTab() {
        press(17, modifiers: .maskCommand)
    }

    static func closeTab() {
        press(13, modifiers: .maskCommand)
    }

    static func refresh() {
        press(15, modifiers: .maskCommand)
    }

    static func copy() {
        press(8, modifiers: .maskCommand)
    }

    static func paste() {
        press(9, modifiers: .maskCommand)
    }

    static func undo() {
        press(6, modifiers: .maskCommand)
    }

    static func redo() {
        press(6, modifiers: [.maskCommand, .maskShift])
    }

    static func zoomIn() {
        press(24, modifiers: .maskCommand)
    }

    static func zoomOut() {
        press(27, modifiers: .maskCommand)
    }

    static func pageUp() {
        press(116)
    }

    static func pageDown() {
        press(121)
    }

    static func escape() {
        press(53)
    }

    static func returnKey() {
        press(36)
    }

    static func screenshotArea() {
        press(23, modifiers: [.maskCommand, .maskShift])
    }

    static func lockScreen() {
        press(12, modifiers: [.maskCommand, .maskControl])
    }
}
