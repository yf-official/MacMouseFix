import ApplicationServices
import Foundation

final class PointerSmoother {
    private var filteredX = 0.0
    private var filteredY = 0.0
    private var carryX = 0.0
    private var carryY = 0.0
    private var lastEventTime = DispatchTime.now().uptimeNanoseconds

    func reset() {
        filteredX = 0
        filteredY = 0
        carryX = 0
        carryY = 0
        lastEventTime = DispatchTime.now().uptimeNanoseconds
    }

    func transform(event: CGEvent, settings: MouseSettings) {
        guard settings.pointerSmoothing else {
            reset()
            return
        }

        let rawX = Double(event.getIntegerValueField(.mouseEventDeltaX))
        let rawY = Double(event.getIntegerValueField(.mouseEventDeltaY))
        guard rawX != 0 || rawY != 0 else { return }

        let now = DispatchTime.now().uptimeNanoseconds
        let intervalMS = Double(now - lastEventTime) / 1_000_000.0
        lastEventTime = now

        if intervalMS > 80 {
            reset()
        }

        let smoothness = max(0.0, min(0.8, settings.pointerSmoothness))
        let speed = max(0.5, min(2.0, settings.pointerSpeed))
        let magnitude = hypot(rawX, rawY)

        // Keep intentional fast motion responsive, smooth only small jittery deltas.
        let responsiveness = min(1.0, 0.34 + magnitude / 18.0)
        let alpha = max(0.18, 1.0 - smoothness * (1.0 - responsiveness))

        filteredX = filteredX * (1.0 - alpha) + rawX * alpha
        filteredY = filteredY * (1.0 - alpha) + rawY * alpha

        let microBoost = magnitude < 1.6 ? 1.08 : 1.0
        let adjustedX = filteredX * speed * microBoost + carryX
        let adjustedY = filteredY * speed * microBoost + carryY

        let outputX = adjustedX.rounded(.toNearestOrAwayFromZero)
        let outputY = adjustedY.rounded(.toNearestOrAwayFromZero)
        carryX = adjustedX - outputX
        carryY = adjustedY - outputY

        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(outputX))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(outputY))
    }
}
