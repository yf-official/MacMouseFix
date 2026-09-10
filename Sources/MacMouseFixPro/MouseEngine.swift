import AppKit
import ApplicationServices

final class MouseEngine {
    static let shared = MouseEngine()

    var onStatusChange: ((String) -> Void)?
    var onButtonEvent: ((Int, Int?, MouseAction?) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var settings = MouseSettings()
    private let settingsQueue = DispatchQueue(label: "MacMouseFixPro.settings")
    private let syntheticScrollMarker: Int64 = 0x4D4D4650
    private lazy var smoothScroller = SmoothScrollController(marker: syntheticScrollMarker)
    private let pointerSmoother = PointerSmoother()
    private let magnificationGesture = MagnificationGestureSimulator()
    private var activeMask: CGEventMask = 0
    private var pressedButtons = Set<Int>()
    private var sideButtonGestures = SideButtonGestureTracker()
    private var lastGestureActionTimes: [GestureActionKey: TimeInterval] = [:]

    private struct GestureActionKey: Hashable {
        let logicalButton: Int
        let direction: ScrollGestureDirection
    }

    private init() {}

    func start(with settings: MouseSettings) {
        settingsQueue.sync {
            self.settings = settings
        }

        guard eventTap == nil else {
            update(settings: settings)
            return
        }

        installEventTap(mask: eventMask(for: settings), enabled: settings.enabled)
    }

    private func installEventTap(mask: CGEventMask, enabled: Bool) {

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else {
                return Unmanaged.passUnretained(event)
            }
            let engine = Unmanaged<MouseEngine>.fromOpaque(refcon).takeUnretainedValue()
            return engine.handle(proxy: proxy, type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            let language = currentSettings().language
            onStatusChange?(language.text(
                "鼠标引擎启动失败。请授予辅助功能权限后重试。",
                "The mouse engine could not start. Grant Accessibility access and try again."
            ))
            return
        }

        eventTap = tap
        activeMask = mask
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        setTapEnabled(enabled)
        onStatusChange?(currentSettings().language.text(
            "鼠标引擎正在运行。",
            "The mouse engine is running."
        ))
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        activeMask = 0
        resetButtonState()
        smoothScroller.reset()
        pointerSmoother.reset()
        onStatusChange?(currentSettings().language.text(
            "鼠标引擎已停止。",
            "The mouse engine has stopped."
        ))
    }

    func update(settings: MouseSettings) {
        settingsQueue.sync {
            self.settings = settings
        }
        if !settings.enabled || !settings.smoothScroll {
            smoothScroller.reset()
        }
        if !settings.enabled || !settings.pointerSmoothing {
            pointerSmoother.reset()
        }
        if !settings.enabled {
            resetButtonState()
        }

        let desiredMask = eventMask(for: settings)
        if eventTap != nil, desiredMask != activeMask {
            removeEventTap()
            installEventTap(mask: desiredMask, enabled: settings.enabled)
            return
        }
        setTapEnabled(settings.enabled)
    }

    private func eventMask(for settings: MouseSettings) -> CGEventMask {
        var mask = eventBit(.otherMouseDown) |
            eventBit(.otherMouseUp) |
            eventBit(.scrollWheel)

        if settings.pointerSmoothing {
            mask |= eventBit(.mouseMoved) |
                eventBit(.leftMouseDragged) |
                eventBit(.rightMouseDragged) |
                eventBit(.otherMouseDragged)
        }
        return mask
    }

    private func eventBit(_ type: CGEventType) -> CGEventMask {
        CGEventMask(1) << type.rawValue
    }

    private func removeEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        activeMask = 0
        resetButtonState()
    }

    private func setTapEnabled(_ enabled: Bool) {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: enabled)
        let language = currentSettings().language
        onStatusChange?(enabled
            ? language.text("鼠标优化已启用。", "Mouse optimization is enabled.")
            : language.text("鼠标优化已暂停。", "Mouse optimization is paused."))
    }

    private func currentSettings() -> MouseSettings {
        settingsQueue.sync { settings }
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            resetButtonState()
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == syntheticScrollMarker {
            return Unmanaged.passUnretained(event)
        }

        let activeSettings = currentSettings()
        guard activeSettings.enabled else {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            pointerSmoother.transform(event: event, settings: activeSettings)
            return Unmanaged.passUnretained(event)

        case .otherMouseDown:
            let physicalButton = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            let logicalButton = activeSettings.logicalButton(forPhysicalButton: physicalButton)
            let mappedAction = logicalButton.map { action(for: $0, settings: activeSettings) }
            onButtonEvent?(physicalButton, logicalButton, mappedAction)
            guard let logicalButton, let action = mappedAction else {
                return Unmanaged.passUnretained(event)
            }
            if sideButtonGestures.press(
                physicalButton: physicalButton,
                logicalButton: logicalButton,
                clickAction: action,
                hasScrollGesture: activeSettings.hasScrollGesture(forButton: logicalButton)
            ) {
                return nil
            }
            if action == .passThrough {
                let language = activeSettings.language
                announce("\(MouseSettings.displayName(forCGButton: logicalButton, language: language)): \(action.menuTitle(for: language))")
                return Unmanaged.passUnretained(event)
            }
            guard pressedButtons.insert(physicalButton).inserted else { return nil }
            perform(action, button: logicalButton)
            return nil

        case .otherMouseUp:
            let physicalButton = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            if let heldButton = sideButtonGestures.release(physicalButton: physicalButton) {
                magnificationGesture.end(for: heldButton.logicalButton)
                if !heldButton.usedScrollGesture {
                    performDeferredClick(heldButton)
                }
                return nil
            }
            return pressedButtons.remove(physicalButton) == nil
                ? Unmanaged.passUnretained(event)
                : nil

        case .scrollWheel:
            let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) == 1
            if isContinuous {
                return Unmanaged.passUnretained(event)
            }
            if
                let direction = scrollGestureDirection(for: event),
                let heldButton = sideButtonGestures.activeButton
            {
                let gestureAction = activeSettings.scrollGestureAction(
                    forButton: heldButton.logicalButton,
                    direction: direction
                )
                if gestureAction != .passThrough {
                    _ = sideButtonGestures.markActiveScrollGestureUsed()
                    smoothScroller.reset()
                    let wheelDelta = scrollGestureDelta(for: event)
                    if magnificationGesture.update(
                        action: gestureAction,
                        wheelDelta: wheelDelta,
                        button: heldButton.logicalButton
                    ) {
                        let language = activeSettings.language
                        let context = "\(MouseSettings.displayName(forCGButton: heldButton.logicalButton, language: language)) + \(direction.menuTitle(for: language))"
                        announce("\(context): \(gestureAction.menuTitle(for: language))")
                        return nil
                    }
                    magnificationGesture.end(for: heldButton.logicalButton)
                    if shouldPerformGestureAction(
                        logicalButton: heldButton.logicalButton,
                        direction: direction
                    ) {
                        let language = activeSettings.language
                        let context = "\(MouseSettings.displayName(forCGButton: heldButton.logicalButton, language: language)) + \(direction.menuTitle(for: language))"
                        perform(gestureAction, button: heldButton.logicalButton, context: context)
                    }
                    return nil
                }
                magnificationGesture.end(for: heldButton.logicalButton)
            }
            if activeSettings.smoothScroll && !isContinuous {
                smoothScroller.enqueue(event: event, settings: activeSettings)
                return nil
            }
            transformScroll(event, settings: activeSettings)
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func action(for button: Int, settings: MouseSettings) -> MouseAction {
        settings.action(forButton: button)
    }

    private func perform(_ action: MouseAction, button: Int, context: String? = nil) {
        let language = currentSettings().language
        let prefix = "\(context ?? MouseSettings.displayName(forCGButton: button, language: language)): "
        switch action {
        case .passThrough:
            return
        case .back:
            Keyboard.commandLeftBracket()
        case .forward:
            Keyboard.commandRightBracket()
        case .missionControl:
            Keyboard.controlUp()
        case .appExpose:
            Keyboard.controlDown()
        case .showDesktop:
            Keyboard.showDesktop()
        case .launchpad:
            Keyboard.launchpad()
        case .spaceLeft:
            Keyboard.moveSpaceLeft()
        case .spaceRight:
            Keyboard.moveSpaceRight()
        case .previousTab:
            Keyboard.previousTab()
        case .nextTab:
            Keyboard.nextTab()
        case .newTab:
            Keyboard.newTab()
        case .closeTab:
            Keyboard.closeTab()
        case .refresh:
            Keyboard.refresh()
        case .copy:
            Keyboard.copy()
        case .paste:
            Keyboard.paste()
        case .undo:
            Keyboard.undo()
        case .redo:
            Keyboard.redo()
        case .zoomIn:
            magnificationGesture.pulse(action: .zoomIn)
        case .zoomOut:
            magnificationGesture.pulse(action: .zoomOut)
        case .pageUp:
            Keyboard.pageUp()
        case .pageDown:
            Keyboard.pageDown()
        case .escape:
            Keyboard.escape()
        case .returnKey:
            Keyboard.returnKey()
        case .screenshotArea:
            Keyboard.screenshotArea()
        case .lockScreen:
            Keyboard.lockScreen()
        case .middleClick:
            postMiddleClick()
        case .volumeUp:
            Keyboard.volumeUp()
        case .volumeDown:
            Keyboard.volumeDown()
        case .mute:
            Keyboard.mute()
        case .previousApp:
            Keyboard.previousApp()
        case .nextApp:
            Keyboard.nextApp()
        case .disabled:
            break
        }
        announce(prefix + action.menuTitle(for: language))
    }

    private func performDeferredClick(_ heldButton: SideButtonGestureTracker.HeldButton) {
        if heldButton.clickAction == .passThrough {
            postPhysicalButtonClick(heldButton.physicalButton)
        } else {
            perform(heldButton.clickAction, button: heldButton.logicalButton)
        }
    }

    private func scrollGestureDirection(for event: CGEvent) -> ScrollGestureDirection? {
        let delta = scrollGestureDelta(for: event)
        guard delta != 0 else { return nil }
        return delta > 0 ? .up : .down
    }

    private func scrollGestureDelta(for event: CGEvent) -> Double {
        let lineDelta = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let pointDelta = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        return Double(lineDelta != 0 ? lineDelta : pointDelta)
    }

    private func shouldPerformGestureAction(
        logicalButton: Int,
        direction: ScrollGestureDirection
    ) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        let key = GestureActionKey(logicalButton: logicalButton, direction: direction)
        if let lastTime = lastGestureActionTimes[key], now - lastTime < 0.075 {
            return false
        }
        lastGestureActionTimes[key] = now
        return true
    }

    private func resetButtonState() {
        magnificationGesture.end()
        pressedButtons.removeAll(keepingCapacity: true)
        sideButtonGestures.reset()
        lastGestureActionTimes.removeAll(keepingCapacity: true)
    }

    private func transformScroll(_ event: CGEvent, settings: MouseSettings) {
        let multiplier = max(0.2, min(4.0, settings.scrollSpeed))
        let direction = settings.naturalScrolling ? -1.0 : 1.0

        for field in [
            CGEventField.scrollWheelEventDeltaAxis1,
            CGEventField.scrollWheelEventDeltaAxis2,
            CGEventField.scrollWheelEventPointDeltaAxis1,
            CGEventField.scrollWheelEventPointDeltaAxis2,
            CGEventField.scrollWheelEventFixedPtDeltaAxis1,
            CGEventField.scrollWheelEventFixedPtDeltaAxis2
        ] {
            let value = Double(event.getIntegerValueField(field))
            let transformed = Int64((value * multiplier * direction).rounded())
            event.setIntegerValueField(field, value: transformed)
        }

        if settings.smoothScroll {
            event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        }
    }

    private func postMiddleClick() {
        guard let down = CGEvent(
            mouseEventSource: CGEventSource(stateID: .hidSystemState),
            mouseType: .otherMouseDown,
            mouseCursorPosition: CGEvent(source: nil)?.location ?? .zero,
            mouseButton: .center
        ) else { return }

        let up = CGEvent(
            mouseEventSource: CGEventSource(stateID: .hidSystemState),
            mouseType: .otherMouseUp,
            mouseCursorPosition: down.location,
            mouseButton: .center
        )
        down.setIntegerValueField(.mouseEventButtonNumber, value: 2)
        up?.setIntegerValueField(.mouseEventButtonNumber, value: 2)
        down.setIntegerValueField(.eventSourceUserData, value: syntheticScrollMarker)
        up?.setIntegerValueField(.eventSourceUserData, value: syntheticScrollMarker)
        down.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private func postPhysicalButtonClick(_ physicalButton: Int) {
        let source = CGEventSource(stateID: .hidSystemState)
        let location = CGEvent(source: nil)?.location ?? .zero
        guard let mouseButton = CGMouseButton(rawValue: UInt32(physicalButton)) else { return }
        let down = CGEvent(
            mouseEventSource: source,
            mouseType: .otherMouseDown,
            mouseCursorPosition: location,
            mouseButton: mouseButton
        )
        let up = CGEvent(
            mouseEventSource: source,
            mouseType: .otherMouseUp,
            mouseCursorPosition: location,
            mouseButton: mouseButton
        )

        down?.setIntegerValueField(.mouseEventButtonNumber, value: Int64(physicalButton))
        up?.setIntegerValueField(.mouseEventButtonNumber, value: Int64(physicalButton))
        down?.setIntegerValueField(.eventSourceUserData, value: syntheticScrollMarker)
        up?.setIntegerValueField(.eventSourceUserData, value: syntheticScrollMarker)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private func announce(_ message: String) {
        DispatchQueue.main.async {
            self.onStatusChange?(message)
        }
    }
}
