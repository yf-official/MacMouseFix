import ApplicationServices

final class MagnificationGestureSimulator {
    enum Phase: Int64, Equatable {
        case began = 0x01
        case changed = 0x02
        case ended = 0x04
    }

    struct Sample: Equatable {
        let magnification: Double
        let phase: Phase
    }

    typealias EventPoster = (Sample) -> Void

    private let postEvent: EventPoster
    private(set) var activeButton: Int?

    init(postEvent: @escaping EventPoster = MagnificationGestureSimulator.postSystemEvent) {
        self.postEvent = postEvent
    }

    @discardableResult
    func update(action: MouseAction, wheelDelta: Double, button: Int) -> Bool {
        guard action == .zoomIn || action == .zoomOut else { return false }

        if activeButton != button {
            end()
            activeButton = button
            postEvent(Sample(magnification: 0, phase: .began))
            // The initial zero change avoids a delayed first magnification in some apps.
            postEvent(Sample(magnification: 0, phase: .changed))
        }

        let magnitude = min(0.16, max(0.035, abs(wheelDelta) * 0.055))
        let signedMagnitude = action == .zoomIn ? magnitude : -magnitude
        postEvent(Sample(magnification: signedMagnitude, phase: .changed))
        return true
    }

    func pulse(action: MouseAction) {
        guard action == .zoomIn || action == .zoomOut else { return }
        end()
        postEvent(Sample(magnification: 0, phase: .began))
        postEvent(Sample(magnification: 0, phase: .changed))
        postEvent(Sample(magnification: action == .zoomIn ? 0.08 : -0.08, phase: .changed))
        postEvent(Sample(magnification: 0, phase: .ended))
    }

    func end(for button: Int? = nil) {
        guard let activeButton else { return }
        if let button, button != activeButton { return }
        postEvent(Sample(magnification: 0, phase: .ended))
        self.activeButton = nil
    }

    private static func postSystemEvent(_ sample: Sample) {
        guard
            let event = CGEvent(source: nil),
            let gestureType = CGEventType(rawValue: 29),
            let gestureSubtypeField = CGEventField(rawValue: 110),
            let magnificationField = CGEventField(rawValue: 113),
            let phaseField = CGEventField(rawValue: 132)
        else { return }

        // These fields are undocumented but represent native trackpad magnification events.
        event.type = gestureType
        event.setIntegerValueField(gestureSubtypeField, value: 8)
        event.setDoubleValueField(magnificationField, value: sample.magnification)
        event.setIntegerValueField(phaseField, value: sample.phase.rawValue)
        event.post(tap: .cghidEventTap)
    }
}
