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
            onStatusChange?("鼠标引擎启动失败。请授予辅助功能权限后重试。")
            return
        }

        eventTap = tap
        activeMask = mask
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        setTapEnabled(enabled)
        onStatusChange?("鼠标引擎正在运行。")
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
        onStatusChange?("鼠标引擎已停止。")
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
        onStatusChange?(enabled ? "鼠标优化已启用。" : "鼠标优化已暂停。")
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
                announce("\(MouseSettings.displayName(forCGButton: logicalButton))：保持原样")
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
                        let context = "\(MouseSettings.displayName(forCGButton: heldButton.logicalButton)) + \(direction.menuTitle)"
                        announce("\(context)：\(gestureAction.menuTitle)")
                        return nil
                    }
                    magnificationGesture.end(for: heldButton.logicalButton)
                    if shouldPerformGestureAction(
                        logicalButton: heldButton.logicalButton,
                        direction: direction
                    ) {
                        let context = "\(MouseSettings.displayName(forCGButton: heldButton.logicalButton)) + \(direction.menuTitle)"
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
        let prefix = "\(context ?? MouseSettings.displayName(forCGButton: button))："
        switch action {
        case .passThrough:
            break
        case .back:
            Keyboard.commandLeftBracket()
            announce(prefix + "后退")
        case .forward:
            Keyboard.commandRightBracket()
            announce(prefix + "前进")
        case .missionControl:
            Keyboard.controlUp()
            announce(prefix + "调度中心")
        case .appExpose:
            Keyboard.controlDown()
            announce(prefix + "App Expose")
        case .showDesktop:
            Keyboard.showDesktop()
            announce(prefix + "显示桌面")
        case .launchpad:
            Keyboard.launchpad()
            announce(prefix + "启动台")
        case .spaceLeft:
            Keyboard.moveSpaceLeft()
            announce(prefix + "切换到左侧桌面")
        case .spaceRight:
            Keyboard.moveSpaceRight()
            announce(prefix + "切换到右侧桌面")
        case .previousTab:
            Keyboard.previousTab()
            announce(prefix + "上一个标签页")
        case .nextTab:
            Keyboard.nextTab()
            announce(prefix + "下一个标签页")
        case .newTab:
            Keyboard.newTab()
            announce(prefix + "新建标签页")
        case .closeTab:
            Keyboard.closeTab()
            announce(prefix + "关闭标签页")
        case .refresh:
            Keyboard.refresh()
            announce(prefix + "刷新")
        case .copy:
            Keyboard.copy()
            announce(prefix + "复制")
        case .paste:
            Keyboard.paste()
            announce(prefix + "粘贴")
        case .undo:
            Keyboard.undo()
            announce(prefix + "撤销")
        case .redo:
            Keyboard.redo()
            announce(prefix + "重做")
        case .zoomIn:
            magnificationGesture.pulse(action: .zoomIn)
            announce(prefix + "捏合放大")
        case .zoomOut:
            magnificationGesture.pulse(action: .zoomOut)
            announce(prefix + "捏合缩小")
        case .pageUp:
            Keyboard.pageUp()
            announce(prefix + "上一页")
        case .pageDown:
            Keyboard.pageDown()
            announce(prefix + "下一页")
        case .escape:
            Keyboard.escape()
            announce(prefix + "Esc")
        case .returnKey:
            Keyboard.returnKey()
            announce(prefix + "回车")
        case .screenshotArea:
            Keyboard.screenshotArea()
            announce(prefix + "区域截图")
        case .lockScreen:
            Keyboard.lockScreen()
            announce(prefix + "锁定屏幕")
        case .middleClick:
            postMiddleClick()
            announce(prefix + "中键点击")
        case .volumeUp:
            Keyboard.volumeUp()
            announce(prefix + "增大音量")
        case .volumeDown:
            Keyboard.volumeDown()
            announce(prefix + "减小音量")
        case .mute:
            Keyboard.mute()
            announce(prefix + "静音 / 取消静音")
        case .previousApp:
            Keyboard.previousApp()
            announce(prefix + "上一个 App")
        case .nextApp:
            Keyboard.nextApp()
            announce(prefix + "下一个 App")
        case .disabled:
            announce(prefix + "按钮已禁用")
        }
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
