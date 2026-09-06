import Foundation

struct SideButtonGestureTracker {
    struct HeldButton: Equatable {
        let physicalButton: Int
        let logicalButton: Int
        let clickAction: MouseAction
        var usedScrollGesture = false
    }

    private var heldButtons: [Int: HeldButton] = [:]
    private var pressOrder: [Int] = []

    var activeButton: HeldButton? {
        guard let physicalButton = pressOrder.last else { return nil }
        return heldButtons[physicalButton]
    }

    mutating func press(
        physicalButton: Int,
        logicalButton: Int,
        clickAction: MouseAction,
        hasScrollGesture: Bool
    ) -> Bool {
        guard hasScrollGesture, logicalButton == 3 || logicalButton == 4 else { return false }
        guard heldButtons[physicalButton] == nil else { return true }

        heldButtons[physicalButton] = HeldButton(
            physicalButton: physicalButton,
            logicalButton: logicalButton,
            clickAction: clickAction
        )
        pressOrder.append(physicalButton)
        return true
    }

    mutating func markActiveScrollGestureUsed() -> HeldButton? {
        guard
            let physicalButton = pressOrder.last,
            var heldButton = heldButtons[physicalButton]
        else { return nil }

        heldButton.usedScrollGesture = true
        heldButtons[physicalButton] = heldButton
        return heldButton
    }

    mutating func release(physicalButton: Int) -> HeldButton? {
        pressOrder.removeAll { $0 == physicalButton }
        return heldButtons.removeValue(forKey: physicalButton)
    }

    mutating func reset() {
        heldButtons.removeAll(keepingCapacity: true)
        pressOrder.removeAll(keepingCapacity: true)
    }
}
