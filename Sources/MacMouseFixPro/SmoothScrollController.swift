import ApplicationServices
import Foundation

final class SmoothScrollController {
    private let marker: Int64
    private let lock = NSLock()
    private var pendingX = 0.0
    private var pendingY = 0.0
    private var carryX = 0.0
    private var carryY = 0.0
    private var latestSmoothness = 0.88
    private var timer: DispatchSourceTimer?
    private let source = CGEventSource(stateID: .hidSystemState)

    init(marker: Int64) {
        self.marker = marker
    }

    func enqueue(event: CGEvent, settings: MouseSettings) {
        let direction = settings.naturalScrolling ? -1.0 : 1.0
        let speed = max(0.2, min(4.0, settings.scrollSpeed))
        let smoothness = max(0.0, min(1.0, settings.smoothness))

        let rawY = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        let rawX = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
        let lineY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let lineX = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)

        let baseY = rawY != 0 ? Double(rawY) * 1.25 : Double(lineY) * 86.0
        let baseX = rawX != 0 ? Double(rawX) * 1.25 : Double(lineX) * 86.0
        let momentumBoost = 1.0 + smoothness * 0.78

        lock.lock()
        pendingY += baseY * speed * direction * momentumBoost
        pendingX += baseX * speed * direction * momentumBoost
        latestSmoothness = smoothness
        lock.unlock()

        ensureTimer()
    }

    func reset() {
        lock.lock()
        pendingX = 0
        pendingY = 0
        carryX = 0
        carryY = 0
        lock.unlock()

        DispatchQueue.main.async {
            self.timer?.cancel()
            self.timer = nil
        }
    }

    private func ensureTimer() {
        DispatchQueue.main.async {
            guard self.timer == nil else { return }
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now(), repeating: .milliseconds(8), leeway: .milliseconds(1))
            timer.setEventHandler { [weak self] in
                self?.tick()
            }
            self.timer = timer
            timer.resume()
        }
    }

    private func tick() {
        let output: (x: Int32, y: Int32, shouldStop: Bool)

        lock.lock()
        let easing = 0.045 + (1.0 - latestSmoothness) * 0.075
        let stepX = pendingX * easing
        let stepY = pendingY * easing

        pendingX -= stepX
        pendingY -= stepY
        carryX += stepX
        carryY += stepY

        let wholeX = Int32(carryX.rounded(.towardZero))
        let wholeY = Int32(carryY.rounded(.towardZero))
        carryX -= Double(wholeX)
        carryY -= Double(wholeY)

        let shouldStop =
            abs(pendingX) < 0.18 &&
            abs(pendingY) < 0.18 &&
            abs(carryX) < 0.98 &&
            abs(carryY) < 0.98
        output = (wholeX, wholeY, shouldStop)
        if shouldStop {
            pendingX = 0
            pendingY = 0
            carryX = 0
            carryY = 0
        }
        lock.unlock()

        if output.x != 0 || output.y != 0 {
            postPixelScroll(x: output.x, y: output.y)
        }

        if output.shouldStop {
            timer?.cancel()
            timer = nil
        }
    }

    private func postPixelScroll(x: Int32, y: Int32) {
        guard let scroll = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 2,
            wheel1: y,
            wheel2: x,
            wheel3: 0
        ) else { return }

        scroll.setIntegerValueField(.eventSourceUserData, value: marker)
        scroll.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        scroll.post(tap: .cghidEventTap)
    }
}
