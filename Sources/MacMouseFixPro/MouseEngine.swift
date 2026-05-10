import AppKit
import ApplicationServices

final class MouseEngine {
    static let shared = MouseEngine()

    var onStatusChange: ((String) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var settings = MouseSettings()
    private let settingsQueue = DispatchQueue(label: "MacMouseFixPro.settings")
    private let syntheticScrollMarker: Int64 = 0x4D4D4650
    private lazy var smoothScroller = SmoothScrollController(marker: syntheticScrollMarker)
    private let pointerSmoother = PointerSmoother()

    private init() {}

    func start(with settings: MouseSettings) {
        update(settings: settings)

        guard eventTap == nil else {
            setTapEnabled(settings.enabled)
            return
        }

        let mask =
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else {
                return Unmanaged.passRetained(event)
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
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        setTapEnabled(settings.enabled)
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
        setTapEnabled(settings.enabled)
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
            return Unmanaged.passRetained(event)
        }

        let activeSettings = currentSettings()
        guard activeSettings.enabled else {
            return Unmanaged.passRetained(event)
        }

        switch type {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            pointerSmoother.transform(event: event, settings: activeSettings)
            return Unmanaged.passRetained(event)

        case .otherMouseDown:
            let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            let action = action(for: button, settings: activeSettings)
            if action == .passThrough {
                announce("\(MouseSettings.displayName(forCGButton: button))：保持原样")
                return Unmanaged.passRetained(event)
            }
            perform(action, button: button)
            return nil

        case .otherMouseUp:
            let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            let action = action(for: button, settings: activeSettings)
            return action == .passThrough ? Unmanaged.passRetained(event) : nil

        case .scrollWheel:
            if event.getIntegerValueField(.eventSourceUserData) == syntheticScrollMarker {
                return Unmanaged.passRetained(event)
            }
            let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) == 1
            if isContinuous {
                return Unmanaged.passRetained(event)
            }
            if activeSettings.smoothScroll && !isContinuous {
                smoothScroller.enqueue(event: event, settings: activeSettings)
                return nil
            }
            transformScroll(event, settings: activeSettings)
            return Unmanaged.passRetained(event)

        default:
            return Unmanaged.passRetained(event)
        }
    }

    private func action(for button: Int, settings: MouseSettings) -> MouseAction {
        settings.action(forButton: button)
    }

    private func perform(_ action: MouseAction, button: Int) {
        let prefix = "\(MouseSettings.displayName(forCGButton: button))："
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
            Keyboard.zoomIn()
            announce(prefix + "放大")
        case .zoomOut:
            Keyboard.zoomOut()
            announce(prefix + "缩小")
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
        case .disabled:
            announce(prefix + "按钮已禁用")
        }
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
        down.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private func announce(_ message: String) {
        DispatchQueue.main.async {
            self.onStatusChange?(message)
        }
    }
}
